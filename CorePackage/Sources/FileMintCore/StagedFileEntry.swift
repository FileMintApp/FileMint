import Foundation
import Darwin

/// Claims a selected directory entry before a destructive operation. A concurrent
/// replacement can enter the private staging directory, but it is never deleted
/// or published unless its filesystem identity matches the captured item.
struct StagedFileEntry {
    let original: URL
    let stagingDirectory: URL
    let staged: URL
    private let captured: FileMoveItem

    static func claim(_ item: FileMoveItem, beforeRename: () throws -> Void = {}) throws -> Self {
        try item.validateIdentity()
        let parent = item.source.deletingLastPathComponent()
        var pattern = Array(parent.appendingPathComponent(".FileMint-operation-XXXXXX").path.utf8CString)
        guard mkdtemp(&pattern) != nil else { throw posixError() }
        let directory = URL(fileURLWithPath: String(decoding: pattern.dropLast().map { UInt8(bitPattern: $0) },
                                                    as: UTF8.self), isDirectory: true)
        let claim = Self(original: item.source, stagingDirectory: directory,
                         staged: directory.appendingPathComponent("item"), captured: item)
        var succeeded = false
        defer { if !succeeded { claim.cleanup() } }
        try beforeRename()
        try renameExclusive(item.source, to: claim.staged)
        do {
            let actual = try FileMoveItem.capture(claim.staged)
            guard actual.device == item.device, actual.inode == item.inode,
                  actual.createdAt == item.createdAt, actual.isDirectory == item.isDirectory,
                  directory.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == item.canonicalParent else {
                throw FileMoveError.sourceChanged
            }
        } catch {
            try claim.restore()
            throw FileMoveError.sourceChanged
        }
        succeeded = true
        return claim
    }

    func validateIdentity() throws {
        let actual = try FileMoveItem.capture(staged)
        guard actual.device == captured.device, actual.inode == captured.inode,
              actual.createdAt == captured.createdAt, actual.isDirectory == captured.isDirectory else {
            throw FileMoveError.sourceChanged
        }
    }

    /// Restoring at the original name is exclusive. If another entry arrived,
    /// preserve the claimed item at a discoverable sibling name or in staging.
    func restore() throws {
        do { try Self.renameExclusive(staged, to: original); return }
        catch {
            let recovered = original.deletingLastPathComponent()
                .appendingPathComponent(".FileMint-recovered-\(UUID().uuidString)")
            do { try Self.renameExclusive(staged, to: recovered) }
            catch { throw FileMoveError.recoveryRequired(staged) }
            throw FileMoveError.recoveryRequired(recovered)
        }
    }

    /// rmdir cannot erase a staged item if recovery failed.
    func cleanup() {
        _ = stagingDirectory.withUnsafeFileSystemRepresentation { path in
            path.map { rmdir($0) } ?? -1
        }
    }

    static func renameExclusive(_ source: URL, to destination: URL) throws {
        let result = source.withUnsafeFileSystemRepresentation { sourcePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath in
                guard let sourcePath, let destinationPath else { return Int32(-1) }
                return renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL))
            }
        }
        if result != 0 { throw posixError() }
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}
