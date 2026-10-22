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
        // The exact encoding round trip rejects repaired surrogate sequences.
        guard let text = String(data: bytes, encoding: encoding),
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

    /// Validate bounded RTF framing before invoking the platform importer. This
    /// is not an RTF renderer; original bytes remain the rich representation.
    public static func validateRTFStructure(_ data: Data) throws {
        guard data.count <= maximumBytes else { throw FileContentCopyError.tooLarge }
        let bytes = Array(data)
        guard bytes.starts(with: Array("{\\rtf1".utf8)), bytes.count > 6,
              !(48...57).contains(bytes[6]) else { throw FileContentCopyError.invalidRTF }
        let unsupported: Set<String> = ["pict", "object", "objdata", "bin", "shp", "shpinst", "shppict",
                                        "nonshppict", "nextgraphic", "filetbl", "datastore", "datafield"]
        func letter(_ value: UInt8) -> Bool { (65...90).contains(value) || (97...122).contains(value) }
        func hex(_ value: UInt8) -> Bool {
            (48...57).contains(value) || (65...70).contains(value) || (97...102).contains(value)
        }
        var depth = 0, index = 0
        while index < bytes.count {
            let byte = bytes[index]
            guard byte != 0 else { throw FileContentCopyError.invalidRTF }
            if byte == 123 {
                depth += 1
                guard depth <= 128 else { throw FileContentCopyError.invalidRTF }
            } else if byte == 125 {
                depth -= 1
                guard depth >= 0 else { throw FileContentCopyError.invalidRTF }
                if depth == 0 {
                    guard bytes[(index + 1)...].allSatisfy({ [9, 10, 13, 32].contains($0) }) else {
                        throw FileContentCopyError.invalidRTF
                    }
                    return
                }
            } else if byte == 92 {
                index += 1
                guard index < bytes.count else { throw FileContentCopyError.invalidRTF }
                if bytes[index] == 39 {
                    guard index + 2 < bytes.count, hex(bytes[index + 1]), hex(bytes[index + 2]) else {
                        throw FileContentCopyError.invalidRTF
                    }
                    index += 2
                } else if letter(bytes[index]) {
                    let start = index
                    while index < bytes.count, letter(bytes[index]) { index += 1 }
                    guard index - start <= 32 else { throw FileContentCopyError.invalidRTF }
                    let word = String(decoding: bytes[start..<index], as: UTF8.self).lowercased()
                    guard !unsupported.contains(word) else { throw FileContentCopyError.invalidRTF }
                    // Revisit the delimiter (which may be a structural brace).
                    continue
                }
            }
            index += 1
        }
        throw FileContentCopyError.invalidRTF
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
