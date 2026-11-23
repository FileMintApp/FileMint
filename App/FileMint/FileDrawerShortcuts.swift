import AppKit
import SwiftUI

/// The file collection and its keyboard guide share the same key bindings.
enum FileDrawerCommand: Hashable {
    case find, back, forward, refresh, chooseFolder, togglePlaces, goToPlaceMenu, actions, newFile, newFolder
    case selectAll, iconView, listView, compactView, pin, close, escape, togglePreview
    case place(FileDrawerPlace)
    case file(FileDrawerAction)

    struct Binding: Identifiable {
        let command: FileDrawerCommand
        let key: String
        let modifiers: NSEvent.ModifierFlags
        var id: String { keys }
        var keys: String {
            (modifiers.contains(.option) ? "⌥" : "") + (modifiers.contains(.shift) ? "⇧" : "")
                + (modifiers.contains(.command) ? "⌘" : "") + key
        }
        init(_ command: FileDrawerCommand, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command) {
            self.command = command
            self.key = key
            self.modifiers = modifiers
        }

        /// Keep ordinary editing keys available to the action search field.
        var paletteAction: FileDrawerAction? {
            guard case let .file(action) = command else { return nil }
            switch action {
            case .open where key == "O": return action
            case .favorite, .reveal, .copyTo, .moveTo, .copyPaths: return action
            default: return nil
            }
        }
    }

    static let windowCommands: [Binding] = [
        .init(.close, "W"), .init(.pin, "P", [.command, .shift]),
        .init(.newFile, "N"), .init(.newFolder, "N", [.command, .shift]),
        .init(.togglePlaces, "L"), .init(.goToPlaceMenu, "0"), .init(.actions, "K")
    ]
    static let places = FileDrawerPlace.allCases.prefix(9).enumerated().map {
        Binding(.place($0.element), String($0.offset + 1))
    }
    static let navigation: [Binding] = [
        .init(.find, "F"), .init(.back, "["), .init(.forward, "]"),
        .init(.refresh, "R"), .init(.chooseFolder, "O", [.command, .shift]),
        .init(.iconView, "1", [.command, .option]), .init(.listView, "2", [.command, .option]),
        .init(.compactView, "3", [.command, .option]), .init(.escape, "Esc", [])
    ]
    static let files: [Binding] = [
        .init(.selectAll, "A"), .init(.file(.open), "O"),
        .init(.file(.rename), "↩", []), .init(.togglePreview, "Space", []),
        .init(.file(.reveal), "R", [.option, .command]), .init(.file(.favorite), "D", [.command, .shift]),
        .init(.file(.copy), "C"), .init(.file(.cut), "X"), .init(.file(.paste), "V"),
        .init(.file(.copyPaths), "C", [.option, .command]),
        .init(.file(.copyTo), "C", [.command, .shift]), .init(.file(.moveTo), "M", [.command, .shift]),
        .init(.file(.trash), "⌫"), .init(.file(.restore), "Z")
    ]
    static let bindings = windowCommands + places + navigation + files

    @MainActor func runWindowCommand(in model: FileDrawerModel) -> Bool {
        switch self {
        case .close: model.close()
        case .pin: model.pinned.toggle()
        case .newFile: model.newFile()
        case .newFolder: model.newFolder()
        case .togglePlaces: model.togglePlaces()
        case .goToPlaceMenu: model.showPlacesMenu()
        case .actions: model.toggleActionPalette()
        case let .place(place): model.openPlace(place)
        default: return false
        }
        return true
    }

    static func binding(for event: NSEvent) -> Binding? {
        let key: String?
        switch event.keyCode {
        case 36, 76: key = "↩"
        case 49: key = "Space"
        case 51: key = "⌫"
        case 53: key = "Esc"
        default: key = event.charactersIgnoringModifiers?.uppercased()
        }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        return bindings.first { $0.key == key && $0.modifiers == modifiers }
    }

    static func match(_ event: NSEvent) -> Self? { binding(for: event)?.command }

    func title(_ chinese: Bool) -> String {
        let pair: (String, String) = switch self {
        case .find: ("Search this folder", "搜索当前文件夹")
        case .back: ("Back", "后退")
        case .forward: ("Forward", "前进")
        case .refresh: ("Refresh", "刷新")
        case .chooseFolder: ("Choose Folder…", "选择文件夹…")
        case .togglePlaces: ("Show or Hide Locations", "显示或隐藏位置")
        case .goToPlaceMenu: ("Go to Location", "前往位置")
        case .actions: ("Selection Actions", "选区操作")
        case .newFile: ("New File…", "新建文件…")
        case .newFolder: ("New Folder…", "新建文件夹…")
        case .selectAll: ("Select All", "全选")
        case .iconView: ("Icon View", "图标视图")
        case .listView: ("List View", "列表视图")
        case .compactView: ("Compact List", "紧凑列表")
        case .pin: ("Pin or Unpin", "固定或取消固定")
        case .close: ("Close Drawer", "收起抽屉")
        case .escape: ("Leave search, close preview or drawer", "离开搜索框、关闭预览或收起抽屉")
        case let .place(place): (place.title(false), place.title(true))
        case .togglePreview: ("Show or hide preview", "显示或关闭预览")
        case let .file(action): (action.title(false), action.title(true))
        }
        return chinese ? pair.1 : pair.0
    }

    func hint(for title: String, shown: Bool) -> String {
        guard shown, let binding = Self.bindings.first(where: { $0.command == self }) else { return title }
        return title + "  " + binding.keys
    }
}

struct FileDrawerShortcutGuide: View {
    let chinese: Bool
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(chinese ? "抽屉快捷键" : "Drawer Shortcuts").font(.headline)
                Spacer()
                Button(chinese ? "完成" : "Done", action: close).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("drawer.shortcuts.done")
            }
            Text(chinese ? "在文件区用 ↑ ↓ 选择项目，→ 进入文件夹，← 返回上一级。按 ⌘K 查看选区操作，按回车重命名。" :
                    "In the file list, use ↑ ↓ to select, → to enter a folder and ← to go to its parent. Press ⌘K for actions or Return to rename.")
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    section(chinese ? "抽屉" : "Drawer", FileDrawerCommand.windowCommands)
                    section(chinese ? "常用位置" : "Places", FileDrawerCommand.places)
                    section(chinese ? "浏览" : "Navigation", FileDrawerCommand.navigation)
                    section(chinese ? "文件操作" : "File Actions", FileDrawerCommand.files)
                }
            }
        }.padding(12)
    }

    private func section(_ title: String, _ bindings: [FileDrawerCommand.Binding]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(bindings) { binding in
                HStack {
                    Text(binding.command.title(chinese))
                    Spacer(minLength: 8)
                    Text(binding.key == "Space" && chinese ? "空格" : binding.keys)
                        .foregroundStyle(.secondary).monospaced()
                }.accessibilityElement(children: .combine)
            }
        }
    }
}
