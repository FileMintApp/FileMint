import Cocoa
import FileMintCore
import FinderSync

// Finder invokes these callbacks on its XPC queue, not necessarily the main
// thread. Keep menu actions as value snapshots and copy values before dispatching UI.
final class FinderSync: FIFinderSync {
    private let actions = LockedMenuActions()
    private let cachedPreferences = LockedFinderPreferences()
    private let cachedFavorites = LockedFavoriteCatalog()
    override init() {
        super.init()
        reloadPreferences()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(reloadPreferences),
            name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil)
    }
    deinit { DistributedNotificationCenter.default().removeObserver(self) }
    override var toolbarItemName: String { "FileMint" }
    override var toolbarItemToolTip: String {
        FileMintStrings.text(.createNewFileTooltip, language: cachedPreferences.snapshot().language)
    }
    override var toolbarItemImage: NSImage {
        let image = Bundle(for: Self.self).image(forResource: "FinderMenuIcon")?.copy() as? NSImage ?? NSImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let preferences = cachedPreferences.snapshot()
        let language = preferences.language.resolved()
        let foreground = preferences.finderMenuIconStyle == .systemMonochrome
            ? Self.currentMenuForeground() : nil
        func menuImage(_ image: NSImage?) -> NSImage? {
            FileToolAppearance.finderMenuImage(image, foreground: foreground)
        }
        func text(_ key: FileMintTextKey) -> String {
            FileMintStrings.text(key, language: language)
        }
        func menuIcon(_ slot: MenuIconSlot) -> NSImage? {
            menuImage(FileToolAppearance.image(for: slot, customization: preferences.menuIcons[slot.rawValue],
                defaultBundle: Bundle(for: Self.self), style: preferences.finderMenuIconStyle))
        }
        let target = FIFinderSyncController.default().targetedURL()
        let isContainer = menuKind == .contextualMenuForContainer
        let targetIsDirectory = target.map {
            $0.hasDirectoryPath || (!isContainer && (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true)
        } ?? false
        guard let directory = FileMenuDestination.directory(
            target: target, isContainer: isContainer, targetIsDirectory: targetIsDirectory,
            monitoredFolders: preferences.monitoredFolderURLs
        ) else { return nil }
        let menu = NSMenu(title: "FileMint")
        let creationMenu = actions.registerCreationMenu(CreationMenuLayout(preferences: preferences), directory: directory)
        func appendCreation(_ entries: [RegisteredCreationMenu.Entry], to destination: NSMenu) {
            for entry in entries {
                let item: NSMenuItem
                switch entry.content {
                case .separator:
                    destination.addItem(.separator())
                    continue
                case .action(let action):
                    let selector: Selector
                    switch action {
                    case .newFile: selector = #selector(showCustomFile(_:))
                    case .clipboardText: selector = #selector(pasteTextFile(_:))
                    case .clipboardImage: selector = #selector(pasteImageFile(_:))
                    }
                    item = NSMenuItem(title: text(action.title), action: selector, keyEquivalent: "")
                    item.image = menuIcon(action.iconSlot)
                case .template(let id):
                    guard let template = preferences.templates.first(where: { $0.id == id }) else { continue }
                    let title = "\(FileMintStrings.templateDisplayName(for: template, language: language)) (.\(template.fileExtension))"
                    item = NSMenuItem(title: title, action: #selector(createFile(_:)), keyEquivalent: "")
                    item.image = menuImage(FileToolAppearance.image(for: template, style: preferences.finderMenuIconStyle))
                }
                guard let tag = entry.tag else { continue }
                item.tag = tag
                destination.addItem(item)
            }
        }
        appendCreation(creationMenu.main, to: menu)
        if !creationMenu.submenu.isEmpty {
            let root = NSMenuItem(title: text(.newFile), action: nil, keyEquivalent: "")
            root.image = menuIcon(.newFile)
            let submenu = NSMenu(title: text(.newFile))
            appendCreation(creationMenu.submenu, to: submenu)
            root.submenu = submenu
            menu.addItem(root)
        }
        let selection = menuKind == .contextualMenuForItems
            ? FIFinderSyncController.default().selectedItemURLs() ?? [] : []
        // Use the clicked folder for item menus, not a later Finder selection.
        let moveTarget = isContainer ? target : (selection.count == 1 ? selection.first : nil)
        let moveValues = isContainer ? nil : try? moveTarget?.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        var moveHereItem: NSMenuItem?
        if let pending = try? PendingFileMoveStore().load(),
           FileMovePolicy.isEnabled(preferences, pending: pending),
           let destination = FileMovePolicy.destination(target: moveTarget, isContainer: isContainer,
               selectionCount: selection.count, targetIsDirectory: moveValues?.isDirectory == true,
               targetIsPackage: moveValues?.isPackage == true,
               isItemMenu: menuKind == .contextualMenuForItems, preferences: preferences) {
            let title = pending.items.count == 1 ? text(.moveSelectedHere)
                : String(format: text(.moveSelectedHereCount), pending.items.count)
            let item = NSMenuItem(title: title, action: #selector(moveSelectedHere(_:)), keyEquivalent: "")
            item.image = menuIcon(.moveHere)
            item.tag = actions.register([FileMenuAction(directory: destination, moveBatchID: pending.id)])[0]
            // Root-level entry; Finder owns placement relative to system rows.
            moveHereItem = item
        }
        let fileToolTarget = FileToolsPolicy.target(directory: directory, selection: selection,
            isItemMenu: menuKind == .contextualMenuForItems, isContainer: isContainer)
        let tools = fileToolTarget.map {
            FileToolsPolicy.availableTools(target: $0, preferences: preferences)
        } ?? []
        let layout = FileToolsMenuLayout(tools: tools, hasMoveDestination: moveHereItem != nil,
                                         preferences: preferences.fileTools)
        let toolsMenu = NSMenu(title: text(.fileTools))
        if let moveHereItem {
            if layout.moveHereInMain { menu.insertItem(moveHereItem, at: 0) }
            else if layout.moveHereInSubmenu {
                toolsMenu.addItem(moveHereItem)
            }
        }
        let toolTags = fileToolTarget.map { target in
            actions.register(tools.map {
                FileMenuAction(directory: directory, tool: $0, target: target)
            })
        } ?? []
        for (index, tool) in tools.enumerated() {
            let item = NSMenuItem(title: text(tool.title), action: #selector(performFileTool(_:)), keyEquivalent: "")
            item.image = menuIcon(tool.menuIconSlot)
            item.tag = toolTags[index]
            if layout.main.contains(tool) { menu.addItem(item) }
            else { toolsMenu.addItem(item) }
        }
        if layout.showsSubmenu {
            let toolsRoot = NSMenuItem(title: text(.fileTools), action: nil, keyEquivalent: "")
            toolsRoot.image = menuIcon(.fileTools)
            toolsRoot.submenu = toolsMenu
            menu.addItem(toolsRoot)
        }
        let resourceTools = ResourceToolsPolicy.availableTools(selection: selection,
            isItemMenu: menuKind == .contextualMenuForItems, preferences: preferences)
        if !resourceTools.isEmpty {
            let resourceMenu = NSMenu(title: text(.resourceTools))
            let resourceTags = actions.register(resourceTools.map {
                FileMenuAction(directory: directory, resourceTool: $0, selection: selection)
            })
            for (index, tool) in resourceTools.enumerated() {
                let item = NSMenuItem(title: tool.title(language), action: #selector(performResourceTool(_:)), keyEquivalent: "")
                item.tag = resourceTags[index]
                item.image = menuIcon(tool.menuIconSlot)
                resourceMenu.addItem(item)
            }
            let item = NSMenuItem(title: text(.resourceTools), action: nil, keyEquivalent: "")
            item.image = menuIcon(.resourceTools)
            item.submenu = resourceMenu
            menu.addItem(item)
        }
        let directoryValues = selection.count == 1
            ? try? selection[0].resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .isAliasFileKey]) : nil
        let ordinaryDirectory = directoryValues?.isDirectory == true && directoryValues?.isPackage != true &&
            directoryValues?.isSymbolicLink != true && directoryValues?.isAliasFile != true
        let openTarget = OpenWithTargetPolicy.target(directory: directory, selection: selection,
            isContainer: isContainer, selectedIsOrdinaryDirectory: ordinaryDirectory)
        let applications = openTarget.map { OpenWithPolicy.availableApplications(target: $0, preferences: preferences) } ?? []
        let appLayout = OpenWithMenuLayout(applications: applications)
        let appMenu = NSMenu(title: text(.openWithApps))
        let appTags = actions.register(applications.map {
            FileMenuAction(directory: directory, openWithApplication: $0.reference,
                target: openTarget!, mode: $0.terminalOpenMode)
        })
        for (index, application) in applications.enumerated() {
            let item = NSMenuItem(title: application.menuTitle(target: openTarget!, language: language),
                                 action: #selector(openWithApplication(_:)), keyEquivalent: "")
            item.image = FileToolAppearance.applicationImage(at: application.url)
            item.tag = appTags[index]
            if application.placement == .main { menu.addItem(item) }
            else { appMenu.addItem(item) }
        }
        if appLayout.showsSubmenu {
            let item = NSMenuItem(title: text(.openWithApps), action: nil, keyEquivalent: "")
            item.image = menuIcon(.openWith)
            item.submenu = appMenu
            menu.addItem(item)
        }
        let favorites = cachedFavorites.snapshot()
        if FavoriteLocationsPolicy.canAdd(selection, isItemMenu: menuKind == .contextualMenuForItems,
                                          preferences: preferences) {
            let item = NSMenuItem(title: FavoriteText.add.text(language),
                action: #selector(performFavorite(_:)), keyEquivalent: "")
            item.image = menuImage(FileToolAppearance.image(for: .favoriteLocations, style: preferences.finderMenuIconStyle))
            item.tag = actions.register([FileMenuAction(directory: directory,
                favoriteAction: .add, selection: selection)])[0]
            menu.addItem(item)
        }
        if preferences.favoriteLocations.showListInFinder, !favorites.items.isEmpty {
            let submenu = NSMenu(title: FavoriteText.title.text(language))
            let quick = favorites.quickItems()
            let duplicateNames = Dictionary(grouping: quick, by: \.name)
            for favorite in quick {
                let title = (duplicateNames[favorite.name]?.count ?? 0) > 1
                    ? "\(favorite.name) — \(favorite.url.deletingLastPathComponent().lastPathComponent)"
                    : favorite.name
                let item = NSMenuItem(title: title, action: #selector(performFavorite(_:)), keyEquivalent: "")
                item.image = menuImage(FileToolAppearance.image(for: .favoriteLocations, style: preferences.finderMenuIconStyle))
                item.tag = actions.register([FileMenuAction(directory: directory,
                    favoriteAction: .locate(favorite.id))])[0]
                submenu.addItem(item)
            }
            if !quick.isEmpty { submenu.addItem(.separator()) }
            let search = NSMenuItem(title: FavoriteText.searchAll.text(language),
                action: #selector(performFavorite(_:)), keyEquivalent: "")
            search.tag = actions.register([FileMenuAction(directory: directory,
                favoriteAction: .search)])[0]
            submenu.addItem(search)
            let root = NSMenuItem(title: FavoriteText.title.text(language), action: nil, keyEquivalent: "")
            root.image = menuIcon(.favoriteLocations)
            root.submenu = submenu
            menu.addItem(root)
        }
        return menu.items.isEmpty ? nil : menu
    }

    private static func currentMenuForeground() -> MonochromeMenuForeground {
        // The extension never applies the main app's window-theme preference.
        // Read effectiveAppearance on its owner thread, not the XPC thread's
        // idle drawing appearance; transfer only the resolved black/white tone.
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                MonochromeMenuForeground(appearance: NSApplication.shared.effectiveAppearance)
            }
        }
        return DispatchQueue.main.sync {
            MonochromeMenuForeground(appearance: NSApplication.shared.effectiveAppearance)
        }
    }

    @objc private func performFavorite(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag), let favoriteAction = action.favoriteAction else { return }
        let selection = action.selection
        Task { @MainActor in
            switch favoriteAction {
            case .add:
                guard FavoriteLocationsPolicy.canAdd(selection, isItemMenu: true,
                    preferences: FileMintPreferencesStore().load()) else { return }
                FinderActions.shared.perform(.favoriteAdd(selection), errorTitle: .favoriteLocations)
            case .locate(let id):
                FinderActions.shared.perform(.favoriteLocate(id), activate: true, errorTitle: .favoriteLocations)
            case .search:
                FinderActions.shared.perform(.favoriteSearch, activate: true, errorTitle: .favoriteLocations)
            }
        }
    }

    @objc private func openWithApplication(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag), let application = action.openWithApplication,
              let target = action.openWithTarget, let mode = action.openWithMode else { return }
        Task { @MainActor in
            FinderActions.shared.openWith(application, target: target, mode: mode)
        }
    }

    @objc private func performResourceTool(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag), let tool = action.resourceTool else { return }
        let selection = action.selection
        Task { @MainActor in
            guard ResourceToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: FileMintPreferencesStore().load()).contains(tool) else { return }
            FinderActions.shared.perform(.resource(tool: tool, selection: selection), activate: true)
        }
    }

    @objc private func performFileTool(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag), let tool = action.tool,
              let target = action.fileToolTarget else { return }
        let selection = action.selection
        Task { @MainActor in
            let preferences = FileMintPreferencesStore().load()
            guard FileToolsPolicy.availableTools(target: target, preferences: preferences).contains(tool) else { return }
            if tool == .move {
                FinderActions.shared.perform(.prepare(selection))
                return
            }
            if tool == .permanentDelete {
                FinderActions.shared.delete(selection, confirmation: preferences.fileTools.deleteConfirmation)
                return
            }
            if tool == .desktopAlias {
                FinderActions.shared.sendAliasesToDesktop(selection)
                return
            }
            if tool == .airDrop {
                FinderActions.shared.perform(.airDrop(selection))
                return
            }
            guard let value = FileToolsPolicy.clipboardText(for: tool, target: target) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard pasteboard.setString(value, forType: .string) else {
                let alert = NSAlert()
                alert.messageText = FileMintStrings.text(.fileToolsErrorTitle, language: preferences.language)
                alert.informativeText = FileMintStrings.text(.clipboardWriteFailed, language: preferences.language)
                alert.runModal()
                return
            }
        }
    }

    @objc private func reloadPreferences() {
        let preferences = FileMintPreferencesStore().load()
        cachedPreferences.replace(preferences)
        cachedFavorites.replace((try? FavoriteLocationsStore().load()) ?? FavoriteLocationsCatalog())
        FIFinderSyncController.default().directoryURLs = FolderScope.observationRoots(
            for: preferences.monitoredFolderURLs,
            home: DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)
        )
    }

    @objc private func moveSelectedHere(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag), let batchID = action.moveBatchID else { return }
        let request = FileOperationRequest.perform(batchID: batchID, destination: action.directory)
        Task { @MainActor in FinderActions.shared.perform(request) }
    }

    @objc private func showCustomFile(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag) else { return }
        let directory = action.directory
        Task { @MainActor in FinderActions.shared.openPanel(in: directory) }
    }

    @objc private func createFile(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag), let id = action.templateID else { return }
        let directory = action.directory
        Task { @MainActor in FinderActions.shared.create(templateID: id, in: directory) }
    }

    @objc private func pasteImageFile(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag) else { return }
        Task { @MainActor in FinderActions.shared.pasteImage(in: action.directory) }
    }

    @objc private func pasteTextFile(_ item: NSMenuItem) {
        guard let action = actions.take(item.tag) else { return }
        Task { @MainActor in FinderActions.shared.pasteText(in: action.directory) }
    }
}

private final class LockedFavoriteCatalog: @unchecked Sendable {
    private let lock = NSLock()
    private var value = FavoriteLocationsCatalog()
    func replace(_ catalog: FavoriteLocationsCatalog) {
        lock.lock(); defer { lock.unlock() }
        value = catalog
    }
    func snapshot() -> FavoriteLocationsCatalog {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

private final class LockedFinderPreferences: @unchecked Sendable {
    private let lock = NSLock()
    private var value = FileMintPreferences.default

    func replace(_ preferences: FileMintPreferences) {
        lock.lock(); defer { lock.unlock() }
        value = preferences
    }

    func snapshot() -> FileMintPreferences {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

@MainActor
private final class FinderActions {
    static let shared = FinderActions()

    func openWith(_ application: OpenWithApplicationReference, target: OpenWithTarget, mode: TerminalOpenMode) {
        guard let configured = OpenWithPolicy.application(for: application, target: target,
            preferences: FileMintPreferencesStore().load()), configured.terminalOpenMode == mode else {
            showError(OpenWithError.changedConfiguration, title: .openWithApps)
            return
        }
        switch target {
        case .selection(let selection):
            perform(.openWith(application: application, selection: selection), errorTitle: .openWithApps)
        case .directory(let directory):
            perform(.openDirectory(application: application, directory: directory, mode: mode), errorTitle: .openWithApps)
        }
    }

    func openPanel(in directory: URL) {
        guard let url = CreationRoute.url(for: directory) else { return }
        open(url, activate: true)
    }

    func create(templateID: String, in directory: URL) {
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try QuickCreationTicketStore().enqueue(directory: directory, templateID: templateID)
                }.value
                open(url, activate: false)
            } catch { showError(error) }
        }
    }

    func pasteImage(in directory: URL) {
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try QuickCreationTicketStore().enqueueClipboardImage(directory: directory)
                }.value
                open(url, activate: true)
            } catch { showError(error) }
        }
    }

    func pasteText(in directory: URL) {
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try QuickCreationTicketStore().enqueueClipboardText(directory: directory)
                }.value
                open(url, activate: true)
            } catch { showError(error) }
        }
    }

    func delete(_ selection: [URL], confirmation: DeleteConfirmation) {
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    let items = try FileDeletionService.capture(selection)
                    return try FileOperationTicketStore().enqueue(.permanentDelete(items: items, confirmation: confirmation))
                }.value
                open(url, activate: false)
            } catch { showError(error, title: .fileToolsErrorTitle) }
        }
    }

    func sendAliasesToDesktop(_ selection: [URL]) {
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    let items = try DesktopAliasService.capture(selection)
                    return try FileOperationTicketStore().enqueue(.desktopAlias(items))
                }.value
                open(url, activate: false)
            } catch { showError(error, title: .sendAliasToDesktop) }
        }
    }

    func perform(_ request: FileOperationRequest, activate: Bool = false, errorTitle: FileMintTextKey = .fileToolsErrorTitle) {
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try FileOperationTicketStore().enqueue(request)
                }.value
                open(url, activate: activate)
            } catch { showError(error, title: errorTitle) }
        }
    }

    private func open(_ url: URL, activate: Bool) {
        let appURL = Bundle(for: FinderSync.self).bundleURL
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        // LaunchServices calls this even after a successful launch, on its own
        // queue. Do not inherit FinderActions' MainActor isolation here: that
        // would trap before reaching the Task and terminate the extension.
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { @Sendable _, error in
            if let error { Task { @MainActor in FinderActions.shared.showError(error) } }
        }
    }

    private func showError(_ error: Error, title: FileMintTextKey = .createFileErrorTitle) {
        let alert = NSAlert()
        let language = FileMintPreferencesStore().load().language
        alert.messageText = FileMintStrings.text(title, language: language)
        if let error = error as? OpenWithError {
            alert.informativeText = FileMintStrings.text(error.messageKey, language: language)
        } else { alert.informativeText = error.localizedDescription }
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// Finder's XPC callbacks may overlap. The lock guards every registry access;
// only Sendable value snapshots leave it, never NSMenu or NSMenuItem instances.
private final class LockedMenuActions: @unchecked Sendable {
    private let lock = NSLock()
    private var registry = FileMenuActionRegistry()
    func register(_ actions: [FileMenuAction]) -> [Int] {
        lock.lock(); defer { lock.unlock() }
        return registry.register(actions)
    }
    func registerCreationMenu(_ layout: CreationMenuLayout, directory: URL) -> RegisteredCreationMenu {
        lock.lock(); defer { lock.unlock() }
        return registry.registerCreationMenu(layout, directory: directory)
    }
    func take(_ tag: Int) -> FileMenuAction? {
        lock.lock(); defer { lock.unlock() }
        return registry.takeAction(for: tag)
    }
}
