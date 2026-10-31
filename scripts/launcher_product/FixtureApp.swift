import AppKit
import AppIntents
import Combine
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct LauncherProductFixtureApp: App {
    @NSApplicationDelegateAdaptor(LauncherProductFixtureDelegate.self) private var delegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("QA Controls") { LauncherProductRuntime.shared.showControls() }.keyboardShortcut(",")
                }
            }
    }
}

@MainActor
final class LauncherProductFixtureDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.accessory)
        _ = LauncherProductRuntime.shared
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        FileMintLauncherShortcuts.updateAppShortcutParameters()
        let expected = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(kAEApplicationActivationExpected))?.booleanValue == true
        LauncherProductRuntime.shared.record("launch", ["activationExpected": expected])
        LauncherProductRuntime.shared.coordinator.handleOrdinaryLaunch(
            isDefault: notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true,
            activationExpected: expected)
    }
    func application(_ sender: NSApplication, open urls: [URL]) {
        for url in urls {
            let raw = url.absoluteString
            guard raw.utf8.count <= ExternalDraftLimits.urlBytes, raw.hasPrefix("filemint-product-qa://") else { continue }
            LauncherProductRuntime.shared.record("url-delivered")
            let canonical = "filemint://" + raw.dropFirst("filemint-product-qa://".count)
            guard let received = URL(string: canonical) else { continue }
            LauncherProductRuntime.shared.coordinator.receive(received)
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LauncherProductRuntime.shared.record("reopen", ["hasVisibleWindows": flag])
        LauncherProductRuntime.shared.coordinator.handleReopen()
        return false
    }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let runtime = LauncherProductRuntime.shared
        return runtime.model.pendingCreationCount == 0 && !CustomFileSavePanelController.shared.hasActiveDraft ? .terminateNow : .terminateCancel
    }
}

@MainActor
final class LauncherProductRuntime: NSObject {
    static let shared = LauncherProductRuntime()
    let model: PreferencesModel
    let favorites: FavoriteLocationsModel
    let fileOperations: FileOperationCoordinator
    private(set) var coordinator: ExternalInvocationCoordinator!
    private let root: URL
    private let hostDirectory: URL
    private let invocation = UUID().uuidString
    private var controls: NSWindow?
    private var logView: NSTextView?
    private var log: [String] = []
    private var subscription: AnyCancellable?
    private var heldGuard: (@MainActor () -> Void)?
    private var modal: NSWindow?
    private var integrationsWindow: NSWindow?

    private override init() {
        let run = Bundle.main.object(forInfoDictionaryKey: "FixtureRunID") as? String ?? "unknown"
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FileMintLauncherProductQA", isDirectory: true).appendingPathComponent(run, isDirectory: true)
        hostDirectory = URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "FixtureHostDirectory") as! String, isDirectory: true)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let output = root.appendingPathComponent("CreatedFiles", isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let preferencesFile = root.appendingPathComponent("preferences.json")
        let store = FileMintPreferencesStore(fileURL: preferencesFile)
        if !FileManager.default.fileExists(atPath: preferencesFile.path) {
            var preferences = FileMintPreferences.default
            preferences.language = .chinese
            preferences.launchAtLogin = false
            preferences.showMenuBar = false
            preferences.automaticallyChecksForUpdates = false
            preferences.revealAfterCreation = false
            preferences.monitoredFolderURLs = [output]
            preferences.monitoredFolderBookmarks = [:]
            try! store.save(preferences)
        }
        let slow = UserDefaults.standard.bool(forKey: "launcherQA.delayNextStartup")
        UserDefaults.standard.set(false, forKey: "launcherQA.delayNextStartup")
        let startupPreparation: (@MainActor () async -> Void)?
        if slow { startupPreparation = { try? await Task.sleep(for: .seconds(20)) } }
        else { startupPreparation = nil }
        model = PreferencesModel(store: store, documentTemplates: .init(directory: root.appendingPathComponent("assets")),
            quickCreationTickets: .init(directory: root.appendingPathComponent("quick-requests")),
            startupPreparation: startupPreparation)
        let favoritesStore = FavoriteLocationsStore(file: root.appendingPathComponent("favorites.json"))
        if !FileManager.default.fileExists(atPath: favoritesStore.file.path) { try! favoritesStore.save(.init()) }
        favorites = FavoriteLocationsModel(store: favoritesStore)
        let rename = BatchRenameOperations(store: .init(directory: root.appendingPathComponent("rename")),
            accessStore: .init(file: root.appendingPathComponent("rename-access.json")), preferencesFile: preferencesFile)
        let resources = ResourceToolsController(preferencesFile: preferencesFile)
        fileOperations = FileOperationCoordinator(store: .init(file: root.appendingPathComponent("pending-move.json")),
            tickets: .init(directory: root.appendingPathComponent("operation-tickets")), preferencesFile: preferencesFile,
            aliasAccessStore: .init(file: root.appendingPathComponent("alias-access.json")),
            openWithAccessStore: .init(file: root.appendingPathComponent("open-access.json")), desktopDirectory: output,
            resourceController: resources, renameOperations: rename)
        super.init()
        let search = QuickSearchPanelController(openSettings: { [weak self] _ in self?.showControls() })
        coordinator = ExternalInvocationCoordinator(model: model, search: search,
            favorites: { [favorites] in favorites }, isBlocked: { [favorites] in favorites.pendingOperations > 0 },
            reserveOperation: { [fileOperations] in fileOperations.reserveExternalPresentation() },
            openSettings: { [weak self] in self?.record("ordinary-controls-shown"); self?.showControls() },
            diagnostic: { [weak self] event, flags in self?.record(event, flags.mapValues { $0 as Any }) })
        model.externalInvocations = coordinator
        ExternalInvocationCoordinator.fixtureInstance = coordinator
        subscription = coordinator.$lastAcceptedRequestID.dropFirst().sink { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let window = CustomFileSavePanelController.shared.externalWindow
                self.record("draft-accepted", ["visible": window?.isVisible == true, "key": window?.isKeyWindow == true,
                    "appActive": NSApp.isActive, "pendingWorkers": ExternalDraftDirectoryAccess.pendingOperationCount])
            }
        }
        record("fixture-started", ["artificialReadinessDelay": slow])
    }

    func record(_ event: String, _ fields: [String: Any] = [:]) {
        var value = fields
        value["event"] = event
        value["invocationID"] = invocation
        value["buildRunID"] = Bundle.main.object(forInfoDictionaryKey: "FixtureRunID")
        value["uptimeNS"] = DispatchTime.now().uptimeNanoseconds
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        log.append(line)
        if log.count > 1000 { log.removeFirst(log.count - 1000) }
        logView?.string = log.suffix(12).joined(separator: "\n")
        let directory = root.appendingPathComponent("events", isDirectory: true).appendingPathComponent(invocation, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? (log.joined(separator: "\n") + "\n").write(to: directory.appendingPathComponent("events.jsonl"), atomically: true, encoding: .utf8)
    }

    func showControls() {
        if let controls { controls.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 760),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "FileMint Product Launcher QA"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        let heading = NSTextField(wrappingLabelWithString: "Isolated signed sandbox fixture using production Intents, parser, coordinator and draft UI. Synthetic data and the reserved QA folder only. No production stores are loaded.")
        let view = NSTextView()
        view.isEditable = false
        view.string = log.suffix(12).joined(separator: "\n")
        logView = view
        let scroll = NSScrollView()
        scroll.documentView = view
        scroll.hasVerticalScroller = true
        scroll.heightAnchor.constraint(equalToConstant: 180).isActive = true
        let stack = NSStackView(views: [heading, button("Choose / remember reserved QA folder…", #selector(chooseFolder)),
            row([button("Open product integrations", #selector(showIntegrations)),
                 button("Open manual draft", #selector(openManualDraft)), button("Open production draft", #selector(openDraft))]),
            row([button("Toggle product language", #selector(toggleLanguage)), button("Toggle product appearance", #selector(toggleAppearance))]),
            row([button("Verify generator validation", #selector(verifyGeneratorValidation)), button("Verify native input mapping", #selector(verifyNativeInputMapping))]),
            button("Export minimal Raycast note…", #selector(exportRaycast)),
            row([button("Hold / release exclusive operation", #selector(toggleGuard)), button("Open / close modal guard", #selector(toggleModal))]),
            button("Delay next startup (cancellation QA)", #selector(delayNextStartup)),
            row([button("Export product screenshot…", #selector(exportScreenshot)), button("Export QA evidence…", #selector(exportEvidence)), button("Quit QA", #selector(quit))]), scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24), scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            heading.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        window.contentView = content
        controls = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: self, action: action) }
    private func row(_ buttons: [NSButton]) -> NSStackView {
        let view = NSStackView(views: buttons)
        view.orientation = .horizontal
        view.spacing = 10
        return view
    }
    @objc private func openManualDraft() { model.newFile(templateID: "markdown") }
    @objc private func chooseFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.canCreateDirectories = false
        picker.directoryURL = hostDirectory
        picker.message = "Choose only the reserved FileMint launcher QA folder. This saves access in this fixture's private preferences."
        guard picker.runModal() == .OK, let url = picker.url,
              url.standardizedFileURL == hostDirectory.standardizedFileURL else { record("folder-choice-cancelled-or-rejected"); return }
        guard model.rememberMonitoredFolders([url]) else { record("folder-remember-failed"); return }
        model.preferences.monitoredFolderURLs.removeAll { $0 == url }
        model.preferences.monitoredFolderURLs.insert(url, at: 0)
        _ = model.save()
        record("qa-folder-remembered")
    }
    @objc private func openDraft() {
        Task {
            do { _ = try await coordinator.openDraft(.init(name: "FileMint-QA Note", templateID: "markdown"), source: .preview) }
            catch { coordinator.reportURLFailure(error) }
        }
    }
    @objc private func exportRaycast() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "filemint-product-qa-note.sh"
        guard panel.runModal() == .OK, let destination = panel.url else { record("raycast-export-cancelled"); return }
        let granted = destination.startAccessingSecurityScopedResource()
        defer { if granted { destination.stopAccessingSecurityScopedResource() } }
        do {
            let request = try ExternalDraftRequest(templateID: "markdown", destination: .directory(model.initialCreationDirectory.path))
            let command = try LauncherCommand(title: "FileMint Product QA Note", invocation: .draft(request), runtimeName: true)
            try command.exportRaycast(to: destination, bundleIdentifier: Bundle.main.bundleIdentifier!, scheme: "filemint-product-qa")
            record("raycast-script-exported")
        } catch { record("raycast-export-failed", ["errorCode": (error as NSError).code]); coordinator.reportURLFailure(error) }
    }
    @objc private func toggleGuard() {
        if let heldGuard { heldGuard(); self.heldGuard = nil; record("exclusive-guard-released") }
        else { heldGuard = fileOperations.reserveExternalPresentation(); record("exclusive-guard-held", ["busy": fileOperations.isBusy]) }
    }
    @objc private func toggleModal() {
        if let modal { controls?.endSheet(modal); modal.orderOut(nil); self.modal = nil; record("modal-closed"); return }
        guard let controls else { return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        let close = button("Close modal", #selector(toggleModal))
        close.frame = NSRect(x: 130, y: 30, width: 160, height: 32)
        window.contentView?.addSubview(close)
        modal = window
        controls.beginSheet(window)
        record("modal-opened")
    }
    @objc private func delayNextStartup() {
        UserDefaults.standard.set(true, forKey: "launcherQA.delayNextStartup")
        record("next-startup-delay-armed")
    }
    @objc private func showIntegrations() {
        if let integrationsWindow {
            model.integrationsState?.attachOwner(integrationsWindow)
            integrationsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "FileMint — 快捷指令与启动器"
        window.contentMinSize = NSSize(width: 760, height: 570)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(rootView: IntegrationsPane(settings: model, favorites: favorites).padding(24))
        integrationsWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        record("product-integrations-shown")
    }
    @objc private func toggleLanguage() {
        model.preferences.language = model.preferences.language == .chinese ? .english : .chinese
        record("product-language-toggled", ["saved": model.save()])
    }
    @objc private func toggleAppearance() {
        model.setAppearance(model.preferences.appearance == .dark ? .light : .dark)
        record("product-appearance-toggled", ["saved": model.preferences.appearance == model.committedPreferences.appearance])
    }
    @objc private func verifyNativeInputMapping() {
        var passed = true
        var count = 0
        let favoriteID = UUID()
        let nativeText = "  Synthetic workflow text 🧪\n{{year}} & # + % $() `literal`\n"
        for location in LauncherSaveLocation.allCases {
            for content in LauncherContentMode.allCases {
                var intent = OpenFileMintDraftIntent()
                intent.name = "FileMint-QA Native Mapping"
                intent.location = location
                intent.folder = IntentFile(fileURL: hostDirectory, type: .folder)
                intent.favorite = .init(id: favoriteID.uuidString, name: "Synthetic folder", parent: "/private/tmp", searchTerms: "Synthetic")
                intent.content = content
                intent.text = nativeText
                do {
                    let input = try intent.requestInput()
                    let destinations: [LauncherSaveLocation: ExternalDraftDestination] = [
                        .defaultLocation: .defaultLocation,
                        .folder: .directory(hostDirectory.standardizedFileURL.path),
                        .favorite: .favorite(favoriteID), .ask: .ask]
                    let bodies: [LauncherContentMode: ExternalDraftContent] = [.templateDefault: .templateDefault, .text: .verbatim(nativeText), .empty: .verbatim("")]
                    let destinationMatches = input.request.destination == destinations[location]
                    let contentMatches = input.request.content == bodies[content]
                    let scopeMatches = (input.nativeGrantURL != nil) == (location == .folder)
                    passed = passed && destinationMatches && contentMatches && scopeMatches
                    if !destinationMatches || !contentMatches || !scopeMatches {
                        record("native-input-mapping-mismatch", ["location": location.rawValue, "content": content.rawValue,
                            "destinationMatches": destinationMatches, "contentMatches": contentMatches, "scopeMatches": scopeMatches])
                    }
                    count += 1
                } catch { passed = false }
            }
        }
        var invalid = 0
        var missingFolder = OpenFileMintDraftIntent(); missingFolder.location = .folder
        var missingFavorite = OpenFileMintDraftIntent(); missingFavorite.location = .favorite
        var missingText = OpenFileMintDraftIntent(); missingText.content = .text
        for intent in [missingFolder, missingFavorite, missingText] {
            do { _ = try intent.requestInput() } catch { invalid += 1 }
        }
        record("native-input-mapping", ["passed": passed && count == 12 && invalid == 3, "cases": count, "requiredFieldsRejected": invalid])
    }
    @objc private func exportScreenshot() {
        let target = CustomFileSavePanelController.shared.externalWindow
            ?? integrationsWindow?.attachedSheet ?? (integrationsWindow?.isVisible == true ? integrationsWindow : nil)
        guard let target, target.isVisible, let view = target.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        // AppKit's cache has a transparent background. NSBitmapImageRep.draw
        // copies those transparent pixels, so explicitly composite source-over.
        let foreground = NSImage(size: view.bounds.size)
        foreground.addRepresentation(bitmap)
        let rendered = NSImage(size: view.bounds.size)
        target.effectiveAppearance.performAsCurrentDrawingAppearance {
            rendered.lockFocus()
            let windowBackground = target.backgroundColor ?? .windowBackgroundColor
            let background = windowBackground.alphaComponent == 0
                ? NSColor.windowBackgroundColor : windowBackground
            background.withAlphaComponent(1).setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: view.bounds.size)).fill()
            foreground.draw(in: NSRect(origin: .zero, size: view.bounds.size),
                            from: .zero, operation: .sourceOver, fraction: 1)
            rendered.unlockFocus()
        }
        guard let tiff = rendered.tiffRepresentation, let image = NSBitmapImageRep(data: tiff),
              let data = image.representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "filemint-launcher-product.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            try data.write(to: url, options: .atomic)
            record("product-screenshot-exported", ["width": bitmap.pixelsWide, "height": bitmap.pixelsHigh])
        } catch { record("product-screenshot-export-failed") }
    }
    @objc private func verifyGeneratorValidation() {
        // View link rendering also runs for invalid and just-cleared configs.
        // It must never publish an error while SwiftUI is reading its body.
        let state = IntegrationsModel(settings: model, favorites: favorites)
        var values = [IntegrationConfiguration()]
        var valid = IntegrationConfiguration()
        valid.templateID = "markdown"
        values.append(valid)
        var missingFolder = valid
        missingFolder.location = .directory
        values.append(missingFolder)
        var badName = valid
        badName.nameMode = .fixed
        badName.fileName = "../invalid"
        values.append(badName)
        var tooLarge = valid
        tooLarge.bodyMode = .text
        tooLarge.text = String(repeating: "x", count: 8193)
        values.append(tooLarge)
        var changes = 0
        let observation = state.objectWillChange.sink { changes += 1 }
        var pure = true
        var failures = 0
        for value in values {
            state.config = value
            let before = changes
            do { _ = try state.link() } catch { failures += 1 }
            pure = pure && changes == before
        }
        withExtendedLifetime(observation) {}
        record("generator-validation", ["readOnly": pure, "expectedInvalidCases": failures == 4, "cases": values.count])
    }
    @objc private func exportEvidence() {
        record("evidence-export-requested", ["pendingWorkers": ExternalDraftDirectoryAccess.pendingOperationCount])
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "launcher-product-" + invocation + ".jsonl"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        try? (log.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
    @objc private func quit() { heldGuard?(); heldGuard = nil; NSApp.terminate(nil) }
}
