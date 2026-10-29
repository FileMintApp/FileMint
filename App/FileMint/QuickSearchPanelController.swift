import AppKit
import FileMintCore
import SwiftUI

/// A command palette must accept keyboard focus even when opened while another
/// app is active. Do not rely on NSPanel inferring this from hosted controls.
private final class QuickSearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) {
        guard (firstResponder as? NSTextView)?.hasMarkedText() != true else { return }
        performClose(sender)
    }
}

private struct QuickSearchResumeState {
    var query: String
    var scope: QuickSearchGroup?
    var selection: QuickSearchSelection
}

@MainActor
final class QuickSearchPanelController: NSObject, NSWindowDelegate {
    struct OperationContext {
        fileprivate let generation: UInt64
        fileprivate let owner: NSPanel?
    }

    static let shared = QuickSearchPanelController()
    private(set) var panel: NSPanel?
    private weak var searchField: NSSearchField?
    private var savedSearch: QuickSearchResumeState?
    private var generation: UInt64 = 0
    private var selectQueryOnFocus = false
    private var relatedInteractions = 0
    private var trackedMenus: Set<ObjectIdentifier> = []
    private var frontmostApplicationAtPresentation: pid_t?
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
        generation &+= 1
        frontmostApplicationAtPresentation = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let panel {
            selectQueryOnFocus = true
            panel.makeKeyAndOrderFront(nil); focusSearch()
            return
        }
        selectQueryOnFocus = true
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        let size = NSSize(width: min(680, visible.width), height: min(500, visible.height))
        let window = QuickSearchPanel(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        window.identifier = NSUserInterfaceItemIdentifier("io.github.daigua.filemint.quick-search")
        window.title = QuickSearchText.title.text(settings.preferences.language)
        window.contentMinSize = NSSize(width: min(520, size.width), height: min(360, size.height))
        window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.isReleasedWhenClosed = false; window.isRestorable = false
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.hidesOnDeactivate = false; window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.backgroundColor = FileMintStyle.backgroundNS; window.delegate = self
        panel = window
        window.contentView = NSHostingView(rootView: QuickSearchView(settings: settings, favorites: favorites,
            controller: self, initialState: savedSearch, createdField: { [weak self, weak window] field in
                guard let self, let window, self.panel === window, field.window === window else { return }
                self.searchField = field
                window.initialFirstResponder = field
                self.focusSearch()
            }, rememberState: { [weak self, weak window] state in
                guard let self, let window, self.panel === window else { return }
                self.savedSearch = state
            }))
        window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2,
                                      y: visible.midY - window.frame.height / 2))
        // A nonactivating panel takes keyboard focus directly. Requesting app
        // activation as well races macOS's asynchronous activation decision.
        window.makeKeyAndOrderFront(nil)
        focusSearch()
        startObservingDismissal()
    }

    func toggle(settings: PreferencesModel = .shared, favorites: FavoriteLocationsModel = .shared) {
        if panel?.isKeyWindow == true, relatedInteractions == 0,
           NSApp.modalWindow == nil, panel?.attachedSheet == nil {
            close()
        } else {
            show(settings: settings, favorites: favorites)
        }
    }

    func close() { panel?.close() }
    func focusSearch() {
        guard let panel else { return }
        if let searchField, searchField.window === panel { focus(searchField, in: panel) }
        // Hosting can mount the field after show(), and a SwiftUI Button can
        // update focus after its action returns. Finish focus in that same panel
        // on the next turn; never resurrect a closed or replaced search session.
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel, panel.isVisible,
                  panel.isKeyWindow, let field = self.searchField, field.window === panel else { return }
            self.focus(field, in: panel)
        }
    }
    private func focus(_ field: NSSearchField, in panel: NSPanel) {
        if panel.firstResponder !== field.currentEditor() { panel.makeFirstResponder(field) }
        if selectQueryOnFocus, let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText() {
            editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
            selectQueryOnFocus = false
        }
    }
    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        focusSearch()
    }
    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        scheduleDismissal()
    }
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        stopObservingDismissal()
        panel = nil; searchField = nil
        relatedInteractions = 0; trackedMenus.removeAll()
        selectQueryOnFocus = false
    }

    /// Acquire before scheduling the relink task: its first await can otherwise
    /// leave a gap between the context menu closing and its picker appearing.
    func beginRelatedInteraction() -> @MainActor () -> Void {
        guard let owner = panel else { return {} }
        relatedInteractions += 1
        var finished = false
        return { [weak self, weak owner] in
            guard !finished else { return }
            finished = true
            guard let self, let owner, self.panel === owner else { return }
            self.relatedInteractions -= 1
            if self.relatedInteractions == 0, NSApp.isActive,
               NSApp.keyWindow == nil || NSApp.keyWindow === owner,
               NSApp.modalWindow == nil, owner.attachedSheet == nil {
                owner.makeKeyAndOrderFront(nil)
                self.focusSearch()
            } else {
                self.scheduleDismissal()
            }
        }
    }

    /// AppKit can promote the main settings window when a modal picker ends.
    /// Restore its search owner at that precise boundary, before any later I/O;
    /// finishing background work must never perform this focus transfer.
    func relatedPickerDidClose(_ context: OperationContext) {
        guard generation == context.generation, let owner = context.owner,
              panel === owner, owner.isVisible, relatedInteractions > 0,
              NSApp.isActive, NSApp.modalWindow == nil else { return }
        owner.makeKeyAndOrderFront(nil)
        focusSearch()
    }

    private func startObservingDismissal() {
        NotificationCenter.default.addObserver(self, selector: #selector(menuBegan(_:)),
            name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuEnded(_:)),
            name: NSMenu.didEndTrackingNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    private func stopObservingDismissal() {
        for name in [NSMenu.didBeginTrackingNotification, NSMenu.didEndTrackingNotification] {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            NSWorkspace.shared.notificationCenter.removeObserver(self, name: name, object: nil)
        }
    }

    @objc private func menuBegan(_ notification: Notification) {
        guard let panel, panel.isVisible, let menu = notification.object as? NSMenu,
              panel.isKeyWindow || !trackedMenus.isEmpty else { return }
        trackedMenus.insert(ObjectIdentifier(menu))
    }

    @objc private func menuEnded(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu,
              trackedMenus.remove(ObjectIdentifier(menu)) != nil else { return }
        scheduleDismissal()
    }

    @objc private func applicationChanged(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              application.processIdentifier != frontmostApplicationAtPresentation else { return }
        scheduleDismissal()
    }
    @objc private func spaceChanged() { scheduleDismissal(leavingSpace: true) }

    private func scheduleDismissal(leavingSpace: Bool = false) {
        guard let owner = panel else { return }
        // AppKit may temporarily transfer key status to a menu or IME. Let the
        // native event finish, then check the same window and related UI again.
        DispatchQueue.main.async { [weak self, weak owner] in
            guard let self, let owner, self.panel === owner, owner.isVisible,
                  leavingSpace || !owner.isKeyWindow,
                  self.relatedInteractions == 0, self.trackedMenus.isEmpty,
                  owner.attachedSheet == nil,
                  (self.searchField?.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
            owner.close()
        }
    }

    func captureOperation() -> OperationContext { .init(generation: generation, owner: panel) }

    fileprivate func isCurrent(_ context: OperationContext) -> Bool {
        generation == context.generation && panel != nil && panel === context.owner
    }

    private func completeSearch(_ context: OperationContext) {
        guard generation == context.generation else { return }
        savedSearch = nil
        if let owner = context.owner, panel === owner { owner.close() }
    }

    func activateFavorite(_ id: UUID, openFile: Bool = false, favorites: FavoriteLocationsModel,
                          context: OperationContext? = nil) async throws {
        guard favorites.catalog.items.contains(where: { $0.id == id }) else { throw QuickSearchExecutionError.unavailable }
        guard !favorites.isBusy else { throw QuickSearchExecutionError.busy }
        let context = context ?? captureOperation()
        try await performFavoriteActivation(id, openFile, favorites)
        // The user may have closed this search and opened another while the
        // bookmark or catalog operation was pending. That new query is theirs.
        completeSearch(context)
    }

    /// Revalidate the stable identity using committed state, never the row title,
    /// current Finder selection or the last search-result position.
    func execute(_ id: QuickSearchID, settings: PreferencesModel, favorites: FavoriteLocationsModel,
                 context: OperationContext? = nil) async throws {
        let context = context ?? captureOperation()
        switch id {
        case .command(let action):
            completeSearch(context)
            switch action {
            case .newFile: settings.newFile()
            case .clipboardText: settings.newFileFromClipboard()
            case .clipboardImage: settings.pasteImageFile()
            }
        case .template(let templateID):
            guard settings.committedPreferences.templates.contains(where: { $0.id == templateID && $0.isEnabled }) else {
                throw QuickSearchExecutionError.unavailable
            }
            completeSearch(context)
            settings.newFile(templateID: templateID)
        case .favorite(let itemID):
            try await activateFavorite(itemID, favorites: favorites, context: context)
        case .settings(let name):
            guard let pane = PreferencesModel.Pane(rawValue: name) else { throw QuickSearchExecutionError.unavailable }
            completeSearch(context)
            settings.selectedPane = pane; openSettings(pane)
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
    let rememberState: (QuickSearchResumeState) -> Void
    private let restoresSelection: Bool
    @State private var query = ""
    @State private var scope: QuickSearchGroup?
    @State private var results: [QuickSearchResult] = []
    @State private var selection = QuickSearchSelection()
    @State private var message: String?
    @State private var executing = false
    private var language: AppLanguage { settings.preferences.language }
    private var isEmptyQuery: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var selectedResult: QuickSearchResult? { results.first { $0.id == selection.id } }

    init(settings: PreferencesModel, favorites: FavoriteLocationsModel,
         controller: QuickSearchPanelController, initialState: QuickSearchResumeState?,
         createdField: @escaping (NSSearchField) -> Void,
         rememberState: @escaping (QuickSearchResumeState) -> Void) {
        self.settings = settings; self.favorites = favorites; self.controller = controller
        self.createdField = createdField; self.rememberState = rememberState
        restoresSelection = initialState != nil
        _query = State(initialValue: initialState?.query ?? "")
        _scope = State(initialValue: initialState?.scope)
        _selection = State(initialValue: initialState?.selection ?? QuickSearchSelection())
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                searchHeader(move: { offset in
                    selection.move(offset, in: results)
                    remember()
                    if let id = selection.id { proxy.scrollTo(id) }
                })
                scopeBar
                Rectangle().fill(FileMintStyle.line).frame(height: 1)
                if results.isEmpty {
                    GeometryReader { geometry in
                        ScrollView {
                            emptyState.frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(QuickSearchGroup.allCases, id: \.self) { group in
                                let rows = results.filter { $0.group == group }
                                if !rows.isEmpty {
                                    sectionHeader(group, count: rows.count).id(group.rawValue)
                                    ForEach(rows) { result in row(result).id(result.id) }
                                }
                            }
                        }.padding(.horizontal, 12)
                    }.padding(.bottom, 12)
                }
                if let message {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.system(size: 12)).foregroundStyle(Color(nsColor: .systemOrange))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .accessibilityIdentifier("quickSearch.feedback")
                }
                footer
            }
            .onChange(of: query) { _ in scrollToResultsStart(proxy) }
            .onChange(of: scope) { _ in scrollToResultsStart(proxy) }
            .onAppear {
                rebuild(reset: !restoresSelection)
                if let id = selection.id { proxy.scrollTo(id) }
            }
        }
        .background(FileMintStyle.background).ignoresSafeArea()
        .onReceive(settings.$committedPreferences) { snapshot in rebuild(preferences: snapshot) }
        .onReceive(favorites.$catalog) { snapshot in rebuild(catalog: snapshot) }
    }

    private func searchHeader(move: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 15) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium)).foregroundStyle(FileMintStyle.accent)
                .frame(width: 44, height: 44)
                .background(FileMintStyle.selection, in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            QuickSearchInputField(text: Binding(get: { query }, set: { value in
                query = value
                // AppKit may deliver Return before SwiftUI's next update.
                // Rebuild from this exact input and scope in the same callback.
                rebuild(query: value, reset: true)
            }), placeholder: QuickSearchText.placeholder.text(language), move: move,
                submit: executeSelected, cancel: controller.close, onCreate: createdField, paletteStyle: true)
                .frame(height: 34).accessibilityIdentifier("quickSearch.query")
                .accessibilityLabel(QuickSearchText.title.text(language))
            Button(action: controller.close) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 26, height: 26)
                    .background(FileMintStyle.soft, in: Circle())
            }.buttonStyle(.plain).help(QuickSearchText.close.text(language))
                .accessibilityLabel(QuickSearchText.close.text(language))
                .accessibilityIdentifier("quickSearch.close")
        }
        .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 18)
    }

    private var scopeBar: some View {
        HStack(spacing: 5) {
            scopeButton(nil, index: 1)
            ForEach(Array(QuickSearchGroup.allCases.enumerated()), id: \.element) { index, group in
                scopeButton(group, index: index + 2)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 20).padding(.bottom, 13)
    }

    private func scopeButton(_ group: QuickSearchGroup?, index: Int) -> some View {
        let title = scopeTitle(group)
        return Button { changeScope(group) } label: {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12, weight: scope == group ? .semibold : .regular))
                Text("⌘" + String(index)).font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary).accessibilityHidden(true)
            }.fixedSize().padding(.horizontal, 8).padding(.vertical, 7)
        }
        .buttonStyle(QuickSearchScopeStyle(selected: scope == group))
        .keyboardShortcut(KeyEquivalent(Character(String(index))), modifiers: .command)
        .accessibilityLabel(title)
        .accessibilityAddTraits(scope == group ? [.isSelected] : [])
        .accessibilityIdentifier("quickSearch.scope." + (group?.rawValue ?? "all"))
        .help(title + " · ⌘" + String(index))
    }

    private func sectionHeader(_ group: QuickSearchGroup, count: Int) -> some View {
        HStack(spacing: 7) {
            Text(scope == nil && isEmptyQuery && group == .actions
                 ? QuickSearchText.suggestions.text(language) : scopeTitle(group))
            Text(String(count)).monospacedDigit().foregroundStyle(.tertiary)
            Spacer()
        }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.top, 15).padding(.bottom, 5)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ result: QuickSearchResult) -> some View {
        let unavailable: Bool = if case .favorite(let id) = result.id { favorites.unavailableIDs.contains(id) } else { false }
        let selected = selection.id == result.id
        return Button {
            selection.select(result.id); remember(); executeSelected()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: result.symbol).font(.system(size: 17, weight: .regular))
                    .foregroundStyle(iconColor(result.group)).frame(width: 36, height: 36)
                    .background(iconColor(result.group).opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary).lineLimit(1).truncationMode(.middle)
                    Text(detail(result)).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if result.group == .templates {
                    Text(result.detail).font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 4)
                        .background(FileMintStyle.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                }
                if unavailable {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                        .accessibilityLabel(FavoriteText.unavailable.text(language))
                }
                Image(systemName: "return").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FileMintStyle.accent).opacity(selected ? 1 : 0)
                    .frame(width: 18).accessibilityHidden(true)
            }.padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(QuickSearchRowStyle(selected: selected)).disabled(executing)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .help(result.title + " — " + detail(result))
        .contextMenu {
            if case .favorite(let id) = result.id {
                Button(FavoriteText.relink.text(language)) {
                    let finish = controller.beginRelatedInteraction()
                    let context = controller.captureOperation()
                    Task {
                        defer { finish() }
                        await favorites.relink(id, language: language, pickerDidClose: {
                            controller.relatedPickerDidClose(context)
                            finish()
                        })
                    }
                }.disabled(favorites.isBusy)
                if favorites.catalog.items.first(where: { $0.id == id })?.kind == .file {
                    Button(FavoriteText.openFile.text(language)) {
                        let context = controller.captureOperation()
                        Task {
                            do { try await controller.activateFavorite(id, openFile: true, favorites: favorites, context: context) }
                            catch {
                                if controller.isCurrent(context) { message = QuickSearchText.unavailable.text(language) }
                            }
                        }
                    }.disabled(favorites.isBusy)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 28, weight: .light))
                .foregroundStyle(FileMintStyle.accent).padding(16)
                .background(FileMintStyle.soft, in: Circle()).accessibilityHidden(true)
            Text((isEmptyQuery ? QuickSearchText.emptyCategory : .noResults).text(language))
                .font(.system(size: 15, weight: .medium))
                .accessibilityIdentifier("quickSearch.empty")
            Text(QuickSearchText.emptyHint.text(language)).font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if !isEmptyQuery {
                    Button(QuickSearchText.clear.text(language)) {
                        query = ""; rebuild(query: "", reset: true); controller.focusSearch()
                    }.buttonStyle(MintButtonStyle()).accessibilityIdentifier("quickSearch.clear")
                }
                if scope != nil {
                    Button(QuickSearchText.showAll.text(language)) { changeScope(nil) }
                        .buttonStyle(MintButtonStyle())
                }
            }.padding(.top, 3)
        }.padding(20)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(FileMintStyle.line).frame(height: 1)
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle().fill(FileMintStyle.accent).frame(width: 5, height: 5)
                    Text("FileMint").font(.system(size: 11, weight: .semibold))
                }.foregroundStyle(.secondary).accessibilityHidden(true)
                Spacer(minLength: 4)
                ViewThatFits(in: .horizontal) {
                    navigationHints(showLabels: true)
                    navigationHints(showLabels: false)
                }
                Rectangle().fill(FileMintStyle.line).frame(width: 1, height: 18)
                Button(action: executeSelected) {
                    HStack(spacing: 8) {
                        if executing { ProgressView().controlSize(.mini) }
                        Text(executing ? QuickSearchText.working.text(language) : actionTitle)
                            .font(.system(size: 11, weight: .medium))
                        keycap("↵")
                    }.foregroundStyle(selectedResult == nil ? Color.secondary : FileMintStyle.strong)
                        .fixedSize(horizontal: true, vertical: false)
                }.buttonStyle(.plain).disabled(executing || selectedResult == nil).layoutPriority(1)
                    .accessibilityIdentifier("quickSearch.primaryAction")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
                .padding(.horizontal, 20).frame(height: 48)
                .background(FileMintStyle.soft.opacity(0.6))
        }
    }

    private func navigationHints(showLabels: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                keycap("↑↓")
                if showLabels { Text(QuickSearchText.navigate.text(language)) }
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel(QuickSearchText.navigate.text(language) + " ↑↓")
            HStack(spacing: 5) {
                keycap("esc")
                if showLabels { Text(QuickSearchText.close.text(language)) }
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel(QuickSearchText.close.text(language) + " Escape")
        }.fixedSize()
    }

    private func keycap(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 5).frame(height: 20)
            .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
    }

    private var actionTitle: String {
        guard let result = selectedResult else { return QuickSearchText.results.text(language) }
        switch result.id {
        case .command, .template: return QuickSearchText.create.text(language)
        case .favorite: return QuickSearchText.locate.text(language)
        case .settings: return QuickSearchText.openSettings.text(language)
        }
    }

    private func scopeTitle(_ group: QuickSearchGroup?) -> String {
        guard let group else { return QuickSearchText.all.text(language) }
        return group == .favorites ? QuickSearchText.favorites.text(language) : group.title(language)
    }

    private func iconColor(_ group: QuickSearchGroup) -> Color {
        switch group {
        case .actions: FileMintStyle.accent
        case .templates: Color(nsColor: .systemBlue)
        case .favorites: Color(nsColor: .systemOrange)
        case .settings: Color.secondary
        }
    }

    private func detail(_ result: QuickSearchResult) -> String {
        switch result.id {
        case .command(.newFile): return CreationMenuAction.newFile.detail(language)
        case .command(.clipboardText): return CreationMenuAction.clipboardText.detail(language)
        case .command(.clipboardImage): return CreationMenuAction.clipboardImage.detail(language)
        case .template: return QuickSearchText.templateDetail.text(language)
        default: return result.detail
        }
    }

    private func changeScope(_ group: QuickSearchGroup?) {
        scope = group
        rebuild(reset: true)
        controller.focusSearch()
    }

    private func scrollToResultsStart(_ proxy: ScrollViewProxy) {
        if let group = results.first?.group { proxy.scrollTo(group.rawValue, anchor: .top) }
    }

    private func rebuild(query: String? = nil, preferences: FileMintPreferences? = nil,
                         catalog: FavoriteLocationsCatalog? = nil, reset: Bool = false) {
        let snapshot = preferences ?? settings.committedPreferences
        let matches = QuickSearchCatalog.search(query ?? self.query, preferences: snapshot, favorites: catalog ?? favorites.catalog,
            settings: QuickSearchSettingsCatalog.entries(language: snapshot.language), scope: scope)
        results = matches
        selection.reconcile(matches, reset: reset)
        message = nil
        remember()
    }

    private func remember() {
        rememberState(.init(query: query, scope: scope, selection: selection))
    }

    private func executeSelected() {
        guard !executing, let id = selection.id, results.contains(where: { $0.id == id }) else { return }
        executing = true
        let context = controller.captureOperation()
        Task { @MainActor in
            defer { executing = false }
            do { try await controller.execute(id, settings: settings, favorites: favorites, context: context) }
            catch QuickSearchExecutionError.busy {
                if controller.isCurrent(context) { message = QuickSearchText.busy.text(language) }
            }
            catch {
                if controller.isCurrent(context) { message = QuickSearchText.unavailable.text(language) }
            }
        }
    }
}

private struct QuickSearchRowStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.isFocused) private var focused
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(selected ? FileMintStyle.selection : hovered ? FileMintStyle.soft : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                focused ? FileMintStyle.accent : selected ? FileMintStyle.accent.opacity(0.22) : Color.clear,
                lineWidth: focused ? 1.5 : 0.7))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .onHover { hovered = $0 }
    }
}

private struct QuickSearchScopeStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.isFocused) private var focused
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? FileMintStyle.strong : Color.secondary)
            .background(selected ? FileMintStyle.selection : hovered ? FileMintStyle.soft : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(focused ? FileMintStyle.accent : Color.clear))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .onHover { hovered = $0 }
    }
}
