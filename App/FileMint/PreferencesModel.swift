import AppKit
import FileMintCore
import Foundation

@MainActor
final class PreferencesModel: ObservableObject {
    static let shared = PreferencesModel()
    enum Pane: String, CaseIterable, Identifiable {
        case fileTypes, creation, fileTools, resourceTools, openWith, general, folders, about
        var id: String { rawValue }
    }
    @Published var selectedPane: Pane = .general
    @Published var preferences: FileMintPreferences
    @Published var lastError: String?
    @Published var extensionEnabled = false
    @Published var loginItemState: LoginItemState = .notRegistered
    @Published var loginItemError: String?
    @Published var isUpdatingLoginItem = false
    @Published var isChoosingOpenWithApp = false
    private let loginItemService = LoginItemService()
    private let store: FileMintPreferencesStore
    private let folderAccess = FolderAccess()
    private var preferenceObserver: NSObjectProtocol?

    init(store: FileMintPreferencesStore = FileMintPreferencesStore()) {
        self.store = store
        preferences = store.load()
        folderAccess.restore(preferences)
        refreshStatus()
        preferenceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let loaded = self.store.load()
                guard loaded != self.preferences else { return }
                self.preferences = loaded
                self.folderAccess.restore(loaded)
            }
        }
    }

    var enabledTemplates: [FileTemplate] { TemplateCatalog.enabledTemplates(from: preferences.templates) }
    func text(_ key: FileMintTextKey) -> String { FileMintStrings.text(key, language: preferences.language) }
    func templateDisplayName(for template: FileTemplate) -> String {
        FileMintStrings.templateDisplayName(for: template, language: preferences.language)
    }
    func refreshStatus() {
        extensionEnabled = FinderIntegrationStatus.isEnabled
        loginItemState = loginItemService.state
        guard loginItemService.isInstalled, preferences.hasAttemptedLoginItemSetup,
              !isUpdatingLoginItem, loginItemError == nil else { return }
        let actual = loginItemState == .enabled || loginItemState == .requiresApproval
        if preferences.launchAtLogin != actual {
            preferences.launchAtLogin = actual
            save()
        }
    }

    var loginItemHint: String? {
        if !loginItemService.isInstalled { return text(.loginInstallFirst) }
        if loginItemError != nil { return text(.loginRegistrationFailed) }
        if loginItemState == .requiresApproval { return text(.loginNeedsApproval) }
        return nil
    }

    func prepareLoginItemIfNeeded() async {
        guard loginItemService.isInstalled, !preferences.hasAttemptedLoginItemSetup else { return }
        let state = loginItemService.state
        if LoginItemPolicy.shouldRegisterInitially(wantsEnabled: preferences.launchAtLogin,
            attempted: false, status: state, installed: true) {
            await setLaunchAtLogin(true)
        } else if !preferences.launchAtLogin && (state == .enabled || state == .requiresApproval) {
            await setLaunchAtLogin(false)
        } else {
            preferences.hasAttemptedLoginItemSetup = true
            refreshStatus()
            save()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        guard !isUpdatingLoginItem else { return }
        guard loginItemService.isInstalled else {
            preferences.launchAtLogin = enabled
            preferences.hasAttemptedLoginItemSetup = !enabled
            save()
            return
        }
        isUpdatingLoginItem = true
        preferences.hasAttemptedLoginItemSetup = true
        do {
            try await loginItemService.setEnabled(enabled)
            loginItemError = nil
        } catch { loginItemError = error.localizedDescription }
        loginItemState = loginItemService.state
        preferences.launchAtLogin = loginItemState == .enabled || loginItemState == .requiresApproval
        save()
        isUpdatingLoginItem = false
    }

    func setShowMenuBar(_ visible: Bool) {
        guard preferences.showMenuBar != visible else { return }
        preferences.showMenuBar = visible
        save()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard preferences.automaticallyChecksForUpdates != enabled else { return }
        preferences.automaticallyChecksForUpdates = enabled
        save()
    }

    @discardableResult
    func recordUpdateCheckAttempt(_ date: Date) -> Bool {
        preferences.lastUpdateCheckAttempt = date
        return save()
    }

    func openLoginSettings() { loginItemService.openSettings() }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    @discardableResult
    func save() -> Bool {
        do {
            try store.save(preferences)
            DistributedNotificationCenter.default().post(
                name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil
            )
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func resetTemplates() {
        preferences.templates = TemplateCatalog.restoringBuiltIns(in: preferences.templates)
        save()
    }

    func moveTemplates(fromOffsets source: IndexSet, toOffset destination: Int) {
        preferences.templates = TemplateCatalog.reorderedTemplates(preferences.templates, moving: source, to: destination)
        save()
    }

    func moveTemplate(id: String, by offset: Int) {
        let ordered = TemplateCatalog.sortedTemplates(from: preferences.templates)
        guard let index = ordered.firstIndex(where: { $0.id == id }), ordered.indices.contains(index + offset) else { return }
        moveTemplates(fromOffsets: IndexSet(integer: index), toOffset: index + offset + (offset > 0 ? 1 : 0))
    }

    func canMoveTemplate(id: String, by offset: Int) -> Bool {
        guard let index = preferences.templates.firstIndex(where: { $0.id == id }) else { return false }
        return preferences.templates.indices.contains(index + offset)
    }

    func isCustom(_ id: String) -> Bool { !TemplateCatalog.builtInTemplates.contains { $0.id == id } }

    func saveType(name: String, suffix: String, content: String, id: String?) throws {
        let type = try TemplateCatalog.customTemplate(name: name, fileExtension: suffix, content: content,
                                                       id: id, in: preferences.templates)
        if let index = preferences.templates.firstIndex(where: { $0.id == type.id }) { preferences.templates[index] = type }
        else { preferences.templates.append(type) }
        save()
    }

    func removeType(_ id: String) {
        guard isCustom(id) else { return }
        preferences.templates.removeAll { $0.id == id }
        save()
    }

    func addMonitoredFolder(initial: URL? = nil) {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = true
        picker.directoryURL = initial
        picker.message = text(.authorizeFolderHint)
        picker.prompt = text(.allowFolder)
        guard picker.runModal() == .OK else { return }
        do {
            for url in picker.urls { try FolderAccess.remember(url, in: &preferences) }
            save()
            folderAccess.restore(preferences)
        } catch { lastError = error.localizedDescription }
    }

    func removeFolder(_ url: URL) {
        preferences.monitoredFolderURLs.removeAll { $0 == url }
        preferences.monitoredFolderBookmarks.removeValue(forKey: url.path)
        save()
        folderAccess.restore(preferences)
    }

    func newFile() {
        if CustomFileSavePanelController.shared.focusExistingPanel() { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.canCreateDirectories = true
        picker.title = text(.saveLocation)
        picker.prompt = text(.newFile)
        picker.directoryURL = preferences.monitoredFolderURLs.first
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            try FolderAccess.remember(url, in: &preferences)
            save()
            folderAccess.restore(preferences)
            CustomFileSavePanelController.shared.present(in: url, preferences: preferences)
        } catch { lastError = error.localizedDescription }
    }

    func importSettings() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let attemptedHere = preferences.hasAttemptedLoginItemSetup
            preferences = try FileMintPreferencesStore.decode(Data(contentsOf: url))
            preferences.hasAttemptedLoginItemSetup = attemptedHere
            let launchAtLogin = preferences.launchAtLogin
            save()
            folderAccess.restore(preferences)
            Task { await setLaunchAtLogin(launchAtLogin) }
        } catch { lastError = error.localizedDescription }
    }

    private(set) var pendingCreationCount = 0

    func handle(url: URL) {
        if url.scheme == "filemint", url.host == "move" {
            FileOperationCoordinator.shared.enqueue(url)
            return
        }
        if let directory = CreationRoute.directory(from: url) {
            CustomFileSavePanelController.shared.present(in: directory, preferences: preferences,
                                                          templateID: CreationRoute.templateID(from: url))
            return
        }
        pendingCreationCount += 1
        Task {
            defer { pendingCreationCount -= 1 }
            do {
                let snapshot = preferences
                let ticket = try await Task.detached(priority: .userInitiated) {
                    try QuickCreationTicketStore().consume(url, preferences: snapshot)
                }.value
                guard let ticket else { return }
                await quickCreate(ticket)
            } catch { lastError = error.localizedDescription }
        }
    }

    private func quickCreate(_ ticket: QuickCreationTicket) async {
        guard let template = TemplateCatalog.template(withID: ticket.templateID, in: preferences.templates) else { return }
        let request = FileCreationRequest(destinationDirectory: ticket.directory, template: template,
                                           collisionStrategy: preferences.collisionStrategy == .replace ? .increment : preferences.collisionStrategy)
        let result = await Task.detached(priority: .userInitiated) {
            Result { try FileCreationService().createFile(request) }
        }.value
        switch result {
        case .success(let created):
            if preferences.revealAfterCreation { NSWorkspace.shared.activateFileViewerSelecting([created.createdURL]) }
        case .failure(let error):
            if FolderAccess.isPermissionError(error) {
                // The retry remains an explicit user action in the single creation panel.
                CustomFileSavePanelController.shared.present(in: ticket.directory, preferences: preferences, templateID: ticket.templateID)
            } else {
                let alert = NSAlert()
                alert.messageText = text(.createFileErrorTitle)
                alert.informativeText = error.localizedDescription
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    func openExtensionSettings() { FinderIntegrationStatus.showSettings() }
}
