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

    private static func fixtureCasesURL() throws -> URL {
        if let url = Bundle.module.url(forResource: "file_creation_cases", withExtension: "json") {
            return url
        }

        if let url = Bundle.module.url(
            forResource: "file_creation_cases",
            withExtension: "json",
            subdirectory: "Fixtures"
        ) {
            return url
        }

        throw CocoaError(.fileNoSuchFile)
    }
}
