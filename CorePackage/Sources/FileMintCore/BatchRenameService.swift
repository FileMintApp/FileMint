import Foundation
import CoreFoundation
import Darwin

/// Synchronous descriptor-relative engine. Run away from the main thread while
/// holding the application's serialized operation ownership and exact-parent grant.
public struct BatchRenameService: Sendable {
    public let store: BatchRenameStore
    // Internal deterministic crash-gap injection, unavailable to application callers.
    var checkpoint: (@Sendable (String, Int) throws -> Void)?
    public init(store: BatchRenameStore = BatchRenameStore()) { self.store = store }

    public func prepare(selection: BatchRenameSelection, parentBookmark: Data,
                        observationRoots: [URL], privateLocations: [URL] = []) throws -> BatchRenameSession {
        guard !store.status().hasUnresolvedOperation else { throw BatchRenameError.recoveryRequired }
        guard !parentBookmark.isEmpty else { throw BatchRenameError.invalidBookmark }
        guard (2...1_000).contains(selection.items.count), selection.items.count == selection.itemIdentities.count else {
            throw BatchRenameError.invalidSelection
        }
        let parent = try RenameDirectory(selection.parent, expected: selection.parentIdentity)
        let environment = try capabilities(parent)
        var sources: [BatchRenameSource] = [], identities: [UUID: BatchRenameIdentity] = [:]
        for (item, identity) in zip(selection.items, selection.itemIdentities) {
            guard item.canonicalParent == selection.parent, item.source.isFileURL,
                  item.source.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL == selection.parent,
                  item.device == identity.device, item.inode == identity.inode,
                  item.isDirectory == identity.isDirectory else { throw BatchRenameError.invalidSelection }
            try item.validateIdentity()
            let id = UUID()
            sources.append(.init(id: id, originalName: item.source.lastPathComponent, kind: identity.isDirectory ? .directory : .file))
            identities[id] = identity
        }
        guard Set(identities.values.map { "\($0.device):\($0.inode)" }).count == identities.count else {
            throw BatchRenameError.invalidSelection
        }
        let batch = try BatchRenameBatch(id: selection.id, sources: sources)
        let session = BatchRenameSession(batch: batch, parent: parent, sensitive: environment.sensitive,
                                        nameLimit: environment.limit, identities: identities, bookmark: parentBookmark,
                                        roots: observationRoots, privateLocations: privateLocations)
        try validateSources(session)
        return session
    }

    public func observeTargets(preview: BatchRenamePreview, session: BatchRenameSession) throws -> BatchRenameTargetSnapshot {
        guard preview.reference.batch == session.batch,
              preview.reference.caseSensitivity == session.caseSensitivity,
              preview.reference.nativeNameByteLimit == session.nativeNameByteLimit else { throw BatchRenameError.stalePlan }
        try session.parent.validatePath()
        let observations = try preview.rows.compactMap { row -> BatchRenameTargetObservation? in
            guard let name = row.proposedName else { return nil }
            let state = try targetState(name, sources: session.batch.sources, identities: session.identities,
                                        parent: session.parent, sensitive: session.caseSensitivity == .sensitive)
            return .init(rowID: row.source.id, targetName: name, state: state)
        }
        return .init(preview: preview, observations: observations)
    }

    public func execute(plan: BatchRenamePlan, session: BatchRenameSession,
                        shouldContinue: @Sendable () -> Bool) throws -> BatchRenameResult {
        guard !store.status().hasUnresolvedOperation else { throw BatchRenameError.recoveryRequired }
        guard plan.reference.batch == session.batch else { throw BatchRenameError.stalePlan }
        try validateSources(session)
        let reference = plan.reference
        let preview = try BatchRenamePlanner.preview(batch: reference.batch, revision: reference.revision,
                                                     mode: reference.mode, order: reference.order,
                                                     caseSensitivity: reference.caseSensitivity,
                                                     nativeNameByteLimit: reference.nativeNameByteLimit)
        let fresh = try BatchRenamePlanner.freeze(BatchRenamePlanner.checkingTargets(of: preview,
                                                   using: observeTargets(preview: preview, session: session)))
        guard fresh.rows.count == plan.rows.count, zip(fresh.rows, plan.rows).allSatisfy({
            $0.source == $1.source && $0.proposedName?.utf8.elementsEqual($1.proposedName?.utf8 ?? "".utf8) == true
        }) else { throw BatchRenameError.stalePlan }
        let rows = fresh.rows.map { RenameRecordRow(id: $0.source.id, original: $0.source.originalName,
                                                   target: $0.proposedName!, slot: $0.source.id.uuidString,
                                                   identity: session.identities[$0.source.id]!) }
        let receipt = RenameReceipt(version: 1, id: UUID(), parent: session.parentURL,
                                    parentIdentity: session.parent.identity, bookmark: session.bookmark,
                                    sensitive: session.caseSensitivity == .sensitive, rows: rows)
        return try transact(receipt: receipt, parent: session.parent, isUndo: false, shouldContinue: shouldContinue)
    }

    public func undoPreview(parentURL: URL, parentBookmark: Data? = nil, observationRoots: [URL], privateLocations: [URL] = []) throws -> BatchRenameUndoPreview {
        guard !store.status().hasUnresolvedOperation, let receipt = try store.receipt() else { throw BatchRenameError.recoveryRequired }
        let parent = try RenameDirectory(parentURL, expected: receipt.parentIdentity)
        let environment = try capabilities(parent)
        guard environment.sensitive == receipt.sensitive else { throw BatchRenameError.unsupportedFilesystem }
        let reverse = reverseRows(receipt.rows)
        try preflight(rows: reverse, parent: parent, sensitive: receipt.sensitive,
                      roots: observationRoots, privateLocations: privateLocations, restoring: true)
        return .init(rows: receipt.rows.map { .init(id: $0.id, currentName: $0.target, originalName: $0.original) },
                     parentURL: parentURL, receipt: receipt, bookmark: parentBookmark ?? receipt.bookmark, parent: parent, roots: observationRoots,
                     privateLocations: privateLocations)
    }
    public func undo(preview: BatchRenameUndoPreview, shouldContinue: @Sendable () -> Bool) throws -> BatchRenameResult {
        guard !store.status().hasUnresolvedOperation, try store.receipt() == preview.receipt else { throw BatchRenameError.stalePlan }
        let receipt = preview.receipt, rows = reverseRows(receipt.rows)
        try preflight(rows: rows, parent: preview.parent, sensitive: receipt.sensitive,
                      roots: preview.roots, privateLocations: preview.privateLocations, restoring: true)
        return try transact(receipt: .init(version: 1, id: UUID(), parent: preview.parentURL,
                                          parentIdentity: receipt.parentIdentity, bookmark: preview.bookmark,
                                          sensitive: receipt.sensitive, rows: rows), parent: preview.parent,
                            isUndo: true, shouldContinue: shouldContinue)
    }
    public func restore(parentURL: URL) throws -> BatchRenameResult {
        let manifest = try store.manifest()
        let parent = try RenameDirectory(parentURL, expected: manifest.receipt.parentIdentity)
        _ = try capabilities(parent)
        if try store.isCommitted() {
            // A durable commit is never interpreted as a request to roll back.
            let rows = try reconcile(manifest, parent: parent, allowMissingStage: true)
            guard zip(rows, manifest.receipt.rows).allSatisfy({ actual, saved in
                actual.state == (saved.changes ? .target : .original)
            }) else { return .init(outcome: .recoveryRequired, rows: rows, failureStage: "committed-state-changed") }
            try removeStage(manifest, parent: parent)
            try checkpoint?("staging-removed", 0)
            try store.markStagingClean(restored: false)
            try store.finishCommitted()
            return .init(outcome: manifest.isUndo ? .undone : .renamed, rows: rows, failureStage: nil)
        }
        return rollback(manifest, parent: parent, failureStage: "interrupted")
    }

    private func validateSources(_ session: BatchRenameSession) throws {
        let environment = try capabilities(session.parent)
        guard environment.sensitive == (session.caseSensitivity == .sensitive), environment.limit == session.nativeNameByteLimit else {
            throw BatchRenameError.unsupportedFilesystem
        }
        let rows = session.batch.sources.map { RenameRecordRow(id: $0.id, original: $0.originalName, target: $0.originalName,
                                                              slot: $0.id.uuidString, identity: session.identities[$0.id]!) }
        try preflight(rows: rows, parent: session.parent, sensitive: environment.sensitive,
                      roots: session.observationRoots, privateLocations: session.privateLocations)
    }
    private func preflight(rows: [RenameRecordRow], parent: RenameDirectory, sensitive: Bool,
                           roots: [URL], privateLocations: [URL], restoring: Bool = false) throws {
        try parent.validatePath()
        _ = try capabilities(parent)
        let realRoots = roots.map { $0.resolvingSymlinksInPath().standardizedFileURL }
        guard !realRoots.isEmpty, FolderScope.contains(parent.url, in: realRoots) else { throw BatchRenameError.disabled }
        let sources = rows.map { BatchRenameSource(id: $0.id, originalName: $0.original,
                                                   kind: $0.identity.isDirectory ? .directory : .file) }
        let identities = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.identity) })
        for row in rows {
            try RenameNamePolicy.validateRestorationComponent(row.original)
            try RenameNamePolicy.validateRestorationComponent(row.target)
            guard let actual = try BatchRenameIdentity.at(row.original, in: parent.fd), actual == row.identity,
                  actual.device == parent.identity.device else { throw BatchRenameError.sourceChanged }
            guard try actualName(row.original, parent: parent).utf8.elementsEqual(row.original.utf8) else {
                throw BatchRenameError.sourceChanged
            }
            try validateMetadata(row.original, identity: actual, parent: parent, allowingRenamedPackage: restoring && actual.isDirectory)
            try protect(row.original, identity: actual, parent: parent, roots: realRoots,
                        privateLocations: [FileMintStorage.directory, store.directory] + privateLocations)
            switch try targetState(row.target, sources: sources, identities: identities, parent: parent, sensitive: sensitive) {
            case .absent: break
            case .occupiedBySource: break
            default: throw BatchRenameError.occupiedTarget
            }
        }
        try parent.validatePath()
    }
    private func targetState(_ name: String, sources: [BatchRenameSource], identities: [UUID: BatchRenameIdentity],
                             parent: RenameDirectory, sensitive: Bool) throws -> BatchRenameTargetState {
        guard let actual = try BatchRenameIdentity.at(name, in: parent.fd) else { return .absent }
        let key = RenameNamePolicy.namespaceKey(name, caseSensitive: sensitive)
        if let source = sources.first(where: {
            identities[$0.id] == actual && RenameNamePolicy.namespaceKey($0.originalName, caseSensitive: sensitive) == key
        }) { return .occupiedBySource(source.id) }
        return .occupiedExternally
    }
    private func capabilities(_ parent: RenameDirectory) throws -> (sensitive: Bool, limit: Int?) {
        try parent.validatePath()
        var filesystem = statfs()
        guard fstatfs(parent.fd, &filesystem) == 0 else { throw renamePOSIXError() }
        let type = withUnsafeBytes(of: filesystem.f_fstypename) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        guard type == "apfs", filesystem.f_flags & UInt32(MNT_LOCAL) != 0,
              filesystem.f_flags & UInt32(MNT_RDONLY) == 0,
              faccessat(parent.fd, ".", W_OK | X_OK, 0) == 0 else { throw BatchRenameError.unsupportedFilesystem }
        let values = try parent.url.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey,
                                                             .volumeSupportsExclusiveRenamingKey])
        guard let sensitive = values.volumeSupportsCaseSensitiveNames,
              values.volumeSupportsExclusiveRenaming == true else { throw BatchRenameError.unsupportedFilesystem }
        errno = 0
        let limit = fpathconf(parent.fd, _PC_NAME_MAX)
        guard limit > 0 || errno == 0 else { throw renamePOSIXError() }
        return (sensitive, limit > 0 ? limit : nil)
    }
    private func validateMetadata(_ name: String, identity: BatchRenameIdentity, parent: RenameDirectory,
                                  allowingRenamedPackage: Bool) throws {
        guard identity.isRegular || identity.isDirectory else { throw BatchRenameError.unsupportedItem }
        var info = stat()
        guard fstatat(parent.fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { throw renamePOSIXError() }
        guard info.st_flags & UInt32(SF_DATALESS) == 0 else { throw BatchRenameError.unavailable }
        let values = try parent.url.appendingPathComponent(name).resourceValues(forKeys: [.isAliasFileKey, .isPackageKey,
                                                                                        .isRegularFileKey, .isDirectoryKey])
        guard values.isAliasFile == false, (values.isPackage == false || allowingRenamedPackage),
              identity.isDirectory ? values.isDirectory == true : values.isRegularFile == true else {
            throw BatchRenameError.unsupportedItem
        }
        guard try BatchRenameIdentity.at(name, in: parent.fd) == identity else { throw BatchRenameError.sourceChanged }
    }
    private func protect(_ name: String, identity: BatchRenameIdentity, parent: RenameDirectory,
                         roots: [URL], privateLocations: [URL]) throws {
        let source = parent.url.appendingPathComponent(name).standardizedFileURL
        let home = DefaultFolders.resolvedUserHomeDirectory(fileManager: .default).resolvingSymlinksInPath()
        let fixed = ["/", "/System", "/Library", "/Applications", "/Users", "/Volumes"].map { URL(fileURLWithPath: $0) }
        let standard = [home] + ["Desktop", "Documents", "Downloads", "Library", "Applications", "Pictures", "Movies", "Music", "Public"].map { home.appendingPathComponent($0) }
        for known in fixed + standard + roots {
            let real = known.resolvingSymlinksInPath().standardizedFileURL
            if try BatchRenameIdentity.path(real) == identity { throw BatchRenameError.protectedItem }
        }
        for known in privateLocations {
            guard known.isFileURL else { throw BatchRenameError.unresolvedProtection }
            let real = known.resolvingSymlinksInPath().standardizedFileURL
            // Resolve each existing ancestor: required protection errors are fatal;
            // a not-yet-created private store is still protected lexically.
            var ancestor = real
            while try BatchRenameIdentity.path(ancestor) == nil, ancestor.path != "/" { ancestor.deleteLastPathComponent() }
            if FolderScope.contains(source, in: [real]) || (identity.isDirectory && FolderScope.contains(real, in: [source])) {
                throw BatchRenameError.protectedItem
            }
        }
        var fs = statfs()
        guard fstatfs(parent.fd, &fs) == 0 else { throw renamePOSIXError() }
        let mount = withUnsafeBytes(of: fs.f_mntonname) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        if try BatchRenameIdentity.path(URL(fileURLWithPath: mount)) == identity { throw BatchRenameError.protectedItem }
    }

    private func transact(receipt: RenameReceipt, parent: RenameDirectory, isUndo: Bool,
                          shouldContinue: @Sendable () -> Bool) throws -> BatchRenameResult {
        // Stable checkpoints: #1 pre-mutation, #2 before first stage, #3 before
        // second stage (when two rows change), used by the crash-process fixture.
        guard shouldContinue() else { throw BatchRenameError.disabled }
        try parent.validatePath()
        let stageName = ".FileMint-rename-\(receipt.id.uuidString)"
        try store.reservePreparation(receipt)
        try checkpoint?("preparing-reserved", 0)
        guard mkdirat(parent.fd, stageName, 0o700) == 0 else {
            let error = renamePOSIXError()
            try? store.discardEmptyPreparation(operationID: receipt.id)
            throw error
        }
        guard let stageIdentity = try BatchRenameIdentity.at(stageName, in: parent.fd) else { throw BatchRenameError.sourceChanged }
        let manifest = RenameManifest(version: 1, receipt: receipt, isUndo: isUndo, stageName: stageName, stageIdentity: stageIdentity)
        do { try store.begin(manifest) }
        catch {
            // Nothing has moved; rmdir only removes an empty directory we own.
            try? removeStage(manifest, parent: parent)
            throw error
        }
        var phase = "stage"
        do {
            let stage = try RenameDirectory(parent: parent, component: stageName, expected: stageIdentity)
            for (index, row) in receipt.rows.enumerated() where row.changes {
                guard shouldContinue() else { throw BatchRenameError.disabled }
                try parent.validatePath(); try validateStage(manifest, parent: parent, stage: stage)
                guard try BatchRenameIdentity.at(row.original, in: parent.fd) == row.identity else { throw BatchRenameError.sourceChanged }
                try store.record("stage-intent", row: row.id, operation: receipt.id)
                try checkpoint?("stage-intent", index)
                try renameExclusive(from: row.original, in: parent.fd, to: row.slot, in: stage.fd)
                try checkpoint?("stage-syscall", index)
                try verifyClaim(row, manifest: manifest, at: row.slot, in: stage.fd,
                                restoreTo: row.original, in: parent.fd)
                try store.record("staged", row: row.id, operation: receipt.id)
            }
            phase = "publish"
            // Whole-stage verification precedes every result publication.
            try parent.validatePath(); try validateStage(manifest, parent: parent, stage: stage)
            for row in receipt.rows where row.changes {
                guard try BatchRenameIdentity.at(row.slot, in: stage.fd) == row.identity else { throw BatchRenameError.sourceChanged }
            }
            for (index, row) in receipt.rows.enumerated() where row.changes {
                guard shouldContinue() else { throw BatchRenameError.disabled }
                try parent.validatePath(); try validateStage(manifest, parent: parent, stage: stage)
                guard try BatchRenameIdentity.at(row.slot, in: stage.fd) == row.identity else { throw BatchRenameError.sourceChanged }
                try store.record("publish-intent", row: row.id, operation: receipt.id)
                try checkpoint?("publish-intent", index)
                try renameExclusive(from: row.slot, in: stage.fd, to: row.target, in: parent.fd)
                try checkpoint?("publish-syscall", index)
                try verifyClaim(row, manifest: manifest, at: row.target, in: parent.fd,
                                restoreTo: row.slot, in: stage.fd)
                try store.record("published", row: row.id, operation: receipt.id)
            }
            phase = "commit"
            guard shouldContinue() else { throw BatchRenameError.disabled }
            let rows = try reconcile(manifest, parent: parent)
            guard zip(rows, receipt.rows).allSatisfy({ $0.state == ($1.changes ? .target : .original) }) else {
                throw BatchRenameError.sourceChanged
            }
            try store.commit(manifest)
            try checkpoint?("commit-marker", 0)
            phase = "cleanup"
            try removeStage(manifest, parent: parent)
            try checkpoint?("staging-removed", 0)
            try store.markStagingClean(restored: false)
            try store.finishCommitted()
            return .init(outcome: isUndo ? .undone : .renamed, rows: rows, failureStage: nil)
        } catch is RenameSimulatedCrash { throw RenameSimulatedCrash() }
        catch {
            // A save may have installed a commit marker before fsync reported an
            // error; re-read it. A marker or an unreadable store forbids rollback.
            guard (try? store.isCommitted()) == false, !store.status().requiresMetadataFinalization else {
                return result(manifest, parent: parent, outcome: .recoveryRequired, failureStage: phase)
            }
            return rollback(manifest, parent: parent, failureStage: phase)
        }
    }
    private func verifyClaim(_ row: RenameRecordRow, manifest: RenameManifest, at target: String, in targetFD: Int32,
                             restoreTo source: String, in sourceFD: Int32) throws {
        let actual = try BatchRenameIdentity.at(target, in: targetFD)
        guard actual != row.identity else { return }
        if let actual {
            try store.record("unexpected-restore-intent", row: row.id, operation: manifest.receipt.id)
            if try BatchRenameIdentity.at(target, in: targetFD) == actual {
                try renameExclusive(from: target, in: targetFD, to: source, in: sourceFD)
            }
        }
        throw BatchRenameError.sourceChanged
    }
    private func reverseRows(_ rows: [RenameRecordRow]) -> [RenameRecordRow] {
        rows.map { .init(id: $0.id, original: $0.target, target: $0.original, slot: $0.slot, identity: $0.identity) }
    }
    private func validateStage(_ manifest: RenameManifest, parent: RenameDirectory, stage: RenameDirectory) throws {
        guard try BatchRenameIdentity.at(manifest.stageName, in: parent.fd) == manifest.stageIdentity,
              try BatchRenameIdentity.descriptor(stage.fd) == manifest.stageIdentity else { throw BatchRenameError.sourceChanged }
    }
    private func rollback(_ manifest: RenameManifest, parent: RenameDirectory, failureStage: String) -> BatchRenameResult {
        do {
            try parent.validatePath()
            let positions = try reconcile(manifest, parent: parent, allowMissingStage: true)
            if positions.allSatisfy({ $0.state == .original }) {
                try removeStage(manifest, parent: parent)
                try checkpoint?("staging-removed", 0)
                try store.markStagingClean(restored: true)
                try store.finishRestored()
                return .init(outcome: .restored, rows: positions, failureStage: failureStage)
            }
            guard positions.allSatisfy({ [.original, .staged, .target].contains($0.state) }) else { throw BatchRenameError.recoveryRequired }
            let stage = try RenameDirectory(parent: parent, component: manifest.stageName, expected: manifest.stageIdentity)
            // Stage all published owned entries before restoring any names: swaps
            // and cycles cannot be undone with a single reverse per-item loop.
            for (row, actual) in zip(manifest.receipt.rows, positions) where row.changes && actual.state == .target {
                try parent.validatePath(); try validateStage(manifest, parent: parent, stage: stage)
                guard try BatchRenameIdentity.at(row.target, in: parent.fd) == row.identity else { throw BatchRenameError.sourceChanged }
                try store.record("rollback-claim-intent", row: row.id, operation: manifest.receipt.id)
                try renameExclusive(from: row.target, in: parent.fd, to: row.slot, in: stage.fd)
                try verifyClaim(row, manifest: manifest, at: row.slot, in: stage.fd,
                                restoreTo: row.target, in: parent.fd)
                try store.record("rollback-staged", row: row.id, operation: manifest.receipt.id)
            }
            for row in manifest.receipt.rows where row.changes {
                try parent.validatePath(); try validateStage(manifest, parent: parent, stage: stage)
                if try BatchRenameIdentity.at(row.original, in: parent.fd) == row.identity { continue }
                guard try BatchRenameIdentity.at(row.slot, in: stage.fd) == row.identity else { throw BatchRenameError.sourceChanged }
                try store.record("restore-intent", row: row.id, operation: manifest.receipt.id)
                try renameExclusive(from: row.slot, in: stage.fd, to: row.original, in: parent.fd)
                try verifyClaim(row, manifest: manifest, at: row.original, in: parent.fd,
                                restoreTo: row.slot, in: stage.fd)
                try store.record("restored", row: row.id, operation: manifest.receipt.id)
            }
            let rows = try reconcile(manifest, parent: parent)
            guard rows.allSatisfy({ $0.state == .original }) else { throw BatchRenameError.recoveryRequired }
            try removeStage(manifest, parent: parent)
            try checkpoint?("staging-removed", 0)
            try store.markStagingClean(restored: true)
            try store.finishRestored()
            return .init(outcome: .restored, rows: rows, failureStage: failureStage)
        } catch { return result(manifest, parent: parent, outcome: .recoveryRequired, failureStage: failureStage) }
    }
    private func reconcile(_ manifest: RenameManifest, parent: RenameDirectory, allowMissingStage: Bool = false) throws -> [BatchRenameResultRow] {
        try parent.validatePath()
        let stageIdentity = try BatchRenameIdentity.at(manifest.stageName, in: parent.fd)
        let stage: RenameDirectory?
        if stageIdentity == nil, allowMissingStage { stage = nil }
        else {
            guard stageIdentity == manifest.stageIdentity else { throw BatchRenameError.sourceChanged }
            stage = try RenameDirectory(parent: parent, component: manifest.stageName, expected: manifest.stageIdentity)
        }
        return try manifest.receipt.rows.map { row in
            var matches: [(BatchRenameActualState, URL)] = []
            let original = try BatchRenameIdentity.at(row.original, in: parent.fd)
            let target = try BatchRenameIdentity.at(row.target, in: parent.fd)
            let sameNamespace = RenameNamePolicy.namespaceKey(row.original, caseSensitive: manifest.receipt.sensitive)
                == RenameNamePolicy.namespaceKey(row.target, caseSensitive: manifest.receipt.sensitive)
            if original == row.identity { matches.append((.original, parent.url.appendingPathComponent(row.original))) }
            if target == row.identity, row.changes {
                if sameNamespace, !matches.isEmpty {
                    // Exact spelling is needed to distinguish a case-only syscall
                    // crash gap. getattrlistat requests only the known entry name.
                    let spelling = try actualName(row.target, parent: parent)
                    let state: BatchRenameActualState = spelling.utf8.elementsEqual(row.target.utf8) ? .target
                        : spelling.utf8.elementsEqual(row.original.utf8) ? .original : .ambiguous
                    matches = [(state, parent.url.appendingPathComponent(spelling))]
                } else { matches.append((.target, parent.url.appendingPathComponent(row.target))) }
            }
            if let stage, try BatchRenameIdentity.at(row.slot, in: stage.fd) == row.identity {
                matches.append((.staged, stage.url.appendingPathComponent(row.slot)))
            }
            return .init(id: row.id, originalName: row.original, targetName: row.target,
                         location: matches.count == 1 ? matches[0].1 : nil,
                         state: matches.count == 1 ? matches[0].0 : matches.isEmpty ? .missing : .ambiguous)
        }
    }
    private func actualName(_ name: String, parent: RenameDirectory) throws -> String {
        var attributes = attrlist()
        attributes.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        attributes.commonattr = attrgroup_t(ATTR_CMN_NAME)
        var buffer = [UInt8](repeating: 0, count: 4_096)
        guard getattrlistat(parent.fd, name, &attributes, &buffer, buffer.count, UInt(FSOPT_NOFOLLOW)) == 0 else {
            throw renamePOSIXError()
        }
        return try buffer.withUnsafeBytes { raw in
            let reference = raw.loadUnaligned(fromByteOffset: 4, as: attrreference_t.self)
            let offset = 4 + Int(reference.attr_dataoffset), length = Int(reference.attr_length)
            guard offset >= 12, length > 0, offset + length <= raw.count else { throw BatchRenameError.sourceChanged }
            let bytes = raw[offset..<(offset + length - 1)]
            guard let result = String(bytes: bytes, encoding: .utf8) else { throw BatchRenameError.sourceChanged }
            try RenameNamePolicy.validateRestorationComponent(result)
            return result
        }
    }
    private func removeStage(_ manifest: RenameManifest, parent: RenameDirectory) throws {
        try parent.validatePath()
        guard let identity = try BatchRenameIdentity.at(manifest.stageName, in: parent.fd) else { return }
        guard identity == manifest.stageIdentity else { throw BatchRenameError.sourceChanged }
        guard unlinkat(parent.fd, manifest.stageName, AT_REMOVEDIR) == 0 else { throw renamePOSIXError() }
    }
    private func result(_ manifest: RenameManifest, parent: RenameDirectory, outcome: BatchRenameOutcome,
                        failureStage: String) -> BatchRenameResult {
        let rows = (try? reconcile(manifest, parent: parent, allowMissingStage: true)) ?? manifest.receipt.rows.map {
            BatchRenameResultRow(id: $0.id, originalName: $0.original, targetName: $0.target, location: nil, state: .ambiguous)
        }
        return .init(outcome: outcome, rows: rows, failureStage: failureStage)
    }
}
struct RenameSimulatedCrash: Error {}
