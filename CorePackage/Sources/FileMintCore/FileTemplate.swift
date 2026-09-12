import Foundation

public struct FileTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var suggestedFileName: String
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
        rank: Int
    ) {
        self.id = id
        self.displayName = displayName
        self.suggestedFileName = suggestedFileName
        self.group = group
        self.content = content
        self.isEnabled = isEnabled
        self.rank = rank
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
            return left.displayName.localizedStandardCompare(right.displayName) == .orderedAscending
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
                                      id: String? = nil, in templates: [FileTemplate]) throws -> FileTemplate {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw TemplateValidationError.emptyName }
        guard let suffix = FilenamePolicy.normalizedFileExtension(fileExtension)?.lowercased() else {
            throw TemplateValidationError.invalidExtension
        }
        guard !templates.contains(where: {
            $0.id != id && $0.suggestedFileName.lowercased() == "untitled.\(suffix)"
        }) else { throw TemplateValidationError.duplicateExtension }
        let existing = templates.first { $0.id == id }
        return FileTemplate(id: id ?? "custom-\(UUID().uuidString)", displayName: name,
                            suggestedFileName: "Untitled.\(suffix)", group: "Custom", content: content,
                            isEnabled: existing?.isEnabled ?? true,
                            rank: existing?.rank ?? ((templates.map(\.rank).max() ?? 0) + 10))
    }

    public static func migratingTemplates(_ templates: [FileTemplate]) -> [FileTemplate] {
        let ids = Set(templates.map(\.id))
        var result = sortedTemplates(from: templates)
        for var template in builtInTemplates where !ids.contains(template.id) {
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
