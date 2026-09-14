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

    @Test("format suggestions use deterministic fuzzy matching")
    func formatSuggestionsUseDeterministicFuzzyMatching() {
        #expect(FileFormatCatalog.matching("mark").first?.fileExtension == "md")
        #expect(FileFormatCatalog.matching(".SW").first?.fileExtension == "swift")
        #expect(FileFormatCatalog.matching("脚本").first?.fileExtension == "sh")
        #expect(FileFormatCatalog.matching("").map(\.fileExtension) == [
            "txt", "md", "swift", "json", "html", "css", "sh"
        ])
    }

    @Test("custom extensions are normalized and applied to filenames")
    func customExtensionsAreNormalizedAndAppliedToFilenames() {
        #expect(FilenamePolicy.normalizedFileExtension(" .Log ") == "Log")
        #expect(FilenamePolicy.normalizedFileExtension("tar.gz") == "tar.gz")
        #expect(FilenamePolicy.normalizedFileExtension("bad/name") == nil)
        #expect(FilenamePolicy.normalizedFileExtension("two words") == nil)
        #expect(FilenamePolicy.fileName("Report.txt", applyingFileExtension: "md") == "Report.md")
        #expect(FilenamePolicy.fileName("archive.tar.gz", applyingFileExtension: "tar.gz") == "archive.tar.gz")
        #expect(FilenamePolicy.fileName("README", applyingFileExtension: ".txt") == "README.txt")
    }

    @Test("custom draft preserves edited content across format changes")
    func customDraftPreservesEditedContentAcrossFormatChanges() throws {
        let markdown = try #require(FileFormatCatalog.option(forFileExtension: "md"))
        let json = try #require(FileFormatCatalog.option(forFileExtension: "json"))
        var draft = CustomFileDraft()

        draft.selectFormat(markdown)
        #expect(draft.content.contains("{{fileName}}"))

        draft.updateContent("My exact content\n")
        draft.selectFormat(json)

        #expect(draft.extensionInput == "json")
        #expect(draft.content == "My exact content\n")
        #expect(draft.hasEditedContent)
    }

    @Test("custom draft preserves multiline Unicode and an intentional empty value")
    func customDraftPreservesMultilineUnicodeAndEmptyValue() throws {
        let markdown = try #require(FileFormatCatalog.option(forFileExtension: "md"))
        let swift = try #require(FileFormatCatalog.option(forFileExtension: "swift"))
        var draft = CustomFileDraft()

        draft.updateContent("第一行\nsecond line\n")
        draft.selectFormat(markdown)

        #expect(draft.content == "第一行\nsecond line\n")
        #expect(draft.hasEditedContent)

        draft.updateContent("")
        draft.selectFormat(swift)

        #expect(draft.content.isEmpty)
        #expect(draft.hasEditedContent)
    }

    @Test("canceling destination browsing preserves the current directory")
    func cancelingDestinationBrowsingPreservesCurrentDirectory() {
        let initialDirectory = URL(fileURLWithPath: "/Users/example/Desktop", isDirectory: true)
        var selection = CustomFileLocationSelection(directoryURL: initialDirectory)

        selection.beginBrowsing()
        #expect(selection.isBrowsing)

        selection.finishBrowsing(selectedDirectoryURL: nil)

        #expect(selection.directoryURL == initialDirectory)
        #expect(selection.isBrowsing == false)
    }

    @Test("selecting a browsed destination returns to compact state")
    func selectingBrowsedDestinationReturnsToCompactState() {
        let initialDirectory = URL(fileURLWithPath: "/Users/example/Desktop", isDirectory: true)
        let selectedDirectory = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        var selection = CustomFileLocationSelection(directoryURL: initialDirectory)

        selection.beginBrowsing()
        selection.finishBrowsing(selectedDirectoryURL: selectedDirectory)

        #expect(selection.directoryURL == selectedDirectory)
        #expect(selection.isBrowsing == false)
    }

    @Test("confirmed replace overwrites the selected file")
    func confirmedReplaceOverwritesSelectedFile() throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileMintReplace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let targetURL = workspace.appendingPathComponent("Status.log")
        try Data("old\n".utf8).write(to: targetURL)
        let template = FileTemplate(
            id: "custom",
            displayName: "Custom",
            suggestedFileName: "Status.log",
            group: "Custom",
            content: "new {{year}}\n",
            rank: 0
        )

        let result = try FileCreationService().createFile(
            FileCreationRequest(
                destinationDirectory: workspace,
                template: template,
                requestedFileName: "Status.log",
                collisionStrategy: .replace
            ),
            now: Date(timeIntervalSince1970: 1_704_067_200)
        )

        #expect(result.createdURL == targetURL)
        #expect(result.usedCollisionFallback == false)
        #expect(try String(contentsOf: targetURL, encoding: .utf8) == "new 2024\n")
    }

    @Test("template menu order follows saved ranks after reordering")
    func templateMenuOrderFollowsSavedRanksAfterReordering() {
        let reordered = TemplateCatalog.reorderedTemplates(
            TemplateCatalog.builtInTemplates,
            moving: IndexSet(integer: 2),
            to: 0
        )

        #expect(Array(reordered.prefix(3).map(\.id)) == ["swift", "plain-text", "markdown"])
        #expect(reordered.map(\.rank) == (1...TemplateCatalog.builtInTemplates.count).map { $0 * 10 })
        #expect(Array(TemplateCatalog.enabledTemplates(from: reordered).prefix(3).map(\.id)) == [
            "swift",
            "plain-text",
            "markdown"
        ])
    }

    @Test("preferences default to the system language")
    func preferencesDefaultToSystemLanguage() {
        #expect(FileMintPreferences.default.language == .system)
        #expect(AppLanguage.allCases == [.system, .english, .chinese])
    }

    @Test("default monitored folders use the real user home")
    func defaultMonitoredFoldersUseTheRealUserHome() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        #expect(DefaultFolders.urls(homeDirectory: home).map(\.path) == [
            "/Users/example",
            "/Users/example/Desktop",
            "/Users/example/Documents",
            "/Users/example/Downloads"
        ])
    }

    @Test("legacy preferences without language follow the system")
    func legacyPreferencesWithoutLanguageFollowSystem() throws {
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

        #expect(preferences.language == .system)
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
        #expect(FileMintStrings.text(.customNewFile, language: .chinese) == "新建文件…")
        #expect(FileMintStrings.text(.chooseOtherFolder, language: .chinese) == "选择其他文件夹…")
        #expect(FileMintStrings.text(.replace, language: .chinese) == "替换")
        #expect(
            FileMintStrings.replaceExistingFileMessage(fileName: "报告.txt", language: .chinese)
                == "是否替换所选文件夹中的“报告.txt”？"
        )
        #expect(FileMintStrings.templateDisplayName(for: template, language: .chinese) == "文本")
        #expect(steps.map(\.id) == [
            "open-settings",
            "enable-extension",
            "check-location",
            "relaunch-finder"
        ])
        #expect(steps[1].detail.contains("Finder"))
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
