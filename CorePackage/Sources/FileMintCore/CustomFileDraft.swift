import Foundation

public struct FileFormatOption: Equatable, Identifiable, Sendable {
    public var id: String { templateID }
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
        return TemplateCatalog.enabledTemplates(from: templates).compactMap { template in
            guard let normalized = FilenamePolicy.normalizedFileExtension(template.fileExtension) else { return nil }
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
    public private(set) var selectedTemplateID: String?
    private var defaultTemplateIDs: [String: String]

    public var normalizedFileExtension: String? {
        FilenamePolicy.normalizedFileExtension(extensionInput)
    }

    public init(
        extensionInput: String = "txt",
        content: String? = nil,
        hasEditedContent: Bool = false,
        templates: [FileTemplate] = TemplateCatalog.builtInTemplates,
        defaultTemplateIDs: [String: String] = [:]
    ) {
        self.extensionInput = extensionInput
        self.hasEditedContent = hasEditedContent
        self.defaultTemplateIDs = defaultTemplateIDs
        let selected = TemplateCatalog.defaultTemplate(forExtension: extensionInput, in: templates, defaults: defaultTemplateIDs)
        self.selectedTemplateID = selected?.id

        if let content {
            self.content = content
        } else {
            self.content = selected?.content ?? ""
        }
    }

    @discardableResult
    public mutating func updateExtensionInput(
        _ value: String,
        templates: [FileTemplate] = TemplateCatalog.builtInTemplates
    ) -> Bool {
        let normalized = FilenamePolicy.normalizedFileExtension(value) ?? ""
        let current = templates.first { $0.id == selectedTemplateID && $0.isEnabled && $0.fileExtension.caseInsensitiveCompare(normalized) == .orderedSame }
        let candidate = current ?? TemplateCatalog.defaultTemplate(forExtension: normalized, in: templates, defaults: defaultTemplateIDs)
        guard candidate?.document == nil || !hasEditedContent || content.isEmpty else { return false }
        extensionInput = value
        if let selected = templates.first(where: { $0.id == selectedTemplateID && $0.isEnabled }),
           selected.fileExtension.caseInsensitiveCompare(normalizedFileExtension ?? "") == .orderedSame {
            // Preserve explicitly selected templates when a complete name is typed.
        } else {
            selectedTemplateID = TemplateCatalog.defaultTemplate(forExtension: normalizedFileExtension ?? "", in: templates,
                defaults: defaultTemplateIDs)?.id
        }
        updatePresetIfNeeded(templates: templates)
        return true
    }

    @discardableResult
    public mutating func selectFormat(
        _ option: FileFormatOption,
        templates: [FileTemplate] = TemplateCatalog.builtInTemplates
    ) -> Bool {
        guard let selected = templates.first(where: { $0.id == option.templateID && $0.isEnabled && $0.fileExtension == option.fileExtension }),
              selected.document == nil || !hasEditedContent || content.isEmpty else { return false }
        extensionInput = option.fileExtension
        selectedTemplateID = option.templateID
        updatePresetIfNeeded(templates: templates)
        return true
    }

    public mutating func updateContent(_ value: String) {
        content = value
        hasEditedContent = true
    }

    private mutating func updatePresetIfNeeded(templates: [FileTemplate]) {
        guard !hasEditedContent else {
            return
        }
        content = templates.first { $0.id == selectedTemplateID }?.content ?? ""
    }
}
