import AppKit
import FileMintCore

/// Uses the production coordinator with isolated preferences/state and synthetic
/// external fixtures. No Finder registration or real FileMint data is touched.
@MainActor
final class MoveSandboxSmoke: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var status: NSTextField!
    private var coordinator: FileMoveCoordinator!
    private var store: PendingFileMoveStore!
    private var tickets: FileMoveTicketStore!
    private var fixture: URL!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            fixture = URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "FixturePath") as! String)
            let local = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("move-smoke")
            store = PendingFileMoveStore(file: local.appendingPathComponent("pending.json"))
            tickets = FileMoveTicketStore(directory: local.appendingPathComponent("requests"))
            let preferencesURL = local.appendingPathComponent("preferences.json")
            var preferences = FileMintPreferences.default
            preferences.monitoredFolderURLs = [fixture]
            preferences.fileTools.isEnabled = true
            preferences.language = .chinese
            try FileMintPreferencesStore(fileURL: preferencesURL).save(preferences)
            coordinator = FileMoveCoordinator(store: store, tickets: tickets, preferencesFile: preferencesURL)
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 180),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "FileMint isolated move regression"
            for (index, action) in [("Prepare selection", #selector(prepare)), ("Move here", #selector(move))].enumerated() {
                let button = NSButton(title: action.0, target: self, action: action.1)
                button.frame = NSRect(x: 18 + index * 220, y: 120, width: 210, height: 32)
                window.contentView?.addSubview(button)
            }
            status = NSTextField(wrappingLabelWithString: "")
            status.frame = NSRect(x: 18, y: 15, width: 625, height: 90)
            window.contentView?.addSubview(status)
            let readable = FileManager.default.isReadableFile(atPath: fixture.appendingPathComponent("source").path)
            status.stringValue = "Sandbox fixture readable before grant: \(readable).\nExisting pending items: \((try store.load())?.items.count ?? 0)."
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch { fatalError("Could not initialize isolated smoke fixture") }
    }

    @objc private func prepare() {
        run(.prepare([fixture.appendingPathComponent("source/图片.png"), fixture.appendingPathComponent("source/Demo.app")]))
    }

    @objc private func move() {
        guard let pending = try? store.load() else { status.stringValue = "No pending selection."; return }
        run(.perform(batchID: pending.id, destination: fixture.appendingPathComponent("target")))
    }

    private func run(_ request: FileMoveRequest) {
        guard !coordinator.isBusy else { return }
        do { coordinator.enqueue(try tickets.enqueue(request)) }
        catch { status.stringValue = "FAIL: enqueue"; return }
        Task {
            while coordinator.isBusy { try? await Task.sleep(for: .milliseconds(100)) }
            status.stringValue = "Request finished. Pending items: \((try? store.load())?.items.count ?? 0)."
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = MoveSandboxSmoke()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
