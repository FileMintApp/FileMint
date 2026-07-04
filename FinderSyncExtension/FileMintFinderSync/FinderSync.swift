import Cocoa
import FileMintCore
import FinderSync

private final class CreateMenuAction: NSObject {
    let folderURL: URL
    let templateID: String

    init(folderURL: URL, templateID: String) {
        self.folderURL = folderURL
        self.templateID = templateID
    }
}

final class FinderSync: FIFinderSync {
    private let store = FileMintPreferencesStore()
    private var preferences: FileMintPreferences
    private let creationService = FileCreationService()
    private var language: AppLanguage { preferences.language }

    override init() {
        self.preferences = store.load()
        super.init()

        reloadMonitoredFolders()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    override var toolbarItemName: String {
        "FileMint"
    }

    override var toolbarItemToolTip: String {
        FileMintStrings.text(.createNewFileTooltip, language: language)
    }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "FileMint")
            ?? NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard let folderURL = targetFolderURL(for: menuKind) else {
            return nil
        }

        let menu = NSMenu(title: "FileMint")
        let templates = TemplateCatalog.enabledTemplates(from: preferences.templates)

        guard !templates.isEmpty else {
            let emptyItem = NSMenuItem(
                title: FileMintStrings.text(.noTemplatesEnabled, language: language),
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return menu
        }

        let newFileTitle = FileMintStrings.text(.newFile, language: language)
        let rootItem = NSMenuItem(title: newFileTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: newFileTitle)

        for template in templates {
            let item = NSMenuItem(
                title: FileMintStrings.templateDisplayName(for: template, language: language),
                action: #selector(createFile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = CreateMenuAction(folderURL: folderURL, templateID: template.id)
            submenu.addItem(item)
        }

        rootItem.submenu = submenu
        menu.addItem(rootItem)
        return menu
    }

    @objc private func preferencesChanged() {
        preferences = store.load()
        reloadMonitoredFolders()
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? CreateMenuAction,
              let template = TemplateCatalog.template(withID: action.templateID, in: preferences.templates) else {
            return
        }

        do {
            let result = try creationService.createFile(
                FileCreationRequest(
                    destinationDirectory: action.folderURL,
                    template: template,
                    collisionStrategy: preferences.collisionStrategy
                )
            )

            if preferences.revealAfterCreation {
                NSWorkspace.shared.activateFileViewerSelecting([result.createdURL])
            }
        } catch {
            showError(error)
        }
    }

    private func reloadMonitoredFolders() {
        FIFinderSyncController.default().directoryURLs = Set(preferences.monitoredFolderURLs)
    }

    private func targetFolderURL(for menuKind: FIMenuKind) -> URL? {
        let controller = FIFinderSyncController.default()

        switch menuKind {
        case .contextualMenuForContainer, .contextualMenuForSidebar, .toolbarItemMenu:
            return controller.targetedURL()
        case .contextualMenuForItems:
            guard let targetURL = controller.targetedURL() else {
                return nil
            }

            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return targetURL
            }
            return targetURL.deletingLastPathComponent()
        @unknown default:
            return controller.targetedURL()
        }
    }

    private func showError(_ error: Error) {
        let message = error.localizedDescription
        let title = FileMintStrings.text(.createFileErrorTitle, language: language)

        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
