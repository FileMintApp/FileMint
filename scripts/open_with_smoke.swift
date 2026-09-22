import AppKit
import FileMintCore

/// A real receiver app proves that NSWorkspace delivered the complete selection.
/// Both modes use only disposable fixture files, never the user's preferences.
@main
@MainActor
final class OpenWithSmoke: NSObject, NSApplicationDelegate {
    #if !OPEN_WITH_RECEIVER
    private var coordinator: FileOperationCoordinator?
    #endif

    static func main() {
        let app = NSApplication.shared
        let delegate = OpenWithSmoke()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !OPEN_WITH_RECEIVER
        Task {
            do { try await run(); print("PASS sandbox open-with: selection delivered, ticket consumed, sources and clipboard preserved"); exit(0) }
            catch { print("FAIL sandbox open-with: \(error)"); exit(1) }
        }
        #endif
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        #if OPEN_WITH_RECEIVER
        do {
            guard let first = urls.first else { throw OpenWithError.missingSelection }
            let receipt = first.deletingLastPathComponent().appendingPathComponent("receipt.json")
            try JSONEncoder().encode(urls).write(to: receipt, options: .atomic)
            NSApp.terminate(nil)
        } catch { exit(2) }
        #endif
    }

    #if !OPEN_WITH_RECEIVER
    private func run() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("open-with-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let document = root.appendingPathComponent("资料 % & 🪴.txt")
        let folder = root.appendingPathComponent("A folder", isDirectory: true)
        let content = Data("Open with App fixture".utf8)
        try content.write(to: document)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OpenWithReceiver.app")
        let app = try OpenWithApplicationAccess.capture(target)
        let resolved = try OpenWithApplicationAccess.resolve(app)
        let started = resolved.startAccessingSecurityScopedResource()
        defer { if started { resolved.stopAccessingSecurityScopedResource() } }
        try OpenWithApplicationAccess.validate(app, at: resolved)
        var wrongIdentity = app
        wrongIdentity.bundleIdentifier = "example.wrong"
        do {
            try OpenWithApplicationAccess.validate(wrongIdentity, at: resolved)
            throw SmokeFailure("Changed application identity was accepted")
        } catch OpenWithError.unavailableApplication {}
        do {
            _ = try OpenWithApplicationAccess.capture(folder)
            throw SmokeFailure("Ordinary directory was accepted as an app")
        } catch OpenWithError.invalidApplication {}
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.openWith.add(app)
        let file = root.appendingPathComponent("preferences.json")
        try FileMintPreferencesStore(fileURL: file).save(preferences)
        let tickets = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
        let selection = [document, folder]
        let ticket = try tickets.enqueue(.openWith(application: app.reference, selection: selection))
        let clipboardChangeCount = NSPasteboard.general.changeCount
        let coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: root.appendingPathComponent("move.json")),
            tickets: tickets, preferencesFile: file,
            aliasAccessStore: DesktopAliasAccessStore(file: root.appendingPathComponent("aliases.json")),
            desktopDirectory: root, resourceController: ResourceToolsController(preferencesFile: file))
        self.coordinator = coordinator
        coordinator.enqueue(ticket)
        guard coordinator.isBusy else { throw SmokeFailure("Open request did not hold busy guard") }
        let receipt = root.appendingPathComponent("receipt.json")
        for _ in 0..<80 {
            if !coordinator.isBusy && FileManager.default.fileExists(atPath: receipt.path) { break }
            try await Task.sleep(for: .milliseconds(125))
        }
        guard !coordinator.isBusy else { throw SmokeFailure("Open request did not finish") }
        let received = try JSONDecoder().decode([URL].self, from: Data(contentsOf: receipt))
        guard received.map(\.path) == selection.map(\.path), try tickets.consume(ticket) == nil,
              try Data(contentsOf: document) == content,
              FileManager.default.fileExists(atPath: folder.path),
              NSPasteboard.general.changeCount == clipboardChangeCount else {
            throw SmokeFailure("Selection, ticket, source preservation or clipboard assertion failed")
        }
    }
    #endif
}

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
