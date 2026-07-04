import FileMintCore
import Foundation
import Testing

@Suite("File creation harness")
struct FileCreationHarnessTests {
    @Test("public harness cases pass")
    func harnessCasesPass() throws {
        let casesURL = try Self.fixtureCasesURL()
        let data = try Data(contentsOf: casesURL)
        let cases = try JSONDecoder().decode([FileCreationHarnessCase].self, from: data)
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileMintCoreTests-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let results = try HarnessRunner.run(cases: cases, workspaceRoot: workspace)

        #expect(results.allSatisfy { $0.passed })
    }

    @Test("collision fail strategy refuses overwrite")
    func collisionFailStrategyRefusesOverwrite() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileMintCollision-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let existingURL = workspace.appendingPathComponent("Untitled.txt")
        FileManager.default.createFile(atPath: existingURL.path, contents: Data(), attributes: nil)

        let service = FileCreationService()
        let template = try #require(TemplateCatalog.template(withID: "plain-text"))

        #expect(throws: FileMintError.self) {
            try service.createFile(
                FileCreationRequest(
                    destinationDirectory: workspace,
                    template: template,
                    collisionStrategy: .fail
                )
            )
        }
    }

    @Test("template placeholders are deterministic")
    func templatePlaceholdersAreDeterministic() throws {
        let template = FileTemplate(
            id: "note",
            displayName: "Note",
            suggestedFileName: "Note.md",
            group: "Test",
            content: "{{fileName}} {{date}} {{year}}",
            rank: 1
        )
        let date = Date(timeIntervalSince1970: 1_704_067_200)

        let rendered = TemplateRenderer.render(
            template,
            context: TemplateContext(fileName: "Note.md", createdAt: date)
        )

        #expect(rendered == "Note.md 2024-01-01 2024")
    }

    @Test("template menu order follows saved ranks after reordering")
    func templateMenuOrderFollowsSavedRanksAfterReordering() {
        let reordered = TemplateCatalog.reorderedTemplates(
            TemplateCatalog.builtInTemplates,
            moving: IndexSet(integer: 2),
            to: 0
        )

        #expect(Array(reordered.prefix(3).map(\.id)) == ["swift", "plain-text", "markdown"])
        #expect(reordered.map(\.rank) == [10, 20, 30, 40, 50, 60, 70])
        #expect(Array(TemplateCatalog.enabledTemplates(from: reordered).prefix(3).map(\.id)) == [
            "swift",
            "plain-text",
            "markdown"
        ])
    }

    @Test("preferences default to English")
    func preferencesDefaultToEnglish() {
        #expect(FileMintPreferences.default.language == .english)
        #expect(AppLanguage.allCases == [.english, .chinese])
    }

    @Test("legacy preferences without language decode as English")
    func legacyPreferencesWithoutLanguageDecodeAsEnglish() throws {
        let data = """
        {
          "templates": [],
          "monitoredFolderURLs": [],
          "collisionStrategy": "fail",
          "revealAfterCreation": false,
          "favoritesFirst": false
        }
        """.data(using: .utf8)!

        let preferences = try JSONDecoder().decode(FileMintPreferences.self, from: data)

        #expect(preferences.language == .english)
        #expect(preferences.collisionStrategy == .fail)
        #expect(preferences.revealAfterCreation == false)
        #expect(preferences.favoritesFirst == false)
    }

    @Test("Chinese localization covers settings and built-in templates")
    func chineseLocalizationCoversSettingsAndBuiltInTemplates() throws {
        let template = try #require(TemplateCatalog.template(withID: "plain-text"))
        let steps = PermissionGuide.steps(language: .chinese)

        #expect(FileMintStrings.text(.language, language: .chinese) == "语言")
        #expect(FileMintStrings.text(.newFile, language: .chinese) == "新建文件")
        #expect(FileMintStrings.templateDisplayName(for: template, language: .chinese) == "文本")
        #expect(steps.map(\.id) == [
            "open-settings",
            "enable-extension",
            "check-location",
            "relaunch-finder"
        ])
        #expect(steps[1].detail.contains("Finder 扩展"))
    }

    private static func fixtureCasesURL() throws -> URL {
        let fileManager = FileManager.default
        var directory = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

        while true {
            let candidate = directory
                .appendingPathComponent("specs/harness/cases/file_creation_cases.json")
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }

            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path {
                break
            }
            directory = parent
        }

        throw CocoaError(.fileNoSuchFile)
    }
}
