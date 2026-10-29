import AppKit
import FileMintCore
import SwiftUI

@MainActor
final class QuickSearchPanelController: NSObject, NSWindowDelegate {
    static let shared = QuickSearchPanelController()
    private(set) var panel: NSPanel?
    private weak var searchField: NSSearchField?
    private let performFavoriteActivation: @MainActor (UUID, Bool, FavoriteLocationsModel) async throws -> Void
    private let openSettings: (PreferencesModel.Pane) -> Void

    init(openSettings: @escaping (PreferencesModel.Pane) -> Void = { SettingsWindowController.shared.show(pane: $0) },
         activateFavorite: @escaping @MainActor (UUID, Bool, FavoriteLocationsModel) async throws -> Void = { id, openFile, favorites in
        if openFile { try await favorites.openFile(id) }
        else { try await favorites.locate(id) }
    }) {
        self.performFavoriteActivation = activateFavorite
        self.openSettings = openSettings
        super.init()
    }

    func show(settings: PreferencesModel = .shared, favorites: FavoriteLocationsModel = .shared) {
        if let modal = NSApp.modalWindow ?? NSApp.windows.compactMap(\.attachedSheet).first {
            NSApp.activate(ignoringOtherApps: true); modal.makeKeyAndOrderFront(nil)
            return
        }
        if let panel {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil); panel.makeFirstResponder(searchField)
            return
        }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        let size = NSSize(width: min(580, visible.width), height: min(440, visible.height))
        let window = NSPanel(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        window.identifier = NSUserInterfaceItemIdentifier("io.github.daigua.filemint.quick-search")
        window.title = QuickSearchText.title.text(settings.preferences.language)
        window.contentMinSize = NSSize(width: min(440, size.width), height: min(320, size.height))
        window.isReleasedWhenClosed = false; window.isRestorable = false
        window.hidesOnDeactivate = false; window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.backgroundColor = FileMintStyle.backgroundNS; window.delegate = self
        window.contentView = NSHostingView(rootView: QuickSearchView(settings: settings, favorites: favorites,
            controller: self, createdField: { [weak self] in self?.searchField = $0 }))
        window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2,
                                      y: visible.midY - window.frame.height / 2))
        panel = window
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }

    func close() { panel?.close() }
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        panel = nil; searchField = nil
    }

    func activateFavorite(_ id: UUID, openFile: Bool = false, favorites: FavoriteLocationsModel) async throws {
        guard favorites.catalog.items.contains(where: { $0.id == id }) else { throw QuickSearchExecutionError.unavailable }
        guard !favorites.isBusy else { throw QuickSearchExecutionError.busy }
        let owner = panel
        try await performFavoriteActivation(id, openFile, favorites)
        // The user may have closed this search and opened another while the
        // bookmark or catalog operation was pending. That new query is theirs.
        if let owner, panel === owner { owner.close() }
    }

    /// Revalidate the stable identity using committed state, never the row title,
    /// current Finder selection or the last search-result position.
    func execute(_ id: QuickSearchID, settings: PreferencesModel, favorites: FavoriteLocationsModel) async throws {
        switch id {
        case .command(let action):
            close()
            switch action {
            case .newFile: settings.newFile()
            case .clipboardText: settings.newFileFromClipboard()
            case .clipboardImage: settings.pasteImageFile()
            }
        case .template(let templateID):
            guard settings.committedPreferences.templates.contains(where: { $0.id == templateID && $0.isEnabled }) else {
                throw QuickSearchExecutionError.unavailable
            }
            close(); settings.newFile(templateID: templateID)
        case .favorite(let itemID):
            try await activateFavorite(itemID, favorites: favorites)
        case .settings(let name):
            guard let pane = PreferencesModel.Pane(rawValue: name) else { throw QuickSearchExecutionError.unavailable }
            close(); settings.selectedPane = pane; openSettings(pane)
        }
    }
}

enum QuickSearchExecutionError: Error { case unavailable, busy }

@MainActor
enum QuickSearchSettingsCatalog {
    static func entries(language: AppLanguage) -> [QuickSearchResult] {
        PreferencesModel.Pane.allCases.map { pane in
            let aliases: [String] = switch pane {
            case .general: ["appearance", "theme", "language", "startup", "login", "shortcut", "hotkey", "menu bar", "外观", "主题", "语言", "开机", "快捷键", "菜单栏"]
            case .fileTypes: ["templates", "types", "模板", "类型"]
            case .creation: ["creation", "collision", "preview", "新建", "创建", "重名", "预览"]
            case .folders: ["folders", "permission", "authorization", "finder", "目录", "授权", "权限", "扩展"]
            case .fileTools: ["rename", "checksum", "hash", "move", "file info", "重命名", "校验", "移动", "文件信息"]
            case .resourceTools: ["images", "ocr", "compress", "convert", "图片", "压缩", "转换", "文字识别"]
            case .openWith: ["open with", "terminal", "应用", "终端"]
            case .favoriteLocations: ["favorites", "locations", "常用", "收藏", "分组"]
            case .about: ["about", "version", "update", "license", "关于", "版本", "更新", "许可"]
            }
            return QuickSearchResult(id: .settings(pane.rawValue), title: FileMintStrings.text(pane.title, language: language),
                detail: QuickSearchGroup.settings.title(language) + " · " + pane.groupTitle(language), symbol: pane.symbol,
                keywords: aliases + [FileMintStrings.text(pane.title, language: .english), FileMintStrings.text(pane.title, language: .chinese)])
        }
    }
}

private struct QuickSearchView: View {
    @ObservedObject var settings: PreferencesModel
    @ObservedObject var favorites: FavoriteLocationsModel
    let controller: QuickSearchPanelController
    let createdField: (NSSearchField) -> Void
    @State private var query = ""
    @State private var results: [QuickSearchResult] = []
    @State private var selection = QuickSearchSelection()
    @State private var message: String?
    @State private var executing = false
    private var language: AppLanguage { settings.preferences.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollViewReader { proxy in
                QuickSearchInputField(text: Binding(get: { query }, set: { value in
                    query = value
                    // AppKit may deliver Return before SwiftUI's next update.
                    // Keep results and selection current in the input callback.
                    rebuild(query: value, reset: true)
                }), placeholder: QuickSearchText.placeholder.text(language),
                    move: { offset in
                        selection.move(offset, in: results)
                        if let id = selection.id { proxy.scrollTo(id, anchor: .center) }
                    }, submit: executeSelected, cancel: controller.close, onCreate: createdField)
                    .frame(height: 28).accessibilityIdentifier("quickSearch.query")
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(QuickSearchGroup.allCases, id: \.self) { group in
                            let rows = results.filter { $0.group == group }
                            if !rows.isEmpty {
                                Text(group.title(language)).font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary).padding(.top, 8).padding(.horizontal, 10)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(rows) { result in row(result).id(result.id) }
                            }
                        }
                        if results.isEmpty {
                            Text(QuickSearchText.noResults.text(language)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(.top, 45)
                        }
                    }
                }
            }
            Text(message ?? QuickSearchText.keyboardHint.text(language))
                .font(.caption).foregroundStyle(message == nil ? Color.secondary : .orange)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("quickSearch.feedback")
        }.padding(18).background(FileMintStyle.background)
            .onAppear { rebuild(reset: true) }
            .onReceive(settings.$committedPreferences) { snapshot in rebuild(preferences: snapshot) }
            .onReceive(favorites.$catalog) { snapshot in rebuild(catalog: snapshot) }
    }

    private func row(_ result: QuickSearchResult) -> some View {
        let unavailable: Bool = if case .favorite(let id) = result.id { favorites.unavailableIDs.contains(id) } else { false }
        return Button {
            selection.select(result.id); executeSelected()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: result.symbol).frame(width: 20).foregroundStyle(FileMintStyle.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                    Text(result.detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if unavailable {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                        .accessibilityLabel(FavoriteText.unavailable.text(language))
                }
            }.padding(.horizontal, 10).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                .background(selection.id == result.id ? FileMintStyle.selection : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).disabled(executing)
            .accessibilityAddTraits(selection.id == result.id ? [.isSelected] : [])
            .contextMenu {
                if case .favorite(let id) = result.id {
                    Button(FavoriteText.relink.text(language)) {
                        Task { await favorites.relink(id, language: language) }
                    }.disabled(favorites.isBusy)
                    if favorites.catalog.items.first(where: { $0.id == id })?.kind == .file {
                        Button(FavoriteText.openFile.text(language)) {
                            Task {
                                do { try await controller.activateFavorite(id, openFile: true, favorites: favorites) }
                                catch { message = QuickSearchText.unavailable.text(language) }
                            }
                        }.disabled(favorites.isBusy)
                    }
                }
            }
    }

    private func rebuild(query: String? = nil, preferences: FileMintPreferences? = nil,
                         catalog: FavoriteLocationsCatalog? = nil, reset: Bool = false) {
        let snapshot = preferences ?? settings.committedPreferences
        let matches = QuickSearchCatalog.search(query ?? self.query, preferences: snapshot, favorites: catalog ?? favorites.catalog,
            settings: QuickSearchSettingsCatalog.entries(language: snapshot.language))
        results = matches
        selection.reconcile(matches, reset: reset)
        message = nil
    }

    private func executeSelected() {
        guard !executing, let id = selection.id, results.contains(where: { $0.id == id }) else { return }
        executing = true
        Task { @MainActor in
            defer { executing = false }
            do { try await controller.execute(id, settings: settings, favorites: favorites) }
            catch QuickSearchExecutionError.busy { message = QuickSearchText.busy.text(language) }
            catch { message = QuickSearchText.unavailable.text(language) }
        }
    }
}
