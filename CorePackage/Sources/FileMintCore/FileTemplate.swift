import Foundation

public struct FileTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var suggestedFileName: String
    public var fileExtension: String
    public var document: DocumentTemplateReference? = nil
    public var group: String
    public var content: String
    public var isEnabled: Bool
    public var rank: Int

    public init(
        id: String,
        displayName: String,
        suggestedFileName: String,
        group: String,
        content: String,
        isEnabled: Bool = true,
        rank: Int,
        fileExtension: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.suggestedFileName = suggestedFileName
        self.fileExtension = fileExtension ?? Self.legacyExtension(suggestedFileName)
        self.group = group
        self.content = content
        self.isEnabled = isEnabled
        self.rank = rank
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, suggestedFileName, fileExtension, document, group, content, isEnabled, rank
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        displayName = try values.decode(String.self, forKey: .displayName)
        suggestedFileName = try values.decode(String.self, forKey: .suggestedFileName)
        fileExtension = try values.decodeIfPresent(String.self, forKey: .fileExtension) ?? Self.legacyExtension(suggestedFileName)
        if values.contains(.document), try !values.decodeNil(forKey: .document) {
            // A malformed asset reference must remain unavailable, never become
            // a text template or discard otherwise valid neighboring templates.
            document = (try? values.decode(DocumentTemplateReference.self, forKey: .document))
                ?? DocumentTemplateReference(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                    kind: OfficeDocumentKind(rawValue: fileExtension) ?? .docx, byteCount: 0, sha256: "")
        }
        group = try values.decode(String.self, forKey: .group)
        content = try values.decode(String.self, forKey: .content)
        isEnabled = try values.decode(Bool.self, forKey: .isEnabled)
        rank = try values.decode(Int.self, forKey: .rank)
    }

    private static func legacyExtension(_ name: String) -> String {
        name.hasPrefix("Untitled.") ? String(name.dropFirst("Untitled.".count)) : (name as NSString).pathExtension
    }
}

public enum TemplateCatalog {
    public static let builtInTemplates: [FileTemplate] = [
        FileTemplate(
            id: "plain-text",
            displayName: "Text",
            suggestedFileName: "Untitled.txt",
            group: "Basic",
            content: "",
            rank: 10
        ),
        FileTemplate(
            id: "markdown",
            displayName: "Markdown",
            suggestedFileName: "Untitled.md",
            group: "Writing",
            content: "# {{fileName}}\n\n",
            rank: 20
        ),
        FileTemplate(
            id: "swift",
            displayName: "Swift",
            suggestedFileName: "Untitled.swift",
            group: "Code",
            content: "import Foundation\n\n",
            rank: 30
        ),
        FileTemplate(
            id: "json",
            displayName: "JSON",
            suggestedFileName: "Untitled.json",
            group: "Data",
            content: "{}\n",
            rank: 40
        ),
        FileTemplate(
            id: "html",
            displayName: "HTML",
            suggestedFileName: "Untitled.html",
            group: "Web",
            content: "<!doctype html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"utf-8\">\n  <title>{{fileName}}</title>\n</head>\n<body>\n</body>\n</html>\n",
            rank: 50
        ),
        FileTemplate(
            id: "css",
            displayName: "CSS",
            suggestedFileName: "Untitled.css",
            group: "Web",
            content: ":root {\n}\n\n",
            rank: 60
        ),
        FileTemplate(
            id: "shell",
            displayName: "Shell Script",
            suggestedFileName: "Untitled.sh",
            group: "Code",
            content: "#!/usr/bin/env bash\nset -euo pipefail\n\n",
            rank: 70
        )
    ] + [
        ("csv", "CSV", "Data", ""),
        ("yaml", "YAML", "Data", ""),
        ("xml", "XML", "Data", "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"),
        ("js", "JavaScript", "Code", ""),
        ("ts", "TypeScript", "Code", ""),
        ("py", "Python", "Code", ""),
        ("sql", "SQL", "Data", "")
    ].enumerated().map { index, item in
        FileTemplate(id: item.0, displayName: item.1, suggestedFileName: "Untitled.\(item.0)",
                     group: item.2, content: item.3, isEnabled: false, rank: 80 + index * 10)
    }

    public static func template(withID id: String, in templates: [FileTemplate] = builtInTemplates) -> FileTemplate? {
        templates.first { $0.id == id }
    }

    public static func sortedTemplates(from templates: [FileTemplate]) -> [FileTemplate] {
        templates.sorted(by: menuRankSort)
    }

    public static func enabledTemplates(from templates: [FileTemplate]) -> [FileTemplate] {
        sortedTemplates(from: templates.filter(\.isEnabled))
    }

    public static func reorderedTemplates(
        _ templates: [FileTemplate],
        moving sourceIndexes: IndexSet,
        to destination: Int
    ) -> [FileTemplate] {
        var ordered = sortedTemplates(from: templates)
        let sources = sourceIndexes.sorted()

        guard !sources.isEmpty, sources.allSatisfy({ ordered.indices.contains($0) }) else {
            return normalizedRanks(for: ordered)
        }

        let movedTemplates = sources.map { ordered[$0] }
        for index in sources.reversed() {
            ordered.remove(at: index)
        }

        let removedBeforeDestination = sources.filter { $0 < destination }.count
        let insertionIndex = max(0, min(destination - removedBeforeDestination, ordered.count))
        ordered.insert(contentsOf: movedTemplates, at: insertionIndex)

        return normalizedRanks(for: ordered)
    }

    public static func normalizedRanks(for templates: [FileTemplate]) -> [FileTemplate] {
        templates.enumerated().map { offset, template in
            var rankedTemplate = template
            rankedTemplate.rank = (offset + 1) * 10
            return rankedTemplate
        }
    }

    private static func menuRankSort(_ left: FileTemplate, _ right: FileTemplate) -> Bool {
        if left.rank == right.rank {
            return left.id < right.id
        }
        return left.rank < right.rank
    }
}

public enum TemplateValidationError: Error, LocalizedError {
    case emptyName
    case invalidExtension
    case duplicateExtension

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a name for this file type."
        case .invalidExtension: "Enter a valid text-file extension."
        case .duplicateExtension: "This extension is already in your file types."
        }
    }
}

extension TemplateCatalog {
    public static func customTemplate(name: String, fileExtension: String, content: String,
                                      id: String? = nil, in templates: [FileTemplate],
                                      suggestedFileName: String? = nil) throws -> FileTemplate {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw TemplateValidationError.emptyName }
        guard let suffix = FilenamePolicy.normalizedFileExtension(fileExtension)?.lowercased() else {
            throw TemplateValidationError.invalidExtension
        }
        let existing = templates.first { $0.id == id }
        let requestedName = (suggestedFileName ?? existing?.suggestedFileName)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = FilenamePolicy.fileName(requestedName?.isEmpty == false ? requestedName! : "Untitled.\(suffix)",
            applyingFileExtension: suffix, replacingFileExtension: existing?.fileExtension)!
        return FileTemplate(id: id ?? "custom-\(UUID().uuidString)", displayName: name,
                            suggestedFileName: filename, group: existing?.group ?? "Custom", content: content,
                            isEnabled: existing?.isEnabled ?? true,
                            rank: existing?.rank ?? ((templates.map(\.rank).max() ?? 0) + 10), fileExtension: suffix)
    }

    public static func defaultTemplate(forExtension suffix: String, in templates: [FileTemplate],
                                       defaults: [String: String] = [:]) -> FileTemplate? {
        let matches = enabledTemplates(from: templates).filter { $0.fileExtension.caseInsensitiveCompare(suffix) == .orderedSame }
        return matches.first { $0.id == defaults[suffix.lowercased()] } ?? matches.first
    }

    public static func validDefaults(_ defaults: [String: String], in templates: [FileTemplate]) -> [String: String] {
        defaults.filter { suffix, id in
            suffix == suffix.lowercased() && templates.contains {
                $0.id == id && $0.isEnabled && $0.fileExtension.caseInsensitiveCompare(suffix) == .orderedSame
            }
        }
    }

    public static func migratingTemplates(_ templates: [FileTemplate], excludingBuiltInIDs removedIDs: Set<String> = []) -> [FileTemplate] {
        let ids = Set(templates.map(\.id))
        var result = sortedTemplates(from: templates)
        for var template in builtInTemplates where !ids.contains(template.id) && !removedIDs.contains(template.id) {
            template.rank = (result.map(\.rank).max() ?? 0) + 10
            template.isEnabled = false
            result.append(template)
        }
        return result
    }

    public static func restoringBuiltIns(in templates: [FileTemplate]) -> [FileTemplate] {
        let builtInIDs = Set(builtInTemplates.map(\.id))
        return normalizedRanks(for: builtInTemplates + sortedTemplates(from: templates).filter { !builtInIDs.contains($0.id) })
    }
}
