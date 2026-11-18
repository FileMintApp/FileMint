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

    static func prepare(_ item: FileMoveItem, component: String = "item") throws -> Self {
        try item.validateIdentity()
        let parent = item.source.deletingLastPathComponent()
        var pattern = Array(parent.appendingPathComponent(".FileMint-operation-XXXXXX").path.utf8CString)
        guard mkdtemp(&pattern) != nil else { throw posixError() }
        let directory = URL(fileURLWithPath: String(decoding: pattern.dropLast().map { UInt8(bitPattern: $0) },
                                                    as: UTF8.self), isDirectory: true)
        return Self(original: item.source, stagingDirectory: directory,
                    staged: directory.appendingPathComponent(component), captured: item)
    }

    static func existing(_ item: FileMoveItem, directory: FileMoveItem) throws -> Self {
        guard directory.isDirectory, directory.source.lastPathComponent.hasPrefix(".FileMint-operation-"),
              directory.source.deletingLastPathComponent().standardizedFileURL.path == item.source.deletingLastPathComponent().standardizedFileURL.path else {
            throw FileMoveError.sourceChanged
        }
        try directory.validateIdentity()
        return Self(original: item.source, stagingDirectory: directory.source,
                    staged: directory.source.appendingPathComponent(item.source.lastPathComponent), captured: item)
    }

    static func claim(_ item: FileMoveItem, beforeRename: () throws -> Void = {}) throws -> Self {
        let claim = try prepare(item)
        var succeeded = false
        defer { if !succeeded { claim.cleanup() } }
        try beforeRename()
        try claim.take()
        succeeded = true
        return claim
    }

    func take(keepStageOnConflict: Bool = false) throws {
        try Self.renameExclusive(original, to: staged)
        do {
            try validateIdentity()
            guard stagingDirectory.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == captured.canonicalParent else {
                throw FileMoveError.sourceChanged
            }
        } catch {
            try restore(keepStageOnConflict: keepStageOnConflict)
            throw FileMoveError.sourceChanged
        }
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
    func restore(keepStageOnConflict: Bool = false) throws {
        do { try Self.renameExclusive(staged, to: original); return }
        catch {
            if keepStageOnConflict { throw FileMoveError.recoveryRequired(staged) }
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
