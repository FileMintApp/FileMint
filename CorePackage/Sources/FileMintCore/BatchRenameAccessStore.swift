import Foundation
import Darwin

public struct BatchRenameAccessGrant: Codable, Equatable, Sendable {
    public let identity: BatchRenameIdentity
    public let bookmark: Data

    public init(identity: BatchRenameIdentity, bookmark: Data) {
        self.identity = identity
        self.bookmark = bookmark
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
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch { throw BatchRenameAccessStoreError.unavailable }
    }

    /// Called only after the app validates the complete request and current scope.
    public func remember(parent: URL, identity: BatchRenameIdentity, bookmark: Data) throws {
        guard parent.isFileURL else { throw BatchRenameAccessStoreError.unavailable }
        let old = try load()
        var grants = old.filter { $0.value.identity != identity }
        grants[parent.standardizedFileURL.path] = .init(identity: identity, bookmark: bookmark)
        if grants != old { try save(grants) }
    }

    /// Exact paths are considered even after replacement, so the caller can require
    /// renewed consent. Other paths qualify only for the same captured directory.
    public static func candidates(for parent: URL, identity: BatchRenameIdentity,
                                  grants: [String: BatchRenameAccessGrant]) -> [(path: String, grant: BatchRenameAccessGrant)] {
        guard parent.isFileURL else { return [] }
        return grants.filter { validPath($0.key) && ($0.key == parent.path || $0.value.identity == identity) }
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
