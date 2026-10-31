import AppKit
import Combine
import FileMintCore
import SwiftUI

enum IntegrationTool: String, CaseIterable { case shortcuts, raycast, url }
enum IntegrationScenario: Equatable { case projectNote, workflowText, quickSearch, custom }
enum IntegrationLocation: String, CaseIterable { case defaultLocation, directory, favorite, ask }
enum IntegrationNameMode: String, CaseIterable { case runtime, fixed, automatic }
enum IntegrationBodyMode: String, CaseIterable { case templateDefault, text, empty }

struct IntegrationConfiguration: Equatable {
    let id = UUID()
    var scenario: IntegrationScenario = .projectNote
    var tool: IntegrationTool = .raycast
    var title = ""
    var templateID: String?
    var location: IntegrationLocation = .defaultLocation
    var directory: URL?
    var favoriteID: UUID?
    var requestID: UUID?
    var nameMode: IntegrationNameMode = .runtime
    var fileName = ""
    var bodyMode: IntegrationBodyMode = .templateDefault
    var text = ""
    var advanced = false
}

@MainActor
final class IntegrationsModel: NSObject, ObservableObject, NSWindowDelegate {
    let settings: PreferencesModel
    let favorites: FavoriteLocationsModel
    let scripts: LauncherScriptsModel
    @Published var config = IntegrationConfiguration() {
        didSet { error = nil; testReceived = false; testNonce = nil }
    }
    @Published var error: (field: String, message: String)?
    @Published private(set) var guide: IntegrationTool?
    @Published private(set) var savedURL: URL?
    @Published private(set) var isExporting = false
    @Published private(set) var testReceived = false
    @Published var previewFocus = UUID()
    @Published private(set) var editingScript: LauncherScriptEdit?
    private weak var owner: NSWindow?
    private var generator: NSWindow?
    private var sessionID: UUID?
    private var previewReservation: ExternalPreviewReservation?
    private var previewTask: Task<Void, Never>?
    private var restoreAfterPreview = false
    private var previewIsOpen = false
    private var focusPreviewOnKey = false
    private var testNonce: UUID?
    private var observations: [NSObjectProtocol] = []
    private var received: AnyCancellable?
    var language: AppLanguage { settings.preferences.language }
    var runtime: ExternalInvocationCoordinator { settings.externalInvocations }
    var isSupported: Bool { runtime.isSupported }
    var templates: [FileTemplate] { TemplateCatalog.enabledTemplates(from: settings.committedPreferences.templates) }
    var folderFavorites: [FavoriteLocation] { favorites.catalog.items.filter { $0.kind == .folder } }
    var scheme: String {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        return (types?.first?["CFBundleURLSchemes"] as? [String])?.first ?? "filemint"
    }

    init(settings: PreferencesModel, favorites: FavoriteLocationsModel) {
        self.settings = settings
        self.favorites = favorites
        scripts = LauncherScriptsModel(store: settings.launcherScriptStore, language: { [weak settings] in
            settings?.preferences.language ?? .system
        })
        super.init()
        received = runtime.$lastAcceptedRequestID.sink { [weak self] id in
            Task { @MainActor in
                guard let self, let id, id == self.testNonce, self.sessionID != nil else { return }
                self.testReceived = true
            }
        }
        for name in [NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification, NSWindow.didEndSheetNotification] {
            observations.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.restoreGeneratorIfPossible() }
            })
        }
        observations.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            let closing = note.object as? NSWindow
            Task { @MainActor in
                guard let self, closing === self.owner else { return }
                self.cancelConfiguration()
                self.owner = nil
            }
        })
    }

    func text(_ english: String, _ chinese: String) -> String { language.resolved() == .chinese ? chinese : english }
    func attachOwner(_ window: NSWindow) { owner = window }

    func start(_ scenario: IntegrationScenario, tool: IntegrationTool) {
        guard isSupported else { show(.unsupportedSystemVersion); return }
        guard !isExporting, let owner, owner.isVisible, owner.attachedSheet == nil,
              NSApp.modalWindow == nil else { show(.busy); return }
        cancelConfiguration()
        var value = IntegrationConfiguration()
        value.scenario = scenario
        value.tool = tool
        value.title = scenario == .quickSearch ? text("Show FileMint Quick Search", "显示 FileMint 快捷搜索")
            : text("New Project Note", "新建项目笔记")
        value.templateID = templates.first { $0.id == "markdown" && $0.document == nil }?.id
        value.fileName = text("Project Note", "项目笔记")
        value.nameMode = tool == .raycast ? .runtime : .fixed
        if scenario == .workflowText { value.bodyMode = .text; value.text = text("Text from an earlier workflow action.\n", "工作流上一步生成的文本。\n") }
        config = value
        sessionID = value.id
        if tool == .shortcuts { guide = .shortcuts }
        else { showGenerator() }
    }

    private func showGenerator(focusPreview: Bool = false) {
        guard isSupported else { show(.unsupportedSystemVersion); return }
        guard let owner, owner.isVisible, owner.attachedSheet == nil, NSApp.modalWindow == nil,
              let sessionID, sessionID == config.id else { show(.busy); return }
        let window: NSWindow
        if let generator { window = generator }
        else {
            let screen = owner.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 750)
            let size = NSSize(width: min(680, screen.width - 40), height: min(650, screen.height - 70))
            window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = editingScript == nil ? text("Create Launcher Command", "创建启动命令") : text("Edit Launcher Command", "编辑启动命令")
            window.contentMinSize = NSSize(width: min(600, size.width), height: min(500, size.height))
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.tabbingMode = .disallowed
            window.backgroundColor = FileMintStyle.backgroundNS
            window.contentView = NSHostingView(rootView: LauncherGeneratorView(state: self))
            window.delegate = self
            generator = window
        }
        guide = nil
        focusPreviewOnKey = focusPreview
        owner.beginSheet(window) { [weak self] _ in
            Task { @MainActor in self?.generatorDidEnd(session: sessionID) }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === generator, focusPreviewOnKey else { return }
        focusPreviewOnKey = false
        let session = sessionID
        // Let AppKit install the sheet's initial responder before SwiftUI moves
        // focus to Preview. Initial presentation still starts in the first field.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.sessionID == session,
                  window.sheetParent === self.owner, window.isKeyWindow else { return }
            self.previewFocus = UUID()
        }
    }

    func returnToEditor() { error = nil; showGenerator() }

    func request() throws -> ExternalDraftRequest {
        try runtime.requireSupportedSystem()
        if config.scenario == .projectNote, config.templateID == nil {
            throw ExternalInvocationError.templateUnavailable
        }
        let destination: ExternalDraftDestination
        switch config.location {
        case .defaultLocation: destination = .defaultLocation
        case .ask: destination = .ask
        case .directory:
            guard let url = config.directory else { throw ExternalInvocationError.destinationUnavailable }
            destination = .directory(url.path)
        case .favorite:
            guard let id = config.favoriteID, folderFavorites.contains(where: { $0.id == id }) else { throw ExternalInvocationError.destinationUnavailable }
            destination = .favorite(id)
        }
        let body: ExternalDraftContent
        switch config.bodyMode {
        case .templateDefault: body = .templateDefault
        case .text: body = .verbatim(config.text)
        case .empty: body = .verbatim("")
        }
        let name = config.nameMode == .fixed ? config.fileName : nil
        let request = try ExternalDraftRequest(name: name, templateID: config.templateID, content: body, destination: destination, requestID: config.requestID)
        _ = try request.resolve(preferences: settings.committedPreferences, capturedAt: Date())
        return request
    }
    func invocation() throws -> ExternalInvocation {
        try runtime.requireSupportedSystem()
        return config.scenario == .quickSearch ? .search : .draft(try request())
    }
    func command() throws -> LauncherCommand { try .init(title: config.title, invocation: invocation(), runtimeName: config.scenario != .quickSearch && config.nameMode == .runtime) }
    func link() throws -> String {
        let original = try ExternalDraftRoute.string(for: invocation())
        let received = scheme + original.dropFirst("filemint".count)
        guard received.utf8.count <= ExternalDraftLimits.urlBytes else { throw ExternalInvocationError.payloadTooLarge }
        return received
    }

    func chooseDirectory() {
        guard let generator, !isExporting else { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.directoryURL = config.directory ?? settings.initialCreationDirectory
        let session = sessionID
        picker.beginSheetModal(for: generator) { [weak self] response in
            Task { @MainActor in
                guard let self, self.sessionID == session, response == .OK, let url = picker.url else { return }
                self.config.directory = url
            }
        }
    }

    func preview() {
        guard !isExporting, let owner, let generator else { return }
        do {
            if config.scenario == .quickSearch {
                // A local search preview does not claim external routing or import.
                previewReservation = try runtime.reservePreview(ownedSheet: generator, owner: owner)
            } else {
                _ = try request()
                previewReservation = try runtime.reservePreview(ownedSheet: generator, owner: owner)
            }
            error = nil
            owner.endSheet(generator)
            generator.orderOut(nil)
        } catch { handle(error) }
    }

    private func generatorDidEnd(session: UUID) {
        guard sessionID == session else { return }
        guard let reservation = previewReservation else { return }
        previewReservation = nil
        let runtime = runtime
        previewTask = Task { [weak self] in
            guard let self, self.sessionID == session, self.owner?.isVisible == true else {
                runtime.cancelPreview(reservation)
                return
            }
            do {
                if self.config.scenario == .quickSearch {
                    self.runtime.cancelPreview(reservation)
                    let result = try await self.runtime.showSearch()
                    guard result == .shown || result == .alreadyVisible else { throw ExternalInvocationError.unavailable }
                    self.guide = self.config.tool
                } else {
                    let request = try self.request()
                    // A local preview must not consume an imported command's
                    // public deduplication ID before that command is actually run.
                    let preview = try ExternalDraftRequest(name: request.name, templateID: request.templateID,
                        content: request.content, destination: request.destination)
                    _ = try await self.runtime.openDraft(preview, source: .preview,
                        nativeGrantURL: self.config.location == .directory ? self.config.directory : nil,
                        didClose: { [weak self] in
                            guard let self, self.sessionID == session else { return }
                            self.previewIsOpen = false
                            self.restoreAfterPreview = true
                            self.restoreGeneratorIfPossible()
                        }, preview: reservation)
                    if self.sessionID == session { self.previewIsOpen = true }
                }
            } catch {
                self.runtime.cancelPreview(reservation)
                guard self.sessionID == session else { return }
                self.handle(error)
                self.restoreAfterPreview = true
                self.restoreGeneratorIfPossible()
            }
        }
    }

    private func restoreGeneratorIfPossible() {
        guard restoreAfterPreview, !previewIsOpen, let owner, owner.isVisible, !owner.isMiniaturized,
              NSApp.isActive, owner.isKeyWindow, owner.attachedSheet == nil, NSApp.modalWindow == nil,
              runtime.pendingRequestCount == 0 else { return }
        restoreAfterPreview = false
        showGenerator(focusPreview: true)
    }

    func copyLink() {
        do {
            let value = try link()
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(value, forType: .string) else { throw ExternalInvocationError.unavailable }
            finishExport(tool: .url, saved: nil)
        } catch { handle(error) }
    }

    func exportRaycast() {
        guard !isExporting, let generator, let session = sessionID else { return }
        do {
            let command = try command()
            _ = try command.raycastScript(bundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.daigua.filemint", scheme: scheme)
            guard let release = runtime.reserveSettingsOperation() else { throw ExternalInvocationError.busy }
            let work = settings.beginLauncherWork()
            let settings = settings
            isExporting = true
            if let editingScript {
                Task {
                    defer { self.isExporting = false; settings.endLauncherWork(work); release() }
                    do {
                        let saved = try await scripts.update(editingScript, command: command,
                            bundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.daigua.filemint", scheme: scheme)
                        guard sessionID == session else { return }
                        self.editingScript = saved.edit
                        finishExport(tool: .raycast, saved: saved.url)
                    } catch {
                        scripts.report(error)
                        self.error = ("general", scripts.error ?? text("Could not update this script.", "未能更新脚本。"))
                    }
                }
                return
            }
            let picker = NSSavePanel()
            picker.nameFieldStringValue = FilenamePolicy.sanitizedFileName(config.title) + ".sh"
            picker.directoryURL = scripts.records.last?.url.deletingLastPathComponent()
            picker.beginSheetModal(for: generator) { [weak self] response in
                Task { @MainActor in
                    defer { settings.endLauncherWork(work); release() }
                    guard let self else { return }
                    defer { self.isExporting = false }
                    guard self.sessionID == session, response == .OK, let url = picker.url, self.owner?.isVisible == true else { return }
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    let identifier = Bundle.main.bundleIdentifier ?? "io.github.daigua.filemint", scheme = self.scheme
                    let result = await Task.detached(priority: .userInitiated) {
                        Result { try command.exportRaycast(to: url, bundleIdentifier: identifier, scheme: scheme) }
                    }.value
                    guard self.sessionID == session else { return }
                    switch result {
                    case .success:
                        do { try await self.scripts.register(url) }
                        catch { self.scripts.reportSavedIndexFailure() }
                        self.finishExport(tool: .raycast, saved: url)
                        self.openRaycast()
                    case .failure(let error): self.handle(error)
                    }
                }
            }
        } catch { handle(error) }
    }

    func editScript(_ record: LauncherScriptRecord) {
        guard isSupported, !isExporting, let owner, owner.isVisible, owner.attachedSheet == nil,
              let release = runtime.reserveSettingsOperation() else { show(.busy); return }
        let work = settings.beginLauncherWork()
        isExporting = true
        Task {
            defer { isExporting = false; settings.endLauncherWork(work); release() }
            do {
                let edit = try await scripts.edit(record,
                    bundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.daigua.filemint", scheme: scheme)
                guard self.owner === owner, owner.isVisible, owner.attachedSheet == nil else { return }
                cancelConfiguration()
                var value = IntegrationConfiguration()
                value.title = edit.command.title
                value.tool = .raycast
                if case .draft(let request) = edit.command.invocation {
                    value.scenario = .custom
                    value.templateID = request.templateID
                    value.requestID = request.requestID
                    value.nameMode = edit.command.runtimeName ? .runtime : request.name == nil ? .automatic : .fixed
                    value.fileName = request.name ?? ""
                    switch request.content {
                    case .templateDefault: value.bodyMode = .templateDefault
                    case .verbatim(let text): value.bodyMode = text.isEmpty ? .empty : .text; value.text = text
                    }
                    switch request.destination {
                    case .defaultLocation: value.location = .defaultLocation
                    case .ask: value.location = .ask
                    case .directory(let path): value.location = .directory; value.directory = URL(fileURLWithPath: path)
                    case .favorite(let id): value.location = .favorite; value.favoriteID = id
                    }
                    value.advanced = value.bodyMode != .templateDefault
                } else { value.scenario = .quickSearch; value.nameMode = .automatic }
                config = value
                sessionID = value.id
                editingScript = edit
                showGenerator()
            } catch { scripts.report(error) }
        }
    }

    func addExistingScript() {
        guard isSupported, !scripts.isWorking, !isExporting, let owner, owner.attachedSheet == nil,
              let release = runtime.reserveSettingsOperation() else { return }
        let settings = self.settings
        let work = settings.beginLauncherWork()
        scripts.addExisting(owner: owner, bundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.daigua.filemint", scheme: scheme) {
            settings.endLauncherWork(work); release()
        }
    }

    func trashScript(_ record: LauncherScriptRecord) {
        guard isSupported else { show(.unsupportedSystemVersion); return }
        guard !scripts.isWorking, !isExporting, let release = runtime.reserveSettingsOperation() else { show(.busy); return }
        let settings = self.settings
        let work = settings.beginLauncherWork()
        scripts.trash(record) { settings.endLauncherWork(work); release() }
    }

    func openRaycast() {
        guard isSupported else { show(.unsupportedSystemVersion); return }
        // The public command route is supported by Raycast 1/2. Settings/import
        // URL guesses are silently ignored by Raycast 2, so keep the steps visible.
        let url = URL(string: "raycast://extensions/raycast/script-commands/search-script-commands")!
        guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil, NSWorkspace.shared.open(url) else {
            error = ("general", text("Raycast could not be opened. Your script is saved; open Raycast and add its folder in Script Commands settings.",
                                     "未能打开 Raycast。脚本已保存，请打开 Raycast，在 Script Commands 设置中添加脚本目录。"))
            return
        }
    }

    private func finishExport(tool: IntegrationTool, saved: URL?) {
        error = nil
        savedURL = saved
        guide = tool
        if let generator, generator.sheetParent === owner { owner?.endSheet(generator); generator.orderOut(nil) }
    }

    func testLocally() {
        guard guide != nil, owner?.attachedSheet == nil else { return }
        if config.scenario == .quickSearch {
            Task {
                do {
                    let result = try await runtime.showSearch()
                    guard result == .shown || result == .alreadyVisible else { throw ExternalInvocationError.unavailable }
                } catch { handle(error) }
            }
            return
        }
        do {
            let original = try request(), nonce = UUID()
            let test = try ExternalDraftRequest(name: config.nameMode == .runtime ? text("FileMint Test Note", "FileMint 测试笔记") : original.name,
                templateID: original.templateID, content: original.content, destination: original.destination, requestID: nonce)
            let canonical = try ExternalDraftRoute.string(for: .draft(test))
            let raw = scheme + canonical.dropFirst("filemint".count)
            guard raw.utf8.count <= ExternalDraftLimits.urlBytes else { throw ExternalInvocationError.payloadTooLarge }
            guard let url = URL(string: raw) else { throw ExternalInvocationError.invalidRequest }
            testNonce = nonce
            testReceived = false
            let options = NSWorkspace.OpenConfiguration()
            options.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: Bundle.main.bundleURL, configuration: options) { [weak self] _, error in
                guard error != nil else { return }
                Task { @MainActor in self?.show(.unavailable) }
            }
        } catch { handle(error) }
    }

    func openShortcuts() {
        guard isSupported else { show(.unsupportedSystemVersion); return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") else { show(.unavailable); return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
    func show(_ code: ExternalInvocationError) { error = ("general", code.message(language)) }
    func handle(_ failure: Error) {
        guard !(failure is CancellationError), error == nil else { return }
        let code = failure as? ExternalInvocationError ?? .unavailable
        if code == .templateUnavailable, config.scenario == .projectNote, config.templateID == nil {
            error = ("template", text("Choose an enabled text template first.", "请先选择一个启用的文本模板。"))
            return
        }
        let field: String = switch code {
        case .templateUnavailable, .contentTemplateMismatch: "template"
        case .invalidFilename: "filename"
        case .destinationUnavailable, .authorizationRequired, .authorizationDenied: "location"
        case .payloadTooLarge: "content"
        default: "general"
        }
        error = (field, code.message(language))
    }

    func cancelConfiguration() {
        if let previewReservation { runtime.cancelPreview(previewReservation) }
        previewReservation = nil
        if CustomFileSavePanelController.shared.externalWindow == nil { previewTask?.cancel() }
        previewTask = nil
        restoreAfterPreview = false
        previewIsOpen = false
        focusPreviewOnKey = false
        sessionID = nil
        editingScript = nil
        guide = nil
        savedURL = nil
        testNonce = nil
        testReceived = false
        if let generator {
            generator.delegate = nil
            if let parent = generator.sheetParent { parent.endSheet(generator) }
            generator.orderOut(nil)
            generator.close()
        }
        generator = nil
        config = IntegrationConfiguration()
        error = nil
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { cancelConfiguration(); return false }
}
