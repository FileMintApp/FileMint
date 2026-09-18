import Foundation
import Darwin

public enum FileMoveError: Error, Equatable, Sendable {
    case invalidSelection, sourceChanged, invalidDestination, destinationExists, staleRequest, disabled
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
        for i in items.indices {
            for j in items.indices where i != j {
                if canonical[i].path == canonical[j].path ||
                    (items[i].isDirectory && FolderScope.contains(canonical[j], in: [canonical[i]])) {
                    throw FileMoveError.invalidSelection
                }
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
/// a move. FileManager moves links as links and supports cross-volume moves.
public struct FileMoveService: Sendable {
    public init() {}

    public func perform(batchID: UUID, to directory: URL, store: PendingFileMoveStore,
                        canContinue: @Sendable (PendingFileMove) -> Bool) throws {
        guard var pending = try store.load(), pending.id == batchID else { throw FileMoveError.staleRequest }
        try FileMovePolicy.validateDestination(directory, items: pending.items)
        while let item = pending.items.first {
            guard canContinue(pending) else { throw FileMoveError.disabled }
            guard try store.load()?.id == pending.id else { throw FileMoveError.staleRequest }
            try move(item: item, to: directory)
            pending.items.removeFirst()
            pending.id = UUID()
            try store.save(pending.items.isEmpty ? nil : pending)
        }
    }

    public func move(item: FileMoveItem, to directory: URL) throws {
        try item.validateIdentity()
        try FileMovePolicy.validateDestination(directory, items: [item])
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values.isDirectory == true, values.isPackage != true else { throw FileMoveError.invalidDestination }
        let destination = directory.appendingPathComponent(item.source.lastPathComponent)
        let manager = FileManager()
        // Includes dangling symlinks, which fileExists does not detect.
        if (try? manager.attributesOfItem(atPath: destination.path)) != nil { throw FileMoveError.destinationExists }
        // Exclusive rename closes the same-volume check/rename collision race.
        let result = item.source.withUnsafeFileSystemRepresentation { sourcePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath in
                renamex_np(sourcePath!, destinationPath!, UInt32(RENAME_EXCL))
            }
        }
        if result == 0 { return }
        let code = errno
        if code == EEXIST { throw FileMoveError.destinationExists }
        if code == EXDEV || code == ENOTSUP {
            try manager.moveItem(at: item.source, to: destination)
        } else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
    }
}
