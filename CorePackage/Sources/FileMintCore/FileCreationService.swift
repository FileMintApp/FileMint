import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

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

    public init(
        destinationDirectory: URL,
        template: FileTemplate,
        requestedFileName: String? = nil,
        collisionStrategy: NameCollisionStrategy = .increment,
        contentMode: FileContentMode = .template,
        fileData: Data? = nil
    ) {
        self.destinationDirectory = destinationDirectory
        self.template = template
        self.requestedFileName = requestedFileName
        self.collisionStrategy = collisionStrategy
        self.contentMode = contentMode
        self.fileData = fileData
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
    private let documentTemplates: DocumentTemplateStore

    public init(fileManager: FileManager = .default, documentTemplates: DocumentTemplateStore = DocumentTemplateStore()) {
        self.fileManager = fileManager
        self.documentTemplates = documentTemplates
    }

    public func createFile(_ request: FileCreationRequest, now: Date = Date()) throws -> FileCreationResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: request.destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileMintError.destinationIsNotDirectory(request.destinationDirectory)
        }

        let requestedName = request.requestedFileName ?? request.template.suggestedFileName
        if let reference = request.template.document {
            guard request.template.fileExtension == reference.kind.rawValue else { throw DocumentTemplateError.unavailable }
            let data = try documentTemplates.data(for: reference)
            let name = FilenamePolicy.fileName(requestedName, applyingFileExtension: reference.kind.rawValue)!
            return try BinaryFileWriter.create(data, in: request.destinationDirectory, name: name, collision: request.collisionStrategy)
        }
        if let data = request.fileData {
            return try BinaryFileWriter.create(data, in: request.destinationDirectory,
                name: requestedName, collision: request.collisionStrategy)
        }
        let naiveURL = request.destinationDirectory.appendingPathComponent(
            FilenamePolicy.sanitizedFileName(requestedName),
            isDirectory: false
        )
        var index = 1
        while true {
            let targetURL = FilenamePolicy.candidateURL(for: naiveURL, index: index)
            let content = request.contentMode == .verbatim ? request.template.content : TemplateRenderer.render(
                request.template,
                context: TemplateContext(fileName: targetURL.lastPathComponent, createdAt: now)
            )
            let data = Data(content.utf8)

            if request.collisionStrategy == .replace {
                // Atomic rename replaces a symlink itself, never follows its target.
                if let type = try? fileManager.attributesOfItem(atPath: targetURL.path)[.type] as? FileAttributeType,
                   type == .typeDirectory {
                    throw FileMintError.destinationIsNotDirectory(targetURL)
                }
                try data.write(to: targetURL, options: .atomic)
            } else {
                // O_EXCL is the collision decision. A separate existence check cannot
                // prevent another process from creating the same name before this one.
                let descriptor = targetURL.withUnsafeFileSystemRepresentation { path in
                    path.map { open($0, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode_t(0o666)) } ?? -1
                }
                if descriptor == -1 {
                    if errno == EEXIST {
                        if request.collisionStrategy == .increment {
                            index += 1
                            continue
                        }
                        throw FileMintError.fileAlreadyExists(targetURL)
                    }
                    throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno),
                                  userInfo: [NSFilePathErrorKey: targetURL.path])
                }
                var completed = false
                defer {
                    close(descriptor)
                    if !completed { try? fileManager.removeItem(at: targetURL) }
                }
                try data.withUnsafeBytes { bytes in
                    var offset = 0
                    while offset < bytes.count {
                        let count = write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                        if count < 0 && errno == EINTR { continue }
                        guard count > 0 else {
                            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno),
                                          userInfo: [NSFilePathErrorKey: targetURL.path])
                        }
                        offset += count
                    }
                }
                completed = true
            }
            return FileCreationResult(createdURL: targetURL, usedCollisionFallback: index > 1)
        }
    }
}
