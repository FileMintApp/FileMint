import Foundation

public enum FileContentMode: Sendable {
    case template
    case verbatim
}

public struct FileCreationRequest: Sendable {
    public var destinationDirectory: URL
    public var template: FileTemplate
    public var requestedFileName: String?
    public var collisionStrategy: NameCollisionStrategy
    public var contentMode: FileContentMode
    public var fileData: Data?
    public var capturedAt: Date?
    public var finderRoots: [URL]?
    public var expectedDirectoryIdentity: CreationDirectoryIdentity?

    public init(
        destinationDirectory: URL,
        template: FileTemplate,
        requestedFileName: String? = nil,
        collisionStrategy: NameCollisionStrategy = .increment,
        contentMode: FileContentMode = .template,
        fileData: Data? = nil,
        capturedAt: Date? = nil,
        expectedDirectoryIdentity: CreationDirectoryIdentity? = nil,
        finderRoots: [URL]? = nil
    ) {
        self.destinationDirectory = destinationDirectory
        self.template = template
        self.requestedFileName = requestedFileName
        self.collisionStrategy = collisionStrategy
        self.contentMode = contentMode
        self.fileData = fileData
        self.capturedAt = capturedAt
        self.expectedDirectoryIdentity = expectedDirectoryIdentity
        self.finderRoots = finderRoots
    }
}

public enum CreatedContentKind: String, Codable, Sendable { case text, officeDocument, binary }

public struct FileCreationResult: Equatable, Sendable {
    public var createdURL: URL
    public var usedCollisionFallback: Bool
    public var identity: CreatedFileIdentity?
    public var contentKind: CreatedContentKind
    public init(createdURL: URL, usedCollisionFallback: Bool, identity: CreatedFileIdentity? = nil, contentKind: CreatedContentKind = .text) {
        self.createdURL = createdURL; self.usedCollisionFallback = usedCollisionFallback; self.identity = identity; self.contentKind = contentKind
    }
}

public enum FileMintError: Error, LocalizedError {
    case destinationIsNotDirectory(URL)
    case templateNotFound(String)
    case fileAlreadyExists(URL)
    case writeFailed(URL)
    case outsideFinderScope
    case destinationChanged

    public var errorDescription: String? {
        switch self {
        case .destinationIsNotDirectory(let url):
            return "Destination is not a folder: \(url.path)"
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .fileAlreadyExists(let url):
            return "File already exists: \(url.path)"
        case .writeFailed(let url):
            return "Could not create file: \(url.path)"
        case .outsideFinderScope:
            return "The destination is outside the configured Finder folders. Choose a save folder."
        case .destinationChanged:
            return "The save folder changed. Choose the folder again."
        }
    }
}

public final class FileCreationService {
    private let documentTemplates: DocumentTemplateStore

    public init(fileManager _: FileManager = .default, documentTemplates: DocumentTemplateStore = DocumentTemplateStore()) {
        self.documentTemplates = documentTemplates
    }

    public func createFile(_ request: FileCreationRequest, now: Date = Date()) throws -> FileCreationResult {
        guard request.destinationDirectory.isFileURL else {
            throw FileMintError.destinationIsNotDirectory(request.destinationDirectory)
        }
        let directory = request.destinationDirectory
        let name = request.requestedFileName ?? request.template.suggestedFileName
        let ext = request.template.fileExtension
        let expected = request.expectedDirectoryIdentity
        if let reference = request.template.document {
            guard ext == reference.kind.rawValue else { throw DocumentTemplateError.unavailable }
            let data = try documentTemplates.data(for: reference)
            let documentName = FilenamePolicy.fileName(name, applyingFileExtension: ext)!
            return try PinnedCreationWriter.create(in: directory, expected: expected, name: documentName, fileExtension: ext,
                collision: request.collisionStrategy, kind: .officeDocument, contentDependsOnName: false,
                finderRoots: request.finderRoots) { _ in data }
        }
        if let data = request.fileData {
            return try PinnedCreationWriter.create(in: directory, expected: expected, name: name, fileExtension: ext,
                collision: request.collisionStrategy, kind: .binary, contentDependsOnName: false,
                finderRoots: request.finderRoots) { _ in data }
        }
        return try PinnedCreationWriter.create(in: directory, expected: expected, name: name, fileExtension: ext,
            collision: request.collisionStrategy, kind: .text,
            contentDependsOnName: request.contentMode == .template && request.template.content.contains("{{fileName}}"),
            finderRoots: request.finderRoots) { candidate in
                Data(CreationContentResolver.text(template: request.template, fileName: candidate,
                    mode: request.contentMode, capturedAt: request.capturedAt ?? now).utf8)
            }
    }
}
