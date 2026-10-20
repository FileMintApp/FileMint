import Foundation

/// The small, literal-text portion of a release note displayed before installation.
public struct UpdateSummary: Equatable, Sendable {
    public let headline: String
    public let highlights: [String]
}

public struct UpdateReleaseNotes: Equatable, Sendable {
    public static let maximumBodyBytes = 65_536
    private let chinese: UpdateSummary?
    private let english: UpdateSummary?

    public init?(body: String?, version: ReleaseVersion) {
        guard let body, body.utf8.count <= Self.maximumBodyBytes else { return nil }
        let lines = body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let start = lines.firstIndex(where: { $0.hasPrefix("# ") }),
              lines[start] == "# FileMint \(version)" else { return nil }
        let end = lines[(start + 1)...].firstIndex(where: { $0.hasPrefix("# ") }) ?? lines.endIndex
        let release = Array(lines[(start + 1)..<end])
        chinese = Self.summary(in: release, heading: "## 更新摘要")
        english = Self.summary(in: release, heading: "## Highlights")
        guard chinese != nil || english != nil else { return nil }
    }

    public func summary(for language: AppLanguage, preferredLanguages: [String]? = nil) -> UpdateSummary? {
        language.resolved(preferredLanguages: preferredLanguages) == .chinese ? chinese : english
    }

    private static func summary(in lines: [String], heading: String) -> UpdateSummary? {
        let matches = lines.indices.filter { lines[$0] == heading }
        guard matches.count == 1, let start = matches.first else { return nil }
        let end = lines[(start + 1)...].firstIndex(where: { $0.hasPrefix("## ") }) ?? lines.endIndex
        let content = lines[(start + 1)..<end].filter { !$0.isEmpty }
        guard (2...5).contains(content.count), let headline = content.first,
              !headline.hasPrefix("- "), plainText(headline, limit: 120) else { return nil }
        var highlights: [String] = []
        for line in content.dropFirst() {
            guard line.hasPrefix("- ") else { return nil }
            let text = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            guard plainText(text, limit: 240) else { return nil }
            highlights.append(text)
        }
        return UpdateSummary(headline: headline, highlights: highlights)
    }

    private static func plainText(_ value: String, limit: Int) -> Bool {
        // Summary authors use plain text. Full Markdown belongs in the details.
        // The view also uses Text(verbatim:); these strings never become links/HTML.
        !value.isEmpty && value.unicodeScalars.count <= limit &&
            !value.contains(where: { "<>[]`*#".contains($0) }) &&
            !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }
}
