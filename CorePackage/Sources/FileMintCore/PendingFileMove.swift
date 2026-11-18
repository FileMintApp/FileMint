import Foundation
import Darwin

public enum FileMoveError: Error, Equatable, Sendable {
    case invalidSelection, sourceChanged, invalidDestination, destinationExists, staleRequest, disabled
    case recoveryRequired(URL), retryDestination(URL), copiedSourceRetained
    case restoreBlocked(staged: URL, destination: URL), sourceRestored

    public var recoveryURL: URL? {
        if case .recoveryRequired(let url) = self { return url }
        return nil
    }
}

public struct FileMoveItem: Codable, Equatable, Sendable {
    public let source: URL
    public let canonicalParent: URL
    public let device: UInt64
    public let inode: UInt64
    public let createdAt: Date?
    public let isDirectory: Bool

    public static func capture(_ source: URL) throws -> FileMoveItem {
        guard source.isFileURL, source.path != "/", !source.lastPathComponent.isEmpty else {
            throw FileMoveError.invalidSelection
        }
        let source = source.standardizedFileURL
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        guard let device = attributes[.systemNumber] as? NSNumber,
              let inode = attributes[.systemFileNumber] as? NSNumber else { throw FileMoveError.sourceChanged }
        return FileMoveItem(source: source,
            canonicalParent: source.deletingLastPathComponent().resolvingSymlinksInPath(),
            device: device.uint64Value, inode: inode.uint64Value,
            createdAt: attributes[.creationDate] as? Date,
            isDirectory: attributes[.type] as? FileAttributeType == .typeDirectory)
    }

    func sameObject(as other: Self?) -> Bool {
        guard let other else { return false }
        return device == other.device && inode == other.inode && createdAt == other.createdAt && isDirectory == other.isDirectory
    }

    static func ifPresent(_ url: URL) throws -> Self? {
        var info = stat()
        if lstat(url.path, &info) == 0 { return try capture(url) }
        if errno == ENOENT { return nil }
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    public func validateIdentity() throws {
        guard try Self.capture(source) == self else { throw FileMoveError.sourceChanged }
    }
}

public struct PendingFileMove: Codable, Equatable, Sendable {
    public var id: UUID
    public var items: [FileMoveItem]
    public var bookmarks: [String: Data]
    // Optional so pending selections from older versions remain usable.
    var progress: FileMoveProgress?

    public init(items: [FileMoveItem], bookmarks: [String: Data] = [:]) {
        id = UUID()
        self.items = items
        self.bookmarks = bookmarks
    }

    public static func capture(selection: [URL], bookmarks: [String: Data] = [:]) throws -> PendingFileMove {
        guard !selection.isEmpty else { throw FileMoveError.invalidSelection }
        let items = try selection.map(FileMoveItem.capture)
        let canonical = items.map { $0.canonicalParent.appendingPathComponent($0.source.lastPathComponent) }
        let paths = canonical.map(\.standardizedFileURL.path)
        guard Set(paths).count == paths.count else { throw FileMoveError.invalidSelection }
        let directories = Set(items.indices.filter { items[$0].isDirectory }.map { paths[$0] })
        for path in paths {
            var parent = URL(fileURLWithPath: path).deletingLastPathComponent()
            while parent.path != "/" {
                if directories.contains(parent.path) { throw FileMoveError.invalidSelection }
                parent.deleteLastPathComponent()
            }
        }
        return PendingFileMove(items: items, bookmarks: bookmarks)
    }

    public static func validate(captured items: [FileMoveItem]) throws -> PendingFileMove {
        let current = try capture(selection: items.map(\.source))
        guard current.items == items else { throw FileMoveError.sourceChanged }
        return current
    }
}

public struct PendingFileMoveStore: Sendable {
    public let file: URL
    public init(file: URL = FileMintStorage.directory.appendingPathComponent("pending-move.json")) { self.file = file }

    public func load() throws -> PendingFileMove? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try JSONDecoder().decode(PendingFileMove?.self, from: Data(contentsOf: file))
    }

    public func replaceSelection(_ pending: PendingFileMove) throws {
        if let progress = try load()?.progress, !progress.originalRestored {
            throw FileMoveError.retryDestination(progress.destination)
        }
        try save(pending)
    }

    public func save(_ pending: PendingFileMove?) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(pending).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}

public enum FileMovePolicy {
    public static func isEnabled(_ preferences: FileMintPreferences, pending: PendingFileMove) -> Bool {
        FileToolsPolicy.availableTools(selection: pending.items.map(\.source), isItemMenu: true,
                                       preferences: preferences).contains(.move)
    }

    public static func destination(target: URL?, isContainer: Bool, selectionCount: Int,
                                   targetIsDirectory: Bool, targetIsPackage: Bool,
                                   isItemMenu: Bool, preferences: FileMintPreferences) -> URL? {
        guard let target, target.isFileURL,
              isContainer || (isItemMenu && selectionCount == 1 && targetIsDirectory && !targetIsPackage),
              FolderScope.contains(target, in: preferences.monitoredFolderURLs) else { return nil }
        return target
    }

    public static func validateDestination(_ destination: URL, items: [FileMoveItem]) throws {
        guard destination.isFileURL, !items.isEmpty else { throw FileMoveError.invalidDestination }
        let canonical = destination.resolvingSymlinksInPath().standardizedFileURL
        for item in items {
            let source = item.canonicalParent.appendingPathComponent(item.source.lastPathComponent)
            guard canonical.path != item.canonicalParent.path,
                  !(item.isDirectory && FolderScope.contains(canonical, in: [source])) else {
                throw FileMoveError.invalidDestination
            }
        }
    }
}
