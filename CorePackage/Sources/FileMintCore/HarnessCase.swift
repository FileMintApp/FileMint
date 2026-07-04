import Foundation

public struct FileCreationHarnessCase: Codable, Equatable, Sendable {
    public var name: String
    public var templateID: String
    public var requestedFileName: String?
    public var existingFileNames: [String]
    public var expectedFileName: String
    public var expectedContentContains: [String]

    public init(
        name: String,
        templateID: String,
        requestedFileName: String?,
        existingFileNames: [String],
        expectedFileName: String,
        expectedContentContains: [String]
    ) {
        self.name = name
        self.templateID = templateID
        self.requestedFileName = requestedFileName
        self.existingFileNames = existingFileNames
        self.expectedFileName = expectedFileName
        self.expectedContentContains = expectedContentContains
    }
}

public struct HarnessCaseResult: Equatable, Sendable {
    public var name: String
    public var createdFileName: String
    public var passed: Bool
}

public enum HarnessRunner {
    public static func run(
        cases: [FileCreationHarnessCase],
        workspaceRoot: URL,
        fileManager: FileManager = .default
    ) throws -> [HarnessCaseResult] {
        let service = FileCreationService(fileManager: fileManager)
        let fixedDate = Date(timeIntervalSince1970: 1_704_067_200)

        return try cases.map { testCase in
            let caseRoot = workspaceRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fileManager.createDirectory(at: caseRoot, withIntermediateDirectories: true)

            for existingFileName in testCase.existingFileNames {
                let existingURL = caseRoot.appendingPathComponent(existingFileName, isDirectory: false)
                fileManager.createFile(atPath: existingURL.path, contents: Data(), attributes: nil)
            }

            guard let template = TemplateCatalog.template(withID: testCase.templateID) else {
                throw FileMintError.templateNotFound(testCase.templateID)
            }

            let result = try service.createFile(
                FileCreationRequest(
                    destinationDirectory: caseRoot,
                    template: template,
                    requestedFileName: testCase.requestedFileName,
                    collisionStrategy: .increment
                ),
                now: fixedDate
            )

            let content = try String(contentsOf: result.createdURL, encoding: .utf8)
            let contentMatches = testCase.expectedContentContains.allSatisfy { content.contains($0) }
            let fileNameMatches = result.createdURL.lastPathComponent == testCase.expectedFileName

            return HarnessCaseResult(
                name: testCase.name,
                createdFileName: result.createdURL.lastPathComponent,
                passed: fileNameMatches && contentMatches
            )
        }
    }
}
