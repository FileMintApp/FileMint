import Foundation
import CryptoKit
import Darwin

struct RenameRecordRow: Codable, Equatable, Sendable {
    let id: UUID
    let original: String
    let target: String
    let slot: String
    let identity: BatchRenameIdentity
    var changes: Bool { !original.utf8.elementsEqual(target.utf8) }
}
struct RenameReceipt: Codable, Equatable, Sendable {
    let version: Int
    let id: UUID
    let parent: URL
    let parentIdentity: BatchRenameIdentity
    let bookmark: Data
    let sensitive: Bool
    let rows: [RenameRecordRow]
    func validate() throws {
        guard version == 1, parent.isFileURL, parentIdentity.isDirectory, !bookmark.isEmpty,
              (1...1_000).contains(rows.count), Set(rows.map(\.id)).count == rows.count,
              Set(rows.map(\.identity)).count == rows.count else { throw BatchRenameError.corruptStore }
        for row in rows {
            try RenameNamePolicy.validateRestorationComponent(row.original)
            try RenameNamePolicy.validateRestorationComponent(row.target)
            try RenameNamePolicy.validateRestorationComponent(row.slot)
            guard row.slot == row.id.uuidString, row.original.utf8.count <= 1_024,
                  row.target.utf8.count <= 1_024,
                  row.identity.isDirectory || row.identity.isRegular else { throw BatchRenameError.corruptStore }
        }
        guard Set(rows.map { RenameNamePolicy.namespaceKey($0.original, caseSensitive: sensitive) }).count == rows.count,
              Set(rows.map { RenameNamePolicy.namespaceKey($0.target, caseSensitive: sensitive) }).count == rows.count else {
            throw BatchRenameError.corruptStore
        }
    }
    var authorization: BatchRenameAuthorization {
        .init(parentURL: parent, parentBookmark: bookmark, parentIdentity: parentIdentity)
    }
}
struct RenameManifest: Codable, Sendable {
    let version: Int
    let receipt: RenameReceipt
    let isUndo: Bool
    let stageName: String
    let stageIdentity: BatchRenameIdentity
    func validate() throws {
        try receipt.validate()
        guard version == 1, stageName == ".FileMint-rename-\(receipt.id.uuidString)",
              stageIdentity.isDirectory, stageIdentity.device == receipt.parentIdentity.device else {
            throw BatchRenameError.corruptStore
        }
    }
}
struct RenameJournal: Codable, Sendable {
    let version: Int
    let operationID: UUID
    var states: [String: String]
}
struct RenameRetirement: Codable, Sendable {
    let exportDigest: String
    let exportURL: URL
    let fileDigests: [String: String]
}
struct RenamePreparation: Codable, Sendable {
    let parent: URL
    let parentIdentity: BatchRenameIdentity
    let bookmark: Data
    let stageName: String
}
struct RenameIndex: Codable, Sendable {
    let version: Int
    let operationID: UUID
    let manifestDigest: String
    /// active, committed, retired. A committed index is the atomic commit marker.
    let state: String
    let committedReceipt: RenameReceipt?
    let consumesReceipt: Bool
    let retirement: RenameRetirement?
    var cleanupDigests: [String: String]? = nil
    var receiptBeforeDigest: String? = nil
    var preparation: RenamePreparation? = nil
}

public struct BatchRenameStoreStatus: Sendable {
    public let hasUnresolvedOperation: Bool
    public let canUndo: Bool
    public let requiresMetadataFinalization: Bool
    public let isCorrupt: Bool
    public let requiresCommittedCleanup: Bool
    init(hasUnresolvedOperation: Bool, canUndo: Bool, requiresMetadataFinalization: Bool,
         isCorrupt: Bool, requiresCommittedCleanup: Bool = false) {
        self.hasUnresolvedOperation = hasUnresolvedOperation; self.canUndo = canUndo
        self.requiresMetadataFinalization = requiresMetadataFinalization
        self.isCorrupt = isCorrupt; self.requiresCommittedCleanup = requiresCommittedCleanup
    }
}

/// The caller serializes access with the application operation coordinator.
/// All access is to these four fixed private names; decoded paths never select control files.
public struct BatchRenameStore: Sendable {
    public static let maximumBytes = 8 * 1_024 * 1_024
    public let directory: URL
    var checkpoint: (@Sendable (String) throws -> Void)?
    static let controlNames = ["index.json", "manifest.json", "journal.json", "receipt.json"]
    static let scratchNames = controlNames.map { "pending-" + $0 }
    static let names = controlNames + scratchNames
    public init(directory: URL = FileMintStorage.directory.appendingPathComponent("batch-rename", isDirectory: true)) {
        self.directory = directory
    }

    public func status() -> BatchRenameStoreStatus {
        do {
            let raw = try snapshot()
            if let indexData = raw["index.json"] {
                let index = try decodeIndex(indexData)
                if index.state == "retired" { try validateRetirement(index) }
                else if Self.scratchNames.contains(where: { raw[$0] != nil }) { throw BatchRenameError.corruptStore }
                else if ["active", "committed"].contains(index.state) { _ = try manifest() }
                else { try validateCompleted(index) }
                return .init(hasUnresolvedOperation: true, canUndo: false,
                             requiresMetadataFinalization: ["retired", "committedClean", "restored"].contains(index.state), isCorrupt: false,
                             requiresCommittedCleanup: index.state == "committed")
            }
            guard raw["manifest.json"] == nil, raw["journal.json"] == nil,
                  !Self.scratchNames.contains(where: { raw[$0] != nil }) else { throw BatchRenameError.corruptStore }
            if let data = raw["receipt.json"] { try JSONDecoder().decode(RenameReceipt.self, from: data).validate() }
            return .init(hasUnresolvedOperation: false, canUndo: raw["receipt.json"] != nil,
                         requiresMetadataFinalization: false, isCorrupt: false)
        } catch { return .init(hasUnresolvedOperation: true, canUndo: false, requiresMetadataFinalization: false, isCorrupt: true) }
    }
    public func recoveryAuthorization() throws -> BatchRenameAuthorization? {
        guard let data = try read("index.json") else { return nil }
        let index = try decodeIndex(data)
        guard ["active", "committed"].contains(index.state) else { return nil }
        return try manifest().receipt.authorization
    }
    public func undoAuthorization() throws -> BatchRenameAuthorization? {
        guard !status().hasUnresolvedOperation else { throw BatchRenameError.recoveryRequired }
        return try receipt()?.authorization
    }
    public func forgetReceipt() throws {
        guard !status().hasUnresolvedOperation else { throw BatchRenameError.recoveryRequired }
        if let data = try read("receipt.json") { try remove("receipt.json", expected: digest(data)) }
    }
    public func exportAndRetire(to destination: URL) throws {
        guard destination.isFileURL, !FolderScope.contains(destination, in: [directory]) else {
            throw BatchRenameError.invalidSelection
        }
        let before = try snapshot()
        guard !before.isEmpty, status().hasUnresolvedOperation else { throw BatchRenameError.stateChanged }
        // This envelope intentionally stores opaque bytes, even for unsupported schemas.
        let export = try JSONEncoder().encode(RenameEvidence(version: 1, files: before))
        try RenameNamePolicy.validateRestorationComponent(destination.lastPathComponent)
        // NSSavePanel grants the chosen file, not read access to its parent.
        // Keep this descriptor through write and read-back verification.
        let fd = open(destination.path, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw renamePOSIXError() }
        defer { close(fd) }
        let identity = try BatchRenameIdentity.descriptor(fd)
        var filesystem = statfs()
        guard fstatfs(fd, &filesystem) == 0, filesystem.f_flags & UInt32(MNT_LOCAL) != 0 else {
            throw BatchRenameError.unsupportedFilesystem
        }
        try writeAll(export, fd: fd)
        guard fsync(fd) == 0, lseek(fd, 0, SEEK_SET) == 0 else { throw renamePOSIXError() }
        try checkpoint?("export-written")
        let saved = try readDescriptor(fd, maximum: export.count)
        guard saved == export, try BatchRenameIdentity.path(destination) == identity,
              try snapshot() == before else { throw BatchRenameError.stateChanged }
        let marker = RenameIndex(version: 1, operationID: UUID(), manifestDigest: "", state: "retired",
                                 committedReceipt: nil, consumesReceipt: true,
                                 retirement: .init(exportDigest: digest(export), exportURL: destination,
                                                   fileDigests: before.mapValues(digest)))
        try saveData(JSONEncoder().encode(marker), name: "index.json", reusingExportedScratch: before)
        try checkpoint?("retirement-marker")
        try finalizeRetirement()
    }
    public func finalizeRetirement() throws {
        guard let raw = try read("index.json") else { throw BatchRenameError.stateChanged }
        let marker = try decodeIndex(raw)
        try validateRetirement(marker)
        let retirement = marker.retirement!
        // Only marker-bound fixed control files may be removed. No user-directory access.
        for name in Self.names where name != "index.json" {
            if let actual = try read(name) {
                guard let expected = retirement.fileDigests[name], digest(actual) == expected else {
                    throw BatchRenameError.stateChanged
                }
                try remove(name, expected: expected)
            }
        }
        try remove("index.json", expected: digest(raw))
    }

    func receipt() throws -> RenameReceipt? {
        guard let data = try read("receipt.json") else { return nil }
        let receipt = try JSONDecoder().decode(RenameReceipt.self, from: data)
        try receipt.validate(); return receipt
    }
    func manifest() throws -> RenameManifest {
        guard let raw = try read("index.json"), let data = try read("manifest.json") else { throw BatchRenameError.corruptStore }
        let index = try decodeIndex(raw)
        try rejectScratch()
        guard index.state != "retired", digest(data) == index.manifestDigest else { throw BatchRenameError.corruptStore }
        let result = try JSONDecoder().decode(RenameManifest.self, from: data)
        try result.validate()
        guard result.receipt.id == index.operationID else { throw BatchRenameError.corruptStore }
        // Journals are clues, but corruption is never silently ignored.
        if let journalData = try read("journal.json") {
            let journal = try JSONDecoder().decode(RenameJournal.self, from: journalData)
            guard journal.version == 1, journal.operationID == result.receipt.id,
                  journal.states.count <= 1_000 else { throw BatchRenameError.corruptStore }
        } else if index.state == "active" { throw BatchRenameError.corruptStore }
        return result
    }
    /// Reserve the one bounded slot before creating a sibling staging directory.
    /// An interrupted preparation has no authority to mutate user entries; its raw
    /// record is retained for explicit export if the full manifest was not saved.
    func reservePreparation(_ receipt: RenameReceipt) throws {
        guard !status().hasUnresolvedOperation else { throw BatchRenameError.recoveryRequired }
        var reservation = RenameIndex(version: 1, operationID: receipt.id, manifestDigest: "", state: "preparing",
                                      committedReceipt: nil, consumesReceipt: false, retirement: nil)
        reservation.receiptBeforeDigest = try read("receipt.json").map(digest)
        reservation.preparation = .init(parent: receipt.parent, parentIdentity: receipt.parentIdentity,
                                        bookmark: receipt.bookmark, stageName: ".FileMint-rename-\(receipt.id.uuidString)")
        try save(reservation, name: "index.json")
    }
    func discardEmptyPreparation(operationID: UUID) throws {
        try rejectScratch()
        guard let data = try read("index.json"), try read("manifest.json") == nil, try read("journal.json") == nil else {
            throw BatchRenameError.stateChanged
        }
        let index = try decodeIndex(data)
        guard index.state == "preparing", index.operationID == operationID else { throw BatchRenameError.stateChanged }
        try remove("index.json", expected: digest(data))
    }
    func begin(_ manifest: RenameManifest) throws {
        try rejectScratch()
        guard let raw = try read("index.json"), try read("manifest.json") == nil, try read("journal.json") == nil else {
            throw BatchRenameError.recoveryRequired
        }
        let reservation = try decodeIndex(raw)
        guard reservation.state == "preparing", reservation.operationID == manifest.receipt.id else {
            throw BatchRenameError.recoveryRequired
        }
        try manifest.validate()
        let data = try JSONEncoder().encode(manifest)
        try saveData(data, name: "manifest.json")
        try save(RenameJournal(version: 1, operationID: manifest.receipt.id, states: [:]), name: "journal.json")
        var index = RenameIndex(version: 1, operationID: manifest.receipt.id, manifestDigest: digest(data), state: "active",
                                committedReceipt: nil, consumesReceipt: false, retirement: nil)
        index.receiptBeforeDigest = try read("receipt.json").map(digest)
        try save(index, name: "index.json")
    }
    func record(_ state: String, row: UUID, operation: UUID) throws {
        guard let indexRaw = try read("index.json"), let raw = try read("journal.json") else { throw BatchRenameError.corruptStore }
        let index = try decodeIndex(indexRaw)
        guard index.operationID == operation, index.state == "active" else { throw BatchRenameError.stateChanged }
        var journal = try JSONDecoder().decode(RenameJournal.self, from: raw)
        guard journal.version == 1, journal.operationID == operation else { throw BatchRenameError.corruptStore }
        journal.states[row.uuidString] = state
        try save(journal, name: "journal.json")
    }
    func commit(_ manifest: RenameManifest) throws {
        guard let data = try read("index.json") else { throw BatchRenameError.corruptStore }
        let old = try decodeIndex(data)
        guard old.state == "active", old.operationID == manifest.receipt.id else { throw BatchRenameError.stateChanged }
        let changed = manifest.receipt.rows.filter(\.changes)
        let receipt = RenameReceipt(version: 1, id: manifest.receipt.id, parent: manifest.receipt.parent,
                                    parentIdentity: manifest.receipt.parentIdentity, bookmark: manifest.receipt.bookmark,
                                    sensitive: manifest.receipt.sensitive, rows: changed)
        var index = RenameIndex(version: 1, operationID: old.operationID, manifestDigest: old.manifestDigest, state: "committed",
                                committedReceipt: manifest.isUndo ? nil : receipt,
                                consumesReceipt: manifest.isUndo, retirement: nil)
        index.receiptBeforeDigest = old.receiptBeforeDigest
        try save(index, name: "index.json")
    }
    func isCommitted() throws -> Bool {
        guard let raw = try read("index.json") else { return false }
        return try decodeIndex(raw).state == "committed"
    }
    /// Called only after the owned staging directory was verified empty and removed.
    func markStagingClean(restored: Bool) throws {
        guard let raw = try read("index.json") else { throw BatchRenameError.corruptStore }
        let index = try decodeIndex(raw)
        guard index.state == (restored ? "active" : "committed") else { throw BatchRenameError.stateChanged }
        var terminal = RenameIndex(version: 1, operationID: index.operationID, manifestDigest: index.manifestDigest,
                                   state: restored ? "restored" : "committedClean", committedReceipt: index.committedReceipt,
                                   consumesReceipt: index.consumesReceipt, retirement: nil)
        terminal.cleanupDigests = [:]
        for name in ["manifest.json", "journal.json"] {
            guard let data = try read(name) else { throw BatchRenameError.corruptStore }
            terminal.cleanupDigests?[name] = digest(data)
        }
        guard terminal.cleanupDigests?["manifest.json"] == index.manifestDigest else { throw BatchRenameError.stateChanged }
        terminal.receiptBeforeDigest = index.receiptBeforeDigest
        try save(terminal, name: "index.json")
    }
    public func finalizeCompletedOperation() throws {
        guard let raw = try read("index.json") else { throw BatchRenameError.stateChanged }
        let index = try decodeIndex(raw)
        if index.state == "retired" { try finalizeRetirement(); return }
        if index.state == "restored" { try validateCompleted(index); try clearOperation(indexData: raw); return }
        try finishCommitted()
    }
    func finishCommitted() throws {
        guard let data = try read("index.json") else { throw BatchRenameError.corruptStore }
        let index = try decodeIndex(data)
        guard index.state == "committedClean" else { throw BatchRenameError.stateChanged }
        try validateCompleted(index)
        if index.consumesReceipt {
            if let receipt = try read("receipt.json") { try remove("receipt.json", expected: digest(receipt)) }
        } else {
            guard let receipt = index.committedReceipt else { throw BatchRenameError.corruptStore }
            try receipt.validate(); try save(receipt, name: "receipt.json")
        }
        try clearOperation(indexData: data)
    }
    func finishRestored() throws {
        guard let data = try read("index.json"), try decodeIndex(data).state == "restored" else { throw BatchRenameError.stateChanged }
        try clearOperation(indexData: data)
    }
    private func clearOperation(indexData: Data) throws {
        let index = try decodeIndex(indexData)
        try validateCompleted(index)
        for name in ["journal.json", "manifest.json"] {
            if let raw = try read(name) { try remove(name, expected: digest(raw)) }
        }
        try remove("index.json", expected: digest(indexData))
    }
    private func rejectScratch() throws {
        for name in Self.scratchNames { if try read(name) != nil { throw BatchRenameError.corruptStore } }
    }
    private func validateCompleted(_ index: RenameIndex) throws {
        try rejectScratch()
        guard ["restored", "committedClean"].contains(index.state),
              let expected = index.cleanupDigests, Set(expected.keys) == ["manifest.json", "journal.json"],
              expected["manifest.json"] == index.manifestDigest else { throw BatchRenameError.corruptStore }
        try index.committedReceipt?.validate()
        for name in ["manifest.json", "journal.json"] {
            if let bytes = try read(name), digest(bytes) != expected[name] { throw BatchRenameError.stateChanged }
        }
        let receipt = try read("receipt.json")
        let actual = receipt.map(digest)
        var allowed = [index.receiptBeforeDigest]
        if index.state == "committedClean" {
            if index.consumesReceipt { allowed.append(nil) }
            else if let committed = index.committedReceipt { allowed.append(digest(try JSONEncoder().encode(committed))) }
            else { throw BatchRenameError.corruptStore }
        }
        // JSONEncoder field ordering is not stable: compare decoded receipt after
        // confirming its complete versioned structure when resuming a prior save.
        if !allowed.contains(actual) {
            guard index.state == "committedClean", let committed = index.committedReceipt, let receipt,
                  try JSONDecoder().decode(RenameReceipt.self, from: receipt) == committed else { throw BatchRenameError.stateChanged }
        }
    }
    private func validateRetirement(_ index: RenameIndex) throws {
        guard index.state == "retired", let marker = index.retirement, marker.exportURL.isFileURL,
              marker.exportDigest.count == 64, !marker.fileDigests.isEmpty,
              marker.fileDigests.keys.allSatisfy({ Self.names.contains($0) }),
              marker.fileDigests.values.allSatisfy({ $0.count == 64 }) else { throw BatchRenameError.corruptStore }
    }
    private func decodeIndex(_ data: Data) throws -> RenameIndex {
        let value = try JSONDecoder().decode(RenameIndex.self, from: data)
        guard value.version == 1, ["preparing", "active", "committed", "committedClean", "restored", "retired"].contains(value.state) else { throw BatchRenameError.corruptStore }
        return value
    }
    func snapshot() throws -> [String: Data] {
        var result: [String: Data] = [:]
        for name in Self.names { result[name] = try read(name) }
        return result
    }
    func read(_ name: String) throws -> Data? {
        guard Self.names.contains(name) else { throw BatchRenameError.corruptStore }
        guard try BatchRenameIdentity.path(directory) != nil else { return nil }
        let handle = try privateDirectory(create: false)
        return try readBounded(name, directory: handle, maximum: Self.maximumBytes)
    }
    func save<T: Encodable>(_ value: T, name: String) throws { try saveData(JSONEncoder().encode(value), name: name) }
    func saveData(_ data: Data, name: String, reusingExportedScratch snapshot: [String: Data]? = nil) throws {
        guard Self.controlNames.contains(name), data.count <= Self.maximumBytes else { throw BatchRenameError.storeTooLarge }
        let handle = try privateDirectory(create: true)
        let temporary = "pending-" + name
        let fd: Int32
        let reused: Bool
        let openedIdentity: BatchRenameIdentity
        if let snapshot, let expected = snapshot[temporary] {
            guard let identity = try BatchRenameIdentity.at(temporary, in: handle.fd),
                  try readBounded(temporary, directory: handle, maximum: Self.maximumBytes) == expected else {
                throw BatchRenameError.stateChanged
            }
            fd = openat(handle.fd, temporary, O_WRONLY | O_NOFOLLOW | O_CLOEXEC)
            guard fd >= 0 else { throw renamePOSIXError() }
            var info = stat()
            guard fstat(fd, &info) == 0 else { let error = renamePOSIXError(); close(fd); throw error }
            openedIdentity = BatchRenameIdentity(info)
            guard openedIdentity == identity else { close(fd); throw BatchRenameError.stateChanged }
            // An exported scratch name may have been manually hard-linked to an
            // unrelated original. Exporting its bytes never authorizes truncating
            // the other directory entry or repairing its permissions.
            guard info.st_mode & UInt16(S_IFMT) == UInt16(S_IFREG), info.st_uid == getuid(),
                  info.st_mode & 0o7777 == 0o600, info.st_nlink == 1 else {
                close(fd); throw BatchRenameError.corruptStore
            }
            guard ftruncate(fd, 0) == 0 else { let error = renamePOSIXError(); close(fd); throw error }
            reused = true
        } else {
            fd = openat(handle.fd, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { throw renamePOSIXError() }
            do { openedIdentity = try BatchRenameIdentity.descriptor(fd) }
            catch { close(fd); throw error }
            reused = false
        }
        // Reused exported scratch remains a blocker even if a partial marker
        // write fails. Normal caught errors can remove only their new scratch.
        defer {
            // A new occupant of the fixed scratch name is not ours to remove,
            // including one arriving after atomic publication but before a later
            // fsync/checkpoint failure unwinds this scope.
            if !reused, (try? BatchRenameIdentity.at(temporary, in: handle.fd)) == openedIdentity {
                _ = unlinkat(handle.fd, temporary, 0)
            }
            close(fd)
        }
        try writeAll(data, fd: fd)
        guard fsync(fd) == 0 else { throw renamePOSIXError() }
        guard renameat(handle.fd, temporary, handle.fd, name) == 0 else { throw renamePOSIXError() }
        guard fsync(handle.fd) == 0 else { throw renamePOSIXError() }
        try checkpoint?("saved-" + name)
    }
    private func privateDirectory(create: Bool) throws -> RenameDirectory {
        if create, try BatchRenameIdentity.path(directory) == nil {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        }
        let handle = try RenameDirectory(directory)
        var info = stat()
        guard fstat(handle.fd, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw BatchRenameError.corruptStore
        }
        return handle
    }
    private func remove(_ name: String, expected: String) throws {
        let handle = try privateDirectory(create: false)
        guard let raw = try readBounded(name, directory: handle, maximum: Self.maximumBytes), digest(raw) == expected else {
            throw BatchRenameError.stateChanged
        }
        guard unlinkat(handle.fd, name, 0) == 0, fsync(handle.fd) == 0 else { throw renamePOSIXError() }
        try checkpoint?("removed-" + name)
    }
}
private struct RenameEvidence: Codable { let version: Int; let files: [String: Data] }
func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
private func readBounded(_ name: String, directory: RenameDirectory, maximum: Int) throws -> Data? {
    let fd = openat(directory.fd, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
    if fd < 0 { if errno == ENOENT { return nil }; throw renamePOSIXError() }
    defer { close(fd) }
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_mode & UInt16(S_IFMT) == UInt16(S_IFREG), info.st_uid == getuid(),
          info.st_mode & 0o077 == 0, info.st_size >= 0, info.st_size <= maximum else { throw BatchRenameError.corruptStore }
    return try readDescriptor(fd, maximum: maximum)
}
private func readDescriptor(_ fd: Int32, maximum: Int) throws -> Data {
    var data = Data(), buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
        let count = Darwin.read(fd, &buffer, buffer.count)
        if count < 0 { if errno == EINTR { continue }; throw renamePOSIXError() }
        if count == 0 { break }
        guard data.count + count <= maximum else { throw BatchRenameError.storeTooLarge }
        data.append(contentsOf: buffer.prefix(count))
    }
    return data
}
private func writeAll(_ data: Data, fd: Int32) throws {
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            if count < 0 { if errno == EINTR { continue }; throw renamePOSIXError() }
            guard count > 0 else { throw BatchRenameError.corruptStore }
            offset += count
        }
    }
}
