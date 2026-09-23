import AppKit
import FileMintCore
import FileMintImages
import UniformTypeIdentifiers
import Foundation

@MainActor
final class PreferencesModel: ObservableObject {
    static let shared = PreferencesModel()
    enum Pane: String, CaseIterable, Identifiable {
        case fileTypes, creation, fileTools, resourceTools, openWith, general, folders, about
        var id: String { rawValue }
    }
    @Published var selectedPane: Pane = .general
    @Published var preferences: FileMintPreferences {
        didSet {
            if preferences.appearance != oldValue.appearance { applyAppearance() }
        }
    }
    @Published var lastError: String?
    @Published var extensionEnabled = false
    @Published var loginItemState: LoginItemState = .notRegistered
    @Published var loginItemError: String?
    @Published var isUpdatingLoginItem = false
    @Published var isChoosingOpenWithApp = false
    private let loginItemService = LoginItemService()
    private let store: FileMintPreferencesStore
    let documentTemplates: DocumentTemplateStore
    @Published var isImportingDocument = false
    private let folderAccess = FolderAccess()
    private var preferenceObserver: NSObjectProtocol?

    init(store: FileMintPreferencesStore = FileMintPreferencesStore(), documentTemplates: DocumentTemplateStore = DocumentTemplateStore()) {
        self.store = store
        self.documentTemplates = documentTemplates
        preferences = store.load()
        applyAppearance()
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
    var finderSettingsPath: String {
        if #available(macOS 15, *) { return text(.finderSettingsPathModern) }
        return text(.finderSettingsPathLegacy)
    }
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

    func setAppearance(_ appearance: AppAppearance) {
        guard preferences.appearance != appearance else { return }
        let previous = preferences.appearance
        preferences.appearance = appearance
        if !save() { preferences.appearance = previous }
    }

    private func applyAppearance() {
        // AppKit propagates this to both SwiftUI hosts and native panels/sheets.
        // nil restores live system following instead of freezing today's scheme.
        NSApplication.shared.appearance = switch preferences.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
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
            preferences.defaultTemplateIDs = TemplateCatalog.validDefaults(preferences.defaultTemplateIDs, in: preferences.templates)
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

    func saveType(name: String, suffix: String, content: String, id: String?, suggestedFileName: String? = nil) throws {
        let previous = preferences
        let document = preferences.templates.first { $0.id == id }?.document
        if let document, suffix.lowercased() != document.kind.rawValue { throw DocumentTemplateError.unsupported }
        var type = try TemplateCatalog.customTemplate(name: name, fileExtension: suffix, content: document == nil ? content : "",
                                                       id: id, in: preferences.templates, suggestedFileName: suggestedFileName)
        type.document = document
        if let index = preferences.templates.firstIndex(where: { $0.id == type.id }) { preferences.templates[index] = type }
        else { preferences.templates.append(type) }
        if !save() { preferences = previous }
    }

    func removeType(_ id: String) {
        guard isCustom(id) else { return }
        let previous = preferences
        let document = preferences.templates.first { $0.id == id }?.document
        preferences.templates.removeAll { $0.id == id }
        if !save() { preferences = previous; return }
        if let document, !preferences.templates.contains(where: { $0.document?.id == document.id }) {
            let assets = documentTemplates
            Task.detached(priority: .utility) { try? assets.remove(document) }
        }
    }

    func setDefaultTemplate(_ template: FileTemplate) {
        guard template.isEnabled else { return }
        let previous = preferences
        preferences.defaultTemplateIDs[template.fileExtension.lowercased()] = template.id
        if !save() { preferences = previous }
    }

    func isDefaultTemplate(_ template: FileTemplate) -> Bool {
        TemplateCatalog.defaultTemplate(forExtension: template.fileExtension, in: preferences.templates,
            defaults: preferences.defaultTemplateIDs)?.id == template.id
    }

    func importDocumentTemplate() {
        guard !isImportingDocument else { return }
        let picker = NSOpenPanel()
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = false
        picker.allowedContentTypes = [UTType(filenameExtension: "docx"), UTType(filenameExtension: "xlsx")].compactMap { $0 }
        picker.title = text(.importDocumentTemplate)
        picker.resolvesAliases = false
        guard picker.runModal() == .OK, let source = picker.url else { return }
        Task { await importDocumentTemplate(from: source) }
    }

    func importDocumentTemplate(from source: URL) async {
        guard !isImportingDocument else { return }
        isImportingDocument = true
        pendingCreationCount += 1
        let access = source.startAccessingSecurityScopedResource()
        defer {
            if access { source.stopAccessingSecurityScopedResource() }
            isImportingDocument = false
            pendingCreationCount -= 1
        }
        let assets = documentTemplates
        do {
            let reference = try await Task.detached(priority: .userInitiated) { try assets.importDocument(at: source) }.value
            let previous = preferences
            var template = FileTemplate(id: "document-\(reference.id.uuidString)", displayName: source.deletingPathExtension().lastPathComponent,
                suggestedFileName: source.lastPathComponent, group: "Custom", content: "",
                rank: (preferences.templates.map(\.rank).max() ?? 0) + 10, fileExtension: reference.kind.rawValue)
            template.document = reference
            preferences.templates.append(template)
            if !save() {
                preferences = previous
                _ = await Task.detached(priority: .utility) { try? assets.remove(reference) }.value
            }
        } catch {
            lastError = text((error as? DocumentTemplateError)?.textKey ?? .documentImportFailed)
        }
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
            CustomFileSavePanelController.shared.present(in: url, preferences: preferences, documentTemplates: documentTemplates)
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
    private var preparingClipboardImage = false

    func pasteImageFile() {
        guard !preparingClipboardImage, !CustomFileSavePanelController.shared.focusExistingPanel() else { return }
        let directory = preferences.monitoredFolderURLs.first ?? FileManager.default.homeDirectoryForCurrentUser
        Task { await presentClipboardImage(in: directory) }
    }

    func presentClipboardImage(in directory: URL, pasteboard: NSPasteboard = .general) async {
        guard !preparingClipboardImage, !CustomFileSavePanelController.shared.focusExistingPanel() else { return }
        preparingClipboardImage = true
        pendingCreationCount += 1
        defer { preparingClipboardImage = false; pendingCreationCount -= 1 }
        do {
            guard let items = pasteboard.pasteboardItems, items.count == 1,
                  !items[0].types.contains(.fileURL),
                  let data = items[0].data(forType: .png) ?? items[0].data(forType: .tiff) else {
                throw ClipboardImageError.unsupported
            }
            let image = try await Task.detached(priority: .userInitiated) {
                try ClipboardImageEncoder.encode(data)
            }.value
            // A different creation action may have opened a draft while decoding.
            guard !CustomFileSavePanelController.shared.focusExistingPanel() else { return }
            CustomFileSavePanelController.shared.present(in: directory, preferences: preferences,
                imageData: image.png, imagePreview: NSImage(data: image.preview))
        } catch {
            let key: FileMintTextKey
            switch error {
            case ClipboardImageError.tooLarge: key = .clipboardImageTooLarge
            case ClipboardImageError.unsupported: key = .clipboardImageUnsupported
            default: key = .clipboardImageFailed
            }
            let alert = NSAlert()
            alert.messageText = text(.pasteImageFile)
            alert.informativeText = text(key)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    func handle(url: URL) {
        if url.scheme == "filemint", url.host == "move" {
            FileOperationCoordinator.shared.enqueue(url)
            return
        }
        if let directory = CreationRoute.directory(from: url) {
            CustomFileSavePanelController.shared.present(in: directory, preferences: preferences,
                                                          templateID: CreationRoute.templateID(from: url), documentTemplates: documentTemplates)
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
                if ticket.clipboardImage == true { await presentClipboardImage(in: ticket.directory) }
                else { await quickCreate(ticket) }
            } catch { lastError = error.localizedDescription }
        }
    }

    private func quickCreate(_ ticket: QuickCreationTicket) async {
        guard let template = TemplateCatalog.template(withID: ticket.templateID, in: preferences.templates) else { return }
        let request = FileCreationRequest(destinationDirectory: ticket.directory, template: template,
                                           collisionStrategy: preferences.collisionStrategy == .replace ? .increment : preferences.collisionStrategy)
        let assets = documentTemplates
        let result = await Task.detached(priority: .userInitiated) {
            Result { try FileCreationService(documentTemplates: assets).createFile(request) }
        }.value
        switch result {
        case .success(let created):
            if preferences.revealAfterCreation { NSWorkspace.shared.activateFileViewerSelecting([created.createdURL]) }
        case .failure(let error):
            if FolderAccess.isPermissionError(error) {
                // The retry remains an explicit user action in the single creation panel.
                CustomFileSavePanelController.shared.present(in: ticket.directory, preferences: preferences, templateID: ticket.templateID,
                    documentTemplates: documentTemplates)
            } else {
                let alert = NSAlert()
                alert.messageText = text(.createFileErrorTitle)
                alert.informativeText = (error as? DocumentTemplateError).map { text($0.textKey) } ?? error.localizedDescription
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    func openExtensionSettings() { FinderIntegrationStatus.showSettings() }
}
