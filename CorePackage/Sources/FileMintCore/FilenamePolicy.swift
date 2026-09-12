import Foundation

public enum NameCollisionStrategy: String, Codable, CaseIterable, Sendable {
    case increment
    case fail
    case replace
}

public enum FilenamePolicy {
    public static func sanitizedFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Untitled" : trimmed
        let invalidScalars = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        let components = fallback.unicodeScalars.map { scalar -> String in
            invalidScalars.contains(scalar) ? "-" : String(scalar)
        }
        let result = components.joined()
        return result == "." || result == ".." ? "Untitled" : result
    }

    public static func normalizedFileExtension(_ fileExtension: String) -> String? {
        let trimmed = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = String(trimmed.drop(while: { $0 == "." }))

        guard !normalized.isEmpty,
              !normalized.contains(where: { $0 == "/" || $0 == ":" || $0 == "\\" }),
              !normalized.contains(where: { $0.isWhitespace }),
              normalized.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              !normalized.hasSuffix("."), !normalized.contains("..") else {
            return nil
        }

        return normalized
    }

    public static func inferredFileExtension(from fileName: String, knownExtensions: [String] = []) -> String? {
        let name = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let known = knownExtensions.sorted(by: { $0.count > $1.count }).first(where: {
            name.lowercased().hasSuffix(".\($0.lowercased())")
        }) { return String(name.suffix(known.count)) }
        return normalizedFileExtension((name as NSString).pathExtension)
    }

    public static func fileName(_ fileName: String, applyingFileExtension fileExtension: String, replacingFileExtension previousExtension: String? = nil) -> String? {
        guard let normalizedExtension = normalizedFileExtension(fileExtension) else {
            return nil
        }

        let sanitized = sanitizedFileName(fileName)
        let expectedSuffix = ".\(normalizedExtension)"
        if sanitized.lowercased().hasSuffix(expectedSuffix.lowercased()) {
            return sanitized
        }

        let path = sanitized as NSString
        let baseName: String
        if let previousExtension, sanitized.lowercased().hasSuffix(".\(previousExtension.lowercased())") {
            baseName = String(sanitized.dropLast(previousExtension.count + 1))
        } else {
            baseName = path.pathExtension.isEmpty ? sanitized : path.deletingPathExtension
        }
        return "\(baseName).\(normalizedExtension)"
    }

    public static func resolvedURL(
        in directoryURL: URL,
        requestedFileName: String,
        strategy: NameCollisionStrategy,
        fileManager: FileManager = .default
    ) throws -> URL {
        let sanitized = sanitizedFileName(requestedFileName)
        let firstURL = directoryURL.appendingPathComponent(sanitized, isDirectory: false)

        guard (try? fileManager.attributesOfItem(atPath: firstURL.path)) != nil else {
            return firstURL
        }

        switch strategy {
        case .fail:
            throw FileMintError.fileAlreadyExists(firstURL)
        case .increment:
            return incrementedURL(for: firstURL, fileManager: fileManager)
        case .replace:
            return firstURL
        }
    }

    public static func candidateURL(for firstURL: URL, index: Int) -> URL {
        guard index > 1 else { return firstURL }
        let name = firstURL.lastPathComponent as NSString
        let suffix = name.pathExtension.isEmpty ? "" : ".\(name.pathExtension)"
        return firstURL.deletingLastPathComponent().appendingPathComponent(
            "\(name.deletingPathExtension) \(index)\(suffix)", isDirectory: false
        )
    }

    private static func incrementedURL(for firstURL: URL, fileManager: FileManager) -> URL {
        var index = 2
        while true {
            let candidate = candidateURL(for: firstURL, index: index)
            if (try? fileManager.attributesOfItem(atPath: candidate.path)) == nil { return candidate }
            index += 1
        }
    }
}
