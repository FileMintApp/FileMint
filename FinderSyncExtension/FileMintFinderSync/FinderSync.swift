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
        guard let target = FIFinderSyncController.default().targetedURL() else { return nil }
        var isDirectory: ObjCBool = false
        let directory = FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? target : target.deletingLastPathComponent()
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
        return menu
    }

    @objc private func reloadPreferences() {
        let preferences = FileMintPreferencesStore().load()
        FIFinderSyncController.default().directoryURLs = Set(preferences.monitoredFolderURLs)
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

    private func open(_ url: URL, activate: Bool) {
        let appURL = Bundle(for: FinderSync.self).bundleURL
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error { Task { @MainActor in FinderActions.shared.showError(error) } }
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        let language = FileMintPreferencesStore().load().language
        alert.messageText = FileMintStrings.text(.createFileErrorTitle, language: language)
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
