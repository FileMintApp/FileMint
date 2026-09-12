import Foundation

public struct FileFormatOption: Equatable, Identifiable, Sendable {
    public var id: String { fileExtension }
    public let fileExtension: String
    public let templateID: String
    public let aliases: [String]

    public init(fileExtension: String, templateID: String, aliases: [String]) {
        self.fileExtension = fileExtension
        self.templateID = templateID
        self.aliases = aliases
    }
}

public enum FileFormatCatalog {
    public static let builtInOptions: [FileFormatOption] = [
        FileFormatOption(
            fileExtension: "txt",
            templateID: "plain-text",
            aliases: ["text", "plain text", "文本", "纯文本"]
        ),
        FileFormatOption(
            fileExtension: "md",
            templateID: "markdown",
            aliases: ["markdown", "写作"]
        ),
        FileFormatOption(
            fileExtension: "swift",
            templateID: "swift",
            aliases: ["swift", "code", "代码"]
        ),
        FileFormatOption(
            fileExtension: "json",
            templateID: "json",
            aliases: ["json", "data", "数据"]
        ),
        FileFormatOption(
            fileExtension: "html",
            templateID: "html",
            aliases: ["html", "web", "网页"]
        ),
        FileFormatOption(
            fileExtension: "css",
            templateID: "css",
            aliases: ["css", "stylesheet", "style", "样式"]
        ),
        FileFormatOption(
            fileExtension: "sh",
            templateID: "shell",
            aliases: ["shell", "shell script", "bash", "脚本"]
        )
    ]

    public static func options(from templates: [FileTemplate]) -> [FileFormatOption] {
        var seen = Set<String>()
        return TemplateCatalog.enabledTemplates(from: templates).compactMap { template in
            let prefix = "Untitled."
            let suffix = template.suggestedFileName.hasPrefix(prefix)
                ? String(template.suggestedFileName.dropFirst(prefix.count))
                : (template.suggestedFileName as NSString).pathExtension
            guard let normalized = FilenamePolicy.normalizedFileExtension(suffix),
                  seen.insert(normalized.lowercased()).inserted else { return nil }
            let aliases = builtInOptions.first { $0.templateID == template.id }?.aliases ?? []
            return FileFormatOption(fileExtension: normalized, templateID: template.id,
                                    aliases: aliases + [template.displayName])
        }
    }

    public static func matching(
        _ query: String,
        in options: [FileFormatOption] = builtInOptions
    ) -> [FileFormatOption] {
        let normalizedQuery = normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else {
            return options
        }

        return options.enumerated()
            .compactMap { index, option -> (option: FileFormatOption, score: Int, index: Int)? in
                let extensionText = option.fileExtension.lowercased()
                let terms = [extensionText] + option.aliases.map { $0.lowercased() }
                let scores = terms.compactMap { matchScore(text: $0, query: normalizedQuery) }
                guard let score = scores.min() else {
                    return nil
                }
                return (option, score, index)
            }
            .sorted { left, right in
                if left.score == right.score {
                    return left.index < right.index
                }
                return left.score < right.score
            }
            .map(\.option)
    }

    public static func option(
        forFileExtension fileExtension: String,
        in options: [FileFormatOption] = builtInOptions
    ) -> FileFormatOption? {
        guard let normalized = FilenamePolicy.normalizedFileExtension(fileExtension) else {
            return nil
        }

        return options.first {
            $0.fileExtension.caseInsensitiveCompare(normalized) == .orderedSame
        }
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "." })
            .lowercased()
    }

    private static func matchScore(text: String, query: String) -> Int? {
        if text == query {
            return 0
        }
        if text.hasPrefix(query) {
            return 1
        }
        if text.contains(query) {
            return 2
        }
        return nil
    }
}

public struct CustomFileLocationSelection: Equatable, Sendable {
    public private(set) var directoryURL: URL
    public private(set) var isBrowsing: Bool

    public init(directoryURL: URL, isBrowsing: Bool = false) {
        self.directoryURL = directoryURL
        self.isBrowsing = isBrowsing
    }

    public mutating func selectDirectory(_ directoryURL: URL) {
        self.directoryURL = directoryURL
        isBrowsing = false
    }

    public mutating func beginBrowsing() {
        isBrowsing = true
    }

    public mutating func finishBrowsing(selectedDirectoryURL: URL?) {
        if let selectedDirectoryURL {
            directoryURL = selectedDirectoryURL
        }
        isBrowsing = false
    }
}

public struct CustomFileDraft: Equatable, Sendable {
    public private(set) var extensionInput: String
    public private(set) var content: String
    public private(set) var hasEditedContent: Bool

    public var normalizedFileExtension: String? {
        FilenamePolicy.normalizedFileExtension(extensionInput)
    }

    public init(
        extensionInput: String = "txt",
        content: String? = nil,
        hasEditedContent: Bool = false,
        templates: [FileTemplate] = TemplateCatalog.builtInTemplates
    ) {
        self.extensionInput = extensionInput
        self.hasEditedContent = hasEditedContent

        if let content {
            self.content = content
        } else {
            self.content = Self.presetContent(for: extensionInput, templates: templates)
        }
    }

    public mutating func updateExtensionInput(
        _ value: String,
        templates: [FileTemplate] = TemplateCatalog.builtInTemplates
    ) {
        extensionInput = value
        updatePresetIfNeeded(templates: templates)
    }

    public mutating func selectFormat(
        _ option: FileFormatOption,
        templates: [FileTemplate] = TemplateCatalog.builtInTemplates
    ) {
        extensionInput = option.fileExtension
        updatePresetIfNeeded(templates: templates)
    }

    public mutating func updateContent(_ value: String) {
        content = value
        hasEditedContent = true
    }

    private mutating func updatePresetIfNeeded(templates: [FileTemplate]) {
        guard !hasEditedContent else {
            return
        }
        content = Self.presetContent(for: extensionInput, templates: templates)
    }

    private static func presetContent(
        for fileExtension: String,
        templates: [FileTemplate]
    ) -> String {
        guard let option = FileFormatCatalog.option(forFileExtension: fileExtension, in: FileFormatCatalog.options(from: templates)),
              let template = TemplateCatalog.template(withID: option.templateID, in: templates) else {
            return ""
        }
        return template.content
    }
}
