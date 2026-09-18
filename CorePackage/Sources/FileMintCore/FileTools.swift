import Foundation

public enum FileTool: String, Codable, CaseIterable, Sendable {
    case copyNames, copyPaths, move, permanentDelete, airDrop, desktopAlias

    public var title: FileMintTextKey {
        switch self {
        case .copyNames: .copyItemNames
        case .copyPaths: .copyItemPaths
        case .move: .moveItems
        case .permanentDelete: .permanentDelete
        case .airDrop: .airDrop
        case .desktopAlias: .sendAliasToDesktop
        }
    }
}

public enum DeleteConfirmation: String, Codable, CaseIterable, Sendable {
    case required, silent

    public static func isRequired(captured: Self, current: Self) -> Bool {
        captured == .required || current == .required
    }
}

public struct FileToolsPreferences: Codable, Equatable, Sendable {
    public var isEnabled = false
    public var copyNames = true
    public var copyPaths = true
    public var move = true
    public var permanentDelete = false
    public var airDrop = false
    public var desktopAlias = false
    public var mainMenuTools: Set<FileTool> = []
    public var moveHereInMainMenu = true
    public var deleteConfirmation: DeleteConfirmation = .required

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case isEnabled, copyNames, copyPaths, move, permanentDelete, airDrop, desktopAlias
        case mainMenuTools, moveHereInMainMenu, deleteConfirmation
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try? values.decode(Bool.self, forKey: .isEnabled)) ?? false
        copyNames = (try? values.decode(Bool.self, forKey: .copyNames)) ?? true
        copyPaths = (try? values.decode(Bool.self, forKey: .copyPaths)) ?? true
        move = (try? values.decode(Bool.self, forKey: .move)) ?? true
        permanentDelete = (try? values.decode(Bool.self, forKey: .permanentDelete)) ?? false
        airDrop = (try? values.decode(Bool.self, forKey: .airDrop)) ?? false
        desktopAlias = (try? values.decode(Bool.self, forKey: .desktopAlias)) ?? false
        mainMenuTools = (try? values.decode(Set<FileTool>.self, forKey: .mainMenuTools)) ?? []
        moveHereInMainMenu = (try? values.decode(Bool.self, forKey: .moveHereInMainMenu)) ?? true
        deleteConfirmation = (try? values.decode(DeleteConfirmation.self, forKey: .deleteConfirmation)) ?? .required
    }

    public func allows(_ tool: FileTool) -> Bool { isEnabled && isToolEnabled(tool) }

    public mutating func setEnabled(_ enabled: Bool, for tool: FileTool) {
        switch tool {
        case .copyNames: copyNames = enabled
        case .copyPaths: copyPaths = enabled
        case .move: move = enabled
        case .permanentDelete: permanentDelete = enabled
        case .airDrop: airDrop = enabled
        case .desktopAlias: desktopAlias = enabled
        }
    }

    public func isToolEnabled(_ tool: FileTool) -> Bool {
        switch tool {
        case .copyNames: return copyNames
        case .copyPaths: return copyPaths
        case .move: return move
        case .permanentDelete: return permanentDelete
        case .airDrop: return airDrop
        case .desktopAlias: return desktopAlias
        }
    }
}

public enum FileToolsPolicy {
    public static func availableTools(selection: [URL], isItemMenu: Bool,
                                      preferences: FileMintPreferences) -> [FileTool] {
        guard isItemMenu, !selection.isEmpty,
              selection.allSatisfy({ $0.isFileURL && FolderScope.contains($0, in: preferences.monitoredFolderURLs) })
        else { return [] }
        return FileTool.allCases.filter { preferences.fileTools.allows($0) }
    }

    public static func clipboardText(for tool: FileTool, selection: [URL]) -> String? {
        guard tool == .copyNames || tool == .copyPaths else { return nil }
        return selection.map { tool == .copyNames ? $0.lastPathComponent : $0.path }.joined(separator: "\n")
    }
}

/// One partition drives the native menu, including the conditional move destination.
public struct FileToolsMenuLayout: Equatable, Sendable {
    public let main: [FileTool]
    public let submenu: [FileTool]
    public let moveHereInMain: Bool
    public let moveHereInSubmenu: Bool
    public var showsSubmenu: Bool { !submenu.isEmpty || moveHereInSubmenu }

    public init(tools: [FileTool], hasMoveDestination: Bool, preferences: FileToolsPreferences) {
        let enabled = tools.filter { preferences.allows($0) }
        main = enabled.filter { preferences.mainMenuTools.contains($0) }
        submenu = enabled.filter { !preferences.mainMenuTools.contains($0) }
        let moveHere = hasMoveDestination && preferences.allows(.move)
        moveHereInMain = moveHere && preferences.moveHereInMainMenu
        moveHereInSubmenu = moveHere && !preferences.moveHereInMainMenu
    }
}
