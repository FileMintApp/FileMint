import Foundation
import Darwin

public enum FileMoveError: Error, Equatable, Sendable {
    case invalidSelection, sourceChanged, invalidDestination, destinationExists, staleRequest, disabled
    case recoveryRequired(URL)

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

    public func validateIdentity() throws {
        guard try Self.capture(source) == self else { throw FileMoveError.sourceChanged }
    }
}

public struct PendingFileMove: Codable, Equatable, Sendable {
    public var id: UUID
    public var items: [FileMoveItem]
    public var bookmarks: [String: Data]

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
}

public struct PendingFileMoveStore: Sendable {
    public let file: URL
    public init(file: URL = FileMintStorage.directory.appendingPathComponent("pending-move.json")) { self.file = file }

    public func load() throws -> PendingFileMove? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try JSONDecoder().decode(PendingFileMove?.self, from: Data(contentsOf: file))
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

/// Called off the main thread after authorization. No delegate can silently skip
/// a move. Cross-volume fallback copies to private destination staging first.
public struct FileMoveService: Sendable {
    public init() {}

    public func perform(batchID: UUID, to directory: URL, store: PendingFileMoveStore,
                        canContinue: @Sendable (PendingFileMove) -> Bool) throws {
        try performChecked(batchID: batchID, to: directory, store: store) { pending, _ in canContinue(pending) }
    }

    public func performPerItem(batchID: UUID, to directory: URL, store: PendingFileMoveStore,
                               canContinue: @Sendable (FileMoveItem) -> Bool) throws {
        try performChecked(batchID: batchID, to: directory, store: store) { _, item in canContinue(item) }
    }

    private func performChecked(batchID: UUID, to directory: URL, store: PendingFileMoveStore,
                                canContinue: @Sendable (PendingFileMove, FileMoveItem) -> Bool) throws {
        guard var pending = try store.load(), pending.id == batchID else { throw FileMoveError.staleRequest }
        try FileMovePolicy.validateDestination(directory, items: pending.items)
        while let item = pending.items.first {
            guard canContinue(pending, item) else { throw FileMoveError.disabled }
            guard try store.load()?.id == pending.id else { throw FileMoveError.staleRequest }
            try move(item: item, to: directory)
            pending.items.removeFirst()
            pending.id = UUID()
            try store.save(pending.items.isEmpty ? nil : pending)
        }
    }

    public func move(item: FileMoveItem, to directory: URL) throws {
        try move(item: item, to: directory, forceCopy: false)
    }

    /// The forced route lets Core tests exercise the same copy-and-publish path
    /// used when rename reports a cross-volume boundary.
    func move(item: FileMoveItem, to directory: URL, forceCopy: Bool) throws {
        try item.validateIdentity()
        try FileMovePolicy.validateDestination(directory, items: [item])
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values.isDirectory == true, values.isPackage != true else { throw FileMoveError.invalidDestination }
        let destinationIdentity = try? FileMoveItem.capture(directory)
        let destination = directory.appendingPathComponent(item.source.lastPathComponent)
        let claim = try StagedFileEntry.claim(item)
        defer { claim.cleanup() }
        do {
            try destinationIdentity?.validateIdentity()
            try claim.validateIdentity()
            if forceCopy {
                try copyAcrossVolumes(claim: claim, to: destination, directory: directory,
                                      destinationIdentity: destinationIdentity)
            } else {
                do {
                    try StagedFileEntry.renameExclusive(claim.staged, to: destination)
                } catch {
                    let code = (error as NSError).code
                    if code == EEXIST { throw FileMoveError.destinationExists }
                    if code == EXDEV || code == ENOTSUP {
                        try copyAcrossVolumes(claim: claim, to: destination, directory: directory,
                                              destinationIdentity: destinationIdentity)
                    } else { throw error }
                }
            }
        } catch {
            if (try? FileMoveItem.capture(claim.staged)) != nil { try claim.restore() }
            throw error
        }
    }

    private func copyAcrossVolumes(claim: StagedFileEntry, to destination: URL, directory: URL,
                                   destinationIdentity: FileMoveItem?) throws {
        var pattern = Array(directory.appendingPathComponent(".FileMint-move-XXXXXX").path.utf8CString)
        guard mkdtemp(&pattern) != nil else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let staging = URL(fileURLWithPath: String(decoding: pattern.dropLast().map { UInt8(bitPattern: $0) },
                                                  as: UTF8.self), isDirectory: true)
        let stagedIdentity = try FileMoveItem.capture(staging)
        defer {
            if (try? stagedIdentity.validateIdentity()) != nil { try? FileManager.default.removeItem(at: staging) }
        }
        let copy = staging.appendingPathComponent("item")
        try FileManager.default.copyItem(at: claim.staged, to: copy)
        try claim.validateIdentity()
        try destinationIdentity?.validateIdentity()
        do { try StagedFileEntry.renameExclusive(copy, to: destination) }
        catch {
            if (error as NSError).code == EEXIST { throw FileMoveError.destinationExists }
            throw error
        }
        try FileManager.default.removeItem(at: claim.staged)
    }
}
