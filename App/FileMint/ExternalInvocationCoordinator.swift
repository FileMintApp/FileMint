import AppKit
import Combine
import FileMintCore

enum ExternalDraftOpenResult { case presented, alreadyPresented }
@MainActor
final class ExternalPreviewReservation {
    fileprivate let id: UUID
    fileprivate weak var owner: NSWindow?
    fileprivate init(id: UUID, owner: NSWindow) { self.id = id; self.owner = owner }
}

@MainActor
final class ExternalInvocationCoordinator: ObservableObject {
    #if FILEMINT_LAUNCHER_PRODUCT_QA
    static var fixtureInstance: ExternalInvocationCoordinator?
    static var shared: ExternalInvocationCoordinator {
        guard let fixtureInstance else { preconditionFailure("Isolated launcher fixture was not initialized") }
        return fixtureInstance
    }
    #else
    static var shared: ExternalInvocationCoordinator { PreferencesModel.shared.externalInvocations }
    #endif

    @Published private(set) var lastAcceptedRequestID: UUID?
    let isSupported: Bool
    private weak var model: PreferencesModel?
    private let creation: CustomFileSavePanelController
    private let search: QuickSearchPanelController
    private let favorites: @MainActor () -> FavoriteLocationsModel
    private let isBlocked: @MainActor () -> Bool
    private let reserveOperation: @MainActor () -> (@MainActor () -> Void)?
    private let openSettings: @MainActor () -> Void
    private let diagnostic: (@MainActor (String, [String: Bool]) -> Void)?
    private var admission = ExternalDraftAdmission()
    private var pendingID: UUID?
    private var previewID: UUID?
    private var previewRelease: (@MainActor () -> Void)?
    private weak var lastExternalWindow: NSWindow?
    private weak var externalSearchWindow: NSWindow?
    private var lastFailure: (ExternalInvocationError, TimeInterval)?
    private var lastConflictFocus = -TimeInterval.infinity
    var pendingRequestCount: Int { pendingID == nil ? 0 : 1 }
    var language: AppLanguage { model?.preferences.language ?? .system }
    var templateSnapshot: [FileTemplate] { model?.committedPreferences.templates ?? [] }

    init(model: PreferencesModel, creation: CustomFileSavePanelController? = nil,
         search: QuickSearchPanelController? = nil,
         favorites: @escaping @MainActor () -> FavoriteLocationsModel = { .shared },
         isBlocked: @escaping @MainActor () -> Bool = {
            FavoriteLocationsModel.sharedHasActiveOperations || UpdateModel.shared.isCommittingInstallation
         }, reserveOperation: @escaping @MainActor () -> (@MainActor () -> Void)? = {
             FileOperationCoordinator.shared.reserveExternalPresentation()
         }, openSettings: @escaping @MainActor () -> Void = { SettingsWindowController.shared.show() },
         diagnostic: (@MainActor (String, [String: Bool]) -> Void)? = nil,
         systemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) {
        isSupported = LauncherAvailability.isSupported(on: systemVersion)
        self.model = model
        self.creation = creation ?? .shared
        self.search = search ?? .shared
        self.favorites = favorites
        self.isBlocked = isBlocked
        self.reserveOperation = reserveOperation
        self.openSettings = openSettings
        self.diagnostic = diagnostic
    }

    func openDraft(_ request: ExternalDraftRequest, source: ExternalDraftSource,
                   nativeGrantURL: URL? = nil, didClose: (@MainActor () -> Void)? = nil,
                   preview: ExternalPreviewReservation? = nil) async throws -> ExternalDraftOpenResult {
        try requireSupportedSystem()
        let pending: UUID
        var releaseOperation: (@MainActor () -> Void)?
        if let preview {
            guard source == .preview, preview.owner?.isVisible == true, pendingID == preview.id, previewID == preview.id,
                  let release = previewRelease else { throw ExternalInvocationError.busy }
            pending = preview.id
            releaseOperation = release
            previewID = nil
            previewRelease = nil
        } else {
            guard pendingID == nil else { throw ExternalInvocationError.busy }
            pending = UUID()
            pendingID = pending
        }
        defer { releaseOperation?(); if pendingID == pending { pendingID = nil } }
        let model = try await readyModel()
        try ensureAvailable(model)
        if releaseOperation == nil {
            guard let release = reserveOperation() else { throw ExternalInvocationError.busy }
            releaseOperation = release
        }
        let seed = try request.resolve(preferences: model.committedPreferences, capturedAt: Date())
        let directory: URL
        var favorite: (FavoriteLocationsModel, FavoriteLocation)?
        switch request.destination {
        case .defaultLocation, .ask: directory = model.initialCreationDirectory
        case .directory(let path): directory = URL(fileURLWithPath: path, isDirectory: true)
        case .favorite(let id):
            let catalog = favorites()
            try await waitForFavorites(catalog)
            try ensureAvailable(model)
            guard !catalog.recoveryRequired, let item = catalog.catalog.items.first(where: { $0.id == id && $0.kind == .folder }) else {
                throw ExternalInvocationError.destinationUnavailable
            }
            directory = item.url
            favorite = (catalog, item)
        }
        if let nativeGrantURL {
            guard source != .externalLink, OpenWithPolicy.isLocalFileURL(nativeGrantURL),
                  nativeGrantURL.standardizedFileURL.path == directory.standardizedFileURL.path else {
                throw ExternalInvocationError.invalidRequest
            }
        }
        let result = admission.admit(request, now: ProcessInfo.processInfo.systemUptime,
                                     hasDraft: creation.hasActiveDraft, isBusy: false)
        let session: UUID
        switch result {
        case .accepted(let id): session = id
        case .alreadyPresented(let id):
            guard creation.ownsExternalSession(id) else { throw ExternalInvocationError.unavailable }
            _ = creation.focusExistingPanel(fromExternal: true)
            lastExternalWindow = creation.externalWindow
            return .alreadyPresented
        case .existingDraft:
            creation.showExternalRequestNotice(ExternalInvocationError.existingDraft.message(language))
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastConflictFocus >= 3 {
                lastConflictFocus = now
                _ = creation.focusExistingPanel(fromExternal: true)
            }
            throw ExternalInvocationError.existingDraft
        case .busy: throw ExternalInvocationError.busy
        case .alreadyHandled: throw ExternalInvocationError.alreadyHandled
        case .conflictingRequestID: throw ExternalInvocationError.conflictingRequestID
        }
        let access = ExternalDraftDirectoryAccess(url: directory, needsSelection: request.destination == .ask,
                                                  nativeGrantURL: nativeGrantURL)
        var presented = false
        defer {
            if !presented {
                creation.closeExternalSession(session)
                if !creation.ownsExternalSession(session) {
                    access.releaseWhenIdle()
                    admission.finish(session, now: ProcessInfo.processInfo.systemUptime)
                } else { admission.markPresented(session) }
            }
        }
        try Task.checkCancellation()
        if let preview, preview.owner?.isVisible != true { throw CancellationError() }
        let context = ExternalDraftPresentation(sessionID: session, seed: seed, source: source, directory: access,
            validateTemplate: { [weak model] id in
                guard let id else { return true }
                return model?.committedPreferences.templates.contains(where: { $0.id == id && $0.isEnabled }) == true
            }, didClose: { [weak self] in
                self?.admission.finish(session, now: ProcessInfo.processInfo.systemUptime)
                didClose?()
            })
        creation.present(in: directory, preferences: model.committedPreferences,
                         documentTemplates: model.documentTemplates, external: context)
        guard creation.ownsExternalSession(session) else { throw ExternalInvocationError.existingDraft }
        lastExternalWindow = creation.externalWindow
        if let (catalog, item) = favorite {
            access.prepare(using: { try FavoriteLocationsModel.resolveDraftDirectory(item) },
                stillValid: { [weak catalog] in catalog?.catalog.items.first(where: { $0.id == item.id })?.bookmark == item.bookmark },
                didChange: { [weak self] in self?.creation.externalDirectoryDidChange(session) })
        } else {
            let preferences = model.committedPreferences
            access.prepare(using: { try FolderAccess.externalDirectory(directory, preferences: preferences) },
                didChange: { [weak self] in self?.creation.externalDirectoryDidChange(session) })
        }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !creation.externalPanelIsInteractive(session) {
            try Task.checkCancellation()
            guard pendingID == pending, creation.ownsExternalSession(session), ContinuousClock.now < deadline else {
                diagnostic?("draft-presentation-unavailable", creation.externalPanelState(session))
                throw ExternalInvocationError.unavailable
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        try Task.checkCancellation()
        admission.markPresented(session)
        presented = true
        diagnostic?("draft-presented", creation.externalPanelState(session))
        lastAcceptedRequestID = request.requestID
        return .presented
    }

    func showSearch() async throws -> ExternalSearchResult {
        try requireSupportedSystem()
        guard pendingID == nil else { return .busy }
        let pending = UUID()
        pendingID = pending
        defer { if pendingID == pending { pendingID = nil } }
        let model = try await readyModel()
        do { try ensureAvailable(model) } catch ExternalInvocationError.busy { return .busy }
        guard let releaseOperation = reserveOperation() else { return .busy }
        defer { releaseOperation() }
        let catalog = favorites()
        let result = try await search.showFromExternal(settings: model, favorites: catalog)
        if result == .shown || result == .alreadyVisible {
            lastExternalWindow = search.panel
            externalSearchWindow = search.panel
        }
        return result
    }

    func folderSnapshot() async throws -> [FavoriteLocation] {
        _ = try await readyModel()
        let catalog = favorites()
        try await waitForFavorites(catalog)
        guard !catalog.recoveryRequired else { throw ExternalInvocationError.destinationUnavailable }
        return catalog.catalog.items.filter { $0.kind == .folder }
    }

    func enabledTemplateSnapshot() async throws -> [FileTemplate] {
        let model = try await readyModel()
        return TemplateCatalog.enabledTemplates(from: model.committedPreferences.templates)
    }

    func reservePreview(ownedSheet: NSWindow, owner: NSWindow) throws -> ExternalPreviewReservation {
        try requireSupportedSystem()
        guard pendingID == nil, let model, model.isStartupReady, model.templateRecoveryError == nil else {
            throw ExternalInvocationError.busy
        }
        guard owner.attachedSheet === ownedSheet, ownedSheet.sheetParent === owner,
              ownedSheet.attachedSheet == nil,
              NSApp.modalWindow == nil || NSApp.modalWindow === ownedSheet,
              NSApp.windows.compactMap(\.attachedSheet).allSatisfy({ $0 === ownedSheet }),
              !model.hasIndependentCreationWork, !creation.hasActiveWrite, !isBlocked() else { throw ExternalInvocationError.busy }
        guard !creation.hasActiveDraft else { throw ExternalInvocationError.existingDraft }
        guard let release = reserveOperation() else { throw ExternalInvocationError.busy }
        let id = UUID()
        pendingID = id
        previewID = id
        previewRelease = release
        return ExternalPreviewReservation(id: id, owner: owner)
    }

    func cancelPreview(_ reservation: ExternalPreviewReservation) {
        guard pendingID == reservation.id, previewID == reservation.id else { return }
        pendingID = nil
        previewID = nil
        let release = previewRelease
        previewRelease = nil
        release?()
    }

    func reserveSettingsOperation() -> (@MainActor () -> Void)? {
        guard isSupported, pendingID == nil, let model, !model.hasIndependentCreationWork, !creation.hasActiveWrite, !isBlocked() else { return nil }
        return reserveOperation()
    }

    func receive(_ url: URL) {
        let invocation: ExternalInvocation
        do {
            try requireSupportedSystem()
            invocation = try ExternalDraftRoute.parse(url.absoluteString)
        }
        catch { reportURLFailure(error); return }
        Task {
            do {
                switch invocation {
                case .draft(let request): _ = try await openDraft(request, source: .externalLink)
                case .search:
                    let result = try await showSearch()
                    if result == .busy { reportURLFailure(ExternalInvocationError.busy) }
                    if result == .unavailable { reportURLFailure(ExternalInvocationError.unavailable) }
                }
            } catch { reportURLFailure(error) }
        }
    }

    func handleOrdinaryLaunch(isDefault: Bool, activationExpected: Bool) {
        guard isDefault, activationExpected else { return }
        handleReopen()
    }
    func handleReopen() {
        if let modal = NSApp.modalWindow ?? NSApp.windows.compactMap(\.attachedSheet).first {
            modal.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        if let lastExternalWindow, lastExternalWindow.isVisible {
            if lastExternalWindow === search.panel { search.focusSearch(); lastExternalWindow.makeKeyAndOrderFront(nil) }
            else { _ = creation.focusExistingPanel(fromExternal: true) }
            return
        }
        if creation.externalWindow?.isVisible == true { _ = creation.focusExistingPanel(fromExternal: true); return }
        if let externalSearchWindow, externalSearchWindow === search.panel, externalSearchWindow.isVisible {
            externalSearchWindow.makeKeyAndOrderFront(nil)
            search.focusSearch()
            return
        }
        guard pendingID == nil else { return }
        openSettings()
    }

    func reportURLFailure(_ error: Error) {
        guard !(error is CancellationError), NSApp.modalWindow == nil,
              NSApp.windows.allSatisfy({ $0.attachedSheet == nil }) else { return }
        let code = error as? ExternalInvocationError ?? .unavailable
        let now = ProcessInfo.processInfo.systemUptime
        if let lastFailure, lastFailure.0 == code, now - lastFailure.1 < 3 { return }
        lastFailure = (code, now)
        model?.lastError = code.message(language)
        if creation.hasActiveDraft { creation.showExternalRequestNotice(code.message(language)) }
        else { FavoriteFeedbackController.show(code.message(language), symbol: "exclamationmark.circle") }
    }

    private func readyModel() async throws -> PreferencesModel {
        try requireSupportedSystem()
        guard let model else { throw ExternalInvocationError.unavailable }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !model.isStartupReady {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw ExternalInvocationError.unavailable }
            try await Task.sleep(for: .milliseconds(20))
        }
        try Task.checkCancellation()
        guard model.templateRecoveryError == nil else { throw ExternalInvocationError.unavailable }
        return model
    }
    func requireSupportedSystem() throws {
        guard isSupported else { throw ExternalInvocationError.unsupportedSystemVersion }
    }
    private func waitForFavorites(_ catalog: FavoriteLocationsModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while catalog.isLoading {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw ExternalInvocationError.unavailable }
            try await Task.sleep(for: .milliseconds(20))
        }
        try Task.checkCancellation()
    }
    private func ensureAvailable(_ model: PreferencesModel) throws {
        guard NSApp.modalWindow == nil, NSApp.windows.allSatisfy({ $0.attachedSheet == nil }),
              !model.hasIndependentCreationWork, !creation.hasActiveWrite, !isBlocked() else {
            throw ExternalInvocationError.busy
        }
    }
}
