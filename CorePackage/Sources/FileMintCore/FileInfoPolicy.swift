import Foundation

public enum FileDigestAlgorithm: String, CaseIterable, Codable, Sendable {
    case md5 = "MD5", sha1 = "SHA-1", sha256 = "SHA-256", sha512 = "SHA-512"
    public var hexadecimalLength: Int {
        switch self { case .md5: 32; case .sha1: 40; case .sha256: 64; case .sha512: 128 }
    }
}

public enum FileDigestChoice: String, CaseIterable, Sendable {
    case sha256, sha512, sha1, md5, all
    public var algorithms: [FileDigestAlgorithm] {
        switch self {
        case .sha256: [.sha256]; case .sha512: [.sha512]
        case .sha1: [.sha1]; case .md5: [.md5]; case .all: FileDigestAlgorithm.allCases
        }
    }
    public var includesLegacy: Bool { self == .md5 || self == .sha1 || self == .all }
    public var title: FileInfoText {
        switch self {
        case .sha256: .sha256; case .sha512: .sha512; case .sha1: .sha1; case .md5: .md5; case .all: .all
        }
    }
    public var hint: FileInfoText {
        switch self {
        case .sha256: .sha256Hint; case .sha512: .sha512Hint
        case .sha1: .sha1Hint; case .md5: .md5Hint; case .all: .allHint
        }
    }
}

public struct FileDigestValue: Equatable, Sendable {
    public let algorithm: FileDigestAlgorithm
    public let hexadecimal: String
}

public struct FileDigestResult: Equatable, Sendable {
    public let choice: FileDigestChoice
    public let bytesRead: Int64
    public let values: [FileDigestValue]
    public let metadata: FileInfoMetadata
    public var clipboardText: String {
        values.map { "\($0.algorithm.rawValue): \($0.hexadecimal)" }.joined(separator: "\n")
    }
}

public enum FileDigestComparison: Equatable, Sendable {
    case empty, chooseSingleAlgorithm, invalid, unavailable, match, mismatch
}

public enum FileInfoPolicy {
    /// Path-only: safe during Finder menu construction, even for inaccessible items.
    public static func canSelect(_ selection: [URL]) -> Bool {
        guard selection.count == 1, let url = selection.first else { return false }
        return url.isFileURL && (url.host == nil || url.host == "" || url.host == "localhost")
            && url.standardizedFileURL.path != "/"
    }

    public static func compare(_ input: String, choice: FileDigestChoice,
                               result: FileDigestResult?) -> FileDigestComparison {
        guard choice != .all else { return .chooseSingleAlgorithm }
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .empty }
        let algorithm = choice.algorithms[0]
        guard value.utf8.count == algorithm.hexadecimalLength,
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
        else { return .invalid }
        guard result?.choice == choice, let actual = result?.values.first,
              actual.algorithm == algorithm else { return .unavailable }
        return actual.hexadecimal == value.lowercased() ? .match : .mismatch
    }
}
