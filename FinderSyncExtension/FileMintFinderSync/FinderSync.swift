import Cocoa
import FileMintCore
import FinderSync

// Finder invokes these callbacks on its XPC queue, not necessarily the main
// thread. Keep this adapter stateless and copy values before dispatching UI.
final class FinderSync: FIFinderSync {
    private let actions = LockedMenuActions()
    override init() {
        super.init()
        reloadPreferences()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(reloadPreferences),
            name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil)
    }
    deinit { DistributedNotificationCenter.default().removeObserver(self) }
    override var toolbarItemName: String { "FileMint" }
    override var toolbarItemToolTip: String {
        FileMintStrings.text(.createNewFileTooltip, language: FileMintPreferencesStore().load().language)
    }
    override var toolbarItemImage: NSImage {
        let image = Bundle(for: Self.self).image(forResource: "FinderMenuIcon")?.copy() as? NSImage ?? NSImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let preferences = FileMintPreferencesStore().load()
        let language = preferences.language.resolved()
        func text(_ key: FileMintTextKey) -> String {
            FileMintStrings.text(key, language: language)
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
        let root = NSMenuItem(title: text(.newFile), action: nil, keyEquivalent: "")
        if let source = Bundle(for: Self.self).image(forResource: "FinderRootMenuIcon"),
           let logo = source.copy() as? NSImage {
            logo.size = NSSize(width: 16, height: 16)
            logo.isTemplate = false
            root.image = logo
        }
        let submenu = NSMenu(title: text(.newFile))
        let custom = NSMenuItem(title: text(.customNewFile), action: #selector(showCustomFile(_:)), keyEquivalent: "")
        let templates = TemplateCatalog.enabledTemplates(from: preferences.templates)
        let tags = actions.register([FileMenuAction(directory: directory, templateID: nil)] + templates.map {
            FileMenuAction(directory: directory, templateID: $0.id)
        })
        custom.tag = tags[0]
        submenu.addItem(custom)
        if !templates.isEmpty { submenu.addItem(.separator()) }
        for (index, template) in templates.enumerated() {
            let suffix = template.suggestedFileName.replacingOccurrences(of: "Untitled", with: "")
            let title = "\(FileMintStrings.templateDisplayName(for: template, language: language)) (\(suffix))"
            let item = NSMenuItem(title: title, action: #selector(createFile(_:)), keyEquivalent: "")
            item.tag = tags[index + 1]
            submenu.addItem(item)
        }
        root.submenu = submenu
        menu.addItem(root)
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
            item.image = FileToolAppearance.moveHereImage
            item.tag = actions.register([FileMenuAction(directory: destination, moveBatchID: pending.id)])[0]
            // Root-level entry; Finder owns placement relative to system rows.
            moveHereItem = item
        }
        let tools = FileToolsPolicy.availableTools(selection: selection,
            isItemMenu: menuKind == .contextualMenuForItems, preferences: preferences)
        let layout = FileToolsMenuLayout(tools: tools, hasMoveDestination: moveHereItem != nil,
                                         preferences: preferences.fileTools)
        let toolsMenu = NSMenu(title: text(.fileTools))
        if let moveHereItem {
            if layout.moveHereInMain { menu.insertItem(moveHereItem, at: 0) }
            else if layout.moveHereInSubmenu {
                toolsMenu.addItem(moveHereItem)
            }
        }
        let toolTags = actions.register(tools.map {
            FileMenuAction(directory: directory, tool: $0, selection: selection)
        })
        for (index, tool) in tools.enumerated() {
            let item = NSMenuItem(title: text(tool.title), action: #selector(performFileTool(_:)), keyEquivalent: "")
            item.image = FileToolAppearance.image(for: tool)
            item.tag = toolTags[index]
            if layout.main.contains(tool) { menu.addItem(item) }
            else { toolsMenu.addItem(item) }
        }
        if layout.showsSubmenu {
            let toolsRoot = NSMenuItem(title: text(.fileTools), action: nil, keyEquivalent: "")
            toolsRoot.image = FileToolAppearance.toolsImage
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
                item.image = FileToolAppearance.image(for: tool)
                resourceMenu.addItem(item)
            }
            let item = NSMenuItem(title: text(.resourceTools), action: nil, keyEquivalent: "")
            item.image = FileToolAppearance.resourceToolsImage
            item.submenu = resourceMenu
            menu.addItem(item)
        }
        return menu
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
        guard let action = actions.take(item.tag), let tool = action.tool else { return }
        let selection = action.selection
        Task { @MainActor in
            let preferences = FileMintPreferencesStore().load()
            guard FileToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: preferences).contains(tool) else { return }
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
            guard let value = FileToolsPolicy.clipboardText(for: tool, selection: selection) else { return }
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
}

@MainActor
private final class FinderActions {
    static let shared = FinderActions()

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

    func perform(_ request: FileOperationRequest, activate: Bool = false) {
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try FileOperationTicketStore().enqueue(request)
                }.value
                open(url, activate: activate)
            } catch { showError(error, title: .fileToolsErrorTitle) }
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
        alert.informativeText = error.localizedDescription
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
    func take(_ tag: Int) -> FileMenuAction? {
        lock.lock(); defer { lock.unlock() }
        return registry.takeAction(for: tag)
    }
}
