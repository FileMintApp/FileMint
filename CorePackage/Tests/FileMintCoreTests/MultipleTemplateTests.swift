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
}
