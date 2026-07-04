import Foundation

public struct FileCreationRequest: Sendable {
    public var destinationDirectory: URL
    public var template: FileTemplate
    public var requestedFileName: String?
    public var collisionStrategy: NameCollisionStrategy

    public init(
        destinationDirectory: URL,
        template: FileTemplate,
        requestedFileName: String? = nil,
        collisionStrategy: NameCollisionStrategy = .increment
    ) {
        self.destinationDirectory = destinationDirectory
        self.template = template
        self.requestedFileName = requestedFileName
        self.collisionStrategy = collisionStrategy
    }
}

public struct FileCreationResult: Equatable, Sendable {
    public var createdURL: URL
    public var usedCollisionFallback: Bool
}

public enum FileMintError: Error, LocalizedError {
    case destinationIsNotDirectory(URL)
    case templateNotFound(String)
    case fileAlreadyExists(URL)
    case writeFailed(URL)

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
        }
    }
}

public final class FileCreationService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func createFile(_ request: FileCreationRequest, now: Date = Date()) throws -> FileCreationResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: request.destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileMintError.destinationIsNotDirectory(request.destinationDirectory)
        }

        let requestedName = request.requestedFileName ?? request.template.suggestedFileName
        let naiveURL = request.destinationDirectory.appendingPathComponent(
            FilenamePolicy.sanitizedFileName(requestedName),
            isDirectory: false
        )
        let targetURL = try FilenamePolicy.resolvedURL(
            in: request.destinationDirectory,
            requestedFileName: requestedName,
            strategy: request.collisionStrategy,
            fileManager: fileManager
        )

        let rendered = TemplateRenderer.render(
            request.template,
            context: TemplateContext(fileName: targetURL.lastPathComponent, createdAt: now)
        )

        guard !fileManager.fileExists(atPath: targetURL.path) else {
            throw FileMintError.fileAlreadyExists(targetURL)
        }

        let didCreate = fileManager.createFile(
            atPath: targetURL.path,
            contents: rendered.data(using: .utf8),
            attributes: nil
        )

        guard didCreate else {
            throw FileMintError.writeFailed(targetURL)
        }

        return FileCreationResult(
            createdURL: targetURL,
            usedCollisionFallback: targetURL.lastPathComponent != naiveURL.lastPathComponent
        )
    }
}
