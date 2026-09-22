import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Finish bytes in private staging, then publish exclusively on the same volume.
public enum BinaryFileWriter {
    public static func create(_ data: Data, in directory: URL, name: String,
                              collision: NameCollisionStrategy = .increment) throws -> FileCreationResult {
        let manager = FileManager.default
        var pattern = Array(directory.appendingPathComponent(".FileMint-create-XXXXXX").path.utf8CString)
        guard mkdtemp(&pattern) != nil else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let stagingDirectory = URL(fileURLWithPath: String(decoding: pattern.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self), isDirectory: true)
        defer { try? manager.removeItem(at: stagingDirectory) }
        let staging = stagingDirectory.appendingPathComponent("output")
        try data.write(to: staging, options: .withoutOverwriting)
        let first = directory.appendingPathComponent(FilenamePolicy.sanitizedFileName(name))
        var index = 1
        while true {
            let target = FilenamePolicy.candidateURL(for: first, index: index)
            do {
                #if canImport(Darwin)
                let result = staging.withUnsafeFileSystemRepresentation { source in
                    target.withUnsafeFileSystemRepresentation { destination in
                        renamex_np(source!, destination!, UInt32(RENAME_EXCL))
                    }
                }
                if result != 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
                #else
                try manager.linkItem(at: staging, to: target)
                #endif
                return FileCreationResult(createdURL: target, usedCollisionFallback: index > 1)
            } catch {
                // Includes existing directories and dangling symlinks. Never replace
                // an existing item for binary output, even with a stale preference.
                let failure = error as NSError
                if (failure.domain == NSCocoaErrorDomain && failure.code == NSFileWriteFileExistsError)
                    || (failure.domain == NSPOSIXErrorDomain && failure.code == Int(EEXIST)) {
                    if collision == .increment { index += 1; continue }
                    throw FileMintError.fileAlreadyExists(target)
                }
                throw error
            }
        }
    }
}
