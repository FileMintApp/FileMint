import Foundation

public enum FileTool: String, Codable, CaseIterable, Sendable {
    case copyNames, copyPaths, move

    public var title: FileMintTextKey {
        switch self {
        case .copyNames: .copyItemNames
        case .copyPaths: .copyItemPaths
        case .move: .moveItems
        }
    }
}

public struct FileToolsPreferences: Codable, Equatable, Sendable {
    public var isEnabled = false
    public var copyNames = true
    public var copyPaths = true
    public var move = true

    public init() {}

    private enum CodingKeys: String, CodingKey { case isEnabled, copyNames, copyPaths, move }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try? values.decode(Bool.self, forKey: .isEnabled)) ?? false
        copyNames = (try? values.decode(Bool.self, forKey: .copyNames)) ?? true
        copyPaths = (try? values.decode(Bool.self, forKey: .copyPaths)) ?? true
        move = (try? values.decode(Bool.self, forKey: .move)) ?? true
    }

    public func allows(_ tool: FileTool) -> Bool {
        guard isEnabled else { return false }
        switch tool {
        case .copyNames: return copyNames
        case .copyPaths: return copyPaths
        case .move: return move
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
        guard tool != .move else { return nil }
        return selection.map { tool == .copyNames ? $0.lastPathComponent : $0.path }.joined(separator: "\n")
    }
}
