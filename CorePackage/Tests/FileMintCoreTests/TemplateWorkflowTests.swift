import Foundation
import Testing
@testable import FileMintCore

struct TemplateWorkflowTests {
    @Test func copiedTemplateReplacesItsEntireOriginalSuffix() throws {
        let source = FileTemplate(id: "custom-source", displayName: "Definition", suggestedFileName: "Untitled.d.ts",
            group: "Custom", content: "keep {{fileName}}", rank: 10, fileExtension: "d.ts")
        let copy = TemplateCatalog.copyDraft(source, copySuffix: "Copy")
        for (name, suffix, expected) in [
            (copy.suggestedFileName, "md", "Untitled.md"),
            ("Renamed.D.TS", "test.js", "Renamed.test.js"),
            (copy.suggestedFileName, "d.ts", "Untitled.d.ts"),
            ("Explicit.md", "md", "Explicit.md")
        ] {
            let saved = try TemplateCatalog.customTemplate(name: copy.displayName, fileExtension: suffix,
                content: copy.content, id: copy.id, in: [source], suggestedFileName: name,
                replacingFileExtension: copy.fileExtension)
            let inserted = TemplateCatalog.insertingCopy(saved, after: source.id, in: [source])
            #expect(inserted[0] == source)
            #expect(inserted[1].id == copy.id && inserted[1].suggestedFileName == expected)
            #expect(inserted[1].content == source.content && inserted[1].fileExtension == suffix)
        }
    }

    @Test func selectedApplicationRequiresPortableIdentityButNotALocalGrant() throws {
        #expect(!TemplateCreationAction(.openWithApplication).isValid)
        #expect(throws: TemplateCreationActionError.self) { try TemplateCreationAction(.openWithApplication).validate() }
        let hint = CreationApplicationHint(bundleIdentifier: "com.microsoft.VSCode", displayName: "Code")
        let unresolved = TemplateCreationAction(.openWithApplication, application: hint)
        try unresolved.validate()
        var template = TemplateCatalog.builtInTemplates[0]
        template.afterCreation = unresolved
        let archive = try TemplatePackageCodec.encode(templates: [template], defaults: [:], assets: DocumentTemplateStore())
        #expect(try TemplatePackageCodec.decode(archive).templates[0].afterCreation == unresolved)

        var preferences = FileMintPreferences.default
        preferences.revealAfterCreation = false
        preferences.templates[0].afterCreation = .init(.openWithApplication)
        preferences.templates[1].afterCreation = unresolved
        let decoded = try FileMintPreferencesStore.decode(JSONEncoder().encode(preferences))
        #expect(decoded.templates[0].afterCreation == .basic(reveal: false))
        #expect(decoded.templates[1].afterCreation == unresolved)
    }

    @Test func gatesAndActionsMigrateIndependentlyWithoutLosingNeighbors() throws {
        var old = FileMintPreferences.default
        old.revealAfterCreation = false
        old.templates[0].afterCreation = .init(.openWithApplication, application: .init(bundleIdentifier: "example.editor", displayName: "Editor"))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        var templates = try #require(json["templates"] as? [[String: Any]])
        templates[1]["afterCreation"] = ["kind": "future"]
        templates[2].removeValue(forKey: "afterCreation")
        json["templates"] = templates
        json["creationOpeningEnabled"] = "true"
        json["templatePreviewEnabled"] = 1
        let decoded = try FileMintPreferencesStore.decode(JSONSerialization.data(withJSONObject: json))
        #expect(!decoded.creationOpeningEnabled && !decoded.templatePreviewEnabled)
        #expect(decoded.templates[0].afterCreation == old.templates[0].afterCreation)
        #expect(decoded.templates[1].afterCreation == .basic(reveal: false))
        #expect(decoded.templates[2].afterCreation == .basic(reveal: false))
        #expect(decoded.templates.map(\.id) == old.templates.map(\.id))
        var enabled = decoded; enabled.creationOpeningEnabled = true; enabled.templatePreviewEnabled = true
        #expect(try FileMintPreferencesStore.decode(JSONEncoder().encode(enabled)) == enabled)
    }

    @Test func disableGenerationCannotRevivePendingOpening() {
        var gate = CreationOpeningGate(enabled: false)
        let offRequest = gate.permission
        gate.commit(enabled: true)
        #expect(!gate.permits(offRequest))
        let onRequest = gate.permission
        #expect(gate.permits(onRequest))
        gate.commit(enabled: false); gate.commit(enabled: true)
        #expect(!gate.permits(onRequest))
        #expect(gate.permits(gate.permission))
    }

    @Test func copyPreservesCompleteFieldsAndDefaultsAndRestoration() throws {
        var prefs = FileMintPreferences.default
        prefs.templates[0].isEnabled = false
        prefs.templates[0].afterCreation = .init(.openWithDefaultApp)
        let source = prefs.templates[0]
        let copy = TemplateCatalog.copyDraft(source, copySuffix: "副本", id: "custom-copy")
        #expect(copy.isEnabled && copy.id != source.id && copy.afterCreation == source.afterCreation)
        #expect(copy.displayName == "Text 副本" && copy.content == source.content)
        let inserted = TemplateCatalog.insertingCopy(copy, after: source.id, in: prefs.templates)
        #expect(inserted[1].id == copy.id && inserted[0] == source)
        let orphan = TemplateCatalog.insertingCopy(copy, after: source.id, in: [])
        #expect(orphan.map(\.id) == [copy.id])
        let restored = TemplateCatalog.restoringBuiltIns(in: inserted, revealAfterCreation: false)
        #expect(restored.first { $0.id == copy.id }?.afterCreation == source.afterCreation)
        #expect(restored.first { $0.id == source.id }?.afterCreation == .basic(reveal: false))
        let edited = try TemplateCatalog.customTemplate(name: "Renamed", fileExtension: "txt", content: "changed", id: source.id, in: [source])
        #expect(edited.afterCreation == source.afterCreation)
        let officeCopy = TemplateCatalog.copyDraft(BuiltInDocumentTemplate.allCases[0].template, copySuffix: "Copy")
        #expect(officeCopy.document == BuiltInDocumentTemplate.allCases[0].reference)
    }

    @Test func copyingDisabledSourcePreservesTheEffectiveSuffixDefault() {
        var source = TemplateCatalog.builtInTemplates[0], fallback = source
        source.isEnabled = false; fallback.id = "custom-fallback"; fallback.rank = 20
        var preferences = FileMintPreferences.default
        preferences.templates = [source, fallback]
        let copy = TemplateCatalog.copyDraft(source, copySuffix: "Copy")
        let candidate = TemplateCatalog.preferencesInsertingCopy(copy, after: source.id, in: preferences)
        #expect(candidate.templates[1].id == copy.id && candidate.templates[1].isEnabled)
        #expect(TemplateCatalog.defaultTemplate(forExtension: "txt", in: candidate.templates, defaults: candidate.defaultTemplateIDs)?.id == fallback.id)
    }
    @Test func followingAndTemporaryActionsHaveExactTemplateProvenance() {
        var first = TemplateCatalog.builtInTemplates[0], second = first
        first.afterCreation = .init(.openWithDefaultApp); second.id = "second"; second.afterCreation = .init(.none)
        let follow = CreationActionSelection.followTemplate, fallback = TemplateCreationAction.basic(reveal: true)
        #expect(follow.resolve(template: first, fallback: fallback, enabled: true).opensApplication)
        #expect(follow.resolve(template: second, fallback: fallback, enabled: true).kind == .none)
        let override = CreationActionSelection.override(.init(.openWithDefaultApp))
        #expect(override.resolve(template: second, fallback: fallback, enabled: true).opensApplication)
        #expect(override.resolve(template: first, fallback: fallback, enabled: false) == fallback)
        #expect(follow.resolve(template: nil, fallback: fallback, enabled: true) == fallback)
    }

    @Test func frozenResolutionUsesActualCollisionNameAndEditedBytes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let time = Date(timeIntervalSince1970: 1_767_225_599) // 2025-12-31 23:59:59 UTC
        let template = FileTemplate(id: "test", displayName: "Test", suggestedFileName: "{{year}}.txt", group: "Custom",
            content: "\u{FEFF}{{fileName}}\r\n{{date}} {{isoDate}} {{year}}\n汉字", rank: 10)
        let preview = CreationContentResolver.text(template: template, fileName: "{{year}}.txt", mode: .template, capturedAt: time)
        #expect(preview == "\u{FEFF}{{year}}.txt\r\n2025-12-31 2025-12-31T23:59:59Z 2025\n汉字")
        let request = FileCreationRequest(destinationDirectory: root, template: template, capturedAt: time)
        let one = try FileCreationService().createFile(request, now: .distantFuture)
        #expect(try Data(contentsOf: one.createdURL) == Data(preview.utf8))
        let two = try FileCreationService().createFile(request, now: .distantFuture)
        #expect(try Data(contentsOf: two.createdURL) == Data("\u{FEFF}{{year}} 2.txt\r\n2025-12-31 2025-12-31T23:59:59Z 2025\n汉字".utf8))
        var draft = CustomFileDraft(content: "literal {{date}}\r\n", hasEditedContent: true, capturedAt: time)
        draft.updateExtensionInput("md")
        #expect(draft.capturedAt == time && draft.content == "literal {{date}}\r\n")
    }

    @Test func receiptsDescribeActualBytesAndRejectReplacementFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let template = TemplateCatalog.builtInTemplates[0]
        let binary = try FileCreationService().createFile(.init(destinationDirectory: root, template: template, fileData: Data([1,2,3])))
        #expect(binary.contentKind == .binary)
        let identity = try #require(binary.identity)
        try identity.validate(binary.createdURL)
        try FileManager.default.moveItem(at: binary.createdURL, to: root.appendingPathComponent("preserved"))
        try Data([1,2,3]).write(to: binary.createdURL)
        #expect(throws: CocoaError.self) { try identity.validate(binary.createdURL) }
    }
    @Test func editorPolicyRejectsExecutableAndUnknownDefaultHandlers() {
        #expect(CreationEditingPolicy.permits(bundleIdentifier: "com.apple.TextEdit", isDocument: false))
        #expect(CreationEditingPolicy.permits(bundleIdentifier: "com.microsoft.VSCode", isDocument: false))
        #expect(!CreationEditingPolicy.permits(bundleIdentifier: "com.apple.Terminal", isDocument: false))
        #expect(!CreationEditingPolicy.permits(bundleIdentifier: "unknown", isDocument: false))
        #expect(!CreationEditingPolicy.permits(bundleIdentifier: "com.apple.TextEdit", isDocument: true))
    }
}
