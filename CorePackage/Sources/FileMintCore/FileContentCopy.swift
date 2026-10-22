import Foundation
import UniformTypeIdentifiers

public enum FileContentFormat: Sendable { case plainText, rtf }

public enum FileContentCopyError: Error, Equatable, Sendable {
    case unsupported, invalidEncoding, empty, tooLarge, invalidRTF, clipboardChanged, clipboardWriteFailed
}

public enum FileContentCopyPolicy {
    public static let maximumBytes = 8 * 1024 * 1024
    private static let textExtensions: Set<String> = [
        "txt", "text", "log", "md", "markdown", "mdown", "rst", "adoc", "csv", "tsv",
        "json", "jsonc", "jsonl", "ndjson", "yaml", "yml", "toml", "ini", "cfg", "conf", "config",
        "xml", "html", "htm", "xhtml", "css", "scss", "sass", "less", "sql", "graphql", "gql",
        "swift", "c", "h", "m", "mm", "cc", "cpp", "cxx", "hpp", "hxx", "cs", "java", "kt", "kts",
        "js", "jsx", "mjs", "cjs", "ts", "tsx", "vue", "svelte", "py", "pyi", "rb", "php", "go", "rs",
        "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd", "pl", "pm", "lua", "r", "dart", "ex", "exs",
        "erl", "hrl", "hs", "scala", "sc", "clj", "cljs", "cljc", "edn", "el", "lisp", "scm", "jl",
        "tex", "bib", "sty", "srt", "vtt", "diff", "patch", "properties", "strings", "xcconfig", "env"
    ]
    private static let specialNames: Set<String> = [
        "makefile", "dockerfile", "gemfile", "rakefile", "podfile", "brewfile", "cmakelists.txt",
        ".gitignore", ".gitattributes", ".gitmodules", ".editorconfig", ".npmrc", ".yarnrc", ".env",
        ".bashrc", ".bash_profile", ".zshrc", ".zprofile", ".profile"
    ]

    /// Name/type candidates only. The click-time read must still validate bytes.
    public static func format(for url: URL) -> FileContentFormat? {
        let suffix = url.pathExtension.lowercased()
        if suffix == "rtf" { return .rtf }
        if ["rtfd", "pdf", "doc", "docx", "docm", "xls", "xlsx", "xlsm", "ppt", "pptx", "pptm",
            "odt", "ods", "odp", "pages", "numbers", "key", "svg", "svgz"].contains(suffix) { return nil }
        // Source-code suffixes such as .ts can also be registered as video.
        // Exact byte validation remains authoritative after the click.
        if suffix.isEmpty || specialNames.contains(url.lastPathComponent.lowercased())
            || textExtensions.contains(suffix) { return .plainText }
        let type = UTType(filenameExtension: suffix)
        if let type, type.conforms(to: .image) || type.conforms(to: .audio) || type.conforms(to: .movie)
            || type.conforms(to: .archive) { return nil }
        if type?.conforms(to: .text) == true { return .plainText }
        return nil
    }

    public static func supportsMenuSelection(_ urls: [URL]) -> Bool {
        FileDigestService.supportsMenuSelection(urls) && urls.first.flatMap { format(for: $0) } != nil
    }

    public static func isEnabled(for selection: FileInfoSelection, preferences: FileMintPreferences) -> Bool {
        preferences.fileTools.allows(.copyContents) && FileInfoPolicy.canSelect([selection.source])
            && format(for: selection.source) != nil
            && FolderScope.contains(selection.source, in: preferences.monitoredFolderURLs)
    }

    public static func decodeText(_ data: Data) throws -> String {
        guard data.count <= maximumBytes else { throw FileContentCopyError.tooLarge }
        let bytes: Data
        let encoding: String.Encoding
        if data.starts(with: [0xFF, 0xFE, 0, 0]) || data.starts(with: [0, 0, 0xFE, 0xFF]) {
            throw FileContentCopyError.invalidEncoding
        } else if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes = data.dropFirst(3); encoding = .utf8
        } else if data.starts(with: [0xFF, 0xFE]) {
            bytes = data.dropFirst(2); encoding = .utf16LittleEndian
        } else if data.starts(with: [0xFE, 0xFF]) {
            bytes = data.dropFirst(2); encoding = .utf16BigEndian
        } else {
            bytes = data; encoding = .utf8
        }
        // The standard UTF-8 decoder preserves a content FEFF after our BOM
        // removal. Exact byte round trips reject every repaired sequence, while
        // remaining available on the minimum supported macOS version.
        let decoded = encoding == .utf8 ? String(decoding: bytes, as: UTF8.self)
            : String(data: bytes, encoding: encoding)
        guard let text = decoded,
              text.data(using: encoding, allowLossyConversion: false) == bytes else {
            throw FileContentCopyError.invalidEncoding
        }
        try validateText(text)
        return text
    }

    public static func validateText(_ text: String) throws {
        guard !text.isEmpty else { throw FileContentCopyError.empty }
        guard text.utf8.count <= maximumBytes else { throw FileContentCopyError.tooLarge }
        guard text.unicodeScalars.allSatisfy({ scalar in
            let value = scalar.value
            return value != 127 && (value >= 32 || [9, 10, 12, 13].contains(value))
        }) else { throw FileContentCopyError.invalidEncoding }
    }

    /// Independently extract only the supported RTF subset. The app must compare
    /// this text with its native import before publishing the original bytes.
    public static func validatedRTFText(_ data: Data) throws -> String {
        try RTFContentValidator.text(in: data)
    }
}

public struct FileContentRead: Sendable {
    public let selection: FileInfoSelection
    public let format: FileContentFormat
    public let data: Data
    private let metadata: FileInfoMetadata

    /// Check again after decoding, before the clipboard can be replaced.
    public func validate() throws {
        guard try FileDigestService.inspect(selection).stamp == metadata.stamp else { throw FileInfoError.changed }
    }

    public static func read(_ selection: FileInfoSelection,
                            cancellation: FileDigestCancellation = FileDigestCancellation()) throws -> Self {
        guard let format = FileContentCopyPolicy.format(for: selection.source) else {
            throw FileContentCopyError.unsupported
        }
        let (data, metadata) = try FileDigestService.readContents(selection,
            maximumBytes: FileContentCopyPolicy.maximumBytes, cancellation: cancellation)
        return Self(selection: selection, format: format, data: data, metadata: metadata)
    }
}
