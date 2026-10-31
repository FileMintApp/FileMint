import AppKit
import AppIntents
import Darwin
import SwiftUI

@main
struct LauncherProbeApp: App {
    @NSApplicationDelegateAdaptor(ProbeDelegate.self) private var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

struct ProbeOpenDraftIntent: ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "P0 Open FileMint QA Draft"
    static let description = IntentDescription("Isolated sandbox probe. Use synthetic text and an empty QA folder only. No file is created by this action.")
    // Run in the host without pre-opening ordinary UI. AppKit owns presentation
    // and success requires a visible, active window with keyboard focus.
    // Runtime evidence remains tied to the host OS, not this deployment target.
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Synthetic filename", default: "P0 Synthetic.txt",
        inputOptions: .init(capitalizationType: .none, autocorrect: false, smartQuotes: false, smartDashes: false)) var name: String
    @Parameter(title: "Synthetic text", default: "FileMint P0 synthetic text",
        inputOptions: .init(capitalizationType: .none, multiline: true, autocorrect: false, smartQuotes: false, smartDashes: false)) var text: String
    @Parameter(title: "Empty QA folder (optional)", supportedTypeIdentifiers: ["public.folder"]) var folder: IntentFile?
    @Parameter(title: "Delay before admission (seconds)", default: 0) var delay: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Open QA draft \(\.$name)") {
            \.$text
            \.$folder
            \.$delay
        }
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let controller = ProbeController.shared
        controller.beginIntentPresentation(action: "draft")
        defer { controller.endIntentPresentation(action: "draft") }
        try Task.checkCancellation()
        controller.record("intent-appkit-foreground", ["action": "draft", "appActive": NSApp.isActive])
        let result = try await controller.openDraft(
            name: name, text: text, directory: folder?.fileURL,
            folderProvided: folder != nil, delay: delay, source: "app-intent")
        controller.record("intent-return", ["action": "draft", "result": result])
        // Foreground navigation returns its status without a second system dialog.
        // The first local Shortcuts run stayed running with Show When Run enabled.
        return .result(value: result)
    }
}

struct ProbeShowSearchIntent: ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "P0 Show FileMint QA Search"
    static let description = IntentDescription("Shows the isolated QA search window, or returns busy when a modal window is active.")
    static var openAppWhenRun: Bool { false }
    @Parameter(title: "Delay before admission (seconds)", default: 0) var delay: Int

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let controller = ProbeController.shared
        controller.beginIntentPresentation(action: "search")
        defer { controller.endIntentPresentation(action: "search") }
        try Task.checkCancellation()
        controller.record("intent-appkit-foreground", ["action": "search", "appActive": NSApp.isActive])
        let result = try await controller.showSearch(delay: delay, source: "app-intent")
        controller.record("intent-return", ["action": "search", "result": result])
        return .result(value: result)
    }
}

struct ProbeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ProbeOpenDraftIntent(), phrases: ["Open a draft in \(.applicationName)"],
                    shortTitle: "QA Draft", systemImageName: "doc.badge.plus")
        AppShortcut(intent: ProbeShowSearchIntent(), phrases: ["Show search in \(.applicationName)"],
                    shortTitle: "QA Search", systemImageName: "magnifyingglass")
    }
}

private struct ProbeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class ProbeDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.accessory)
        ProbeController.shared.record("will-finish-launching")
        recordLaunchEvent(at: "will-finish")
        if Bundle.main.object(forInfoDictionaryKey: "FixtureURLMode") as? String == "raw" {
            NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        recordLaunchEvent(at: "did-finish")
        ProbeController.shared.record("did-finish-launching", [
            "defaultLaunch": notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? false])
        ProbeAppShortcuts.updateAppShortcutParameters()
        if notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true {
            let activationExpected = NSAppleEventManager.shared().currentAppleEvent?
                .paramDescriptor(forKeyword: AEKeyword(kAEApplicationActivationExpected))?.booleanValue == true
            ProbeController.shared.requestOrdinaryStartupControl(activationExpected: activationExpected)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        ProbeController.shared.applicationBecameActive()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { ProbeController.shared.receiveURL(url.absoluteString, source: "appkit") }
    }

    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            ProbeController.shared.record("url-missing-string")
            return
        }
        ProbeController.shared.receiveURL(raw, source: "gurl")
        if let converted = URL(string: raw) {
            ProbeController.shared.observeURL(converted.absoluteString, source: "foundation-derived")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ProbeController.shared.record("reopen", ["hasVisibleWindows": flag])
        recordLaunchEvent(at: "reopen")
        ProbeController.shared.presentOrdinaryLaunchControl(source: "reopen")
        return false
    }
    private func recordLaunchEvent(at phase: String) {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            ProbeController.shared.record("launch-event", ["phase": phase, "present": false])
            return
        }
        var metadata: [String: Any] = ["phase": phase, "present": true,
            "eventClass": event.eventClass, "eventID": event.eventID,
            "loginItemParameterPresent": event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil,
            "serviceItemParameterPresent": event.paramDescriptor(forKeyword: keyAELaunchedAsServiceItem) != nil]
        metadata["source"] = event.attributeDescriptor(forKeyword: keyEventSourceAttr)?.int32Value
        metadata["senderPID"] = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value
        if let expected = event.paramDescriptor(forKeyword: AEKeyword(kAEApplicationActivationExpected)) {
            metadata["activationExpected"] = expected.booleanValue
        }
        if event.numberOfItems > 0 {
            metadata["parameterKeywords"] = (1...event.numberOfItems).map {
                String(format: "%08x", event.keywordForDescriptor(at: $0))
            }
        }
        ProbeController.shared.record("launch-event", metadata)
    }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { ProbeController.shared.closeDraft() }
}

@MainActor
final class ProbeController: NSObject, NSWindowDelegate {
    static let shared = ProbeController()
    private let invocationID = UUID().uuidString
    private let buildRunID = Bundle.main.object(forInfoDictionaryKey: "FixtureRunID") as? String ?? "unknown"
    private var control: NSWindow?
    private var draft: NSWindow?
    private var search: NSWindow?
    private weak var lastExternalWindow: NSWindow?
    private var modal: NSWindow?
    private var pendingID: UUID?
    private var sessionID: UUID?
    private var folder: URL?
    private var folderScope = false
    private var logView: NSTextView?
    private var logLines: [String] = []
    private var scopeStatus: NSTextField?
    private var intentPresentations = 0
    private lazy var logURL: URL = {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FileMintLauncherQA", isDirectory: true)
            .appendingPathComponent(buildRunID, isDirectory: true)
            .appendingPathComponent(invocationID, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("events.jsonl")
    }()

    func record(_ event: String, _ fields: [String: Any] = [:]) {
        var entry = fields
        entry["event"] = event
        entry["invocationID"] = invocationID
        entry["buildRunID"] = buildRunID
        entry["uptimeNS"] = DispatchTime.now().uptimeNanoseconds
        guard let bytes = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]),
              let line = String(data: bytes, encoding: .utf8) else { return }
        print(line)
        logLines.append(line)
        if logLines.count > 1000 { logLines.removeFirst(logLines.count - 1000) }
        // QA-only evidence is private to this build and launch; production stores are never loaded.
        try? (logLines.joined(separator: "\n") + "\n").write(to: logURL, atomically: true, encoding: .utf8)
        logView?.string = logLines.suffix(12).joined(separator: "\n")
    }

    func beginIntentPresentation(action: String) {
        intentPresentations += 1
        record("intent-presentation-began", ["action": action, "count": intentPresentations])
    }
    func endIntentPresentation(action: String) {
        intentPresentations -= 1
        record("intent-presentation-ended", ["action": action, "count": intentPresentations])
    }
    func requestOrdinaryStartupControl(activationExpected: Bool) {
        // An accessory app need not become active until it presents a window.
        // The default-launch notification is also sent for an Intent's background
        // host launch. Only the public explicit activation marker requests ordinary
        // UI; do not guess from sender PIDs or delay until an Intent might arrive.
        guard activationExpected else {
            record("ordinary-ui-suppressed", ["source": "default-launch", "reason": "no-explicit-activation"])
            return
        }
        presentOrdinaryLaunchControl(source: "default-launch-activation-request")
    }
    func applicationBecameActive() {
        record("application-became-active", ["intentPresentations": intentPresentations, "active": NSApp.isActive])
    }
    func presentOrdinaryLaunchControl(source: String) {
        if let foregroundModal = NSApp.modalWindow ?? NSApp.windows.compactMap(\.attachedSheet).first ?? modal {
            foregroundModal.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            record("focus-modal-on-reopen", ["source": source])
            return
        }
        // Foreground continuation may deliver reopen after perform() returns.
        // Window-session ownership outlives that stack frame; never retain an
        // unbounded one-shot token that could consume a later ordinary launch.
        if let external = lastExternalWindow ?? search ?? draft {
            external.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            record("focus-external-on-reopen", ["source": source, "kind": external === draft ? "draft" : "search"])
            return
        }
        guard intentPresentations == 0 else {
            record("ordinary-ui-suppressed", ["source": source, "reason": "active-intent-presentation"])
            return
        }
        record("ordinary-ui-shown", ["source": source])
        showControl()
    }

    private func awaitAdmission(delay: Int, action: String, source: String) async throws -> UUID {
        record("request", ["action": action, "source": source, "delay": delay])
        guard pendingID == nil, modal == nil, NSApp.modalWindow == nil,
              NSApp.windows.allSatisfy({ $0.attachedSheet == nil }) else {
            record("outcome", ["action": action, "result": "busy"])
            throw ProbeError(message: "busy: QA modal or request already active")
        }
        let request = UUID()
        pendingID = request
        do {
            try Task.checkCancellation()
            if delay > 0 { try await Task.sleep(for: .seconds(min(delay, 20))) }
            try Task.checkCancellation()
            guard pendingID == request, modal == nil else { throw CancellationError() }
            return request
        } catch {
            if pendingID == request { pendingID = nil }
            record("cancelled-before-presentation", ["action": action])
            throw error
        }
    }

    private func awaitInteractive(_ window: NSWindow, request: UUID) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard pendingID == request else { throw CancellationError() }
            if NSApp.isActive, window.isVisible, window.isKeyWindow,
               window.firstResponder is NSTextView || window.firstResponder is NSTextField {
                return
            }
            try await Task.sleep(for: .milliseconds(30))
        }
        throw ProbeError(message: "unavailable: QA window did not obtain keyboard focus")
    }

    func openDraft(name: String, text: String, directory: URL?, folderProvided: Bool,
                   delay: Int, source: String) async throws -> String {
        let request = try await awaitAdmission(delay: delay, action: "draft", source: source)
        defer { if pendingID == request { pendingID = nil } }
        guard draft == nil else {
            draft?.makeKeyAndOrderFront(nil)
            record("outcome", ["action": "draft", "result": "existingDraft"])
            throw ProbeError(message: "existingDraft: original QA input preserved")
        }
        guard name.utf8.count <= 1024, text.utf8.count <= 1024 * 1024 else {
            throw ProbeError(message: "payloadTooLarge")
        }
        if folderProvided, directory == nil { throw ProbeError(message: "IntentFile has no directory URL") }
        folder = directory
        folderScope = directory?.startAccessingSecurityScopedResource() ?? false
        var transferredToSession = false
        defer { if !transferredToSession { releaseFolder() } }
        if directory != nil {
            var evidence = folderMetadata()
            evidence["started"] = folderScope
            record("scope-acquired", evidence)
            record("scope-in-intent", evidence)
        }
        try Task.checkCancellation()
        sessionID = request
        let window = makeWindow("FileMint P0 Draft — synthetic data only", size: NSSize(width: 620, height: 460))
        draft = window
        lastExternalWindow = window
        window.delegate = self
        let nameField = NSTextField(string: name)
        nameField.setAccessibilityLabel("Synthetic filename")
        let editor = NSTextView()
        editor.string = text
        editor.isRichText = false
        let scroll = NSScrollView()
        scroll.documentView = editor
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 150).isActive = true
        let status = NSTextField(wrappingLabelWithString: directory == nil ? "No folder supplied." :
            directoryMetadataAvailable() ? "Folder metadata available; write access is unproven." : "Directory access unavailable. Choose the QA folder to authorize it.")
        scopeStatus = status
        setContent(window, views: [nameField, scroll, status,
            button("Choose / authorize QA folder…", #selector(chooseFolder)),
            button("Probe folder after Intent returns", #selector(probeFolder)),
            button("Create and remove QA sentinel…", #selector(writeSentinel)),
            button("Cancel draft", #selector(cancelDraft)), button("Show QA controls", #selector(showControls))])
        window.initialFirstResponder = nameField
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(nameField)
        do { try await awaitInteractive(window, request: request) }
        catch { closeDraft(); record("presentation-failed", ["action": "draft"]); throw error }
        transferredToSession = true
        record("outcome", ["action": "draft", "result": "presented", "visible": window.isVisible,
            "key": window.isKeyWindow, "appActive": NSApp.isActive,
            "hasTextFocus": window.firstResponder is NSTextView || window.firstResponder is NSTextField])
        // A delayed observation is not proof of the Shortcuts caller's completion.
        // The manual probe after the workflow finishes supplies that boundary evidence.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.sessionID == request else { return }
            self.record("scope-delayed-probe", self.folderMetadata())
        }
        return "presented"
    }

    func showSearch(delay: Int, source: String) async throws -> String {
        let request = try await awaitAdmission(delay: delay, action: "search", source: source)
        defer { if pendingID == request { pendingID = nil } }
        let existed = search != nil
        if search == nil {
            let window = makeWindow("FileMint P0 Search", size: NSSize(width: 520, height: 190))
            let field = NSSearchField(string: "")
            field.setAccessibilityLabel("QA search query")
            setContent(window, views: [field, NSTextField(labelWithString: "Synthetic search only; query stays in this window."), button("Show QA controls", #selector(showControls))])
            window.initialFirstResponder = field
            window.delegate = self
            search = window
        }
        lastExternalWindow = search
        search?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        guard let search else { throw ProbeError(message: "unavailable: search not visible") }
        search.makeFirstResponder(search.initialFirstResponder)
        do { try await awaitInteractive(search, request: request) }
        catch {
            if !existed { search.close() }
            record("presentation-failed", ["action": "search"])
            throw error
        }
        let result = existed ? "alreadyVisible" : "shown"
        record("outcome", ["action": "search", "result": result, "visible": search.isVisible,
            "key": search.isKeyWindow, "appActive": NSApp.isActive,
            "hasTextFocus": search.firstResponder is NSTextView || search.firstResponder is NSTextField])
        return result
    }

    func observeURL(_ raw: String, source: String) {
        var fields: [String: Any] = ["source": source, "byteCount": raw.utf8.count, "parserStatus": "not-evaluated"]
        let synthetic = raw.contains("probe=filemint-p0") && raw.utf8.count <= 32 * 1024
        if synthetic {
            fields["representation"] = raw
            let parts = URLComponents(string: raw)
            fields["requestID"] = parts?.queryItems?.first(where: { $0.name == "id" })?.value
            fields["decodedText"] = parts?.queryItems?.first(where: { $0.name == "text" })?.value
        } else { fields["redacted"] = true }
        record("url-received", fields)
    }

    func receiveURL(_ raw: String, source: String) {
        observeURL(raw, source: source)
        guard raw.utf8.count <= 32 * 1024, let parts = URLComponents(string: raw),
              parts.scheme == "filemint-launcher-qa", parts.queryItems?.contains(where: { $0.name == "probe" && $0.value == "filemint-p0" }) == true else { return }
        func value(_ key: String) -> String? { parts.queryItems?.first(where: { $0.name == key })?.value }
        // This probe records transport; it deliberately does not claim production parser validation.
        switch parts.host {
        case "control": showControl()
        case "modal": showModal()
        case "cancel": pendingID = nil; closeDraft(); search?.close()
        case "draft":
            let name = value("name") ?? "P0 URL.txt", text = value("text") ?? "P0 synthetic URL text"
            Task { do { _ = try await openDraft(name: name, text: text, directory: nil, folderProvided: false, delay: 0, source: source) }
                catch { record("url-action-error", ["code": String(describing: type(of: error))]) } }
        case "search":
            Task { do { _ = try await showSearch(delay: 0, source: source) }
                catch { record("url-action-error", ["code": String(describing: type(of: error))]) } }
        default: break
        }
    }

    func showControl() {
        if let control { control.makeKeyAndOrderFront(nil); return }
        let window = makeWindow("FileMint Launcher P0 Controls", size: NSSize(width: 760, height: 570))
        control = window
        window.delegate = self
        let output = NSTextView()
        output.isEditable = false
        output.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        output.string = logLines.suffix(12).joined(separator: "\n")
        logView = output
        let scroll = NSScrollView()
        scroll.documentView = output
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 300).isActive = true
        setContent(window, views: [NSTextField(wrappingLabelWithString: "Isolated signed sandbox probe. Real Shortcuts calls are required for Intent evidence. This app never loads FileMint preferences or writes user files automatically."),
            button("Open modal guard", #selector(openModal)), button("Cancel pending request / draft", #selector(cancelDraft)),
            button("Export QA evidence…", #selector(exportEvidence)), button("Quit QA", #selector(quit)), scroll])
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func directoryMetadataAvailable() -> Bool {
        folderMetadata()["metadataAvailable"] as? Bool ?? false
    }
    private func folderMetadata() -> [String: Any] {
        var evidence: [String: Any] = ["metadataAvailable": false, "scopeHeld": folderScope]
        guard let folder else { evidence["folderProvided"] = false; return evidence }
        evidence["folderProvided"] = true
        var metadata = stat()
        guard fstatat(AT_FDCWD, folder.path, &metadata, 0) == 0 else {
            evidence["statErrno"] = errno
            return evidence
        }
        let isDirectory = metadata.st_mode & S_IFMT == S_IFDIR
        evidence["metadataAvailable"] = isDirectory
        evidence["isDirectory"] = isDirectory
        evidence["statErrno"] = 0
        // This identifies the selected object without disclosing its path or
        // enumerating it. The host independently stats the known QA directory.
        evidence["device"] = String(metadata.st_dev)
        evidence["inode"] = String(metadata.st_ino)
        return evidence
    }
    private func releaseFolder() {
        if folderScope { folder?.stopAccessingSecurityScopedResource() }
        if folder != nil { record("scope-released", ["wasStarted": folderScope]) }
        folderScope = false
        folder = nil
    }
    func closeDraft() {
        let old = draft
        draft = nil
        if let old {
            if lastExternalWindow === old { lastExternalWindow = nil }
            record("external-session-cleared", ["kind": "draft"])
        }
        sessionID = nil
        scopeStatus = nil
        releaseFolder()
        old?.close()
    }
    @objc private func cancelDraft() { pendingID = nil; closeDraft(); record("cancel-button") }
    @objc private func showControls() { showControl() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func probeFolder() {
        let available = directoryMetadataAvailable()
        scopeStatus?.stringValue = available ? "Directory metadata still available. This does not prove write access." : "Directory unavailable: native picker fallback required."
        record("scope-manual-probe", folderMetadata())
    }
    @objc private func chooseFolder() {
        let picker = NSOpenPanel()
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.allowsMultipleSelection = false
        picker.canCreateDirectories = false
        picker.directoryURL = folder
        picker.message = "Choose an empty directory reserved for FileMint P0 QA. No directory contents are read."
        guard picker.runModal() == .OK, let selected = picker.url else {
            record("folder-picker-cancelled")
            return
        }
        releaseFolder()
        folder = selected
        folderScope = selected.startAccessingSecurityScopedResource()
        var evidence = folderMetadata()
        evidence["scopeStarted"] = folderScope
        record("folder-picker-selected", evidence)
        scopeStatus?.stringValue = "QA folder selected; use the explicit sentinel probe to verify write access."
    }
    @objc private func writeSentinel() {
        guard let folder else { record("sentinel-result", ["result": "no-folder"]); return }
        let alert = NSAlert()
        alert.messageText = "Write one synthetic QA sentinel?"
        alert.informativeText = "Only use an empty folder selected for this probe. A new unique file is created exclusively and immediately removed; no existing entry is replaced."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Create and remove")
        guard alert.runModal() == .alertSecondButtonReturn else { record("sentinel-cancelled"); return }
        let target = folder.appendingPathComponent("filemint-p0-" + UUID().uuidString + ".txt")
        let fd = Darwin.open(target.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { record("sentinel-result", ["result": "write-denied", "errno": errno]); return }
        let payload = Array("FileMint synthetic P0 sentinel\n".utf8)
        let count = payload.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        let writeErrno = count < 0 ? errno : 0
        Darwin.close(fd)
        let removed = unlink(target.path) == 0
        record("sentinel-result", ["result": count == payload.count && removed ? "created-and-removed" : "failed", "writeErrno": writeErrno, "removed": removed])
        scopeStatus?.stringValue = count == payload.count && removed ? "Write access verified after Intent return; QA file removed." : "QA sentinel failed; inspect evidence."
    }
    @objc private func openModal() { showModal() }
    private func showModal() {
        showControl()
        guard modal == nil, let control else { return }
        let sheet = makeWindow("QA modal guard", size: NSSize(width: 420, height: 140))
        setContent(sheet, views: [NSTextField(labelWithString: "Run a real Shortcut now: expected result is busy."), button("Close modal", #selector(closeModal))])
        modal = sheet
        control.beginSheet(sheet)
        record("modal-opened")
    }
    @objc private func closeModal() {
        if let modal { control?.endSheet(modal); modal.orderOut(nil) }
        modal = nil
        record("modal-closed")
    }
    @objc private func exportEvidence() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "filemint-launcher-p0-" + invocationID + ".jsonl"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let access = destination.startAccessingSecurityScopedResource()
        defer { if access { destination.stopAccessingSecurityScopedResource() } }
        do { try (logLines.joined(separator: "\n") + "\n").write(to: destination, atomically: true, encoding: .utf8) }
        catch { record("evidence-export-failed", ["code": (error as NSError).code]) }
    }
    private func makeWindow(_ title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
    private func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: self, action: action) }
    private func setContent(_ window: NSWindow, views: [NSView]) {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor), stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor)])
        for view in views where view is NSScrollView || view is NSTextField {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36).isActive = true
        }
        window.contentView = content
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === draft {
            draft = nil; sessionID = nil; scopeStatus = nil; releaseFolder()
            if lastExternalWindow === window { lastExternalWindow = nil }
            record("draft-closed")
            record("external-session-cleared", ["kind": "draft"])
        }
        if window === search {
            search = nil
            if lastExternalWindow === window { lastExternalWindow = nil }
            record("search-closed")
            record("external-session-cleared", ["kind": "search"])
        }
        if window === control { closeModal(); control = nil; logView = nil }
    }
}
