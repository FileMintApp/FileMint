import Foundation
import Darwin

public struct TemplateImportTransaction: Sendable {
    public enum Stage: Sendable { case journal, staged(Int), published(Int), beforeSave, afterSave, cleanup }
    /// Fault fixtures model a process exit without running ordinary rollback.
    public struct Interruption: Error { public init() {} }
    public struct Receipt: Sendable { public let preferences: FileMintPreferences; public let cleanupPending: Bool }
    struct DirectoryIdentity: Codable, Equatable {
        let device: UInt64, inode: UInt64
        let createdAt: Date?
        init(_ url: URL) throws {
            let item = try FileMoveItem.capture(url)
            guard item.isDirectory else { throw TemplateTransactionError.recoveryRequired }
            device = item.device; inode = item.inode; createdAt = item.createdAt
        }
    }
    struct Journal: Codable {
        struct Asset: Codable {
            let reference: DocumentTemplateReference
            var identity: CreatedFileIdentity?
        }
        let schemaVersion: Int
        let transactionID: UUID
        let candidateDigest: String
        let stageIdentity: DirectoryIdentity
        let assetDirectoryIdentity: DirectoryIdentity
        var assets: [Asset]
    }
    public let journalURL: URL
    public let preferencesURL: URL
    public let assets: DocumentTemplateStore
    private let saveOverride: (@Sendable (FileMintPreferences) throws -> Void)?
    private let fault: @Sendable (Stage) throws -> Void
    public init(journalURL: URL, preferencesURL: URL, assets: DocumentTemplateStore,
                save: (@Sendable (FileMintPreferences) throws -> Void)? = nil,
                fault: @escaping @Sendable (Stage) throws -> Void = { _ in }) {
        self.journalURL = journalURL; self.preferencesURL = preferencesURL; self.assets = assets
        saveOverride = save; self.fault = fault
    }
    private func stageDirectory(_ id: UUID) -> URL {
        journalURL.deletingLastPathComponent().appendingPathComponent(".template-stage-" + id.uuidString, isDirectory: true)
    }
    private func assetURL(_ reference: DocumentTemplateReference, directory: URL) -> URL {
        directory.appendingPathComponent(reference.id.uuidString + "." + reference.kind.rawValue)
    }
    private func exists(_ url: URL) throws -> Bool {
        var value = stat()
        if url.withUnsafeFileSystemRepresentation({ $0.map { lstat($0, &value) } ?? -1 }) == 0 { return true }
        if errno == ENOENT { return false }
        throw TemplateTransactionError.recoveryRequired
    }
    private func write(_ journal: Journal, initially: Bool) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(journal)
        guard bytes.count <= 1_048_576 else { throw TemplateTransactionError.recoveryRequired }
        if initially {
            _ = try BinaryFileWriter.create(bytes, in: journalURL.deletingLastPathComponent(), name: journalURL.lastPathComponent, collision: .fail)
        } else {
            _ = try CreatedFileIdentity.capture(journalURL)
            try bytes.write(to: journalURL, options: .atomic)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: journalURL.path)
    }
    public func commit(_ plan: TemplateImportPlan) throws -> Receipt {
        let store = FileMintPreferencesStore(fileURL: preferencesURL)
        let loaded = store.loadWithStatus()
        guard !loaded.requiresRecovery, !(try exists(journalURL)) else { throw TemplateTransactionError.recoveryRequired }
        guard try TemplateImportPlanner.revision(loaded.preferences) == plan.baseRevision else { throw TemplateTransactionError.staleReview }
        guard plan.acceptedCount > 0 else { return .init(preferences: loaded.preferences, cleanupPending: false) }
        let id = UUID(), directory = stageDirectory(id)
        let parent = journalURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.createDirectory(at: assets.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        _ = try DirectoryIdentity(assets.directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        var candidate = plan.preferences; candidate.lastTemplateImportTransactionID = id
        guard try JSONEncoder().encode(candidate).count <= FileMintPreferencesStore.maximumBytes else {
            _ = directory.withUnsafeFileSystemRepresentation { rmdir($0!) }
            throw TemplatePackageError.tooLarge
        }
        var journal = Journal(schemaVersion: 1, transactionID: id, candidateDigest: try TemplateImportPlanner.revision(candidate),
            stageIdentity: try DirectoryIdentity(directory), assetDirectoryIdentity: try DirectoryIdentity(assets.directory), assets: plan.assets.map { .init(reference: $0.reference, identity: nil) })
        var written = false, committed = false
        do {
            try write(journal, initially: true); written = true
            try fault(.journal)
            for (index, asset) in plan.assets.enumerated() {
                try Task.checkCancellation()
                let target = assetURL(asset.reference, directory: directory)
                _ = try BinaryFileWriter.create(asset.bytes, in: directory, name: target.lastPathComponent, collision: .fail)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
                journal.assets[index].identity = try CreatedFileIdentity.capture(target)
                try write(journal, initially: false)
                try fault(.staged(index))
                try journal.assets[index].identity?.validate(target)
                try StagedFileEntry.renameExclusive(target, to: assetURL(asset.reference, directory: assets.directory))
                try fault(.published(index))
            }
            try Task.checkCancellation()
            try fault(.beforeSave)
            return try store.withExclusiveAccess {
                let current = store.loadWithStatus()
                guard !current.requiresRecovery, try TemplateImportPlanner.revision(current.preferences) == plan.baseRevision else { throw TemplateTransactionError.staleReview }
                if let saveOverride { try saveOverride(candidate) } else { try store.save(candidate) }
                committed = true
                try fault(.afterSave)
                try fault(.cleanup)
                try reconcile(journal, preferences: candidate)
                return .init(preferences: candidate, cleanupPending: false)
            }
        } catch is Interruption { throw Interruption() }
        catch {
            return try store.withExclusiveAccess {
                let persisted = store.loadWithStatus()
                if committed || (!persisted.requiresRecovery && persisted.preferences.lastTemplateImportTransactionID == id) {
                    return .init(preferences: persisted.requiresRecovery ? candidate : persisted.preferences, cleanupPending: true)
                }
                if written {
                    do {
                        guard !persisted.requiresRecovery else { throw TemplateTransactionError.recoveryRequired }
                        try validateStoredPreferences()
                        try reconcile(journal, preferences: persisted.preferences)
                    } catch { throw TemplateTransactionError.recoveryRequired }
                } else { _ = directory.withUnsafeFileSystemRepresentation { rmdir($0!) } }
                throw error
            }
        }
    }
    public func recover() throws {
        let store = FileMintPreferencesStore(fileURL: preferencesURL)
        try store.withExclusiveAccess { try recoverLocked(store: store) }
    }
    private func recoverLocked(store: FileMintPreferencesStore) throws {
        guard try exists(journalURL) else { return }
        let loaded = store.loadWithStatus()
        guard !loaded.requiresRecovery else { throw TemplateTransactionError.recoveryRequired }
        do {
            try validateStoredPreferences()
            let bytes = try TemplatePackageCodec.read(at: journalURL, limit: 1_048_576)
            var scanner = try TemplatePackageJSON(bytes); try scanner.validate()
            try validateJournalKeys(bytes)
            let journal = try JSONDecoder().decode(Journal.self, from: bytes)
            guard journal.schemaVersion == 1, journal.assets.count <= 64,
                  Set(journal.assets.map { $0.reference.id }).count == journal.assets.count,
                  journal.candidateDigest.utf8.count == 64 else { throw TemplateTransactionError.recoveryRequired }
            for asset in journal.assets {
                guard asset.reference.builtInResource == nil, (1...OfficeDocumentValidator.maximumBytes).contains(asset.reference.byteCount),
                      asset.reference.sha256.utf8.count == 64, asset.identity == nil || asset.identity?.size == Int64(asset.reference.byteCount) else { throw TemplateTransactionError.recoveryRequired }
            }
            try reconcile(journal, preferences: loaded.preferences)
        } catch { throw TemplateTransactionError.recoveryRequired }
    }
    private func validateStoredPreferences() throws {
        if try exists(preferencesURL) {
            let saved = try TemplatePackageCodec.read(at: preferencesURL, limit: FileMintPreferencesStore.maximumBytes)
            var scanner = try TemplatePackageJSON(saved); try scanner.validate()
            guard let object = try JSONSerialization.jsonObject(with: saved) as? [String: Any],
                  object["templates"] is [Any] else { throw TemplateTransactionError.recoveryRequired }
            let templates = try JSONDecoder().decode([FileTemplate].self, from: JSONSerialization.data(withJSONObject: object["templates"]!))
            // A malformed reference hides ownership information; preserve all
            // evidence rather than guessing that its journal asset is unused.
            guard templates.allSatisfy({ $0.document == nil || ($0.document!.byteCount > 0 && $0.document!.sha256.count == 64) }) else {
                throw TemplateTransactionError.recoveryRequired
            }
        }
    }
    private func validateJournalKeys(_ data: Data) throws {
        func keys(_ value: Any?, required: Set<String>, optional: Set<String> = []) throws -> [String: Any] {
            guard let object = value as? [String: Any], Set(object.keys).isSuperset(of: required),
                  Set(object.keys).isSubset(of: required.union(optional)) else { throw TemplateTransactionError.recoveryRequired }
            return object
        }
        let root = try keys(JSONSerialization.jsonObject(with: data), required: ["schemaVersion", "transactionID", "candidateDigest", "stageIdentity", "assetDirectoryIdentity", "assets"])
        for field in ["stageIdentity", "assetDirectoryIdentity"] {
            _ = try keys(root[field], required: ["device", "inode"], optional: ["createdAt"])
        }
        guard let values = root["assets"] as? [Any], values.count <= 64 else { throw TemplateTransactionError.recoveryRequired }
        for value in values {
            let asset = try keys(value, required: ["reference"], optional: ["identity"])
            _ = try keys(asset["reference"], required: ["id", "kind", "byteCount", "sha256"])
            if let identity = asset["identity"] {
                _ = try keys(identity, required: ["device", "inode", "birthSeconds", "birthNanos", "size", "modifiedSeconds", "modifiedNanos"])
            }
        }
    }
    private func removeOwned(_ url: URL, asset: Journal.Asset) throws {
        guard try exists(url) else { return }
        guard let identity = asset.identity else { throw TemplateTransactionError.recoveryRequired }
        try identity.validate(url)
        let data = try TemplatePackageCodec.read(at: url, limit: OfficeDocumentValidator.maximumBytes)
        guard data.count == asset.reference.byteCount, TemplatePackageCodec.digest(data) == asset.reference.sha256 else { throw TemplateTransactionError.recoveryRequired }
        let item = try FileMoveItem.capture(url)
        try identity.validate(url)
        let claim = try StagedFileEntry.claim(item)
        defer { claim.cleanup() }
        do {
            try identity.validate(claim.staged)
            try FileManager.default.removeItem(at: claim.staged)
        } catch { try claim.restore(); throw error }
    }
    private func reconcile(_ journal: Journal, preferences: FileMintPreferences) throws {
        let directory = stageDirectory(journal.transactionID)
        guard try DirectoryIdentity(assets.directory) == journal.assetDirectoryIdentity else { throw TemplateTransactionError.recoveryRequired }
        let stageExists = try exists(directory)
        if stageExists { guard try DirectoryIdentity(directory) == journal.stageIdentity else { throw TemplateTransactionError.recoveryRequired } }
        for asset in journal.assets {
            let referenced = preferences.templates.contains { $0.document?.builtInResource == nil && $0.document?.id == asset.reference.id }
            if !referenced { try removeOwned(assetURL(asset.reference, directory: assets.directory), asset: asset) }
            if stageExists { try removeOwned(assetURL(asset.reference, directory: directory), asset: asset) }
        }
        if stageExists {
            let status = directory.withUnsafeFileSystemRepresentation { rmdir($0!) }
            guard status == 0 else { throw TemplateTransactionError.recoveryRequired }
        }
        // The journal is regular and still refers to this exact transaction.
        let current = try TemplatePackageCodec.read(at: journalURL, limit: 1_048_576)
        guard try JSONDecoder().decode(Journal.self, from: current).transactionID == journal.transactionID else { throw TemplateTransactionError.recoveryRequired }
        let identity = try CreatedFileIdentity.capture(journalURL)
        let item = try FileMoveItem.capture(journalURL)
        let claim = try StagedFileEntry.claim(item)
        defer { claim.cleanup() }
        do { try identity.validate(claim.staged); try FileManager.default.removeItem(at: claim.staged) }
        catch { try claim.restore(); throw error }
    }
}
