import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Read-only grants owned by the main app. This store never changes Finder scope.
public struct OpenWithFolderAccessStore: Sendable {
    public static let maximumBytes = 4 * 1024 * 1024
    public let file: URL

    public init(file: URL = FileMintStorage.directory.appendingPathComponent("open-with-folder-access.json")) {
        self.file = file
    }

    public func load() throws -> [String: Data] {
        do {
            var before = stat()
            let result = file.withUnsafeFileSystemRepresentation { $0.map { lstat($0, &before) } ?? -1 }
            if result != 0 {
                if errno == ENOENT { return [:] }
                throw OpenWithError.folderAccessFailed
            }
            guard before.st_mode & S_IFMT == S_IFREG, before.st_size > 0,
                  before.st_size <= Int64(Self.maximumBytes) else { throw OpenWithError.folderAccessFailed }
            let descriptor = file.withUnsafeFileSystemRepresentation {
                $0.map { open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) } ?? -1
            }
            guard descriptor >= 0 else { throw OpenWithError.folderAccessFailed }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            defer { try? handle.close() }
            var opened = stat()
            guard fstat(descriptor, &opened) == 0, opened.st_mode & S_IFMT == S_IFREG,
                  opened.st_dev == before.st_dev, opened.st_ino == before.st_ino,
                  opened.st_size == before.st_size,
                  let data = try handle.read(upToCount: Self.maximumBytes + 1),
                  data.count == Int(before.st_size) else { throw OpenWithError.folderAccessFailed }
            let bookmarks = try JSONDecoder().decode([String: Data].self, from: data)
            guard Self.isValid(bookmarks) else { throw OpenWithError.folderAccessFailed }
            return bookmarks
        } catch { throw OpenWithError.folderAccessFailed }
    }

    public func save(_ bookmarks: [String: Data]) throws {
        do {
            guard Self.isValid(bookmarks) else { throw OpenWithError.folderAccessFailed }
            let data = try JSONEncoder().encode(bookmarks)
            guard data.count <= Self.maximumBytes else { throw OpenWithError.folderAccessFailed }
            // A damaged or redirected existing file is not permission to overwrite it.
            _ = try load()
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        } catch { throw OpenWithError.folderAccessFailed }
    }

    /// Prefer the narrowest saved grant. Neither an old ancestor outside today's
    /// configured scope nor a similarly named sibling grants access to a target.
    /// The caller must still resolve and validate bookmarks on disk after starting access.
    public static func candidateDirectories(for directory: URL, bookmarks: [String: Data],
                                            folders: [URL]) -> [URL] {
        guard OpenWithPolicy.isLocalFileURL(directory), FolderScope.contains(directory, in: folders) else { return [] }
        return bookmarks.keys.filter { isValidPath($0) }.map { URL(fileURLWithPath: $0, isDirectory: true) }
            .filter { FolderScope.contains($0, in: folders) && FolderScope.contains(directory, in: [$0]) }
            .sorted {
                let lhs = $0.pathComponents.count, rhs = $1.pathComponents.count
                return lhs == rhs ? $0.path < $1.path : lhs > rhs
            }
    }

    private static func isValid(_ bookmarks: [String: Data]) -> Bool {
        bookmarks.count <= 1_024 && bookmarks.allSatisfy {
            isValidPath($0.key) && !$0.value.isEmpty && $0.value.count <= maximumBytes
        }
    }

    private static func isValidPath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.contains("\0") &&
            URL(fileURLWithPath: path).standardizedFileURL.path == path
    }
}
