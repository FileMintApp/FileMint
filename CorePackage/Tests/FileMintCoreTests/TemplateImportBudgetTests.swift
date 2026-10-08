import Foundation
import Testing
@testable import FileMintCore

struct TemplateImportBudgetTests {
    private func emptyPreferences() -> FileMintPreferences {
        var preferences = FileMintPreferences(templates: [], monitoredFolderURLs: [], collisionStrategy: .increment,
            revealAfterCreation: false, favoritesFirst: false)
        preferences.removedBuiltInTemplateIDs = TemplateCatalog.builtInTemplates.map(\.id).sorted()
        return preferences
    }

    private func package(body: String, count: Int) throws -> ValidatedTemplatePackage {
        let templates = (0..<count).map { index in
            FileTemplate(id: "budget-\(index)", displayName: "Budget \(index)", suggestedFileName: "Budget.txt",
                group: "Custom", content: body, rank: index + 1)
        }
        return try TemplatePackageCodec.decode(TemplatePackageCodec.encode(
            templates: templates, defaults: [:], assets: DocumentTemplateStore()))
    }

    @Test func budgetMatchesPersistedEscapingAtUTF8ChunkBoundaries() throws {
        let controls = String((0..<32).map { Character(UnicodeScalar($0)!) })
        for text in ["", "plain text", controls + "\"\\/", "中文😀e\u{301}\u{2028}\u{2029}",
                     String(repeating: "x", count: 65_535) + "😀\"\\/\n",
                     String(repeating: "x", count: 65_534) + "中e\u{301}\u{2028}",
                     String(repeating: "x", count: 65_535) + "</end>"] {
            let bytes = Data(text.utf8)
            let encodedBytes = try JSONEncoder().encode(text).count - 2
            var budget = TemplateImportTextBudget(maximumBytes: encodedBytes * 2 + 7)
            try budget.include(bytes, payloadID: "shared")
            try budget.include(bytes, payloadID: "shared")
            try budget.validate(metadataBytes: 7)
            #expect(throws: TemplatePackageError.tooLarge) { try budget.validate(metadataBytes: 8) }
            if encodedBytes > 0 {
                var insufficient = TemplateImportTextBudget(maximumBytes: encodedBytes - 1)
                #expect(throws: TemplatePackageError.tooLarge) { try insufficient.include(bytes, payloadID: "text") }
            }
        }
    }

    @Test func sharedPayloadAmplificationRejectsWithoutChangingStoredSettings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appendingPathComponent("preferences.json")
        let store = FileMintPreferencesStore(fileURL: storeURL), original = emptyPreferences()
        try store.save(original)
        let before = try Data(contentsOf: storeURL)
        let body = String(repeating: "x", count: 512 * 1024)
        let incoming = try package(body: body, count: 80)
        #expect(incoming.descriptors.count == 1)
        #expect(throws: TemplatePackageError.tooLarge) { try TemplateImportPlanner.plan(incoming, into: original) }
        #expect(try Data(contentsOf: storeURL) == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["preferences.json"])

        var choices = Dictionary(uniqueKeysWithValues: incoming.templates.map { ($0.id, TemplateImportChoice.skip) })
        let skipped = try TemplateImportPlanner.plan(incoming, into: original, choices: choices)
        #expect(skipped.acceptedCount == 0 && skipped.preferences == original)
        choices["budget-0"] = .copy
        choices["budget-1"] = .add
        let accepted = try TemplateImportPlanner.plan(incoming, into: original, choices: choices)
        #expect(accepted.acceptedCount == 2)
        #expect(accepted.rows[0].choice == .copy && accepted.rows[1].choice == .add)
        #expect(accepted.preferences.templates.allSatisfy { Data($0.content.utf8) == Data(body.utf8) })
        let receipt = try TemplateImportTransaction(journalURL: root.appendingPathComponent("journal.json"),
            preferencesURL: storeURL, assets: DocumentTemplateStore(directory: root.appendingPathComponent("assets"))).commit(accepted)
        #expect(!receipt.cleanupPending && store.load() == receipt.preferences)
        #expect(store.load().templates.count == 2)
    }

    @Test func repeatedEscapedTextUsesJSONSizeInsteadOfRawPayloadSize() throws {
        // Six 1 MiB references fit the raw-text budget, but JSON needs 36 MiB.
        let body = String(repeating: "\0", count: 1024 * 1024)
        let incoming = try package(body: body, count: 6)
        let original = emptyPreferences()
        #expect(incoming.payloads.values.reduce(0) { $0 + $1.count } == 1024 * 1024)
        #expect(throws: TemplatePackageError.tooLarge) { try TemplateImportPlanner.plan(incoming, into: original) }
        let choices = Dictionary(uniqueKeysWithValues: incoming.templates.dropFirst().map { ($0.id, TemplateImportChoice.skip) })
        let plan = try TemplateImportPlanner.plan(incoming, into: original, choices: choices)
        #expect(plan.acceptedCount == 1)
        #expect(Data(plan.preferences.templates[0].content.utf8) == Data(body.utf8))
    }

    @Test func textBudgetHonorsCancellation() async {
        let task = Task.detached {
            withUnsafeCurrentTask { $0?.cancel() }
            var budget = TemplateImportTextBudget()
            try budget.include(Data(repeating: 120, count: 128 * 1024), payloadID: "cancelled")
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
