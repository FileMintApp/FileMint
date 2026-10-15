import Foundation
import Darwin

public struct BatchRenameAccessGrant: Codable, Equatable, Sendable {
    public let identity: BatchRenameIdentity
    public let bookmark: Data

    public init(identity: BatchRenameIdentity, bookmark: Data) {
        self.identity = identity
        self.bookmark = bookmark
    }

    /// Read saved metadata, never the current occupant of the remembered path.
    /// Keeping it in the bookmark also supports existing version-1 stores.
    public var volumeUUID: String? {
        let resources = NSURL.resourceValues(forKeys: [.volumeUUIDStringKey], fromBookmarkData: bookmark)
        let volume = resources?[.volumeUUIDStringKey] as? String
        return volume?.isEmpty == false ? volume : nil
    }

    public func matchesIdentity(_ current: BatchRenameIdentity, volumeUUID: String?) -> Bool {
        guard matchesFileIdentity(current) else { return false }
        if let savedVolume = self.volumeUUID { return savedVolume == volumeUUID }
        // A legacy bookmark without persistent volume identity cannot justify
        // relaxing the mount identity check.
        return identity.device == current.device
    }

    fileprivate func matchesFileIdentity(_ current: BatchRenameIdentity) -> Bool {
        identity.inode == current.inode && identity.generation == current.generation
            && identity.birthSeconds == current.birthSeconds && identity.birthNanoseconds == current.birthNanoseconds
            && identity.kind == current.kind
    }
}

public enum BatchRenameAccessStoreError: Error, Equatable, Sendable {
    case unavailable
}

/// Reusable exact-parent read/write grants. Operation cleanup never owns this file.
public struct BatchRenameAccessStore: Sendable {
    public static let maximumBytes = 4 * 1024 * 1024
    public static let maximumGrants = 1_024
    public let file: URL

    private struct Payload: Codable {
        let version: Int
        let grants: [String: BatchRenameAccessGrant]
    }

    public init(file: URL = FileMintStorage.directory.appendingPathComponent("batch-rename-folder-access.json")) {
        self.file = file
    }

    public func load() throws -> [String: BatchRenameAccessGrant] {
        do {
            guard file.isFileURL else { throw BatchRenameAccessStoreError.unavailable }
            var before = stat()
            if lstat(file.path, &before) != 0 {
                if errno == ENOENT { return [:] }
                throw BatchRenameAccessStoreError.unavailable
            }
            guard validFile(before), before.st_size > 0,
                  before.st_size <= Int64(Self.maximumBytes) else { throw BatchRenameAccessStoreError.unavailable }
            let descriptor = open(file.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
            guard descriptor >= 0 else { throw BatchRenameAccessStoreError.unavailable }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var opened = stat()
            guard fstat(descriptor, &opened) == 0, validFile(opened),
                  opened.st_dev == before.st_dev, opened.st_ino == before.st_ino,
                  opened.st_size == before.st_size,
                  let data = try handle.read(upToCount: Self.maximumBytes + 1),
                  data.count == Int(before.st_size) else { throw BatchRenameAccessStoreError.unavailable }
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            guard payload.version == 1, Self.validGrants(payload.grants) else {
                throw BatchRenameAccessStoreError.unavailable
            }
            return payload.grants
        } catch { throw BatchRenameAccessStoreError.unavailable }
    }

    public func save(_ grants: [String: BatchRenameAccessGrant]) throws {
        do {
            guard Self.validGrants(grants) else { throw BatchRenameAccessStoreError.unavailable }
            let data = try JSONEncoder().encode(Payload(version: 1, grants: grants))
            guard data.count <= Self.maximumBytes else { throw BatchRenameAccessStoreError.unavailable }
            // A damaged or redirected cache is not permission to discard its bytes.
            _ = try load()
            let directory = file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let temporary = directory.appendingPathComponent(".batch-rename-access-write-\(UUID().uuidString)")
            let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard descriptor >= 0 else { throw BatchRenameAccessStoreError.unavailable }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            var published = false
            defer {
                try? handle.close()
                if !published { _ = unlink(temporary.path) }
            }
            // Permission/write/close failures must occur before publication. In
            // particular, never leave a first-save 0644 file that load() rejects.
            guard fchmod(descriptor, 0o600) == 0 else { throw BatchRenameAccessStoreError.unavailable }
            try handle.write(contentsOf: data)
            try handle.close()
            guard rename(temporary.path, file.path) == 0 else { throw BatchRenameAccessStoreError.unavailable }
            published = true
        } catch { throw BatchRenameAccessStoreError.unavailable }
    }

    /// Called only after the app validates the complete request and current scope.
    public func remember(parent: URL, identity: BatchRenameIdentity, bookmark: Data) throws {
        guard parent.isFileURL else { throw BatchRenameAccessStoreError.unavailable }
        let old = try load()
        let grant = BatchRenameAccessGrant(identity: identity, bookmark: bookmark)
        let volume = grant.volumeUUID
        var grants = old.filter { !$0.value.matchesIdentity(identity, volumeUUID: volume) }
        grants[parent.standardizedFileURL.path] = grant
        if grants != old { try save(grants) }
    }

    /// Exact paths are considered even after replacement, so the caller can require
    /// renewed consent. Other paths are only candidates: the app must validate
    /// the persistent volume identity after starting the saved bookmark's access.
    public static func candidates(for parent: URL, identity: BatchRenameIdentity,
                                  grants: [String: BatchRenameAccessGrant]) -> [(path: String, grant: BatchRenameAccessGrant)] {
        guard parent.isFileURL else { return [] }
        return grants.filter { validPath($0.key) && ($0.key == parent.path || $0.value.matchesFileIdentity(identity)) }
            .sorted { lhs, rhs in
                if (lhs.key == parent.path) != (rhs.key == parent.path) { return lhs.key == parent.path }
                return lhs.key < rhs.key
            }.map { (path: $0.key, grant: $0.value) }
    }

    private func validFile(_ value: stat) -> Bool {
        value.st_mode & S_IFMT == S_IFREG && value.st_nlink == 1 && value.st_uid == geteuid()
            && value.st_mode & 0o777 == 0o600
    }

    private static func validGrants(_ grants: [String: BatchRenameAccessGrant]) -> Bool {
        grants.count <= maximumGrants && grants.allSatisfy {
            validPath($0.key) && $0.value.identity.isDirectory && !$0.value.bookmark.isEmpty
                && $0.value.bookmark.count <= maximumBytes
        }
    }

    private static func validPath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.contains("\0") && URL(fileURLWithPath: path).standardizedFileURL.path == path
    }
}
