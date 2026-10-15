import Foundation
import Darwin

public enum BatchRenameError: Error, Equatable, Sendable {
    case invalidSelection, sourceChanged, parentChanged, unsupportedFilesystem, unsupportedItem
    case protectedItem, unresolvedProtection, unavailable, disabled, stalePlan, occupiedTarget
    case recoveryRequired, corruptStore, storeTooLarge, invalidBookmark, stateChanged
}

/// Includes birth time and inode generation, not just a potentially reused inode.
public struct BatchRenameIdentity: Codable, Equatable, Hashable, Sendable {
    public let device: UInt64
    public let inode: UInt64
    public let generation: UInt32
    public let birthSeconds: Int64
    public let birthNanoseconds: Int64
    public let kind: UInt16

    init(_ value: stat) {
        device = UInt64(bitPattern: Int64(value.st_dev)); inode = value.st_ino
        generation = value.st_gen; birthSeconds = Int64(value.st_birthtimespec.tv_sec)
        birthNanoseconds = Int64(value.st_birthtimespec.tv_nsec); kind = value.st_mode & UInt16(S_IFMT)
    }
    public func matchesDirectory(at url: URL) throws -> Bool {
        try RenameDirectory(url, expected: self).identity == self
    }
    var isDirectory: Bool { kind == UInt16(S_IFDIR) }
    var isRegular: Bool { kind == UInt16(S_IFREG) }
    static func at(_ name: String, in fd: Int32) throws -> Self? {
        try RenameNamePolicy.validateRestorationComponent(name)
        var value = stat()
        if fstatat(fd, name, &value, AT_SYMLINK_NOFOLLOW) == 0 { return Self(value) }
        if errno == ENOENT { return nil }
        throw renamePOSIXError()
    }
    static func descriptor(_ fd: Int32) throws -> Self {
        var value = stat()
        guard fstat(fd, &value) == 0 else { throw renamePOSIXError() }
        return Self(value)
    }
    static func path(_ url: URL) throws -> Self? {
        var value = stat()
        if lstat(url.path, &value) == 0 { return Self(value) }
        if errno == ENOENT { return nil }
        throw renamePOSIXError()
    }
}

public struct BatchRenameSelection: Codable, Equatable, Sendable {
    public let id: UUID
    public let items: [FileMoveItem]
    public let parent: URL
    public let parentIdentity: BatchRenameIdentity
    public let itemIdentities: [BatchRenameIdentity]

    public static func capture(selection: [URL]) throws -> Self {
        guard (2...1_000).contains(selection.count), selection.allSatisfy(\.isFileURL),
              let first = selection.first else { throw BatchRenameError.invalidSelection }
        let lexicalParent = first.standardizedFileURL.deletingLastPathComponent()
        guard selection.allSatisfy({ $0.standardizedFileURL.deletingLastPathComponent() == lexicalParent }),
              Set(selection.map { Data($0.lastPathComponent.utf8) }).count == selection.count else {
            throw BatchRenameError.invalidSelection
        }
        let parent = lexicalParent.resolvingSymlinksInPath().standardizedFileURL
        // Finder can inspect selected-entry metadata without being authorized to
        // read their parent directory. Do not open an operation handle here:
        // the main app does that after its exact-parent authorization picker.
        guard let parentIdentity = try BatchRenameIdentity.path(parent), parentIdentity.isDirectory else {
            throw BatchRenameError.parentChanged
        }
        var items: [FileMoveItem] = [], identities: [BatchRenameIdentity] = []
        for url in selection {
            guard let identity = try BatchRenameIdentity.path(parent.appendingPathComponent(url.lastPathComponent)),
                  identity.isRegular || identity.isDirectory else { throw BatchRenameError.unsupportedItem }
            let item = try FileMoveItem.capture(url)
            guard item.canonicalParent == parent, item.device == identity.device, item.inode == identity.inode else {
                throw BatchRenameError.sourceChanged
            }
            items.append(item); identities.append(identity)
        }
        guard Set(identities.map { "\($0.device):\($0.inode)" }).count == identities.count else {
            throw BatchRenameError.invalidSelection
        }
        guard try BatchRenameIdentity.path(parent) == parentIdentity else { throw BatchRenameError.parentChanged }
        return Self(id: UUID(), items: items, parent: parent, parentIdentity: parentIdentity, itemIdentities: identities)
    }
}

final class RenameDirectory: @unchecked Sendable {
    let fd: Int32
    let url: URL
    let identity: BatchRenameIdentity
    init(_ url: URL, expected: BatchRenameIdentity? = nil) throws {
        guard url.isFileURL else { throw BatchRenameError.parentChanged }
        let opened = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard opened >= 0 else { throw renamePOSIXError() }
        do {
            let captured = try BatchRenameIdentity.descriptor(opened)
            guard captured.isDirectory, expected == nil || expected == captured else { throw BatchRenameError.parentChanged }
            fd = opened; self.url = url; identity = captured
        } catch { close(opened); throw error }
    }
    init(parent: RenameDirectory, component: String, expected: BatchRenameIdentity) throws {
        try RenameNamePolicy.validateRestorationComponent(component)
        let opened = openat(parent.fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard opened >= 0 else { throw renamePOSIXError() }
        do {
            guard try BatchRenameIdentity.descriptor(opened) == expected else { throw BatchRenameError.parentChanged }
            fd = opened; url = parent.url.appendingPathComponent(component); identity = expected
        } catch { close(opened); throw error }
    }
    deinit { close(fd) }
    func validatePath() throws {
        guard try BatchRenameIdentity.path(url) == identity,
              try BatchRenameIdentity.descriptor(fd) == identity else { throw BatchRenameError.parentChanged }
    }
}

func renamePOSIXError() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
func renameExclusive(from source: String, in sourceFD: Int32, to target: String, in targetFD: Int32) throws {
    try RenameNamePolicy.validateRestorationComponent(source)
    try RenameNamePolicy.validateRestorationComponent(target)
    guard renameatx_np(sourceFD, source, targetFD, target, UInt32(RENAME_EXCL)) == 0 else { throw renamePOSIXError() }
}

public struct BatchRenameAuthorization: Sendable {
    public let parentURL: URL
    public let parentBookmark: Data
    public let parentIdentity: BatchRenameIdentity
}

public final class BatchRenameSession: @unchecked Sendable {
    public let batch: BatchRenameBatch
    public let parentURL: URL
    public let caseSensitivity: BatchRenameCaseSensitivity
    public let nativeNameByteLimit: Int?
    let parent: RenameDirectory
    let identities: [UUID: BatchRenameIdentity]
    let bookmark: Data
    let observationRoots: [URL]
    let privateLocations: [URL]
    init(batch: BatchRenameBatch, parent: RenameDirectory, sensitive: Bool, nameLimit: Int?,
         identities: [UUID: BatchRenameIdentity], bookmark: Data, roots: [URL], privateLocations: [URL]) {
        self.batch = batch; self.parent = parent; parentURL = parent.url
        caseSensitivity = sensitive ? .sensitive : .insensitive; nativeNameByteLimit = nameLimit
        self.identities = identities; self.bookmark = bookmark; observationRoots = roots
        self.privateLocations = privateLocations
    }
}

public enum BatchRenameOutcome: String, Sendable { case renamed, undone, restored, recoveryRequired }
public enum BatchRenameActualState: String, Sendable { case original, staged, target, missing, ambiguous }
public struct BatchRenameResultRow: Sendable {
    public let id: UUID
    public let originalName: String
    public let targetName: String
    public let location: URL?
    public let state: BatchRenameActualState
}
public struct BatchRenameResult: Sendable {
    public let outcome: BatchRenameOutcome
    public let rows: [BatchRenameResultRow]
    /// Safe stage identifier, never an NSError description containing user paths.
    public let failureStage: String?
    public var renamedCount: Int { rows.filter { $0.state == .target && !$0.originalName.utf8.elementsEqual($0.targetName.utf8) }.count }
    public var restoredCount: Int { rows.filter { $0.state == .original && !$0.originalName.utf8.elementsEqual($0.targetName.utf8) }.count }
}
public struct BatchRenameUndoRow: Sendable {
    public let id: UUID
    public let currentName: String
    public let originalName: String
}
public struct BatchRenameUndoPreview: Sendable {
    public let rows: [BatchRenameUndoRow]
    public let parentURL: URL
    let receipt: RenameReceipt
    let bookmark: Data
    let parent: RenameDirectory
    let roots: [URL]
    let privateLocations: [URL]
}
