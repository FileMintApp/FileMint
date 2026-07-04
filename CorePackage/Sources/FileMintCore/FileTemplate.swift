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
    ]

    public static func template(withID id: String, in templates: [FileTemplate] = builtInTemplates) -> FileTemplate? {
        templates.first { $0.id == id }
    }

    public static func enabledTemplates(from templates: [FileTemplate]) -> [FileTemplate] {
        templates
            .filter(\.isEnabled)
            .sorted { left, right in
                if left.rank == right.rank {
                    return left.displayName.localizedStandardCompare(right.displayName) == .orderedAscending
                }
                return left.rank < right.rank
            }
    }
}
