import AppKit
import Sparkle

/// A disposable sandbox host for real Sparkle extraction/replacement/relaunch.
/// Its identifier, archive, local feed and container are separate from FileMint.
@main
@MainActor
final class InstallationSmoke: NSObject, NSApplicationDelegate, SPUUpdaterDelegate, SPUUserDriver {
    private var window: NSWindow!
    private var status: NSTextField!
    private var updater: SPUUpdater!
    private var evidence: NSTextView!

    static func main() {
        let app = NSApplication.shared
        let delegate = InstallationSmoke()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "FileMint Isolated Update QA"
        window.isReleasedWhenClosed = false
        status = NSTextField(wrappingLabelWithString: version == "2" ? "PASS: upgraded and relaunched — build 2" : "Ready — build 1")
        status.font = .systemFont(ofSize: 17, weight: .medium)
        let start = NSButton(title: "Run isolated update", target: self, action: #selector(startUpdate))
        start.isEnabled = version == "1"
        let quit = NSButton(title: "Quit QA", target: self, action: #selector(quit))
        evidence = NSTextView()
        evidence.isEditable = false
        evidence.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let scroll = NSScrollView()
        scroll.documentView = evidence
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 210).isActive = true
        evidence.autoresizingMask = [.width]
        let stack = NSStackView(views: [status, start, quit, scroll])
        stack.orientation = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -30),
            stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor)
        ])
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        record("launch", detail: version)
        if version == "1" {
            updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: self)
            do { try updater.start() }
            catch { fail(error) }
        }
    }

    @objc private func startUpdate() {
        status.stringValue = "Checking isolated update…"
        record("requested")
        updater.checkForUpdates()
    }

    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error { fail(error) }
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { record("checking") }
    func showUpdateFound(with item: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        record("found", detail: item.versionString)
        reply(.install)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) { fail(error); acknowledgement() }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) { fail(error); acknowledgement() }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { status.stringValue = "Downloading…"; record("download") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { status.stringValue = "Extracting…"; record("extract") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        status.stringValue = "Installing and relaunching…"
        record("ready-to-install")
        reply(.install)
    }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        record("installing", detail: String(applicationTerminated))
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func dismissUpdateInstallation() { record("dismissed") }
    func showUpdateInFocus() { window.makeKeyAndOrderFront(nil) }

    private func fail(_ error: Error) {
        let error = error as NSError
        status.stringValue = "FAIL: \(error.domain) \(error.code) — \(error.localizedDescription)"
        record("error", detail: "\(error.domain) \(error.code): \(error.localizedDescription)")
    }

    private func record(_ event: String, detail: String = "") {
        // This is the QA app's private sandbox container, never FileMint's store.
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/UpgradeQA/events.jsonl")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            var data = try JSONSerialization.data(withJSONObject: ["event": event, "detail": detail,
                "pid": ProcessInfo.processInfo.processIdentifier, "bundle": Bundle.main.bundlePath])
            data.append(0x0A)
            if !FileManager.default.fileExists(atPath: url.path) { try Data().write(to: url) }
            let file = try FileHandle(forWritingTo: url)
            defer { try? file.close() }
            try file.seekToEnd()
            try file.write(contentsOf: data)
            evidence.string = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        } catch {
            status.stringValue = "FAIL: could not record QA evidence"
        }
    }
}
