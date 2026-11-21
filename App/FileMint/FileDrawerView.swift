import AppKit
import FileMintCore
import QuickLookUI
import SwiftUI

@MainActor
struct FileDrawerView: View {
    @ObservedObject var model: FileDrawerModel
    @ObservedObject var settings: PreferencesModel
    @StateObject private var browserFocus = FileDrawerBrowserFocus()
    @FocusState private var filterFocused: Bool
    @State private var showingShortcuts = false

    init(model: FileDrawerModel, settings: PreferencesModel) {
        self.model = model
        self.settings = settings
    }

    private var chinese: Bool { settings.preferences.language.resolved() == .chinese }
    private func label(_ english: String, _ mandarin: String) -> String { chinese ? mandarin : english }
    private var showsHints: Bool { settings.preferences.fileDrawer.showsShortcutHints }

    var body: some View {
        Group {
            if showsHints && showingShortcuts {
                FileDrawerShortcutGuide(chinese: chinese) { showingShortcuts = false }
            } else {
                contents
            }
        }
        .disabled(model.actionPalette != nil)
        .accessibilityHidden(model.actionPalette != nil)
        .overlay {
            if let session = model.actionPalette {
                GeometryReader { frame in
                    ZStack(alignment: .bottomTrailing) {
                        Color.clear.contentShape(Rectangle()).onTapGesture { model.closeActionPalette() }
                            .accessibilityHidden(true)
                        FileDrawerActionPalette(model: model, session: session, chinese: chinese, showsHints: showsHints,
                                                availableHeight: frame.size.height - 56)
                            .id(session.id)
                            .frame(width: max(1, min(360, frame.size.width - 24)))
                            .padding(.trailing, 12).padding(.bottom, 44)
                    }
                }
            }
        }
        .onChange(of: model.actionPalette?.id) { id in
            if id == nil { browserFocus.restore(model) } else { showingShortcuts = false }
        }
        .onChange(of: showsHints) { if !$0 { showingShortcuts = false } }
    }

    private var contents: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            navigation
            if let directory = model.directory {
                FileDrawerPathBar(model: model, directory: directory)
            }
            Divider()
            GeometryReader { frame in
                let narrow = frame.size.width < 440
                let placesOnly = narrow && model.placesVisible
                HStack(alignment: .top, spacing: 8) {
                    if model.placesVisible {
                        FileDrawerPlacesSidebar(model: model, favorites: model.favorites,
                            activePlace: model.activePlace, currentRoot: model.rootURL,
                            showsHints: showsHints, chinese: chinese,
                            didChoose: { if narrow && model.directory != nil { model.placesVisible = false } })
                            .frame(width: placesOnly ? frame.size.width : min(164, frame.size.width * 0.28))
                            .disabled(model.busy || model.interacting)
                        if !placesOnly { Divider() }
                    }
                    if !placesOnly {
                        VStack(alignment: .leading, spacing: 8) {
                            if model.directory != nil {
                                browser
                            } else {
                                Spacer()
                                if model.placesVisible {
                                    Text(label("Choose a location in the sidebar", "从侧栏选择要浏览的位置"))
                                        .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                                } else {
                                    Button(label("Show Locations", "显示位置"), action: model.togglePlaces)
                                        .frame(maxWidth: .infinity)
                                }
                                Spacer()
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .onChange(of: model.directory) { url in
                    if narrow, url != nil { model.placesVisible = false }
                }
            }
            if model.directory == nil, !model.busy, let url = model.defaultLocationNeedingAccess {
                Button(label("Authorize Default Location…", "授权默认抽屉激活位置…"), action: model.authorizeDefaultLocation)
                    .disabled(model.interacting).help(url.path).accessibilityIdentifier("drawer.authorizeDefaultLocation")
            }
            if let message = model.message {
                Text(message).font(.body).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("drawer.feedback")
            }
            Divider()
            footer
        }
        .padding(12)
        .font(.system(size: 14))
        .controlSize(.regular)
        .disabled(model.pathMenu != nil)
        .accessibilityHidden(model.pathMenu != nil)
        .overlayPreferenceValue(FileDrawerPathAnchor.self) { anchor in
            if let anchor, let menu = model.pathMenu {
                GeometryReader { frame in
                    let top = min(frame[anchor].maxY + 3, max(4, frame.size.height - 170))
                    let width = max(1, min(frame.size.width - 16, 350))
                    ZStack(alignment: .topLeading) {
                        Color.clear.contentShape(Rectangle()).onTapGesture { model.closePathMenu(menu.id) }
                            .accessibilityHidden(true)
                        FileDrawerPathDropdown(model: model, menu: menu, availableHeight: max(100, frame.size.height - top - 8))
                            .id(menu.id)
                            .frame(width: width, alignment: .leading)
                            .offset(x: min(max(8, frame[anchor].minX), frame.size.width - width - 8), y: top)
                    }
                }
            }
        }
        .onChange(of: model.pathMenu?.id) { current in
            if current == nil { browserFocus.restore(model) }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            iconButton("sidebar.left", model.placesVisible ? label("Hide Locations", "折叠位置") : label("Show Locations", "展开位置"),
                       id: "drawer.places.toggle", command: .togglePlaces, action: model.togglePlaces)
                .disabled(model.interacting)
            Text(label("File Drawer", "文件抽屉")).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                .minimumScaleFactor(0.85).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 2)
            Menu {
                Button(FileDrawerCommand.newFile.hint(for: label("New File…", "新建文件…"), shown: showsHints), action: model.newFile)
                Button(FileDrawerCommand.newFolder.hint(for: label("New Folder…", "新建文件夹…"), shown: showsHints), action: model.newFolder)
            } label: {
                Label(label("New", "新建"), systemImage: "plus")
            }.menuStyle(.borderlessButton).fixedSize().disabled(model.directory == nil || model.busy || model.interacting)
                .accessibilityIdentifier("drawer.new")
            iconButton(model.pinned ? "pin.fill" : "pin", model.pinned ? label("Unpin", "取消固定") : label("Pin", "固定"),
                       id: "drawer.pin", command: .pin) { model.pinned.toggle() }
            iconButton("xmark", label("Close Drawer", "收起抽屉"), id: "drawer.close", command: .close, action: model.close)
        }
    }

    private var navigation: some View {
        HStack(spacing: 7) {
            iconButton("chevron.left", label("Back", "后退"), id: "drawer.back", command: .back, action: model.back)
                .disabled(!model.canBack)
            iconButton("chevron.right", label("Forward", "前进"), id: "drawer.forward", command: .forward, action: model.forward)
                .disabled(!model.canForward)
            iconButton("arrow.up", label("Parent Folder", "上一级"), id: "drawer.up", command: .up, action: model.up)
                .disabled(!model.canUp)
            let choose = label("Choose Folder…", "选择文件夹…")
            Button(action: model.chooseFolder) {
                ViewThatFits(in: .horizontal) {
                    Label(choose, systemImage: "folder").fixedSize()
                    Image(systemName: "folder")
                }
            }.buttonStyle(.borderless).accessibilityLabel(choose).help(choose)
                .accessibilityIdentifier("drawer.chooseFolder")
            Spacer(minLength: 0)
            if model.busy { ProgressView().controlSize(.small) }
            iconButton("arrow.clockwise", label("Refresh", "刷新"), id: "drawer.refresh", command: .refresh, action: model.refresh)
                .disabled(model.directory == nil)
        }.disabled(model.busy || model.interacting)
    }

    @ViewBuilder private var browser: some View {
        let entries = model.visibleEntries
        HStack(spacing: 5) {
            iconButton("magnifyingglass", label("Find in Folder", "搜索当前文件夹"), id: "drawer.find", command: .find) {
                filterFocused = true
            }.keyboardShortcut("f", modifiers: .command).disabled(model.interacting)
            TextField(FileDrawerCommand.find.hint(for: label("Search this folder", "搜索当前文件夹"), shown: showsHints), text: $model.query)
                .textFieldStyle(.roundedBorder).focused($filterFocused).accessibilityIdentifier("drawer.filter")
                .accessibilityLabel(label("Search filenames in this folder", "在当前文件夹搜索文件名"))
                .help(label("Match words in filenames and extensions in any order.", "可按任意顺序输入文件名或扩展名中的多个词。"))
                .onSubmit {
                    model.selectFirstSearchResult()
                    filterFocused = false
                    browserFocus.restore(model)
                }
            Menu {
                Picker(label("Sort by", "排序方式"), selection: $model.sort) {
                    Text(label("Name", "名称")).tag(FileDrawerSort.name)
                    Text(label("Kind (extension)", "类型（扩展名）")).tag(FileDrawerSort.kind)
                    Text(label("Size", "大小")).tag(FileDrawerSort.size)
                    Text(label("Modified", "修改日期")).tag(FileDrawerSort.date)
                }.pickerStyle(.inline)
                Divider()
                Picker(label("Sort order", "排序顺序"), selection: $model.sortAscending) {
                    Text(label("Ascending", "升序")).tag(true)
                    Text(label("Descending", "降序")).tag(false)
                }.pickerStyle(.inline)
            } label: { Image(systemName: "arrow.up.arrow.down") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(label("Sort by", "排序方式")).accessibilityIdentifier("drawer.sort")
            .help(label("Sort by", "排序方式"))
            Menu {
                Picker(label("View", "显示方式"),
                       selection: Binding(get: { model.viewMode }, set: { model.setViewMode($0) })) {
                    ForEach(FileDrawerViewMode.allCases, id: \.self) { mode in
                        Label(mode.command.hint(for: mode.command.title(chinese), shown: showsHints), systemImage: mode.symbol).tag(mode)
                    }
                }.pickerStyle(.inline)
            } label: { Image(systemName: model.viewMode.symbol) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel(label("View", "显示方式")).accessibilityIdentifier("drawer.view")
            .help(label("View", "显示方式"))
        }.disabled(model.interacting)
        ZStack {
            FileDrawerBrowser(model: model, entries: entries, resultsVersion: model.resultsVersion,
                              mode: model.viewMode, chinese: chinese, focus: browserFocus) {
                filterFocused = true
            }
                .accessibilityIdentifier("drawer.files")
                .opacity(model.isSearching ? 0 : 1)
                .allowsHitTesting(!model.isSearching)
                .accessibilityHidden(model.isSearching)
            if model.isSearching {
                ProgressView().controlSize(.small)
            } else if entries.isEmpty && !model.busy {
                Text(model.query.isEmpty ? label("This folder is empty", "文件夹为空") : label("No matching items", "没有匹配的项目"))
                    .font(.callout).foregroundStyle(.secondary).allowsHitTesting(false)
            }
        }
        if let url = model.previewURL {
            Divider()
            HStack {
                Text(url.lastPathComponent).font(.body.weight(.medium)).lineLimit(1).truncationMode(.middle)
                Spacer()
                iconButton("xmark.circle", label("Close Preview", "关闭预览"), id: "drawer.closePreview", action: model.closePreview)
            }
            FileDrawerPreview(url: url, grant: model.location?.grant)
                .id(url).frame(minHeight: 72, idealHeight: 150, maxHeight: 200)
                .accessibilityIdentifier("drawer.quickLook")
        }
        if model.selection.isEmpty && model.clipboardAvailable {
            Button(FileDrawerAction.paste.title(chinese), action: model.paste).disabled(model.busy)
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            if model.directory != nil {
                Text(model.selection.isEmpty
                     ? label("\(model.visibleEntries.count) items", "\(model.visibleEntries.count) 项")
                     : label("\(model.selection.count) selected", "已选 \(model.selection.count) 项"))
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 1)
            if model.directory != nil {
                if model.selection.isEmpty {
                    Menu {
                        ForEach([FileDrawerAction.reveal, .favorite, .paste, .restore], id: \.self) { action in
                            Button(action.title(chinese)) { action.run(model) }.disabled(!action.enabled(model))
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel(label("Folder actions", "文件夹操作"))
                    .accessibilityIdentifier("drawer.folderActions")
                } else {
                    let title = label("Actions", "操作")
                    Button(action: model.toggleActionPalette) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 5) {
                                Text(title)
                                if showsHints { Text("⌘K").foregroundStyle(.secondary) }
                            }.fixedSize()
                            Image(systemName: "ellipsis.circle").frame(width: 24)
                        }
                    }
                    .buttonStyle(.borderless).disabled(model.busy || model.isSearching || model.interacting)
                    .help(FileDrawerCommand.actions.hint(for: title, shown: showsHints)).accessibilityLabel(title)
                    .accessibilityIdentifier("drawer.actions")
                }
            }
            if showsHints {
                iconButton("keyboard", label("Keyboard Shortcuts", "快捷键用法"), id: "drawer.shortcuts") {
                    showingShortcuts = true
                }.disabled(model.interacting)
            }
            Toggle(label("Automatic Preview", "自动预览"),
                   isOn: Binding(get: { settings.preferences.fileDrawer.autoPreview }, set: { model.setAutoPreview($0) }))
                .toggleStyle(.switch).accessibilityIdentifier("drawer.autoPreview")
        }
    }

    private func iconButton(_ symbol: String, _ title: String, id: String, command: FileDrawerCommand? = nil,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                .frame(width: 27, height: 29).contentShape(Rectangle())
        }
            .buttonStyle(.borderless).accessibilityLabel(title)
            .help(command?.hint(for: title, shown: showsHints) ?? title).accessibilityIdentifier(id)
    }
}

private extension FileDrawerViewMode {
    var command: FileDrawerCommand {
        switch self { case .list: .listView; case .icons: .iconView; case .compact: .compactView }
    }
    var symbol: String {
        switch self { case .list: "list.bullet"; case .icons: "square.grid.2x2"; case .compact: "line.3.horizontal" }
    }
}

private struct FileDrawerPreview: NSViewRepresentable {
    let url: URL
    let grant: FileDrawerGrant?

    final class Coordinator {
        var grant: FileDrawerGrant?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.grant = grant
        let container = NSView()
        if let preview = QLPreviewView(frame: .zero, style: .compact) {
            preview.shouldCloseWithWindow = false
            preview.autostarts = false
            preview.frame = container.bounds
            preview.autoresizingMask = [.width, .height]
            container.addSubview(preview)
            preview.previewItem = url as NSURL
        }
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {}

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        (view.subviews.first as? QLPreviewView)?.close()
        coordinator.grant = nil
    }
}

enum FileDrawerAction: Int, CaseIterable {
    case open, openWith, newFileInFolder, preview, rename, copyPaths, favorite, reveal, copy, cut, paste, copyTo, moveTo, trash, restore

    var identifier: String { String(describing: self) }
    var command: FileDrawerCommand { self == .preview ? .togglePreview : .file(self) }
    var symbol: String {
        switch self {
        case .open: "arrow.up.forward.app"
        case .openWith: "square.and.arrow.up"
        case .newFileInFolder: "doc.badge.plus"
        case .preview: "eye"
        case .rename: "pencil"
        case .copy, .copyPaths, .copyTo: "doc.on.doc"
        case .cut: "scissors"
        case .moveTo: "folder"
        case .favorite: "star"
        case .reveal: "magnifyingglass"
        case .paste: "doc.on.clipboard"
        case .trash: "trash"
        case .restore: "arrow.uturn.backward"
        }
    }

    func title(_ chinese: Bool) -> String {
        let pair: (String, String) = switch self {
        case .open: ("Open", "打开")
        case .openWith: ("Open With…", "打开方式…")
        case .newFileInFolder: ("New File from Template Here…", "在此文件夹从模板新建…")
        case .preview: ("Preview", "预览")
        case .rename: ("Rename…", "重命名…")
        case .copyPaths: ("Copy Paths", "拷贝路径")
        case .favorite: ("Add to Favorite Locations", "添加到常用文件（夹）")
        case .reveal: ("Show in Finder", "在 Finder 中显示")
        case .copy: ("Copy Items", "拷贝项目")
        case .cut: ("Prepare to Move", "准备移动")
        case .paste: ("Paste Here", "粘贴到此处")
        case .copyTo: ("Copy to Folder…", "拷贝到文件夹…")
        case .moveTo: ("Move to Folder…", "移动到文件夹…")
        case .trash: ("Move to Trash…", "移到废纸篓…")
        case .restore: ("Put Back Last Trashed Items", "放回上次移到废纸篓的项目")
        }
        return chinese ? pair.1 : pair.0
    }

    @MainActor func enabled(_ model: FileDrawerModel) -> Bool {
        guard !model.busy, !model.isSearching, !model.interacting else { return false }
        switch self {
        case .rename: return model.selection.count == 1
        case .open:
            guard model.selection.count == 1, let item = model.selectedEntries.first else { return false }
            return item.canEnterDirectory || (item.isRegular && !item.isLink && !item.isOffline)
        case .newFileInFolder:
            return model.selection.count == 1 && model.selectedEntries.first?.canEnterDirectory == true
        case .favorite, .reveal: return model.directory != nil
        case .preview: return model.selection.count == 1 && model.selectedEntries.first?.canPreview == true
        case .paste: return model.directory != nil && model.clipboardAvailable
        case .restore: return model.canRestore
        default: return !model.selection.isEmpty
        }
    }

    @MainActor func run(_ model: FileDrawerModel) {
        guard enabled(model) else { return }
        switch self {
        case .open: model.openSelection()
        case .openWith: model.requestOpenWith()
        case .newFileInFolder: model.newFileInSelectedFolder()
        case .preview: model.preview()
        case .rename: model.rename()
        case .copyPaths: model.copyPaths()
        case .favorite: model.favorite()
        case .reveal: model.reveal()
        case .copy: model.copySelection(move: false)
        case .cut: model.copySelection(move: true)
        case .paste: model.paste()
        case .copyTo: model.chooseDestination(move: false)
        case .moveTo: model.chooseDestination(move: true)
        case .trash: model.trash()
        case .restore: model.restore()
        }
    }
}
