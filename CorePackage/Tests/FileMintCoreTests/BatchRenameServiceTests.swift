@testable import FileMintCore
import Foundation
import Darwin
import Testing

@Suite("Batch rename native transaction and recovery")
struct BatchRenameServiceTests {
    private func fixture(_ body: (URL, URL, BatchRenameStore) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rename-\(UUID().uuidString)").resolvingSymlinksInPath()
        let parent = root.appendingPathComponent("items")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root, parent, BatchRenameStore(directory: root.appendingPathComponent("control")))
    }
    private func makeSession(_ service: BatchRenameService, parent: URL, names: [String]) throws -> BatchRenameSession {
        let selection = try BatchRenameSelection.capture(selection: names.map { parent.appendingPathComponent($0) })
        let bookmark = try parent.bookmarkData(options: .minimalBookmark)
        return try service.prepare(selection: selection, parentBookmark: bookmark, observationRoots: [parent])
    }
    private func plan(_ service: BatchRenameService, session: BatchRenameSession, bodies: [String]) throws -> BatchRenamePlan {
        let ids = BatchRenamePlanner.orderedRowIDs(in: session.batch)
        let list = try BatchRenameNameList(text: bodies.joined(separator: "\n"), rowIDs: ids)
        let preview = try BatchRenamePlanner.preview(batch: session.batch, revision: 1, mode: .nameList(list),
                                                    caseSensitivity: session.caseSensitivity, nativeNameByteLimit: session.nativeNameByteLimit)
        return try BatchRenamePlanner.freeze(BatchRenamePlanner.checkingTargets(of: preview,
            using: service.observeTargets(preview: preview, session: session)))
    }
    private func files(_ parent: URL, names: [String] = ["a", "b"]) throws {
        for name in names { try Data(name.utf8).write(to: parent.appendingPathComponent(name), options: .withoutOverwriting) }
    }
    private func text(_ parent: URL, _ name: String) throws -> String {
        try String(contentsOf: parent.appendingPathComponent(name), encoding: .utf8)
    }

    @Test("mixed ordinary file and directory swap preserves descendants and undo consumes receipt")
    func mixedSwapAndUndo() throws {
        try fixture { _, parent, store in
            try files(parent, names: ["a"])
            try FileManager.default.createDirectory(at: parent.appendingPathComponent("b/nested"), withIntermediateDirectories: true)
            try Data("child".utf8).write(to: parent.appendingPathComponent("b/nested/keep"))
            let service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["b", "a"])
            let result = try service.execute(plan: plan(service, session: session, bodies: ["b", "a"]), session: session) { true }
            #expect(result.outcome == .renamed)
            #expect(try text(parent, "b") == "a")
            #expect(try text(parent, "a/nested/keep") == "child")
            #expect(!store.status().hasUnresolvedOperation && store.status().canUndo)
            let preview = try service.undoPreview(parentURL: parent, observationRoots: [parent])
            #expect(preview.rows.count == 2)
            #expect(try service.undo(preview: preview) { true }.outcome == .undone)
            #expect(try text(parent, "a") == "a")
            #expect(try text(parent, "b/nested/keep") == "child")
            #expect(!store.status().canUndo && !store.status().hasUnresolvedOperation)
        }
    }

    @Test("case-only names are published and reverse restoration preserves exact spelling")
    func caseOnly() throws {
        try fixture { _, parent, store in
            try files(parent)
            let service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let result = try service.execute(plan: plan(service, session: session, bodies: ["A", "B"]), session: session) { true }
            #expect(result.outcome == .renamed)
            #expect(Set(try FileManager.default.contentsOfDirectory(atPath: parent.path)) == ["A", "B"])
            #expect(try service.undo(preview: service.undoPreview(parentURL: parent, observationRoots: [parent])) { true }.outcome == .undone)
            #expect(Set(try FileManager.default.contentsOfDirectory(atPath: parent.path)) == ["a", "b"])
        }
    }

    @Test("stop during stage and publication restores original namespace")
    func stop() throws {
        for stopAt in [2, 3, 4, 5] {
            try fixture { _, parent, store in
                try files(parent)
                let service = BatchRenameService(store: store)
                let session = try makeSession(service, parent: parent, names: ["a", "b"])
                let counter = RenameTestCounter()
                let result = try service.execute(plan: plan(service, session: session, bodies: ["b", "a"]), session: session) {
                    counter.next() != stopAt
                }
                #expect(result.outcome == .restored)
                #expect(try text(parent, "a") == "a")
                #expect(try text(parent, "b") == "b")
                #expect(!store.status().hasUnresolvedOperation && !store.status().canUndo)
            }
        }
    }

    @Test("syscall versus journal crash gaps reconcile without trusting phase")
    func crashGaps() throws {
        for crashPoint in ["stage-intent", "stage-syscall", "publish-intent", "publish-syscall"] {
            try fixture { _, parent, store in
                try files(parent)
                var service = BatchRenameService(store: store)
                let session = try makeSession(service, parent: parent, names: ["a", "b"])
                let frozen = try plan(service, session: session, bodies: ["b", "a"])
                service.checkpoint = { phase, index in if phase == crashPoint && index == 0 { throw RenameSimulatedCrash() } }
                #expect(throws: RenameSimulatedCrash.self) { try service.execute(plan: frozen, session: session) { true } }
                #expect(store.status().hasUnresolvedOperation)
                let recovered = try BatchRenameService(store: store).restore(parentURL: parent)
                #expect(recovered.outcome == .restored)
                #expect(try text(parent, "a") == "a")
                #expect(try text(parent, "b") == "b")
                #expect(!store.status().hasUnresolvedOperation)
            }
        }
    }

    @Test("commit marker survives crash and never restores successful targets")
    func committedCrash() throws {
        try fixture { _, parent, store in
            try files(parent)
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            service.checkpoint = { phase, _ in if phase == "commit-marker" { throw RenameSimulatedCrash() } }
            #expect(throws: RenameSimulatedCrash.self) { try service.execute(plan: frozen, session: session) { true } }
            #expect(store.status().hasUnresolvedOperation)
            #expect(try BatchRenameService(store: store).restore(parentURL: parent).outcome == .renamed)
            #expect(try text(parent, "c") == "a")
            #expect(try text(parent, "d") == "b")
            #expect(store.status().canUndo && !store.status().hasUnresolvedOperation)
        }
    }

    @Test("concurrent occupied target stops exclusively and restores all sources")
    func publishCollision() throws {
        try fixture { _, parent, store in
            try files(parent)
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            service.checkpoint = { phase, index in
                if phase == "publish-intent", index == 1 { try Data("external".utf8).write(to: parent.appendingPathComponent("d"), options: .withoutOverwriting) }
            }
            let result = try service.execute(plan: frozen, session: session) { true }
            #expect(result.outcome == .restored)
            #expect(try text(parent, "a") == "a")
            #expect(try text(parent, "b") == "b")
            #expect(try text(parent, "d") == "external")
        }
    }

    @Test("recovery conflict preserves original in staging; opaque export retires without touching it")
    func conflictAndRetirement() throws {
        try fixture { root, parent, store in
            try files(parent)
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            service.checkpoint = { phase, index in if phase == "stage-syscall", index == 0 { throw RenameSimulatedCrash() } }
            #expect(throws: RenameSimulatedCrash.self) { try service.execute(plan: frozen, session: session) { true } }
            try Data("external".utf8).write(to: parent.appendingPathComponent("a"), options: .withoutOverwriting)
            let result = try BatchRenameService(store: store).restore(parentURL: parent)
            #expect(result.outcome == .recoveryRequired)
            let staged = try #require(result.rows.first { $0.state == .staged }?.location)
            #expect(try String(contentsOf: staged, encoding: .utf8) == "a")
            let before = try store.snapshot()
            let export = root.appendingPathComponent("evidence.json")
            try store.exportAndRetire(to: export)
            let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: export)) as! [String: Any]
            let saved = raw["files"] as! [String: String]
            #expect(before.allSatisfy { Data(base64Encoded: saved[$0.key] ?? "") == $0.value })
            #expect(try String(contentsOf: staged, encoding: .utf8) == "a")
            #expect(try text(parent, "a") == "external")
            #expect(!store.status().hasUnresolvedOperation && !store.status().canUndo)
        }
    }

    @Test("damaged unsupported records export byte-for-byte and failed export stays blocked")
    func corruptExport() throws {
        try fixture { root, _, store in
            let corrupt = Data([0, 255, 14, 0, 42])
            try store.saveData(corrupt, name: "index.json")
            try store.saveData(Data("unsupported".utf8), name: "receipt.json")
            #expect(store.status().isCorrupt)
            let existing = root.appendingPathComponent("occupied")
            try Data("keep".utf8).write(to: existing)
            #expect(throws: (any Error).self) { try store.exportAndRetire(to: existing) }
            #expect(store.status().hasUnresolvedOperation)
            #expect(try store.read("index.json") == corrupt)
            try store.exportAndRetire(to: root.appendingPathComponent("export.json"))
            #expect(!store.status().hasUnresolvedOperation)
            #expect(try String(contentsOf: existing, encoding: .utf8) == "keep")
        }
    }

    @Test("cancelled undo preserves receipt and renamed objects")
    func stoppedUndo() throws {
        try fixture { _, parent, store in
            try files(parent)
            let service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            #expect(try service.execute(plan: plan(service, session: session, bodies: ["c", "d"]), session: session) { true }.outcome == .renamed)
            let receiptBefore = try store.read("receipt.json")
            let preview = try service.undoPreview(parentURL: parent, observationRoots: [parent])
            let count = RenameTestCounter()
            #expect(try service.undo(preview: preview) { count.next() < 4 }.outcome == .restored)
            #expect(try store.read("receipt.json") == receiptBefore)
            #expect(try text(parent, "c") == "a")
            #expect(try text(parent, "d") == "b")
        }
    }

    @Test("selection replacement and same-object hardlinks are rejected before writes")
    func replacementAndHardlinks() throws {
        try fixture { _, parent, store in
            try files(parent)
            let selection = try BatchRenameSelection.capture(selection: [parent.appendingPathComponent("a"), parent.appendingPathComponent("b")])
            try FileManager.default.removeItem(at: parent.appendingPathComponent("a"))
            try Data("replacement".utf8).write(to: parent.appendingPathComponent("a"))
            #expect(throws: (any Error).self) {
                try BatchRenameService(store: store).prepare(selection: selection, parentBookmark: Data([1]), observationRoots: [parent])
            }
            #expect(link(parent.appendingPathComponent("a").path, parent.appendingPathComponent("hardlink").path) == 0)
            #expect(throws: BatchRenameError.invalidSelection) {
                try BatchRenameSelection.capture(selection: [parent.appendingPathComponent("a"), parent.appendingPathComponent("hardlink")])
            }
            #expect(!store.status().hasUnresolvedOperation)
        }
    }

    @Test("a parent replaced between Finder capture and main-app authorization is rejected")
    func capturedParentReplacement() throws {
        try fixture { root, parent, store in
            try files(parent)
            let selection = try BatchRenameSelection.capture(selection: [parent.appendingPathComponent("a"), parent.appendingPathComponent("b")])
            let displaced = root.appendingPathComponent("original-parent")
            try FileManager.default.moveItem(at: parent, to: displaced)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
            try files(parent)
            #expect(throws: BatchRenameError.parentChanged) {
                try BatchRenameService(store: store).prepare(selection: selection, parentBookmark: Data([1]),
                                                            observationRoots: [parent])
            }
            #expect(try text(displaced, "a") == "a")
            #expect(try text(parent, "a") == "a")
            #expect(!store.status().hasUnresolvedOperation && !store.status().canUndo)
        }
    }

    @Test("private store ancestors and configured roots are protected without crawling descendants")
    func protections() throws {
        try fixture { _, parent, store in
            try FileManager.default.createDirectory(at: parent.appendingPathComponent("a/control"), withIntermediateDirectories: true)
            try files(parent, names: ["b"])
            let selection = try BatchRenameSelection.capture(selection: [parent.appendingPathComponent("a"), parent.appendingPathComponent("b")])
            #expect(throws: BatchRenameError.protectedItem) {
                try BatchRenameService(store: store).prepare(selection: selection, parentBookmark: Data([1]),
                    observationRoots: [parent], privateLocations: [parent.appendingPathComponent("a/control")])
            }
            #expect(throws: BatchRenameError.protectedItem) {
                try BatchRenameService(store: store).prepare(selection: selection, parentBookmark: Data([1]),
                    observationRoots: [parent, parent.appendingPathComponent("a")])
            }
        }
    }
    @Test("package-looking directory targets remain undoable by captured identity")
    func renamedDirectoryPackageUndo() throws {
        try fixture { _, parent, store in
            for name in ["Photos", "Travel"] {
                try FileManager.default.createDirectory(at: parent.appendingPathComponent(name), withIntermediateDirectories: true)
                try Data(name.utf8).write(to: parent.appendingPathComponent(name + "/child"))
            }
            let service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["Photos", "Travel"])
            #expect(try service.execute(plan: plan(service, session: session, bodies: ["Photos.app", "Travel.bundle"]), session: session) { true }.outcome == .renamed)
            #expect(throws: BatchRenameError.unsupportedItem) {
                try makeSession(service, parent: parent, names: ["Photos.app", "Travel.bundle"])
            }
            #expect(try service.undo(preview: service.undoPreview(parentURL: parent, observationRoots: [parent])) { true }.outcome == .undone)
            #expect(try text(parent, "Photos/child") == "Photos")
            #expect(try text(parent, "Travel/child") == "Travel")
        }
    }

    @Test("an unexpected source claimed in the check-syscall gap is returned exclusively")
    func unexpectedSourceClaim() throws {
        try fixture { _, parent, store in
            try files(parent)
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            service.checkpoint = { phase, index in
                if phase == "stage-intent", index == 0 {
                    try FileManager.default.moveItem(at: parent.appendingPathComponent("a"), to: parent.appendingPathComponent("external-moved-original"))
                    try Data("replacement".utf8).write(to: parent.appendingPathComponent("a"))
                }
            }
            #expect(try service.execute(plan: frozen, session: session) { true }.outcome == .recoveryRequired)
            #expect(try text(parent, "a") == "replacement")
            #expect(try text(parent, "external-moved-original") == "a")
            #expect(try text(parent, "b") == "b")
            #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent("c").path))
        }
    }

    @Test("same object moved parent is recoverable only with its exact identity")
    func movedParentRecovery() throws {
        try fixture { root, parent, store in
            try files(parent)
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            service.checkpoint = { phase, index in if phase == "stage-syscall", index == 0 { throw RenameSimulatedCrash() } }
            #expect(throws: RenameSimulatedCrash.self) { try service.execute(plan: frozen, session: session) { true } }
            let moved = root.appendingPathComponent("moved-parent")
            try FileManager.default.moveItem(at: parent, to: moved)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try Data("replacement".utf8).write(to: parent.appendingPathComponent("a"))
            #expect(throws: BatchRenameError.parentChanged) { try BatchRenameService(store: store).restore(parentURL: parent) }
            #expect(try BatchRenameService(store: store).restore(parentURL: moved).outcome == .restored)
            #expect(try text(parent, "a") == "replacement")
            #expect(try text(moved, "a") == "a")
            #expect(try text(moved, "b") == "b")
        }
    }

    @Test("case-only recovery rejects third spelling of the same object")
    func thirdCaseSpelling() throws {
        try fixture { _, parent, store in
            try files(parent, names: ["alpha", "beta"])
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["alpha", "beta"])
            let frozen = try plan(service, session: session, bodies: ["ALPHA", "BETA"])
            service.checkpoint = { phase, index in if phase == "publish-syscall", index == 0 { throw RenameSimulatedCrash() } }
            #expect(throws: RenameSimulatedCrash.self) { try service.execute(plan: frozen, session: session) { true } }
            try FileManager.default.moveItem(at: parent.appendingPathComponent("ALPHA"), to: parent.appendingPathComponent("Alpha"))
            let result = try BatchRenameService(store: store).restore(parentURL: parent)
            #expect(result.outcome == .recoveryRequired)
            #expect(try text(parent, "Alpha") == "alpha")
            #expect(store.status().hasUnresolvedOperation)
        }
    }

    @Test("journal failure after claim stops publication and retains recoverable originals")
    func journalFailure() throws {
        try fixture { _, parent, cleanStore in
            try files(parent)
            var store = cleanStore
            let counter = RenameTestCounter()
            store.checkpoint = { point in
                if point == "saved-journal.json", counter.next() >= 3 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO)) }
            }
            let service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let result = try service.execute(plan: plan(service, session: session, bodies: ["c", "d"]), session: session) { true }
            #expect(result.outcome == .recoveryRequired)
            #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent("c").path))
            #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent("d").path))
            #expect(try BatchRenameService(store: cleanStore).restore(parentURL: parent).outcome == .restored)
            #expect(try text(parent, "a") == "a")
            #expect(try text(parent, "b") == "b")
        }
    }

    @Test("missing empty staging after rollback cleanup is safely finalized")
    func removedStageCrashGap() throws {
        try fixture { _, parent, store in
            try files(parent)
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            service.checkpoint = { point, _ in if point == "staging-removed" { throw RenameSimulatedCrash() } }
            let counter = RenameTestCounter()
            #expect(try service.execute(plan: frozen, session: session) { counter.next() < 3 }.outcome == .recoveryRequired)
            #expect(store.status().hasUnresolvedOperation)
            #expect(try BatchRenameService(store: store).restore(parentURL: parent).outcome == .restored)
            #expect(try text(parent, "a") == "a")
            #expect(try text(parent, "b") == "b")
        }
    }

    @Test("terminal cleanup binds exact metadata and never deletes changed evidence")
    func terminalMetadataBinding() throws {
        try fixture { root, parent, cleanStore in
            try files(parent)
            var store = cleanStore
            let counter = RenameTestCounter()
            store.checkpoint = { point in
                if point == "saved-index.json", counter.next() == 4 { throw RenameSimulatedCrash() }
            }
            let service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            #expect(throws: RenameSimulatedCrash.self) { try service.execute(plan: frozen, session: session) { true } }
            #expect(cleanStore.status().requiresMetadataFinalization)
            let changed = Data("changed-after-terminal".utf8)
            try cleanStore.saveData(changed, name: "manifest.json")
            #expect(cleanStore.status().isCorrupt)
            #expect(throws: BatchRenameError.stateChanged) { try cleanStore.finalizeCompletedOperation() }
            #expect(try cleanStore.read("manifest.json") == changed)
            try cleanStore.exportAndRetire(to: root.appendingPathComponent("metadata-evidence.json"))
            #expect(try text(parent, "c") == "a")
            #expect(try text(parent, "d") == "b")
            #expect(!cleanStore.status().hasUnresolvedOperation)
        }
    }

    @Test("retirement survives marker and per-file cleanup interruptions")
    func retirementInterruptions() throws {
        for point in ["retirement-marker", "removed-manifest.json", "removed-receipt.json"] {
            try fixture { root, _, cleanStore in
                try cleanStore.saveData(Data("bad-index".utf8), name: "index.json")
                try cleanStore.saveData(Data("raw-manifest".utf8), name: "manifest.json")
                try cleanStore.saveData(Data("raw-receipt".utf8), name: "receipt.json")
                var store = cleanStore
                store.checkpoint = { current in if current == point { throw RenameSimulatedCrash() } }
                #expect(throws: RenameSimulatedCrash.self) { try store.exportAndRetire(to: root.appendingPathComponent("evidence.json")) }
                #expect(cleanStore.status().hasUnresolvedOperation)
                #expect(cleanStore.status().requiresMetadataFinalization)
                try cleanStore.finalizeRetirement()
                #expect(!cleanStore.status().hasUnresolvedOperation && !cleanStore.status().canUndo)
            }
        }
    }

    @Test("fixed scratch crash bytes block new work and are included before safe retirement reuse")
    func scratchRetirement() throws {
        try fixture { root, _, store in
            try store.saveData(Data("bad-index".utf8), name: "index.json")
            let partial = Data("partial-atomic-index".utf8)
            let scratch = store.directory.appendingPathComponent("pending-index.json")
            try partial.write(to: scratch, options: .withoutOverwriting)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: scratch.path)
            #expect(store.status().hasUnresolvedOperation && store.status().isCorrupt)
            #expect(throws: (any Error).self) { try store.saveData(Data("replacement".utf8), name: "index.json") }
            #expect(try Data(contentsOf: scratch) == partial)
            let export = root.appendingPathComponent("export.json")
            try store.exportAndRetire(to: export)
            let envelope = try JSONSerialization.jsonObject(with: Data(contentsOf: export)) as! [String: Any]
            let files = envelope["files"] as! [String: String]
            #expect(Data(base64Encoded: files["pending-index.json"]!) == partial)
            #expect(!store.status().hasUnresolvedOperation)
        }
    }

    @Test("preparation reserves the bounded operation slot before staging exists")
    func preparationCrashGap() throws {
        try fixture { root, parent, store in
            try files(parent)
            var service = BatchRenameService(store: store)
            let session = try makeSession(service, parent: parent, names: ["a", "b"])
            let frozen = try plan(service, session: session, bodies: ["c", "d"])
            service.checkpoint = { point, _ in if point == "preparing-reserved" { throw RenameSimulatedCrash() } }
            #expect(throws: RenameSimulatedCrash.self) { try service.execute(plan: frozen, session: session) { true } }
            #expect(store.status().hasUnresolvedOperation)
            #expect(throws: BatchRenameError.recoveryRequired) { try makeSession(BatchRenameService(store: store), parent: parent, names: ["a", "b"]) }
            #expect(Set(try FileManager.default.contentsOfDirectory(atPath: parent.path)) == ["a", "b"])
            #expect(try text(parent, "a") == "a")
            #expect(try text(parent, "b") == "b")
            try store.exportAndRetire(to: root.appendingPathComponent("preparation.json"))
            #expect(!store.status().hasUnresolvedOperation)
        }
    }

    @Test("retirement exports but never truncates a scratch hardlink to a user original")
    func hardlinkedScratchPreservesOriginal() throws {
        try fixture { root, _, store in
            let index = Data("bad-index".utf8)
            try store.saveData(index, name: "index.json")
            let original = root.appendingPathComponent("manual-original")
            let originalBytes = Data("original-must-survive-retirement".utf8)
            try originalBytes.write(to: original, options: .withoutOverwriting)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: original.path)
            let capturedIdentity = try BatchRenameIdentity.path(original)
            let originalIdentity = try #require(capturedIdentity)
            let scratch = store.directory.appendingPathComponent("pending-index.json")
            #expect(link(original.path, scratch.path) == 0)
            let export = root.appendingPathComponent("hardlink-evidence.json")
            #expect(throws: BatchRenameError.corruptStore) { try store.exportAndRetire(to: export) }
            #expect(try Data(contentsOf: original) == originalBytes)
            #expect(try Data(contentsOf: scratch) == originalBytes)
            #expect(try BatchRenameIdentity.path(original) == originalIdentity)
            #expect(try BatchRenameIdentity.path(scratch) == originalIdentity)
            #expect(try store.read("index.json") == index)
            #expect(store.status().hasUnresolvedOperation)
            let envelope = try JSONSerialization.jsonObject(with: Data(contentsOf: export)) as! [String: Any]
            let files = envelope["files"] as! [String: String]
            #expect(Data(base64Encoded: files["pending-index.json"]!) == originalBytes)
            #expect(Data(base64Encoded: files["index.json"]!) == index)
        }
    }

    @Test("new scratch cleanup preserves a replacement arriving after publication")
    func scratchCleanupPreservesReplacement() throws {
        try fixture { _, _, cleanStore in
            try cleanStore.saveData(Data("old-index".utf8), name: "index.json")
            let scratch = cleanStore.directory.appendingPathComponent("pending-index.json")
            let replacement = Data("external-scratch-replacement".utf8)
            var store = cleanStore
            store.checkpoint = { point in
                if point == "saved-index.json" {
                    try replacement.write(to: scratch, options: .withoutOverwriting)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: scratch.path)
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(EIO))
                }
            }
            let saved = Data("new-index".utf8)
            #expect(throws: (any Error).self) { try store.saveData(saved, name: "index.json") }
            #expect(try cleanStore.read("index.json") == saved)
            #expect(try Data(contentsOf: scratch) == replacement)
            #expect(cleanStore.status().hasUnresolvedOperation)
        }
    }

}
private final class RenameTestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}
