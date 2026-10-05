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
    public var capturedAt: Date?

    public init(
        destinationDirectory: URL,
        template: FileTemplate,
        requestedFileName: String? = nil,
        collisionStrategy: NameCollisionStrategy = .increment,
        contentMode: FileContentMode = .template,
        fileData: Data? = nil,
        capturedAt: Date? = nil
    ) {
        self.destinationDirectory = destinationDirectory
        self.template = template
        self.requestedFileName = requestedFileName
        self.collisionStrategy = collisionStrategy
        self.contentMode = contentMode
        self.fileData = fileData
        self.capturedAt = capturedAt
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
        guard request.destinationDirectory.isFileURL else {
            throw FileMintError.destinationIsNotDirectory(request.destinationDirectory)
        }
        // stat follows a selected directory symlink, as the previous existence
        // check did, but retains EACCES/EPERM for the app's authorization retry.
        var attributes = stat()
        let status = request.destinationDirectory.withUnsafeFileSystemRepresentation {
            $0.map { stat($0, &attributes) } ?? -1
        }
        guard status == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno),
                          userInfo: [NSFilePathErrorKey: request.destinationDirectory.path])
        }
        guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
            throw FileMintError.destinationIsNotDirectory(request.destinationDirectory)
        }

        let requestedName = request.requestedFileName ?? request.template.suggestedFileName
        if let reference = request.template.document {
            guard request.template.fileExtension == reference.kind.rawValue else { throw DocumentTemplateError.unavailable }
            let data = try documentTemplates.data(for: reference)
            let name = FilenamePolicy.fileName(requestedName, applyingFileExtension: reference.kind.rawValue)!
            return try BinaryFileWriter.create(data, in: request.destinationDirectory, name: name, collision: request.collisionStrategy, contentKind: .officeDocument)
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
            let content = CreationContentResolver.text(template: request.template, fileName: targetURL.lastPathComponent,
                mode: request.contentMode, capturedAt: request.capturedAt ?? now)
            let data = Data(content.utf8)

            var identity: CreatedFileIdentity?
            if request.collisionStrategy == .replace {
                // Atomic rename replaces a symlink itself, never follows its target.
                if let type = try? fileManager.attributesOfItem(atPath: targetURL.path)[.type] as? FileAttributeType,
                   type == .typeDirectory {
                    throw FileMintError.destinationIsNotDirectory(targetURL)
                }
                identity = try BinaryFileWriter.replaceText(data, at: targetURL)
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
                var written = stat()
                if fstat(descriptor, &written) == 0 { identity = CreatedFileIdentity(written) }
                completed = true
            }
            return FileCreationResult(createdURL: targetURL, usedCollisionFallback: index > 1, identity: identity)
        }
    }
}
