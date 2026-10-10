import Foundation

public enum CreationMenuPlacement: String, Codable, CaseIterable, Sendable {
    case hidden, main, submenu
}

public enum CreationMenuAction: String, Codable, CaseIterable, Sendable {
    case newFile, clipboardText, clipboardImage

    public var title: FileMintTextKey {
        switch self {
        case .newFile: .customNewFile
        case .clipboardText: .newFileFromClipboard
        case .clipboardImage: .pasteImageFile
        }
    }

    public var iconSlot: MenuIconSlot {
        switch self {
        case .newFile: .customNewFile
        case .clipboardText: .clipboardText
        case .clipboardImage: .clipboardImage
        }
    }
}

/// A menu description without AppKit, target lookup or clipboard access.
public struct CreationMenuLayout: Equatable, Sendable {
    public enum Entry: Equatable, Sendable {
        case action(CreationMenuAction), template(String), separator
    }
    public let main: [Entry]
    public let submenu: [Entry]

    public init(preferences: FileMintPreferences) {
        func entries(at placement: CreationMenuPlacement) -> [Entry] {
            let actions = CreationMenuAction.allCases.filter {
                preferences.creationMenuPlacement(for: $0) == placement
            }.map(Entry.action)
            let templates = TemplateCatalog.enabledTemplates(from: preferences.templates).filter {
                preferences.templateMenuPlacement(for: $0.id) == placement
            }.map { Entry.template($0.id) }
            return actions + (actions.isEmpty || templates.isEmpty ? [] : [.separator]) + templates
        }
        main = entries(at: .main)
        submenu = entries(at: .submenu)
    }
}

/// The complete creation group is one registry batch, across both menu levels.
/// Separators keep their position but never consume an action tag.
public struct RegisteredCreationMenu: Sendable {
    public struct Entry: Sendable {
        public let content: CreationMenuLayout.Entry
        public let tag: Int?
    }
    public let main: [Entry]
    public let submenu: [Entry]
}

extension FileMenuActionRegistry {
    public mutating func registerCreationMenu(_ layout: CreationMenuLayout, directory: URL) -> RegisteredCreationMenu {
        let actions: [FileMenuAction] = (layout.main + layout.submenu).compactMap { entry in
            switch entry {
            case .action: FileMenuAction(directory: directory, templateID: nil)
            case .template(let id): FileMenuAction(directory: directory, templateID: id)
            case .separator: nil
            }
        }
        var tags = register(actions).makeIterator()
        func tagged(_ entries: [CreationMenuLayout.Entry]) -> [RegisteredCreationMenu.Entry] {
            entries.map { .init(content: $0, tag: $0 == .separator ? nil : tags.next()) }
        }
        let main = tagged(layout.main)
        return RegisteredCreationMenu(main: main, submenu: tagged(layout.submenu))
    }
}

/// Decode entries individually so one malformed value cannot reset its neighbors.
struct RecoverableCreationMenuPlacement: Decodable {
    let value: CreationMenuPlacement?
    init(from decoder: Decoder) throws { value = try? CreationMenuPlacement(from: decoder) }
}

extension FileMintPreferences {
    public func creationMenuPlacement(for action: CreationMenuAction) -> CreationMenuPlacement {
        creationMenuPlacements[action.rawValue] ?? .submenu
    }

    public func templateMenuPlacement(for id: String) -> CreationMenuPlacement {
        templateMenuPlacements[id] ?? .submenu
    }

    public mutating func normalizeCreationMenuPlacements() {
        creationMenuPlacements = Dictionary(uniqueKeysWithValues: CreationMenuAction.allCases.map {
            ($0.rawValue, creationMenuPlacement(for: $0))
        })
        let ids = Set(templates.map(\.id))
        templateMenuPlacements = templateMenuPlacements.filter { ids.contains($0.key) }
        for id in ids where templateMenuPlacements[id] == nil { templateMenuPlacements[id] = .submenu }
    }
}
