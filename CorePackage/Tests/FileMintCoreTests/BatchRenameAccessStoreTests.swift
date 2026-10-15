@testable import FileMintCore
import Darwin
import Foundation
import Testing

@Suite("Batch rename remembered directory grants")
struct BatchRenameAccessStoreTests {
    private func fixture(_ body: (URL, URL, BatchRenameAccessStore, BatchRenameIdentity) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rename-grants-\(UUID().uuidString)")
        let parent = root.appendingPathComponent("items")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let identity = try #require(try BatchRenameIdentity.path(parent))
        try body(root, parent, .init(file: root.appendingPathComponent("private/access.json")), identity)
    }

    @Test("fresh instances restore private versioned grants without operation state")
    func persistence() throws {
        try fixture { _, parent, store, identity in
            #expect(try store.load().isEmpty)
            try store.remember(parent: parent, identity: identity, bookmark: Data([1, 2, 3]))
            #expect(try BatchRenameAccessStore(file: store.file).load()[parent.path] == .init(identity: identity, bookmark: Data([1, 2, 3])))
            let attributes = try FileManager.default.attributesOfItem(atPath: store.file.path)
            #expect(attributes[.posixPermissions] as? Int == 0o600)
            let directory = try FileManager.default.attributesOfItem(atPath: store.file.deletingLastPathComponent().path)
            #expect(directory[.posixPermissions] as? Int == 0o700)
        }
    }

    @Test("moving a granted directory updates only its own path and preserves other grants")
    func relocationAndCandidates() throws {
        try fixture { root, parent, store, identity in
            let other = root.appendingPathComponent("other")
            try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
            let otherID = try #require(try BatchRenameIdentity.path(other))
            try store.remember(parent: other, identity: otherID, bookmark: Data([2]))
            try store.remember(parent: parent, identity: identity, bookmark: Data([1]))
            let moved = root.appendingPathComponent("moved")
            try FileManager.default.moveItem(at: parent, to: moved)
            let saved = try store.load()
            #expect(BatchRenameAccessStore.candidates(for: moved, identity: identity, grants: saved).map(\.path) == [parent.path])
            try store.remember(parent: moved, identity: identity, bookmark: Data([3]))
            let updated = try store.load()
            #expect(updated[parent.path] == nil && updated[moved.path]?.bookmark == Data([3]))
            #expect(updated[other.path] == saved[other.path])
            // Same spelling after replacement remains a candidate for rejection,
            // but the stored identity is never silently changed to the new one.
            try FileManager.default.moveItem(at: moved, to: root.appendingPathComponent("displaced"))
            try FileManager.default.createDirectory(at: moved, withIntermediateDirectories: false)
            let replacement = try #require(try BatchRenameIdentity.path(moved))
            #expect(replacement != identity)
            let candidates = BatchRenameAccessStore.candidates(for: moved, identity: replacement, grants: updated)
            #expect(candidates.count == 1 && candidates[0].grant.identity != replacement)
        }
    }

    @Test("invalid or oversized changes preserve the existing valid grants")
    func rejectedWrites() throws {
        try fixture { _, parent, store, identity in
            try store.remember(parent: parent, identity: identity, bookmark: Data([1]))
            let before = try Data(contentsOf: store.file)
            let grant = BatchRenameAccessGrant(identity: identity, bookmark: Data([1]))
            let oversized = Dictionary(uniqueKeysWithValues: (0...BatchRenameAccessStore.maximumGrants).map { ("/grant-\($0)", grant) })
            for invalid in [["relative": grant], ["/bad/../path": grant], ["/bad\0path": grant],
                            [parent.path: .init(identity: identity, bookmark: Data())],
                            [parent.path: .init(identity: identity, bookmark: Data(repeating: 1, count: BatchRenameAccessStore.maximumBytes))],
                            oversized] {
                #expect(throws: BatchRenameAccessStoreError.unavailable) { try store.save(invalid) }
                #expect(try Data(contentsOf: store.file) == before)
            }
        }
    }

    @Test("damaged, unsupported and redirected caches are preserved")
    func damagedStores() throws {
        try fixture { _, parent, store, identity in
            try store.remember(parent: parent, identity: identity, bookmark: Data([1]))
            let valid = try Data(contentsOf: store.file)
            var unsupported = try #require(try JSONSerialization.jsonObject(with: valid) as? [String: Any])
            unsupported["version"] = 99
            for data in [Data("broken".utf8), try JSONSerialization.data(withJSONObject: unsupported),
                         Data(repeating: 32, count: BatchRenameAccessStore.maximumBytes + 1)] {
                try data.write(to: store.file)
                #expect(throws: BatchRenameAccessStoreError.unavailable) { try store.load() }
                #expect(throws: BatchRenameAccessStoreError.unavailable) {
                    try store.remember(parent: parent, identity: identity, bookmark: Data([2]))
                }
                #expect(try Data(contentsOf: store.file) == data)
            }
            try valid.write(to: store.file)
            let other = store.file.deletingLastPathComponent().appendingPathComponent("other.json")
            try FileManager.default.moveItem(at: store.file, to: other)
            try FileManager.default.createSymbolicLink(at: store.file, withDestinationURL: other)
            #expect(throws: BatchRenameAccessStoreError.unavailable) { try store.load() }
            #expect(throws: BatchRenameAccessStoreError.unavailable) { try store.save([:]) }
            #expect(try Data(contentsOf: other) == valid)
        }
    }

    @Test("hard-linked authorization records are never read or overwritten")
    func hardLinkedStore() throws {
        try fixture { root, parent, store, identity in
            try store.remember(parent: parent, identity: identity, bookmark: Data([1]))
            let before = try Data(contentsOf: store.file)
            let linked = root.appendingPathComponent("linked.json")
            #expect(link(store.file.path, linked.path) == 0)
            #expect(throws: BatchRenameAccessStoreError.unavailable) { try store.load() }
            #expect(throws: BatchRenameAccessStoreError.unavailable) { try store.save([:]) }
            #expect(try Data(contentsOf: linked) == before)
        }
    }

    @Test("undo, receipt forgetting and manual retirement never erase remembered grants")
    func independentLifetime() throws {
        try fixture { root, parent, store, identity in
            try store.remember(parent: parent, identity: identity, bookmark: Data([1]))
            let original = try Data(contentsOf: store.file)
            for name in ["a.txt", "b.txt"] { try Data(name.utf8).write(to: parent.appendingPathComponent(name)) }
            let operations = BatchRenameStore(directory: root.appendingPathComponent("operations"))
            let service = BatchRenameService(store: operations)
            func rename() throws {
                let selection = try BatchRenameSelection.capture(selection: ["a.txt", "b.txt"].map { parent.appendingPathComponent($0) })
                let session = try service.prepare(selection: selection, parentBookmark: Data([1]),
                    observationRoots: [root], privateLocations: [store.file])
                let preview = try BatchRenamePlanner.preview(batch: session.batch, revision: 1, mode: .rules([.prepend("new_")]),
                    caseSensitivity: session.caseSensitivity, nativeNameByteLimit: session.nativeNameByteLimit)
                let plan = try BatchRenamePlanner.freeze(BatchRenamePlanner.checkingTargets(of: preview,
                    using: service.observeTargets(preview: preview, session: session)))
                #expect(try service.execute(plan: plan, session: session) { true }.outcome == .renamed)
            }
            try rename()
            #expect(try service.undo(preview: service.undoPreview(parentURL: parent,
                observationRoots: [root], privateLocations: [store.file])) { true }.outcome == .undone)
            #expect(!operations.status().canUndo)
            #expect(try Data(contentsOf: store.file) == original)
            try rename()
            try operations.forgetReceipt()
            #expect(try Data(contentsOf: store.file) == original)
            try operations.saveData(Data("broken".utf8), name: "index.json")
            try operations.exportAndRetire(to: root.appendingPathComponent("evidence.json"))
            #expect(!operations.status().hasUnresolvedOperation)
            #expect(try Data(contentsOf: store.file) == original)
            #expect(try store.load()[parent.path]?.identity == identity)
            #expect(!FolderScope.contains(BatchRenameAccessStore().file, in: [BatchRenameStore().directory]))
        }
    }
}
