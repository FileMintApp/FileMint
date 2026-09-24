import Foundation
import Testing
@testable import FileMintCore

struct MultipleTemplateTests {
    private func templates() throws -> [FileTemplate] {
        let first = try TemplateCatalog.customTemplate(name: "会议纪要", fileExtension: "md", content: "# 会议\n",
            id: "meeting", in: [], suggestedFileName: "会议.md")
        let second = try TemplateCatalog.customTemplate(name: "工作周报", fileExtension: "MD", content: "# 周报\n",
            id: "weekly", in: [first], suggestedFileName: "周报.md")
        return [first, second]
    }

    @Test func sameSuffixChoicesHaveIndependentIdentityContentAndNames() throws {
        let templates = try templates()
        let choices = FileFormatCatalog.options(from: templates)
        #expect(choices.map(\.id) == ["meeting", "weekly"])
        #expect(FileFormatCatalog.matching("周报", in: choices).map(\.id) == ["weekly"])
        var draft = CustomFileDraft(extensionInput: "md", templates: templates)
        #expect(draft.content == "# 会议\n")
        draft.selectFormat(choices[1], templates: templates)
        #expect(draft.selectedTemplateID == "weekly" && draft.content == "# 周报\n")
        draft.updateExtensionInput("MD", templates: templates)
        #expect(draft.selectedTemplateID == "weekly")
        draft.updateContent("用户输入 {{date}}\n")
        draft.selectFormat(choices[0], templates: templates)
        #expect(draft.selectedTemplateID == "meeting" && draft.content == "用户输入 {{date}}\n")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for (template, expectedName, expectedContent) in [(templates[0], "会议.md", "# 会议\n"), (templates[1], "周报.md", "# 周报\n")] {
            let file = try FileCreationService().createFile(.init(destinationDirectory: root, template: template))
            #expect(file.createdURL.lastPathComponent == expectedName)
            #expect(try String(contentsOf: file.createdURL, encoding: .utf8) == expectedContent)
        }
    }

    @Test func defaultsFallbackAndInvalidation() throws {
        var templates = try templates()
        var preferences = FileMintPreferences.default
        preferences.templates = templates
        preferences.defaultTemplateIDs = ["md": "weekly"]
        let decoded = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(decoded.defaultTemplateIDs == ["md": "weekly"])
        var draft = CustomFileDraft(templates: templates, defaultTemplateIDs: decoded.defaultTemplateIDs)
        draft.updateExtensionInput("md", templates: templates)
        #expect(draft.selectedTemplateID == "weekly")
        templates[1].isEnabled = false
        #expect(TemplateCatalog.validDefaults(decoded.defaultTemplateIDs, in: templates).isEmpty)
        #expect(TemplateCatalog.defaultTemplate(forExtension: "MD", in: templates, defaults: decoded.defaultTemplateIDs)?.id == "meeting")
        templates[1].isEnabled = true
        templates[1].fileExtension = "txt"
        #expect(TemplateCatalog.validDefaults(decoded.defaultTemplateIDs, in: templates).isEmpty)
        #expect(TemplateCatalog.validDefaults(decoded.defaultTemplateIDs, in: Array(templates.prefix(1))).isEmpty)
    }

    @Test func legacyCompoundSuffixAndUnrelatedPreferencesSurvive() throws {
        let old = Data(#"{"id":"legacy","displayName":"压缩配置","suggestedFileName":"Untitled.tar.gz","group":"Custom","content":"keep\n","isEnabled":false,"rank":75}"#.utf8)
        let template = try JSONDecoder().decode(FileTemplate.self, from: old)
        #expect(template.id == "legacy" && template.fileExtension == "tar.gz" && template.content == "keep\n")
        var original = FileMintPreferences.default
        original.templates.append(template)
        original.language = .chinese
        original.launchAtLogin = false
        original.monitoredFolderBookmarks = ["fixture": Data([1,2,3])]
        let decoded = try FileMintPreferencesStore.decode(JSONEncoder().encode(original))
        #expect(decoded.templates.contains(template))
        #expect(decoded.language == .chinese && !decoded.launchAtLogin && decoded.monitoredFolderBookmarks == original.monitoredFolderBookmarks)
        let renamed = try TemplateCatalog.customTemplate(name: "Config", fileExtension: "json", content: "keep", id: template.id,
            in: [template], suggestedFileName: "资料.tar.gz")
        #expect(renamed.suggestedFileName == "资料.json")
    }

    @Test func defaultsAreStableUnderNameAndRankTiesAndRestoration() throws {
        var templates = try templates()
        templates[1].rank = templates[0].rank
        templates[0].displayName = "ZZZ"
        templates[1].displayName = "AAA"
        #expect(TemplateCatalog.defaultTemplate(forExtension: "md", in: Array(templates.reversed()))?.id == "meeting")
        let restored = TemplateCatalog.restoringBuiltIns(in: templates)
        #expect(TemplateCatalog.validDefaults(["md":"weekly"], in: restored) == ["md":"weekly"])
        #expect(restored.filter { $0.id == "weekly" }.count == 1)
    }

    @Test func editedBuiltInRetainsIdentityAndUsesItsCustomName() throws {
        let original = try #require(TemplateCatalog.builtInTemplates.first { $0.id == "plain-text" })
        let edited = try TemplateCatalog.customTemplate(name: "My Notes", fileExtension: "txt",
            content: "A custom start\n", id: original.id, in: [original], suggestedFileName: "Notes.txt")
        #expect(edited.id == original.id && edited.rank == original.rank && edited.group == original.group)
        #expect(edited.content == "A custom start\n" && edited.suggestedFileName == "Notes.txt")
        #expect(FileMintStrings.templateDisplayName(for: edited, language: .chinese) == "My Notes")
        #expect(FileMintStrings.templateDisplayName(for: original, language: .chinese) == "文本")
    }

    @Test func removedBuiltInStaysRemovedUntilExplicitRestoration() throws {
        var preferences = FileMintPreferences.default
        let custom = try TemplateCatalog.customTemplate(name: "Notes", fileExtension: "md", content: "keep",
            in: preferences.templates, suggestedFileName: "Notes.md")
        preferences.templates.append(custom)
        preferences.defaultTemplateIDs = ["md": "markdown"]
        preferences.templates.removeAll { $0.id == "markdown" }
        preferences.removedBuiltInTemplateIDs = ["markdown"]

        let restored = try FileMintPreferencesStore.decode(JSONEncoder().encode(preferences))
        #expect(!restored.templates.contains { $0.id == "markdown" })
        #expect(restored.templates.contains(custom))
        #expect(restored.removedBuiltInTemplateIDs == ["markdown"])
        #expect(restored.defaultTemplateIDs.isEmpty)

        var reset = restored
        reset.templates = TemplateCatalog.restoringBuiltIns(in: reset.templates)
        reset.removedBuiltInTemplateIDs = []
        let afterReset = try FileMintPreferencesStore.decode(JSONEncoder().encode(reset))
        #expect(afterReset.templates.contains { $0.id == "markdown" })
        #expect(afterReset.templates.contains(custom))
        #expect(afterReset.removedBuiltInTemplateIDs.isEmpty)

        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        legacy.removeValue(forKey: "removedBuiltInTemplateIDs")
        let migrated = try FileMintPreferencesStore.decode(JSONSerialization.data(withJSONObject: legacy))
        #expect(migrated.templates.contains { $0.id == "markdown" && !$0.isEnabled })
    }
}
