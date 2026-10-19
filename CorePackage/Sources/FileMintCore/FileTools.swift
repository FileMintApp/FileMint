import Foundation

public enum FileTool: String, Codable, CaseIterable, Sendable {
    case copyNames, copyPaths, move, permanentDelete, airDrop, desktopAlias, batchRename, fileInfo

    public var title: FileMintTextKey {
        switch self {
        case .copyNames: .copyItemNames
        case .copyPaths: .copyItemPaths
        case .move: .moveItems
        case .permanentDelete: .permanentDelete
        case .airDrop: .airDrop
        case .desktopAlias: .sendAliasToDesktop
        case .batchRename: .batchRename
        case .fileInfo: .fileInfo
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
    public var batchRename = false
    public var fileInfo = false
    public var mainMenuTools: Set<FileTool> = []
    public var moveHereInMainMenu = true
    public var deleteConfirmation: DeleteConfirmation = .required

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case isEnabled, copyNames, copyPaths, move, permanentDelete, airDrop, desktopAlias, batchRename, fileInfo
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
        batchRename = (try? values.decode(Bool.self, forKey: .batchRename)) ?? false
        fileInfo = (try? values.decode(Bool.self, forKey: .fileInfo)) ?? false
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
        case .batchRename: batchRename = enabled
        case .fileInfo: fileInfo = enabled
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
        case .batchRename: return batchRename
        case .fileInfo: return fileInfo
        }
    }
}

public enum FileToolTarget: Equatable, Sendable {
    case selection([URL])
    case directory(URL)
}

public enum FileToolsPolicy {
    public static func target(directory: URL, selection: [URL], isItemMenu: Bool,
                              isContainer: Bool) -> FileToolTarget? {
        if isContainer { return .directory(directory) }
        guard isItemMenu, !selection.isEmpty else { return nil }
        return .selection(selection)
    }

    public static func availableTools(target: FileToolTarget,
                                      preferences: FileMintPreferences) -> [FileTool] {
        switch target {
        case .selection(let selection):
            return availableTools(selection: selection, isItemMenu: true, preferences: preferences)
        case .directory(let directory):
            guard directory.isFileURL,
                  FolderScope.contains(directory, in: preferences.monitoredFolderURLs),
                  preferences.fileTools.allows(.copyPaths) else { return [] }
            return [.copyPaths]
        }
    }

    public static func availableTools(selection: [URL], isItemMenu: Bool,
                                      preferences: FileMintPreferences) -> [FileTool] {
        guard isItemMenu, !selection.isEmpty,
              selection.allSatisfy({ $0.isFileURL && FolderScope.contains($0, in: preferences.monitoredFolderURLs) })
        else { return [] }
        return FileTool.allCases.filter {
            preferences.fileTools.allows($0) && ($0 != .batchRename || canBatchRename(selection))
                && ($0 != .fileInfo || FileInfoPolicy.canSelect(selection))
        }
    }

    /// Finder menu construction performs only bounded URL checks. Actual item
    /// identities, kinds and filesystem capabilities are checked after the click.
    public static func canBatchRename(_ selection: [URL]) -> Bool {
        guard (2...BatchRenameRuleEngine.maximumRowCount).contains(selection.count),
              selection.allSatisfy({ $0.isFileURL && ($0.host == nil || $0.host == "" || $0.host == "localhost") })
        else { return false }
        let normalized = selection.map(\.standardizedFileURL)
        let paths = normalized.map(\.path)
        guard Set(paths).count == paths.count, let first = normalized.first else { return false }
        let parent = first.deletingLastPathComponent().path
        return normalized.allSatisfy { $0.path != "/" && $0.deletingLastPathComponent().path == parent }
    }

    public static func clipboardText(for tool: FileTool, selection: [URL]) -> String? {
        guard tool == .copyNames || tool == .copyPaths else { return nil }
        return selection.map { tool == .copyNames ? $0.lastPathComponent : $0.path }.joined(separator: "\n")
    }

    public static func clipboardText(for tool: FileTool, target: FileToolTarget) -> String? {
        switch target {
        case .selection(let selection):
            return clipboardText(for: tool, selection: selection)
        case .directory(let directory):
            return tool == .copyPaths ? directory.path : nil
        }
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
