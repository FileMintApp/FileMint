import AppKit
import FileMintCore
import SwiftUI

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
            do {
                if let path = ProcessInfo.processInfo.environment["FILEMINT_OPEN_WITH_ACCESS_FIXTURE"] {
                    try runFolderAccess(fixture: URL(fileURLWithPath: path, isDirectory: true))
                } else if let mode = ProcessInfo.processInfo.environment["FILEMINT_TERMINAL_MODE"],
                   let requested = TerminalOpenMode(rawValue: mode) {
                    try await runTerminalService(mode: requested)
                } else if ProcessInfo.processInfo.environment["FILEMINT_OPEN_WITH_APP"] == "code" {
                    try await runExternalEditor()
                } else {
                    try await run()
                    print("PASS sandbox open-with: selection and directory delivered, text capture, tickets, sources and clipboard preserved")
                }
                exit(0)
            }
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
    /// Run `grant` and `restore` in separate launches of this same sandboxed app.
    /// Only the first phase presents a picker for a synthetic external fixture.
    private func runFolderAccess(fixture: URL) throws {
        guard fixture.lastPathComponent.hasPrefix("filemint-folder-access-") else {
            throw SmokeFailure("Use a disposable folder-access fixture")
        }
        let directory = fixture.appendingPathComponent("target", isDirectory: true)
        let child = directory.appendingPathComponent("child", isDirectory: true)
        let storage = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fixture.lastPathComponent, isDirectory: true)
        let store = OpenWithFolderAccessStore(file: storage.appendingPathComponent("access.json"))
        let clipboardChangeCount = NSPasteboard.general.changeCount
        let phase = ProcessInfo.processInfo.environment["FILEMINT_OPEN_WITH_ACCESS_PHASE"] ?? "restore"
        guard !FileManager.default.isReadableFile(atPath: directory.path) else {
            throw SmokeFailure("Fixture must start outside this process's sandbox access")
        }
        if phase == "grant" {
            guard try store.load().isEmpty else { throw SmokeFailure("Grant phase requires a fresh store") }
            let cancelled = try OpenWithFolderAccess(store: store, chooseDirectory: { _, _ in nil })
            defer { cancelled.release() }
            guard try !cancelled.authorize(directory, folders: [directory], language: .english),
                  try store.load().isEmpty else { throw SmokeFailure("Cancellation saved a grant") }
            let wrong = try OpenWithFolderAccess(store: store, chooseDirectory: { _, _ in storage })
            defer { wrong.release() }
            do {
                _ = try wrong.authorize(directory, folders: [directory], language: .english)
                throw SmokeFailure("Wrong folder was accepted")
            } catch OpenWithError.wrongAuthorizationFolder {}
            guard try store.load().isEmpty else { throw SmokeFailure("Wrong-folder grant was saved") }
            let access = try OpenWithFolderAccess(store: store)
            defer { access.release() }
            guard try access.authorize(directory, folders: [directory], language: .chinese) else {
                throw SmokeFailure("Fixture authorization cancelled")
            }
            guard try store.load().isEmpty else { throw SmokeFailure("Grant saved before request validation") }
            try access.save()
            guard try store.load()[directory.standardizedFileURL.path] != nil else { throw SmokeFailure("Grant not persisted") }
            print("PASS sandbox folder access: cancellation, wrong folder, explicit grant and persistence")
        } else if phase == "restore" {
            var prompts = 0
            let restricted = try OpenWithFolderAccess(store: store, chooseDirectory: { _, _ in prompts += 1; return nil })
            defer { restricted.release() }
            guard try !restricted.authorize(child, folders: [child], language: .english), prompts == 1 else {
                throw SmokeFailure("Removed ancestor scope was restored")
            }
            prompts = 0
            let access = try OpenWithFolderAccess(store: store, chooseDirectory: { _, _ in prompts += 1; return nil })
            defer { access.release() }
            guard try access.authorize(directory, folders: [directory], language: .english),
                  try access.authorize(child, folders: [directory], language: .english), prompts == 0,
                  try String(contentsOf: child.appendingPathComponent("source.txt"), encoding: .utf8) == "keep me\n" else {
                throw SmokeFailure("Saved read access did not survive relaunch or cover descendants")
            }
            let forbiddenWrite = child.appendingPathComponent("unexpected-write.txt")
            var wrote = false
            do { try Data([1]).write(to: forbiddenWrite, options: .withoutOverwriting); wrote = true } catch {}
            if wrote {
                try? FileManager.default.removeItem(at: forbiddenWrite)
                throw SmokeFailure("Restored grant unexpectedly allowed writes")
            }
            try access.save()
            access.release()
            guard !FileManager.default.isReadableFile(atPath: directory.path) else {
                throw SmokeFailure("Completed request kept its sandbox access")
            }
            print("PASS sandbox folder access: separate-process reuse, descendants, read-only, scope and release")
        } else if phase == "moved" {
            var prompts = 0
            let original = try store.load()
            let access = try OpenWithFolderAccess(store: store, chooseDirectory: { _, _ in prompts += 1; return nil })
            defer { access.release() }
            let allowed = try access.authorize(directory, folders: [directory], language: .english)
            let unchanged = try store.load() == original
            guard !allowed, prompts == 1, unchanged else {
                throw SmokeFailure("Moved grant: allowed=\(allowed), prompts=\(prompts), storageUnchanged=\(unchanged)")
            }
            print("PASS sandbox folder access: moved bookmark rejected, cancelled repair preserves storage")
        } else { throw SmokeFailure("Unknown folder-access phase") }
        guard NSPasteboard.general.changeCount == clipboardChangeCount else { throw SmokeFailure("Clipboard changed") }
    }

    private func runTerminalService(mode: TerminalOpenMode) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("filemint-terminal-qa-\(UUID().uuidString)")
        let folder = root.appendingPathComponent("空格 '\" # % ? : $ ; 🪴\nnext", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let kind = ProcessInfo.processInfo.environment["FILEMINT_TERMINAL_APP"] ?? "terminal"
        let appURL = URL(fileURLWithPath: kind == "warp" ? "/Applications/Warp.app" :
            "/System/Applications/Utilities/Terminal.app")
        let app = try OpenWithApplicationAccess.capture(appURL)
        let resolved = try OpenWithApplicationAccess.resolve(app)
        let started = resolved.startAccessingSecurityScopedResource()
        defer { if started { resolved.stopAccessingSecurityScopedResource() } }
        try OpenWithApplicationAccess.validate(app, at: resolved)
        try await TerminalDirectoryLauncher.open(folder, with: app, applicationURL: resolved, mode: mode)
        print("REQUESTED sandbox \(kind) \(mode.rawValue): \(folder.path)")
    }

    private func runExternalEditor() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("filemint-editor-qa-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = try OpenWithApplicationAccess.capture(URL(fileURLWithPath: "/Applications/Visual Studio Code.app"))
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [folder]
        preferences.openWith.add(app)
        let file = folder.appendingPathComponent("preferences.json")
        try FileMintPreferencesStore(fileURL: file).save(preferences)
        let tickets = FileOperationTicketStore(directory: folder.appendingPathComponent("tickets"))
        let ticket = try tickets.enqueue(.openDirectory(application: app.reference,
            directory: folder, mode: .applicationDefault))
        let coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: folder.appendingPathComponent("move.json")),
            tickets: tickets, preferencesFile: file,
            aliasAccessStore: DesktopAliasAccessStore(file: folder.appendingPathComponent("aliases.json")),
            openWithAccessStore: OpenWithFolderAccessStore(file: folder.appendingPathComponent("open-with-access.json")),
            desktopDirectory: folder, resourceController: ResourceToolsController(preferencesFile: file))
        self.coordinator = coordinator
        coordinator.enqueue(ticket)
        guard coordinator.isBusy else { throw SmokeFailure("Editor request did not hold busy guard") }
        for _ in 0..<80 {
            if !coordinator.isBusy { break }
            try await Task.sleep(for: .milliseconds(125))
        }
        guard !coordinator.isBusy, try tickets.consume(ticket) == nil else {
            throw SmokeFailure("Editor request or ticket did not finish")
        }
        print("REQUESTED sandbox code directory: \(folder.path)")
    }

    private func run() async throws {
        let textBoard = NSPasteboard.withUniqueName()
        defer { textBoard.releaseGlobally() }
        textBoard.clearContents()
        let copied = "  中文 🪴\r\n{{fileName}}  "
        guard textBoard.setString(copied, forType: .string),
              try ClipboardTextReader.capture(from: textBoard) == copied else {
            throw SmokeFailure("Explicit clipboard text was not captured verbatim")
        }
        textBoard.clearContents()
        textBoard.setPropertyList(["/tmp/copied.txt"], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        textBoard.setString("wrong body", forType: .string)
        do {
            _ = try ClipboardTextReader.capture(from: textBoard)
            throw SmokeFailure("Copied file reference was accepted as text")
        } catch ClipboardTextError.unsupported {}

        let unusualPath = URL(fileURLWithPath: "/tmp/空格 '#%? & 🪴", isDirectory: true)
        for mode in [TerminalOpenMode.newTab, .newWindow] {
            let url = try TerminalDirectoryLauncher.warpURL(for: unusualPath, mode: mode)
            guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  parts.scheme == "warp", parts.host == "action",
                  parts.path == (mode == .newTab ? "/new_tab" : "/new_window"),
                  parts.queryItems == [URLQueryItem(name: "path", value: unusualPath.path)] else {
                throw SmokeFailure("Warp directory URL changed a literal path")
            }
        }

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
        let oversizedApp = root.appendingPathComponent("Oversized.app")
        let executableDirectory = oversizedApp.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        _ = FileManager.default.createFile(atPath: executableDirectory.appendingPathComponent("runner").path,
            contents: Data([0]), attributes: [.posixPermissions: 0o755])
        let oversizedInfo: [String: String] = [
            "CFBundlePackageType": "APPL", "CFBundleIdentifier": "example.oversized",
            "CFBundleExecutable": "runner", "Padding": String(repeating: "x", count: 1_048_576)
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: oversizedInfo, format: .xml, options: 0)
        try plist.write(to: oversizedApp.appendingPathComponent("Contents/Info.plist"))
        do {
            _ = try OpenWithApplicationAccess.capture(oversizedApp)
            throw SmokeFailure("Oversized application metadata was accepted")
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
            openWithAccessStore: OpenWithFolderAccessStore(file: root.appendingPathComponent("open-with-access.json")),
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
        try FileManager.default.removeItem(at: receipt)
        let directoryTicket = try tickets.enqueue(.openDirectory(application: app.reference,
            directory: folder, mode: .applicationDefault))
        coordinator.enqueue(directoryTicket)
        guard coordinator.isBusy else { throw SmokeFailure("Directory request did not hold busy guard") }
        for _ in 0..<80 {
            if !coordinator.isBusy && FileManager.default.fileExists(atPath: receipt.path) { break }
            try await Task.sleep(for: .milliseconds(125))
        }
        guard !coordinator.isBusy else { throw SmokeFailure("Directory request did not finish") }
        let directoryReceived = try JSONDecoder().decode([URL].self, from: Data(contentsOf: receipt))
        guard directoryReceived == [folder], try tickets.consume(directoryTicket) == nil,
              NSPasteboard.general.changeCount == clipboardChangeCount else {
            throw SmokeFailure("Directory target, ticket or clipboard assertion failed")
        }
    }
    #endif
}

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
