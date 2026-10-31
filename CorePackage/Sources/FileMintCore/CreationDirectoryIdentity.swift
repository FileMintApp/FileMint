import Darwin
import Foundation

/// Only metadata of the selected directory; never enumerates it or grants access.
public struct CreationDirectoryIdentity: Equatable, Sendable {
    let device: Int32
    let inode: UInt64
    let birthSeconds: Int64
    let birthNanos: Int64

    init(_ value: stat) {
        device = value.st_dev
        inode = value.st_ino
        birthSeconds = Int64(value.st_birthtimespec.tv_sec)
        birthNanos = Int64(value.st_birthtimespec.tv_nsec)
    }

    public static func capture(_ url: URL) throws -> Self {
        var value = stat()
        guard OpenWithPolicy.isLocalFileURL(url) else { throw FileMintError.destinationIsNotDirectory(url) }
        guard stat(url.path, &value) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        guard value.st_mode & S_IFMT == S_IFDIR else { throw FileMintError.destinationIsNotDirectory(url) }
        return Self(value)
    }
}

/// External drafts bind writes to the admitted directory object. Opening a
/// search-only descriptor avoids requiring a read of directory contents.
enum PinnedCreationWriter {
    static func create(in directory: URL, expected: CreationDirectoryIdentity, name: String,
                       collision: NameCollisionStrategy, kind: CreatedContentKind,
                       bytes: (String) -> Data) throws -> FileCreationResult {
        let parent = open(directory.path, O_SEARCH | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw posix() }
        defer { close(parent) }
        var parentMetadata = stat()
        guard fstat(parent, &parentMetadata) == 0 else { throw posix() }
        guard parentMetadata.st_mode & S_IFMT == S_IFDIR, CreationDirectoryIdentity(parentMetadata) == expected else {
            throw FileMintError.destinationChanged
        }
        func validatePath() throws {
            guard try CreationDirectoryIdentity.capture(directory) == expected else { throw FileMintError.destinationChanged }
        }
        try validatePath()
        let stageName = ".FileMint-create-" + UUID().uuidString
        guard mkdirat(parent, stageName, 0o700) == 0 else { throw posix() }
        var stageMetadata = stat()
        guard fstatat(parent, stageName, &stageMetadata, AT_SYMLINK_NOFOLLOW) == 0 else { throw posix() }
        let stage = openat(parent, stageName, O_SEARCH | O_NOFOLLOW | O_CLOEXEC)
        guard stage >= 0 else {
            let error = posix()
            var current = stat()
            if fstatat(parent, stageName, &current, AT_SYMLINK_NOFOLLOW) == 0,
               current.st_dev == stageMetadata.st_dev, current.st_ino == stageMetadata.st_ino {
                _ = unlinkat(parent, stageName, AT_REMOVEDIR)
            }
            throw error
        }
        var openedStage = stat()
        guard fstat(stage, &openedStage) == 0 else { let error = posix(); close(stage); throw error }
        guard openedStage.st_dev == stageMetadata.st_dev, openedStage.st_ino == stageMetadata.st_ino else {
            close(stage)
            throw FileMintError.destinationChanged
        }
        defer {
            _ = unlinkat(stage, "output", 0)
            // Clean only the exact private directory this invocation created.
            var current = stat()
            if fstatat(parent, stageName, &current, AT_SYMLINK_NOFOLLOW) == 0,
               current.st_dev == stageMetadata.st_dev, current.st_ino == stageMetadata.st_ino {
                _ = unlinkat(parent, stageName, AT_REMOVEDIR)
            }
            close(stage)
        }
        let output = openat(stage, "output", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o666)
        guard output >= 0 else { throw posix() }
        defer { close(output) }
        let first = directory.appendingPathComponent(FilenamePolicy.sanitizedFileName(name))
        var index = 1
        while true {
            let target = FilenamePolicy.candidateURL(for: first, index: index)
            let data = bytes(target.lastPathComponent)
            guard ftruncate(output, 0) == 0, lseek(output, 0, SEEK_SET) >= 0 else { throw posix() }
            try data.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let count = write(output, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { throw posix(count == 0 ? EIO : errno) }
                    offset += count
                }
            }
            var written = stat()
            guard fstat(output, &written) == 0 else { throw posix() }
            let identity = CreatedFileIdentity(written)
            try validatePath()
            let result: Int32
            if collision == .replace, kind == .text {
                result = renameat(stage, "output", parent, target.lastPathComponent)
            } else {
                result = renameatx_np(stage, "output", parent, target.lastPathComponent, UInt32(RENAME_EXCL))
            }
            if result == 0 {
                return FileCreationResult(createdURL: target, usedCollisionFallback: index > 1,
                                          identity: identity, contentKind: kind)
            }
            let failure = errno
            if failure == EEXIST {
                if collision == .increment { index += 1; continue }
                throw FileMintError.fileAlreadyExists(target)
            }
            throw posix(failure)
        }
    }

    private static func posix(_ code: Int32 = errno) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code))
    }
}
