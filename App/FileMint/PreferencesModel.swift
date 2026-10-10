import AppKit
import FileMintCore
import FileMintImages
import UniformTypeIdentifiers
import Foundation
import SwiftUI

@MainActor
final class PreferencesModel: ObservableObject {
    static let shared = PreferencesModel()
    enum Pane: String, CaseIterable, Identifiable {
        case fileTypes, creation, fileTools, resourceTools, openWith, favoriteLocations, general, folders, about
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
    @Published var accessibilityTrusted = false
    @Published var hiddenItemsMessage: String?
    @Published var loginItemState: LoginItemState = .notRegistered
    @Published var loginItemError: String?
    @Published var isUpdatingLoginItem = false
    @Published var isChoosingOpenWithApp = false
    private let loginItemService = LoginItemService()
    private let store: FileMintPreferencesStore
    private let quickCreationTickets: QuickCreationTicketStore
    let documentTemplates: DocumentTemplateStore
    @Published var isImportingDocument = false
    private let folderAccess = FolderAccess()
    private var preferenceObserver: NSObjectProtocol?
    private var isImportingSettings = false
    private(set) var openingGate = CreationOpeningGate(enabled: false)
    private(set) var committedPreferences: FileMintPreferences = .default
    lazy var postCreationExecutor = PostCreationActionExecutor(gate: { [weak self] in self?.openingGate ?? .init(enabled: false) })
    var hasTemplateModalWork = false
    @Published var packageReview: TemplatePackageReview?
    @Published var isValidatingPackage = false
    private var packageValidationTask: Task<Void, Never>?
    @Published var isMutatingTemplates = false
    var templateRecoveryError: String?
    var templateMutationAllowed: Bool { !isMutatingTemplates && templateRecoveryError == nil }

    func workflowText(_ key: TemplateWorkflowText) -> String { key.text(preferences.language) }
    func creationSnapshot(template: FileTemplate?, selection: CreationActionSelection, temporaryApplication: CreationApplication? = nil) -> CreationFollowUp {
        var snapshot = committedPreferences
        if let temporaryApplication { snapshot.creationApplications.append(temporaryApplication) }
        return .init(selection: selection, template: template, preferences: snapshot, gate: openingGate)
    }
    func setCreationFeature(opening: Bool? = nil, preview: Bool? = nil) {
        let previous = preferences
        if let opening { preferences.creationOpeningEnabled = opening }
        if let preview { preferences.templatePreviewEnabled = preview }
        if !save() { preferences = previous }
    }
    func chooseCreationApplication() async throws -> CreationApplication? {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.applicationBundle]
        picker.canChooseDirectories = false; picker.allowsMultipleSelection = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        picker.title = workflowText(.chooseApp)
        guard picker.runModal() == .OK, let url = picker.url else { return nil }
        pendingCreationWork += 1
        defer { pendingCreationWork -= 1 }
        let app = try await Task.detached { try OpenWithApplicationAccess.capture(url) }.value
        return .init(id: app.id, hint: .init(bundleIdentifier: app.bundleIdentifier, displayName: app.name), url: app.url, bookmark: app.bookmark)
    }
    private func commitFeatureState() {
        committedPreferences = preferences
        openingGate.commit(enabled: preferences.creationOpeningEnabled)
        CustomFileSavePanelController.shared.updateFeatures(preferences)
    }
    private func configureCreationPanel() {
        CustomFileSavePanelController.shared.loadApplicationIcon = { application in
            await CreationApplicationPresentation.icon(for: application)
        }
        CustomFileSavePanelController.shared.makeDocumentPreview = { template, assets, language in
            let surface = TemplatePreviewSurface()
            surface.show(template, assets: assets, language: language, capturedAt: CreationContentResolver.exampleDate)
            return (surface, { surface.close() })
        }
        CustomFileSavePanelController.shared.snapshotFollowUp = { [weak self] template, selection, application in
            self?.creationSnapshot(template: template, selection: selection, temporaryApplication: application)
        }
        CustomFileSavePanelController.shared.completeCreation = { [weak self] result, followUp, language in
            guard let self, let followUp else { return }
            await self.postCreationExecutor.complete(result, followUp: followUp, language: language)
        }
        CustomFileSavePanelController.shared.chooseApplication = { [weak self] in
            try await self?.chooseCreationApplication()
        }
    }

    init(store: FileMintPreferencesStore = FileMintPreferencesStore(), documentTemplates: DocumentTemplateStore = DocumentTemplateStore(),
         quickCreationTickets: QuickCreationTicketStore = QuickCreationTicketStore()) {
        self.store = store
        self.quickCreationTickets = quickCreationTickets
        self.documentTemplates = documentTemplates
        let loaded = store.loadWithStatus()
        preferences = loaded.preferences
        committedPreferences = loaded.preferences
        openingGate = .init(enabled: loaded.preferences.creationOpeningEnabled)
        configureCreationPanel()
        if loaded.requiresRecovery {
            lastError = FileMintStrings.text(.preferencesRecoveryRequired, language: loaded.preferences.language)
        }
        applyAppearance()
        folderAccess.restore(preferences)
        refreshStatus()
        templateRecoveryError = workflowText(.recoveryNeeded)
        Task { await recoverTemplateTransactions() }
        preferenceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let loaded = self.store.load()
                guard loaded != self.preferences else { return }
                self.preferences = loaded
                self.commitFeatureState()
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
        let trusted = FinderHiddenItemsService.isAuthorized
        if trusted != accessibilityTrusted { hiddenItemsMessage = nil }
        accessibilityTrusted = trusted
        loginItemState = loginItemService.state
        guard loginItemService.isInstalled, preferences.hasAttemptedLoginItemSetup,
              !isUpdatingLoginItem, loginItemError == nil else { return }
        let actual = loginItemState == .enabled || loginItemState == .requiresApproval
        if preferences.launchAtLogin != actual {
            preferences.launchAtLogin = actual
            save()
        }
    }

    func toggleFinderHiddenItems() {
        Task { @MainActor in
            let outcome = await FinderHiddenItemsService.toggle()
            accessibilityTrusted = FinderHiddenItemsService.isAuthorized
            switch outcome {
            case .needsAuthorization:
                hiddenItemsMessage = text(.hiddenItemsAuthorizeHint)
                SettingsWindowController.shared.show(pane: .folders)
            case .sent:
                hiddenItemsMessage = text(.hiddenItemsSent)
            case .finderUnavailable:
                hiddenItemsMessage = text(.hiddenItemsUnavailable)
                SettingsWindowController.shared.show(pane: .folders)
            }
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
        // EndpointSecurity/ESClient.h documents this pane URL for macOS 13+.
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    @discardableResult
    func save(recoveringInvalidFile: Bool = false, allowingTemplateMutation: Bool = false) -> Bool {
        if isMutatingTemplates && !allowingTemplateMutation {
            preferences = committedPreferences
            lastError = workflowText(.settingsBusy)
            return false
        }
        if !allowingTemplateMutation && (isMutatingTemplates || templateRecoveryError != nil) && preferences.templates != committedPreferences.templates {
            lastError = workflowText(.recoveryNeeded); return false
        }
        do {
            preferences.normalizeCreationMenuPlacements()
            preferences.defaultTemplateIDs = TemplateCatalog.validDefaults(preferences.defaultTemplateIDs, in: preferences.templates)
            try store.save(preferences, recoveringInvalidFile: recoveringInvalidFile,
                           ifUnchangedFrom: recoveringInvalidFile ? nil : committedPreferences)
            DistributedNotificationCenter.default().post(
                name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil
            )
            commitFeatureState()
            lastError = nil
            return true
        } catch {
            if error as? FileMintPreferencesStoreError == .stalePreferences {
                // Let callers finish rolling back their controls before adopting
                // a newer snapshot written by another preferences entry point.
                Task {
                    guard !isMutatingTemplates else { return }
                    let loaded = store.loadWithStatus()
                    guard !loaded.requiresRecovery else { return }
                    preferences = loaded.preferences; commitFeatureState()
                    folderAccess.restore(preferences)
                }
            }
            lastError = error.localizedDescription
            return false
        }
    }

    func preferenceBinding<Value>(_ keyPath: WritableKeyPath<FileMintPreferences, Value>) -> Binding<Value> {
        Binding(get: { self.preferences[keyPath: keyPath] }, set: { value in
            let previous = self.preferences
            self.preferences[keyPath: keyPath] = value
            if !self.save() { self.preferences = previous }
        })
    }

    func templatePlacementBinding(for id: String) -> Binding<CreationMenuPlacement> {
        Binding(get: { self.preferences.templateMenuPlacement(for: id) }, set: { value in
            guard self.templateMutationAllowed, self.preferences.templates.contains(where: { $0.id == id }) else { return }
            let previous = self.preferences
            self.preferences.templateMenuPlacements[id] = value
            if !self.save() { self.preferences = previous }
        })
    }

    func menuIconBinding(for slot: MenuIconSlot) -> Binding<MenuIconCustomization?> {
        Binding(
            get: { self.preferences.menuIcons[slot.rawValue] },
            set: { value in
                let previous = self.preferences
                self.preferences.menuIcons[slot.rawValue] = value
                if !self.save() { self.preferences = previous }
            }
        )
    }

    func resetTemplates() {
        let previous = preferences
        guard templateMutationAllowed else { return }
        preferences.templates = TemplateCatalog.restoringBuiltIns(in: preferences.templates, revealAfterCreation: preferences.revealAfterCreation)
        preferences.removedBuiltInTemplateIDs = []
        for template in TemplateCatalog.builtInTemplates { preferences.templateMenuPlacements[template.id] = .submenu }
        isMutatingTemplates = true
        guard save(allowingTemplateMutation: true) else { preferences = previous; isMutatingTemplates = false; return }
        let removed = previous.templates.compactMap(\.document).filter { document in
            document.builtInResource == nil && !preferences.templates.contains { $0.document?.id == document.id }
        }
        let assets = documentTemplates
        pendingCreationWork += 1
        Task {
            defer { isMutatingTemplates = false; pendingCreationWork -= 1 }
            for document in Dictionary(removed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values {
                do { try await Task.detached(priority: .utility) { try assets.remove(document) }.value }
                catch { lastError = text(.documentUnavailable) }
            }
        }
    }

    func moveTemplates(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard templateMutationAllowed else { return }
        let previous = preferences
        preferences.templates = TemplateCatalog.reorderedTemplates(preferences.templates, moving: source, to: destination)
        if !save() { preferences = previous }
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

    func saveType(name: String, suffix: String, content: String, id: String?, suggestedFileName: String? = nil,
                  customMenuIcon: MenuIconCustomization?, copy: FileTemplate? = nil, sourceID: String? = nil,
                  action: TemplateCreationAction? = nil, application: CreationApplication? = nil,
                  menuPlacement: CreationMenuPlacement? = nil) async throws {
        guard templateMutationAllowed else { throw TemplateTransactionError.recoveryRequired }
        isMutatingTemplates = true; pendingCreationWork += 1
        defer { isMutatingTemplates = false; pendingCreationWork -= 1 }
        let original = id.flatMap { id in preferences.templates.first { $0.id == id } }
        let document = copy?.document ?? original?.document
        if let document {
            guard suffix.lowercased() == document.kind.rawValue else { throw DocumentTemplateError.unsupported }
            let assets = documentTemplates
            _ = try await Task.detached { try assets.data(for: document) }.value
        }
        let previous = preferences
        var type = try TemplateCatalog.customTemplate(name: name, fileExtension: suffix, content: document == nil ? content : "",
            id: copy?.id ?? id, in: preferences.templates, suggestedFileName: suggestedFileName,
            replacingFileExtension: copy?.fileExtension)
        type.document = document; type.customMenuIcon = customMenuIcon
        type.group = copy?.group ?? original?.group ?? "Custom"
        type.afterCreation = action ?? copy?.afterCreation ?? original?.afterCreation ?? .basic(reveal: preferences.revealAfterCreation)
        try type.afterCreation?.validate()
        if let application, type.afterCreation?.kind == .openWithApplication, type.afterCreation?.localApplicationID == application.id {
            if let existing = preferences.creationApplications.first(where: { $0.hint.bundleIdentifier == application.hint.bundleIdentifier && $0.url == application.url }) {
                type.afterCreation = .init(.openWithApplication, application: existing.hint, localApplicationID: existing.id)
                if let index = preferences.creationApplications.firstIndex(where: { $0.id == existing.id }) {
                    preferences.creationApplications[index].url = application.url
                    preferences.creationApplications[index].bookmark = application.bookmark
                }
            } else { preferences.creationApplications.append(application) }
        }
        if copy != nil { preferences = TemplateCatalog.preferencesInsertingCopy(type, after: sourceID, in: preferences) }
        else if let index = preferences.templates.firstIndex(where: { $0.id == type.id }) { preferences.templates[index] = type }
        else { preferences.templates.append(type) }
        preferences.templateMenuPlacements[type.id] = menuPlacement ?? preferences.templateMenuPlacement(for: type.id)
        guard save(allowingTemplateMutation: true) else { preferences = previous; throw CocoaError(.fileWriteUnknown) }
    }

    func removeType(_ id: String) {
        guard templateMutationAllowed, preferences.templates.contains(where: { $0.id == id }) else { return }
        let previous = preferences
        let document = preferences.templates.first { $0.id == id }?.document
        preferences.templates.removeAll { $0.id == id }
        if TemplateCatalog.builtInTemplates.contains(where: { $0.id == id }) {
            preferences.removedBuiltInTemplateIDs = Array(Set(preferences.removedBuiltInTemplateIDs + [id])).sorted()
        }
        isMutatingTemplates = true
        guard save(allowingTemplateMutation: true) else { preferences = previous; isMutatingTemplates = false; return }
        pendingCreationWork += 1
        let assets = documentTemplates
        let removeAsset = document.flatMap { doc in preferences.templates.contains { $0.document?.id == doc.id } ? nil : doc }
        Task {
            defer { isMutatingTemplates = false; pendingCreationWork -= 1 }
            if let removeAsset {
                do { try await Task.detached(priority: .utility) { try assets.remove(removeAsset) }.value }
                catch { lastError = text(.documentUnavailable) }
            }
        }
    }

    func setDefaultTemplate(_ template: FileTemplate) {
        guard templateMutationAllowed, template.isEnabled else { return }
        let previous = preferences
        preferences.defaultTemplateIDs[template.fileExtension.lowercased()] = template.id
        if !save() { preferences = previous }
    }

    func isDefaultTemplate(_ template: FileTemplate) -> Bool {
        TemplateCatalog.defaultTemplate(forExtension: template.fileExtension, in: preferences.templates,
            defaults: preferences.defaultTemplateIDs)?.id == template.id
    }

    func importDocumentTemplate() {
        guard !isImportingDocument, templateMutationAllowed else { return }
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
        guard !isImportingDocument, templateMutationAllowed else { return }
        isImportingDocument = true
        isMutatingTemplates = true
        pendingCreationWork += 1
        let access = source.startAccessingSecurityScopedResource()
        defer {
            if access { source.stopAccessingSecurityScopedResource() }
            isImportingDocument = false
            isMutatingTemplates = false
            pendingCreationWork -= 1
        }
        let assets = documentTemplates
        do {
            let reference = try await Task.detached(priority: .userInitiated) { try assets.importDocument(at: source) }.value
            let rank: Int
            do { rank = try TemplateCatalog.nextRank(in: preferences.templates) }
            catch {
                _ = await Task.detached(priority: .utility) { try? assets.remove(reference) }.value
                throw error
            }
            let previous = preferences
            var template = FileTemplate(id: "document-\(reference.id.uuidString)", displayName: source.deletingPathExtension().lastPathComponent,
                suggestedFileName: source.lastPathComponent, group: "Custom", content: "",
                rank: rank, fileExtension: reference.kind.rawValue)
            template.document = reference
            template.afterCreation = .basic(reveal: preferences.revealAfterCreation)
            preferences.templates.append(template)
            if !save(allowingTemplateMutation: true) {
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
        if CustomFileSavePanelController.shared.focusExistingPanel() || isPreparingCreation { return }
        isPreparingCreation = true
        pendingCreationWork += 1
        defer { isPreparingCreation = false; pendingCreationWork -= 1 }
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
        guard !isImportingSettings, !isMutatingTemplates else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isImportingSettings = true
        Task { await importSettings(from: url) }
    }

    private func importSettings(from url: URL) async {
        guard !isMutatingTemplates else { isImportingSettings = false; return }
        isMutatingTemplates = true; pendingCreationWork += 1
        defer { isImportingSettings = false; isMutatingTemplates = false; pendingCreationWork -= 1 }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let attemptedHere = preferences.hasAttemptedLoginItemSetup
            let imported = try await Task.detached(priority: .userInitiated) {
                try FileMintPreferencesStore.decodeFile(at: url)
            }.value
            let previous = preferences
            preferences = imported
            preferences.hasAttemptedLoginItemSetup = attemptedHere
            let launchAtLogin = preferences.launchAtLogin
            guard save(recoveringInvalidFile: true, allowingTemplateMutation: true) else { preferences = previous; return }
            folderAccess.restore(preferences)
            Task { await setLaunchAtLogin(launchAtLogin) }
            Task { await recoverTemplateTransactions() }
        } catch { lastError = error.localizedDescription }
    }

    private var pendingCreationWork = 0
    var pendingCreationCount: Int { pendingCreationWork + postCreationExecutor.activeCount + (hasTemplateModalWork ? 1 : 0) }
    private var isPreparingCreation = false

    func newFileFromClipboard() {
        presentClipboardText(in: nil)
    }

    func presentClipboardText(in directory: URL?, pasteboard: NSPasteboard = .general) {
        guard !CustomFileSavePanelController.shared.focusExistingPanel(), !isPreparingCreation else { return }
        isPreparingCreation = true
        pendingCreationWork += 1
        defer { isPreparingCreation = false; pendingCreationWork -= 1 }
        do {
            let content = try ClipboardTextReader.capture(from: pasteboard)
            var destination = directory
            if destination == nil {
                let picker = NSOpenPanel()
                picker.canChooseFiles = false
                picker.canChooseDirectories = true
                picker.allowsMultipleSelection = false
                picker.canCreateDirectories = true
                picker.title = text(.saveLocation)
                picker.prompt = text(.newFileFromClipboard)
                picker.directoryURL = preferences.monitoredFolderURLs.first
                NSApp.activate(ignoringOtherApps: true)
                guard picker.runModal() == .OK, let selected = picker.url else { return }
                try FolderAccess.remember(selected, in: &preferences)
                save()
                folderAccess.restore(preferences)
                destination = selected
            }
            guard let destination, !CustomFileSavePanelController.shared.focusExistingPanel() else { return }
            CustomFileSavePanelController.shared.present(in: destination, preferences: preferences,
                initialText: content, documentTemplates: documentTemplates)
        } catch {
            let key: FileMintTextKey
            switch error {
            case ClipboardTextError.tooLarge: key = .clipboardTextTooLarge
            case ClipboardTextError.unsupported: key = .clipboardTextUnsupported
            default: key = .noClipboardText
            }
            let alert = NSAlert()
            alert.messageText = text(.newFileFromClipboard)
            alert.informativeText = text(key)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    func pasteImageFile() {
        guard !isPreparingCreation, !CustomFileSavePanelController.shared.focusExistingPanel() else { return }
        let directory = preferences.monitoredFolderURLs.first ?? FileManager.default.homeDirectoryForCurrentUser
        Task { await presentClipboardImage(in: directory) }
    }

    func presentClipboardImage(in directory: URL, pasteboard: NSPasteboard = .general) async {
        guard !isPreparingCreation, !CustomFileSavePanelController.shared.focusExistingPanel() else { return }
        isPreparingCreation = true
        pendingCreationWork += 1
        defer { isPreparingCreation = false; pendingCreationWork -= 1 }
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
        pendingCreationWork += 1
        Task {
            defer { pendingCreationWork -= 1 }
            do {
                let snapshot = committedPreferences
                let originalGate = openingGate
                let tickets = quickCreationTickets
                let ticket = try await Task.detached(priority: .userInitiated) {
                    try tickets.consume(url, preferences: snapshot)
                }.value
                guard let ticket, let intent = ticket.resolvedIntent else { return }
                let originalFollowUp = CreationFollowUp(template: snapshot.templates.first { $0.id == ticket.templateID }, preferences: snapshot, gate: originalGate)
                if FolderScope.directoryAccess(ticket.directory, in: preferences.monitoredFolderURLs) == .requiresAuthorization {
                    if CustomFileSavePanelController.shared.focusExistingPanel() { return }
                    guard authorizeQuickCreationDirectory(ticket.directory) else { return }
                    if intent == .template {
                        guard preferences.templates.contains(where: { $0.id == ticket.templateID && $0.isEnabled }) else { return }
                        // Permission recovery still requires Create in the draft;
                        // accepting a folder prompt alone never writes a file.
                        CustomFileSavePanelController.shared.present(in: ticket.directory, preferences: preferences,
                            templateID: ticket.templateID, initialFollowUp: originalFollowUp, documentTemplates: documentTemplates)
                        return
                    }
                }
                guard FolderScope.directoryAccess(ticket.directory, in: preferences.monitoredFolderURLs) == .allowed else { return }
                switch ticket.resolvedIntent {
                case .clipboardImage: await presentClipboardImage(in: ticket.directory)
                case .clipboardText: presentClipboardText(in: ticket.directory)
                case .template: await quickCreate(ticket, originalFollowUp: originalFollowUp)
                case nil: break
                }
            } catch { lastError = error.localizedDescription }
        }
    }

    private func authorizeQuickCreationDirectory(_ directory: URL) -> Bool {
        guard !isPreparingCreation else { return false }
        isPreparingCreation = true
        defer { isPreparingCreation = false }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.canCreateDirectories = false
        picker.directoryURL = directory
        picker.message = text(.authorizeFolderHint)
        picker.prompt = text(.allowFolder)
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let chosen = picker.url else { return false }
        let granted = chosen.startAccessingSecurityScopedResource()
        defer { if granted { chosen.stopAccessingSecurityScopedResource() } }
        guard chosen.resolvingSymlinksInPath().standardizedFileURL == directory.resolvingSymlinksInPath().standardizedFileURL,
              FolderScope.directoryAccess(directory, in: preferences.monitoredFolderURLs) == .allowed else {
            let alert = NSAlert()
            alert.messageText = text(.createFileErrorTitle)
            alert.informativeText = text(.moveChooseExactFolder)
            alert.runModal()
            return false
        }
        let previous = preferences
        do {
            try FolderAccess.remember(chosen, in: &preferences)
            guard save() else {
                preferences = previous
                showCreationFailure(lastError ?? text(.preferencesRecoveryRequired))
                return false
            }
            folderAccess.restore(preferences)
            return true
        } catch {
            preferences = previous
            lastError = error.localizedDescription
            showCreationFailure(error.localizedDescription)
            return false
        }
    }

    private func quickCreate(_ ticket: QuickCreationTicket, originalFollowUp: CreationFollowUp? = nil) async {
        guard let template = TemplateCatalog.template(withID: ticket.templateID, in: preferences.templates),
              template.isEnabled,
              FolderScope.containsResolvedDirectory(ticket.directory, in: preferences.monitoredFolderURLs) else { return }
        let request = FileCreationRequest(destinationDirectory: ticket.directory, template: template,
                                           collisionStrategy: preferences.collisionStrategy == .replace ? .increment : preferences.collisionStrategy, capturedAt: Date())
        let followUp = originalFollowUp ?? creationSnapshot(template: template, selection: .followTemplate)
        let accessed = ticket.directory.startAccessingSecurityScopedResource()
        defer { if accessed { ticket.directory.stopAccessingSecurityScopedResource() } }
        let assets = documentTemplates
        let result = await Task.detached(priority: .userInitiated) {
            Result { try FileCreationService(documentTemplates: assets).createFile(request) }
        }.value
        switch result {
        case .success(let created):
            await postCreationExecutor.complete(created, followUp: followUp, language: preferences.language)
        case .failure(let error):
            if FolderAccess.isPermissionError(error) {
                // The retry remains an explicit user action in the single creation panel.
                CustomFileSavePanelController.shared.present(in: ticket.directory, preferences: preferences, templateID: ticket.templateID,
                    initialFollowUp: followUp, capturedAt: request.capturedAt, templateSnapshot: template,
                    documentTemplates: documentTemplates)
            } else {
                showCreationFailure((error as? DocumentTemplateError).map { text($0.textKey) } ?? error.localizedDescription)
            }
        }
    }

    private func showCreationFailure(_ message: String) {
        let alert = NSAlert()
        alert.messageText = text(.createFileErrorTitle)
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func openExtensionSettings() { FinderIntegrationStatus.showSettings() }
}

extension PreferencesModel {
    private var templateTransaction: TemplateImportTransaction {
        let location = store.location ?? FileMintStorage.directory.appendingPathComponent("preferences.json")
        return .init(journalURL: location.deletingLastPathComponent().appendingPathComponent("template-import-journal.json"),
            preferencesURL: location, assets: documentTemplates)
    }
    func recoverTemplateTransactions() async {
        guard !isMutatingTemplates else { return }
        isMutatingTemplates = true; pendingCreationWork += 1
        defer { isMutatingTemplates = false; pendingCreationWork -= 1 }
        let transaction = templateTransaction
        do {
            try await Task.detached(priority: .utility) { try transaction.recover() }.value
            let loaded = store.loadWithStatus()
            if loaded.requiresRecovery { templateRecoveryError = text(.preferencesRecoveryRequired) }
            else {
                preferences = loaded.preferences; commitFeatureState()
                templateRecoveryError = nil
            }
        } catch { templateRecoveryError = workflowText(.recoveryNeeded); lastError = templateRecoveryError }
    }
    func importTemplatePackage() {
        guard templateMutationAllowed, packageReview == nil else { return }
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [UTType(exportedAs: "io.github.daigua.filemint.templates", conformingTo: .zip)]
        picker.canChooseDirectories = false; picker.allowsMultipleSelection = false; picker.resolvesAliases = false
        picker.title = workflowText(.importPackage)
        guard picker.runModal() == .OK, let source = picker.url else { return }
        packageValidationTask = Task { await importTemplatePackage(from: source) }
    }
    func cancelTemplatePackageValidation() { packageValidationTask?.cancel() }
    func importTemplatePackage(from source: URL) async {
        guard templateMutationAllowed, packageReview == nil else { return }
        isMutatingTemplates = true; isValidatingPackage = true; pendingCreationWork += 1
        let granted = source.startAccessingSecurityScopedResource()
        defer {
            if granted { source.stopAccessingSecurityScopedResource() }
            pendingCreationWork -= 1; isMutatingTemplates = false; isValidatingPackage = false
            packageValidationTask = nil
        }
        do {
            let worker = Task.detached(priority: .userInitiated) {
                try TemplatePackageCodec.decode(TemplatePackageCodec.read(at: source))
            }
            let package = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
            try Task.checkCancellation()
            let plan = try await makeTemplatePlan(package)
            try Task.checkCancellation()
            packageReview = TemplatePackageReview(package: package, plan: plan)
        } catch is CancellationError { lastError = nil }
        catch { lastError = templateErrorText(error, fallback: .importFailed) }
    }
    private func makeTemplatePlan(_ package: ValidatedTemplatePackage, choices: [String: TemplateImportChoice] = [:],
                                  adoptDefaults: Bool = false) async throws -> TemplateImportPlan {
        let snapshot = committedPreferences, suffix = workflowText(.copySuffix)
        return try await Task.detached(priority: .userInitiated) {
            var validated = Set<UUID>()
            if snapshot.creationOpeningEnabled {
                let hints = package.templates.compactMap { $0.afterCreation.application }
                for app in snapshot.creationApplications where hints.contains(app.hint) {
                    if let url = try? OpenWithApplicationAccess.resolve(app.openWithApplication) {
                        let granted = url.startAccessingSecurityScopedResource()
                        defer { if granted { url.stopAccessingSecurityScopedResource() } }
                        if (try? OpenWithApplicationAccess.validate(app.openWithApplication, at: url)) != nil { validated.insert(app.id) }
                    }
                }
            }
            return try TemplateImportPlanner.plan(package, into: snapshot, choices: choices,
                adoptDefaults: adoptDefaults, copySuffix: suffix, validatedApplicationIDs: validated)
        }.value
    }
    func rebuildTemplateReview(_ review: TemplatePackageReview) {
        review.generation = UUID(); let generation = review.generation
        review.isPlanValid = false
        review.isPlanning = true
        Task {
            do {
                let plan = try await makeTemplatePlan(review.package, choices: review.choices, adoptDefaults: review.adoptDefaults)
                guard review.generation == generation else { return }
                review.plan = plan
                review.choices = Dictionary(uniqueKeysWithValues: plan.rows.map { ($0.id, $0.choice) })
                review.isPlanValid = true
                review.message = nil
                review.isPlanning = false
            } catch {
                guard review.generation == generation else { return }
                review.message = templateErrorText(error, fallback: .importFailed); review.isPlanning = false
            }
        }
    }
    func confirmTemplateImport(_ review: TemplatePackageReview) async {
        guard templateMutationAllowed, review.canConfirm, packageReview?.id == review.id else { return }
        let loaded = store.loadWithStatus()
        guard !loaded.requiresRecovery else { templateRecoveryError = text(.preferencesRecoveryRequired); return }
        do {
            if try TemplateImportPlanner.revision(loaded.preferences) != review.plan.baseRevision {
                preferences = loaded.preferences; commitFeatureState()
                review.message = workflowText(.staleReview); rebuildTemplateReview(review); return
            }
            isMutatingTemplates = true; pendingCreationWork += 1
            defer { isMutatingTemplates = false; pendingCreationWork -= 1 }
            let transaction = templateTransaction, plan = review.plan
            let receipt = try await Task.detached(priority: .userInitiated) { try transaction.commit(plan) }.value
            let current = store.loadWithStatus()
            preferences = current.requiresRecovery ? receipt.preferences : current.preferences
            commitFeatureState()
            DistributedNotificationCenter.default().post(name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil)
            packageReview = nil
            templateRecoveryError = receipt.cleanupPending ? workflowText(.cleanupPending) : nil
            lastError = templateRecoveryError
        } catch TemplateTransactionError.staleReview {
            let loaded = store.loadWithStatus()
            guard !loaded.requiresRecovery else { templateRecoveryError = text(.preferencesRecoveryRequired); return }
            preferences = loaded.preferences; commitFeatureState()
            review.message = workflowText(.staleReview); rebuildTemplateReview(review)
        } catch {
            review.message = templateErrorText(error, fallback: .importFailed)
            if error as? TemplateTransactionError == .recoveryRequired { templateRecoveryError = workflowText(.recoveryNeeded) }
        }
    }
    func exportTemplatePackage(ids: Set<String>) async {
        guard templateMutationAllowed else { return }
        let selected = committedPreferences.templates.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { lastError = workflowText(.noSelection); return }
        isMutatingTemplates = true; pendingCreationWork += 1
        defer { isMutatingTemplates = false; pendingCreationWork -= 1 }
        let picker = NSSavePanel()
        picker.title = workflowText(.exportSelection); picker.nameFieldStringValue = "Templates.filemint-templates"
        picker.allowedContentTypes = [UTType(exportedAs: "io.github.daigua.filemint.templates", conformingTo: .zip)]; picker.allowsOtherFileTypes = false; picker.canCreateDirectories = true
        guard picker.runModal() == .OK, let target = picker.url else { return }
        let granted = target.startAccessingSecurityScopedResource()
        defer { if granted { target.stopAccessingSecurityScopedResource() } }
        let assets = documentTemplates, defaults = committedPreferences.defaultTemplateIDs
        do {
            try await Task.detached(priority: .userInitiated) {
                let bytes = try TemplatePackageCodec.encode(templates: selected, defaults: defaults, assets: assets)
                try Task.checkCancellation()
                try TemplatePackageCodec.write(bytes, to: target)
            }.value
            lastError = nil
        } catch { lastError = templateErrorText(error, fallback: .exportFailed) }
    }
    private func templateErrorText(_ error: Error, fallback: TemplateWorkflowText) -> String {
        if let error = error as? TemplatePackageError { return workflowText(error.textKey) }
        if let error = error as? DocumentTemplateError { return text(error.textKey) }
        if let error = error as? TemplateTransactionError {
            return workflowText(error == .staleReview ? .staleReview : error == .cleanupPending ? .cleanupPending : .recoveryNeeded)
        }
        return workflowText(fallback)
    }
}
