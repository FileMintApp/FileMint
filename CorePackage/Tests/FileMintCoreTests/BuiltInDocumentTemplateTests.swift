import Foundation
import Testing
@testable import FileMintCore

struct BuiltInDocumentTemplateTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func newInstallHasSearchableEnabledOfficeTemplatesAndProtectsEditedDrafts() throws {
        let preferences = FileMintPreferences.default
        let options = FileFormatCatalog.options(from: preferences.templates)
        for (id, suffix, name, query) in [("word-document", "docx", "Word 文档", "文档"),
                                         ("excel-workbook", "xlsx", "Excel 工作簿", "表格")] {
            let template = try #require(preferences.templates.first { $0.id == id })
            #expect(template.isEnabled && template.fileExtension == suffix && template.content.isEmpty)
            #expect(template.document?.builtInResource != nil)
            #expect(FileMintStrings.templateDisplayName(for: template, language: .chinese) == name)
            #expect(FileFormatCatalog.matching(query, in: options).contains { $0.id == id })
            #expect(FileFormatCatalog.matching(suffix, in: options).first?.id == id)
            let option = try #require(options.first { $0.id == id })
            var draft = CustomFileDraft()
            let selected = draft.selectFormat(option)
            #expect(selected && draft.selectedTemplateID == id && draft.normalizedFileExtension == suffix)
            var edited = CustomFileDraft()
            edited.updateContent("keep my unsaved text")
            let before = edited
            let accepted = edited.selectFormat(option)
            #expect(!accepted && edited == before)
        }
        #expect(preferences.defaultTemplateIDs.isEmpty)
        #expect(TemplateCatalog.enabledTemplates(from: preferences.templates).count == 9)
    }

    @Test func bundledDocumentsCreateIndependentCopiesWithoutImportAndNeverDeleteAssets() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DocumentTemplateStore(directory: root.appendingPathComponent("imports"))
        for builtIn in BuiltInDocumentTemplate.allCases {
            var template = builtIn.template
            let reference = try #require(template.document)
            let original = try store.data(for: reference)
            try OfficeDocumentValidator.validate(original, kind: reference.kind)
            template.content = "Do not render {{date}} as text"
            let creator = FileCreationService(documentTemplates: store)
            for name in ["Untitled.\(reference.kind.rawValue)", "Untitled 2.\(reference.kind.rawValue)"] {
                let output = try creator.createFile(.init(destinationDirectory: root, template: template))
                #expect(output.createdURL.lastPathComponent == name)
                #expect(try Data(contentsOf: output.createdURL) == original)
            }
            #expect(!FileManager.default.fileExists(atPath: store.directory.path))
            try store.remove(reference)
            #expect(try store.data(for: reference) == original)
            let encoded = try JSONEncoder().encode(template)
            #expect(try JSONDecoder().decode(FileTemplate.self, from: encoded) == template)
            #expect(!String(decoding: encoded, as: UTF8.self).contains(root.path))
        }
        // A managed file with the same UUID is unrelated to the bundled resource.
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let reference = BuiltInDocumentTemplate.word.reference
        let shadow = store.directory.appendingPathComponent(reference.id.uuidString + ".docx")
        try Data("keep this private file".utf8).write(to: shadow)
        try store.remove(reference)
        #expect(try String(contentsOf: shadow, encoding: .utf8) == "keep this private file")
    }

    @Test func unavailableOrUnrecognizedBundledAssetsFailWithoutOutputOrManagedFallback() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let resources = root.appendingPathComponent("bundle")
        let outputs = root.appendingPathComponent("outputs")
        let imports = root.appendingPathComponent("imports")
        for directory in [resources, outputs, imports] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let store = DocumentTemplateStore(directory: imports, bundledDirectory: resources)
        let builtIn = BuiltInDocumentTemplate.word
        let reference = builtIn.reference
        let bytes = try DocumentTemplateStore().data(for: reference)
        let shadow = imports.appendingPathComponent(reference.id.uuidString + ".docx")
        try bytes.write(to: shadow)
        let resource = resources.appendingPathComponent(builtIn.rawValue + ".docx")
        let creator = FileCreationService(documentTemplates: store)
        // Missing, damaged and linked resources cannot fall back to the private asset.
        for state in 0..<3 {
            if state == 1 { try Data("broken package".utf8).write(to: resource) }
            if state == 2 {
                try FileManager.default.removeItem(at: resource)
                try FileManager.default.createSymbolicLink(at: resource, withDestinationURL: shadow)
            }
            do {
                _ = try creator.createFile(.init(destinationDirectory: outputs, template: builtIn.template))
                Issue.record("An unavailable bundled document must not create an output")
            } catch DocumentTemplateError.builtInUnavailable {} // Actionable bundled-resource guidance.
            #expect(try FileManager.default.contentsOfDirectory(atPath: outputs.path).isEmpty)
        }
        try FileManager.default.removeItem(at: resource)
        try bytes.write(to: resource)
        for invalid in [
            DocumentTemplateReference(id: reference.id, kind: .docx, byteCount: bytes.count, sha256: reference.sha256,
                builtInResource: "../blank-word-v1"),
            DocumentTemplateReference(id: reference.id, kind: .docx, byteCount: bytes.count, sha256: String(repeating: "0", count: 64),
                builtInResource: builtIn.rawValue),
            DocumentTemplateReference(id: UUID(), kind: .docx, byteCount: bytes.count, sha256: reference.sha256,
                builtInResource: builtIn.rawValue)
        ] {
            var template = builtIn.template
            template.document = invalid
            #expect(throws: DocumentTemplateError.self) {
                try creator.createFile(.init(destinationDirectory: outputs, template: template))
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: outputs.path).isEmpty)
        }
        #expect(try Data(contentsOf: shadow) == bytes)
    }

    @Test func upgradeAppendsDisabledPresetsAndPreservesCustomOfficeDefault() throws {
        var old = FileMintPreferences.default
        old.templates.removeAll { $0.document?.builtInResource != nil }
        var custom = try TemplateCatalog.customTemplate(name: "Weekly", fileExtension: "docx", content: "", id: "weekly",
            in: old.templates, suggestedFileName: "Weekly.docx")
        // Legacy references had no bundled-resource field.
        let legacy = Data(#"{"id":"1218F409-7F64-447E-9F57-A653B665CC21","kind":"docx","byteCount":1,"sha256":"legacy"}"#.utf8)
        custom.document = try JSONDecoder().decode(DocumentTemplateReference.self, from: legacy)
        #expect(custom.document?.builtInResource == nil)
        old.templates.append(custom)
        old.defaultTemplateIDs = ["docx": custom.id]
        old.language = .chinese
        old.monitoredFolderURLs = []
        old.launchAtLogin = false
        let decoded = try FileMintPreferencesStore.decode(JSONEncoder().encode(old))
        #expect(Array(decoded.templates.prefix(old.templates.count)) == old.templates)
        #expect(decoded.templates.suffix(2).map(\.id) == ["word-document", "excel-workbook"])
        #expect(decoded.templates.suffix(2).allSatisfy { !$0.isEnabled })
        #expect(decoded.defaultTemplateIDs == old.defaultTemplateIDs)
        #expect(decoded.language == .chinese && !decoded.launchAtLogin && decoded.monitoredFolderURLs.isEmpty)
        #expect(try FileMintPreferencesStore.decode(JSONEncoder().encode(decoded)).templates == decoded.templates)
    }

    @Test func officeCustomizationRemovalAndExplicitRestorationPreserveUserTemplates() throws {
        var preferences = FileMintPreferences.default
        let index = try #require(preferences.templates.firstIndex { $0.id == "word-document" })
        preferences.templates[index].displayName = "My Word"
        preferences.templates[index].suggestedFileName = "Notes.docx"
        let edited = preferences.templates[index]
        var imported = BuiltInDocumentTemplate.excel.template
        imported.id = "my-excel"
        imported.rank = try TemplateCatalog.nextRank(in: preferences.templates)
        imported.document = DocumentTemplateReference(id: UUID(), kind: .xlsx, byteCount: 1, sha256: "legacy")
        preferences.templates.append(imported)
        preferences.defaultTemplateIDs = ["xlsx": imported.id]
        let saved = try FileMintPreferencesStore.decode(JSONEncoder().encode(preferences))
        #expect(saved.templates.contains(edited))
        #expect(FileMintStrings.templateDisplayName(for: edited, language: .chinese) == "My Word")
        preferences.templates.removeAll { $0.id == "word-document" }
        preferences.removedBuiltInTemplateIDs = ["word-document"]
        let removed = try FileMintPreferencesStore.decode(JSONEncoder().encode(preferences))
        #expect(!removed.templates.contains { $0.id == "word-document" })
        var restored = removed
        restored.templates = TemplateCatalog.restoringBuiltIns(in: removed.templates)
        restored.removedBuiltInTemplateIDs = []
        let reloaded = try FileMintPreferencesStore.decode(JSONEncoder().encode(restored))
        #expect(reloaded.templates.contains { $0.id == "word-document" && $0.isEnabled && $0.suggestedFileName == "Untitled.docx" })
        #expect(reloaded.templates.filter { $0.id == "word-document" }.count == 1)
        #expect(reloaded.templates.contains(imported) && reloaded.defaultTemplateIDs == preferences.defaultTemplateIDs)
    }
}
