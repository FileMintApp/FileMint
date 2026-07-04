import Foundation

public enum NameCollisionStrategy: String, Codable, CaseIterable, Sendable {
    case increment
    case fail
}

public enum FilenamePolicy {
    public static func sanitizedFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Untitled" : trimmed
        let invalidScalars = CharacterSet(charactersIn: "/:")
        let components = fallback.unicodeScalars.map { scalar -> String in
            invalidScalars.contains(scalar) ? "-" : String(scalar)
        }
        return components.joined()
    }

    public static func resolvedURL(
        in directoryURL: URL,
        requestedFileName: String,
        strategy: NameCollisionStrategy,
        fileManager: FileManager = .default
    ) throws -> URL {
        let sanitized = sanitizedFileName(requestedFileName)
        let firstURL = directoryURL.appendingPathComponent(sanitized, isDirectory: false)

        guard fileManager.fileExists(atPath: firstURL.path) else {
            return firstURL
        }

        switch strategy {
        case .fail:
            throw FileMintError.fileAlreadyExists(firstURL)
        case .increment:
            return incrementedURL(for: firstURL, fileManager: fileManager)
        }
    }

    private static func incrementedURL(for firstURL: URL, fileManager: FileManager) -> URL {
        let directory = firstURL.deletingLastPathComponent()
        let fileName = firstURL.lastPathComponent as NSString
        let baseName = fileName.deletingPathExtension
        let pathExtension = fileName.pathExtension

        var index = 2
        while true {
            let candidateName: String
            if pathExtension.isEmpty {
                candidateName = "\(baseName) \(index)"
            } else {
                candidateName = "\(baseName) \(index).\(pathExtension)"
            }

            let candidateURL = directory.appendingPathComponent(candidateName, isDirectory: false)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            index += 1
        }
    }
}
