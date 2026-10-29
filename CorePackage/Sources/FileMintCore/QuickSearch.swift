import Foundation

public enum QuickSearchCommand: String, CaseIterable, Sendable {
    case newFile, clipboardText, clipboardImage
    public var title: FileMintTextKey {
        switch self {
        case .newFile: .customNewFile
        case .clipboardText: .newFileFromClipboard
        case .clipboardImage: .pasteImageFile
        }
    }
    public var symbol: String {
        switch self {
        case .newFile: "doc.badge.plus"
        case .clipboardText: "doc.on.clipboard"
        case .clipboardImage: "photo"
        }
    }
}

public enum QuickSearchID: Hashable, Sendable {
    case command(QuickSearchCommand), template(String), favorite(UUID), settings(String)
}

public enum QuickSearchGroup: String, CaseIterable, Sendable {
    case actions, templates, favorites, settings
    public func title(_ language: AppLanguage) -> String {
        let chinese = language.resolved() == .chinese
        switch self {
        case .actions: return chinese ? "动作" : "Actions"
        case .templates: return chinese ? "模板" : "Templates"
        case .favorites: return chinese ? "常用文件（夹）" : "Favorite Locations"
        case .settings: return chinese ? "设置" : "Settings"
        }
    }
}

public struct QuickSearchResult: Equatable, Identifiable, Sendable {
    public let id: QuickSearchID
    public let title: String
    public let detail: String
    public let symbol: String
    public let keywords: [String]
    public var group: QuickSearchGroup {
        switch id {
        case .command: .actions
        case .template: .templates
        case .favorite: .favorites
        case .settings: .settings
        }
    }
    public init(id: QuickSearchID, title: String, detail: String, symbol: String, keywords: [String] = []) {
        self.id = id; self.title = title; self.detail = detail; self.symbol = symbol; self.keywords = keywords
    }
}

public enum QuickSearchCatalog {
    /// Search only caller-owned snapshots. Keep each catalog's existing ranking;
    /// shared suffixes and names are not identities and must never merge rows.
    public static func search(_ query: String, preferences: FileMintPreferences,
                              favorites: FavoriteLocationsCatalog,
                              settings: [QuickSearchResult] = [],
                              scope: QuickSearchGroup? = nil) -> [QuickSearchResult] {
        let language = preferences.language
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let actions = QuickSearchCommand.allCases.map { command in
            QuickSearchResult(id: .command(command), title: FileMintStrings.text(command.title, language: language),
                detail: QuickSearchGroup.actions.title(language), symbol: command.symbol,
                keywords: [FileMintStrings.text(command.title, language: .english),
                           FileMintStrings.text(command.title, language: .chinese)])
        }
        let favoriteItems = term.isEmpty && scope == nil ? favorites.quickItems() : favorites.search(term)
        let locations = favoriteItems.map { item in
            QuickSearchResult(id: .favorite(item.id), title: item.name, detail: item.url.path,
                              symbol: item.kind == .folder ? "folder" : "doc")
        }
        // All starts with bounded suggestions. An explicit category lets the user
        // browse its full snapshot without inventing a search term.
        if term.isEmpty && scope == nil { return actions + locations }
        let byID = Dictionary(preferences.templates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let options = FileFormatCatalog.options(from: preferences.templates).map { option in
            let names = byID[option.templateID].map { template in
                [FileMintStrings.templateDisplayName(for: template, language: .english),
                 FileMintStrings.templateDisplayName(for: template, language: .chinese)]
            } ?? []
            return FileFormatOption(fileExtension: option.fileExtension, templateID: option.templateID,
                                    aliases: option.aliases + names)
        }
        let templates = FileFormatCatalog.matching(term, in: options).compactMap { option -> QuickSearchResult? in
            guard let template = byID[option.templateID] else { return nil }
            return QuickSearchResult(id: .template(template.id),
                title: FileMintStrings.templateDisplayName(for: template, language: language),
                detail: "." + option.fileExtension, symbol: "doc.badge.plus")
        }
        let matches = matching(actions, term: term) + templates + locations + matching(settings, term: term)
        guard let scope else { return matches }
        return matches.filter { $0.group == scope }
    }

    private static func matching(_ items: [QuickSearchResult], term: String) -> [QuickSearchResult] {
        guard !term.isEmpty else { return items }
        return items.enumerated().compactMap { index, item -> (Int, Int, QuickSearchResult)? in
            let ranks = ([item.title] + item.keywords).compactMap { value -> Int? in
                let text = value.lowercased()
                if text == term { return 0 }
                if text.hasPrefix(term) { return 1 }
                if text.contains(term) { return 2 }
                return nil
            }
            guard let rank = ranks.min() else { return nil }
            return (rank, index, item)
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }.map(\.2)
    }
}

public struct QuickSearchSelection: Equatable, Sendable {
    public private(set) var id: QuickSearchID?
    public init() {}
    public mutating func select(_ id: QuickSearchID?) { self.id = id }
    public mutating func reconcile(_ results: [QuickSearchResult], reset: Bool) {
        if reset { id = results.first?.id }
        else if !results.contains(where: { $0.id == id }) { id = nil }
    }
    public mutating func move(_ offset: Int, in results: [QuickSearchResult]) {
        guard !results.isEmpty else { id = nil; return }
        guard let index = results.firstIndex(where: { $0.id == id }) else {
            id = offset < 0 ? results.last?.id : results.first?.id; return
        }
        id = results[max(0, min(results.count - 1, index + offset))].id
    }
}
