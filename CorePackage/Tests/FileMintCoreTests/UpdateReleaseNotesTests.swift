import FileMintCore
import Foundation
import Testing

@Suite("Localized update summaries and online help")
struct UpdateReleaseNotesTests {
    private let version = ReleaseVersion("9.9.9")!
    private let headline = "Organize file names and compare file contents."
    private let highlight = "- Replace text or add numbering, with a preview before renaming."

    private func fixture() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "update-release-notes",
                                                withExtension: "md", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func publishedFormatSelectsOnlyTheRequestedLanguageAndSummary() throws {
        let body = try fixture()
        let notes = try #require(UpdateReleaseNotes(body: body, version: version))
        let english = try #require(notes.summary(for: .english))
        #expect(english.headline == headline)
        #expect(english.highlights == [
            "Replace text or add numbering, with a preview before renaming.",
            "Inspect file information, then calculate and compare checksums when needed."
        ])
        let chinese = try #require(notes.summary(for: .chinese))
        #expect(chinese.headline == "批量整理文件名，核对文件内容。")
        #expect(chinese.highlights == [
            "批量替换文字或添加编号，修改前先预览全部结果。",
            "查看文件信息，按需计算和比对校验值。"
        ])
        #expect(notes.summary(for: .system, preferredLanguages: ["zh-Hans-CN"]) == chinese)
        #expect(notes.summary(for: .system, preferredLanguages: ["fr-FR", "en-US"]) == english)
        #expect(notes.summary(for: .english, preferredLanguages: ["zh-Hans"]) == english)
    }

    @Test func absentOrInvalidBodyNeverInventsASummary() throws {
        let body = try fixture()
        for invalid: String? in [nil, "", "Historical free-form release notes.",
                                body.replacingOccurrences(of: "# FileMint 9.9.9", with: "# FileMint 9.9.8"),
                                "# Another document\n" + body,
                                String(repeating: "文", count: 65_536) + body] {
            #expect(UpdateReleaseNotes(body: invalid, version: version) == nil)
        }
    }

    @Test func summariesCannotLeakFromAnOlderVersion() throws {
        let previous = try fixture().replacingOccurrences(of: "9.9.9", with: "9.9.8")
        #expect(UpdateReleaseNotes(body: "# FileMint 9.9.9\n\nNo summary.\n" + previous, version: version) == nil)
    }

    @Test func missingTranslationAndDuplicateSectionsDoNotFallBackToAnotherLanguage() throws {
        let body = try fixture()
        for broken in [
            body.replacingOccurrences(of: "## Highlights", with: "## Other"),
            body.replacingOccurrences(of: "## Highlights", with: "## Highlights\n## Highlights")
        ] {
            let notes = try #require(UpdateReleaseNotes(body: broken, version: version))
            #expect(notes.summary(for: .english) == nil)
            #expect(notes.summary(for: .chinese)?.headline == "批量整理文件名，核对文件内容。")
        }
    }

    @Test(arguments: ["", String(repeating: "x", count: 121), "[Open](https://example.com)",
                      "<script>run()</script>", "**Bold**", "`code`", "Text\u{0}here", "Text\u{202e}here"])
    func invalidHeadlineMakesOnlyItsTranslationUnavailable(replacement: String) throws {
        let body = try fixture().replacingOccurrences(of: headline, with: replacement)
        let notes = try #require(UpdateReleaseNotes(body: body, version: version))
        #expect(notes.summary(for: .english) == nil)
        #expect(notes.summary(for: .chinese) != nil)
    }

    @Test(arguments: ["- ", "- " + String(repeating: "x", count: 241), "Not a bullet",
                      "- First line\n  continuation", Array(repeating: "- Item", count: 5).joined(separator: "\n")])
    func invalidHighlightStructureDoesNotProducePartialClaims(replacement: String) throws {
        let body = try fixture().replacingOccurrences(of: highlight, with: replacement)
        let notes = try #require(UpdateReleaseNotes(body: body, version: version))
        #expect(notes.summary(for: .english) == nil)
    }

    @Test func subheadingsCannotHidePartOfAnInvalidSummary() throws {
        let body = try fixture().replacingOccurrences(of: "## Getting started",
            with: "### Unsupported subsection\nExtra summary text.\n\n## Getting started")
        let notes = try #require(UpdateReleaseNotes(body: body, version: version))
        #expect(notes.summary(for: .english) == nil)
        #expect(notes.summary(for: .chinese) != nil)
    }

    @Test func acceptsCRLFAndExactTextAndBodyBounds() throws {
        let title = String(repeating: "🙂", count: 120)
        let bullet = String(repeating: "文", count: 240)
        let body = "# FileMint 9.9.9\r\n\r\n## Highlights\r\n\r\n\(title)\r\n\r\n- \(bullet)\r\n## Details\r\n"
        let padded = body + String(repeating: "x", count: UpdateReleaseNotes.maximumBodyBytes - body.utf8.count)
        let notes = try #require(UpdateReleaseNotes(body: padded, version: version))
        #expect(notes.summary(for: .english)?.headline == title)
        #expect(notes.summary(for: .english)?.highlights == [bullet])
        #expect(UpdateReleaseNotes(body: padded + "x", version: version) == nil)
    }

    @Test func guideUsesTheCurrentLanguageAndFixedOfficialDestination() {
        #expect(FileMintAbout.guideURL(language: .chinese).absoluteString ==
                "https://filemintapp.github.io/FileMint/guide.html")
        #expect(FileMintAbout.guideURL(language: .english).absoluteString ==
                "https://filemintapp.github.io/FileMint/en/guide.html")
        #expect(FileMintAbout.guideURL(language: .system, preferredLanguages: ["zh-TW"]) ==
                FileMintAbout.guideURL(language: .chinese))
        #expect(FileMintAbout.guideURL(language: .system, preferredLanguages: ["de-DE"]) ==
                FileMintAbout.guideURL(language: .english))
    }
}
