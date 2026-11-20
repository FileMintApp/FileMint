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
                if CommandLine.arguments.dropFirst().first == "--verify-default-application" {
                    try await DefaultApplicationChecks.run()
                } else if CommandLine.arguments.dropFirst().first == "--default-application-fixture",
                          CommandLine.arguments.count == 3 {
                    try await DefaultApplicationChecks.runFixture(CommandLine.arguments[2])
                } else if let path = ProcessInfo.processInfo.environment["FILEMINT_OPEN_WITH_ACCESS_FIXTURE"] {
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
        let appPath: String
        switch kind {
        case "warp": appPath = "/Applications/Warp.app"
        case "otty": appPath = "/Applications/Otty.app"
        case "ghostty": appPath = "/Applications/Ghostty.app"
        default: appPath = "/System/Applications/Utilities/Terminal.app"
        }
        let appURL = URL(fileURLWithPath: appPath)
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
        let folder = root.appendingPathComponent("A folder ' # % 🪴", isDirectory: true)
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
        try FileManager.default.removeItem(at: receipt)
        // The receiver stands in for the already-validated configured Otty app.
        var otty = app
        otty.bundleIdentifier = "io.appmakes.otty"
        do {
            try await TerminalDirectoryLauncher.open(folder, with: otty, applicationURL: resolved, mode: .newWindow)
            throw SmokeFailure("Otty accepted the unsupported new-window mode")
        } catch OpenWithError.unsupportedTerminal {}
        guard !FileManager.default.fileExists(atPath: receipt.path) else {
            throw SmokeFailure("Unsupported Otty mode dispatched a folder")
        }
        try await TerminalDirectoryLauncher.open(folder, with: otty, applicationURL: resolved, mode: .newTab)
        for _ in 0..<80 {
            if FileManager.default.fileExists(atPath: receipt.path) { break }
            try await Task.sleep(for: .milliseconds(125))
        }
        let ottyReceived = try JSONDecoder().decode([URL].self, from: Data(contentsOf: receipt))
        guard ottyReceived == [folder], NSPasteboard.general.changeCount == clipboardChangeCount else {
            throw SmokeFailure("Otty directory dispatch changed the folder or clipboard")
        }
        try await checkQueuedTicketIntake(root: root, first: document, second: folder)
        try await checkDrawerOpenWith(root: root, app: app)
    }

    private func checkDrawerOpenWith(root: URL, app: OpenWithApplication) async throws {
        let source = root.appendingPathComponent("Drawer", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        let regular = source.appendingPathComponent("未知.drawer-unknown")
        let folder = source.appendingPathComponent("A folder", isDirectory: true)
        let text = source.appendingPathComponent("Known.txt")
        try Data("original".utf8).write(to: regular)
        try Data("plain text".utf8).write(to: text)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let link = source.appendingPathComponent("outside")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        let directory = try FileDrawerDirectory(root: source)
        let rows = try directory.list()
        guard let unknown = rows.first(where: { $0.name == regular.lastPathComponent }),
              let subfolder = rows.first(where: { $0.name == folder.lastPathComponent }),
              let plain = rows.first(where: { $0.name == text.lastPathComponent }),
              let outside = rows.first(where: { $0.name == link.lastPathComponent }) else {
            throw SmokeFailure("Missing Open With fixtures")
        }
        let mixed = [unknown, subfolder]
        let saved = try await FileDrawerOpenWith.candidates(for: mixed, configured: [app])
        guard let first = saved.first, first.url.path == app.url.path,
              Set(saved.map(\.url)).count == saved.count else { throw SmokeFailure("Missing or duplicated configured app") }
        let system = try await FileDrawerOpenWith.candidates(for: [plain], configured: [])
        let supported = Set(NSWorkspace.shared.urlsForApplications(toOpen: plain.url).map { $0.resolvingSymlinksInPath().standardizedFileURL })
        guard !system.isEmpty, system.allSatisfy({ supported.contains($0.url) }) else {
            throw SmokeFailure("Text file has no validated LaunchServices candidates")
        }
        func picked(_ url: URL, stage: String) async throws -> FileDrawerOpenWith.Candidate {
            do { return try await FileDrawerOpenWith.picked(url) }
            catch {
                let executable = url.appendingPathComponent("Contents/MacOS/OpenWithReceiver").path
                let attributes = try? FileManager.default.attributesOfItem(atPath: executable)
                let mode = attributes?[.posixPermissions] as? NSNumber
                let recognized = try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication
                throw SmokeFailure("\(stage): \(error), app=\(recognized == true), executable=\(FileManager.default.isExecutableFile(atPath: executable)), mode=\(mode?.intValue ?? -1)")
            }
        }
        let other = try await picked(app.url, stage: "Choosing the embedded receiver")
        let receipt = source.appendingPathComponent("receipt.json")
        for (candidate, selection) in [(first, mixed), (other, [subfolder])] {
            try await FileDrawerOpenWith.open(candidate, directory: directory, items: selection,
                                              currentApps: { [app] }, isCurrent: { true })
            for _ in 0..<80 {
                if FileManager.default.fileExists(atPath: receipt.path) { break }
                try await Task.sleep(for: .milliseconds(125))
            }
            let received = try JSONDecoder().decode([URL].self, from: Data(contentsOf: receipt))
            guard received.map(\.path) == selection.map({ $0.url.path }) else {
                throw SmokeFailure("Drawer Open With changed the selected file/folder URLs")
            }
            try FileManager.default.removeItem(at: receipt)
        }
        do {
            try await FileDrawerOpenWith.open(first, directory: directory, items: mixed,
                                              currentApps: { [] }, isCurrent: { true })
            throw SmokeFailure("Removed configured app could still open the selection")
        } catch OpenWithError.changedConfiguration {}
        do {
            try await FileDrawerOpenWith.open(other, directory: directory, items: [outside],
                                              currentApps: { [] }, isCurrent: { true })
            throw SmokeFailure("Open With followed a link outside the drawer root")
        } catch FileInfoError.accessDenied {}
        do {
            try await FileDrawerOpenWith.open(other, directory: directory, items: mixed,
                                              currentApps: { [] }, isCurrent: { false })
            throw SmokeFailure("Dismissed chooser opened its old selection")
        } catch is CancellationError {}
        let temporaryApp = root.appendingPathComponent("Chosen.app", isDirectory: true)
        func makeIdentityFixture() throws {
            try FileManager.default.copyItem(at: app.url, to: temporaryApp)
            // The sandbox denies X_OK on newly copied executables in its temporary
            // directory, even with mode 0755. This fixture varies only the bundle
            // directory's identity and uses the signed receiver as its binary.
            let executable = "Contents/MacOS/OpenWithReceiver"
            let copy = temporaryApp.appendingPathComponent(executable)
            try FileManager.default.removeItem(at: copy)
            try FileManager.default.createSymbolicLink(at: copy, withDestinationURL: app.url.appendingPathComponent(executable))
        }
        try makeIdentityFixture()
        let chosenCandidate = try await picked(temporaryApp, stage: "Choosing the temporary receiver copy")
        let savedCopy = try OpenWithApplicationAccess.capture(temporaryApp)
        let configuredCopyCandidates = try await FileDrawerOpenWith.candidates(for: [plain], configured: [savedCopy])
        guard let savedCandidate = configuredCopyCandidates.first, savedCandidate.url.path == savedCopy.url.path else {
            throw SmokeFailure("Could not present a configured temporary app")
        }
        try FileManager.default.moveItem(at: temporaryApp, to: root.appendingPathComponent("Old.app", isDirectory: true))
        try makeIdentityFixture()
        for candidate in [chosenCandidate, savedCandidate] {
            do {
                // A regression must fail before dispatching the temporary app.
                try await FileDrawerOpenWith.open(candidate, directory: directory, items: mixed,
                                                  currentApps: { [savedCopy] }, isCurrent: { false })
                throw SmokeFailure("Chooser launched a same-path, same-bundle-ID replacement application")
            } catch OpenWithError.unavailableApplication {}
        }
        try FileManager.default.moveItem(at: regular, to: source.appendingPathComponent("Retained"))
        try Data("replacement".utf8).write(to: regular)
        do {
            try await FileDrawerOpenWith.open(other, directory: directory, items: mixed,
                                              currentApps: { [] }, isCurrent: { true })
            throw SmokeFailure("Open With dispatched a replaced file")
        } catch FileMoveError.sourceChanged {}
        print("PASS drawer Open With: validated system and configured candidates, explicit receiver, mixed and folder delivery, cancelled and stale selections")
    }

    private func checkQueuedTicketIntake(root: URL, first: URL, second: URL) async throws {
        let preferencesFile = root.appendingPathComponent("queue-preferences.json")
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true
        preferences.resourceTools.isEnabled = true
        try FileMintPreferencesStore(fileURL: preferencesFile).save(preferences)
        let image = root.appendingPathComponent("queue-blocker.png")
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let bytes = bitmap.representation(using: .png, properties: [:]) else {
            throw SmokeFailure("Could not create queue image fixture")
        }
        try bytes.write(to: image)
        let ticketDirectory = root.appendingPathComponent("queue-tickets")
        let tickets = FileOperationTicketStore(directory: ticketDirectory)
        let pending = PendingFileMoveStore(file: root.appendingPathComponent("queue-pending.json"))
        let resources = ResourceToolsController(preferencesFile: preferencesFile)
        let clock = TicketClock()
        let coordinator = FileOperationCoordinator(store: pending, tickets: tickets, preferencesFile: preferencesFile,
            resourceController: resources, ticketClock: { clock.read() })
        self.coordinator = coordinator
        coordinator.enqueue(try tickets.enqueue(.resource(tool: .convert, selection: [image]), now: clock.read()))
        var resourceWindow: NSWindow?
        for _ in 0..<100 {
            resourceWindow = NSApp.windows.first { $0.title == ResourceTool.convert.title(preferences.language) && $0.isVisible }
            if resourceWindow != nil && !resources.isPreparing { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        guard let resourceWindow, coordinator.isBusy else { throw SmokeFailure("Resource panel did not hold queue ownership") }
        defer { if resourceWindow.isVisible { resourceWindow.close() } }
        let issuedAt = clock.read()
        let firstTicket = try tickets.enqueue(.prepare([first]), now: issuedAt)
        let secondTicket = try tickets.enqueue(.prepare([second]), now: issuedAt)
        coordinator.enqueue(firstTicket)
        coordinator.enqueue(secondTicket)
        // Advance before detached work is guaranteed to run: eligibility is
        // captured at receipt, while execution remains behind the resource panel.
        clock.advance(by: 61)
        coordinator.enqueue(try tickets.enqueue(.prepare([first]), now: issuedAt))
        for _ in 0..<100 {
            if try FileManager.default.contentsOfDirectory(at: ticketDirectory, includingPropertiesForKeys: nil).isEmpty { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        guard try FileManager.default.contentsOfDirectory(at: ticketDirectory, includingPropertiesForKeys: nil).isEmpty,
              coordinator.isBusy, try pending.load() == nil else {
            throw SmokeFailure("Queued tickets were not claimed promptly or executed before the active panel closed")
        }
        resourceWindow.close()
        for _ in 0..<100 where coordinator.isBusy { try await Task.sleep(for: .milliseconds(20)) }
        guard !coordinator.isBusy, let saved = try pending.load(), saved.items.map(\.source) == [second] else {
            throw SmokeFailure("Queued requests expired, lost FIFO order, or accepted an expired inbound ticket")
        }
        coordinator.enqueue(firstTicket)
        for _ in 0..<100 where coordinator.isBusy { try await Task.sleep(for: .milliseconds(20)) }
        guard !coordinator.isBusy, try pending.load() == saved else { throw SmokeFailure("Consumed queue ticket replayed") }
        print("PASS queued ticket intake: receipt-time TTL, resource-panel wait, FIFO, expired inbound rejection, replay and busy guard")
    }
    #endif
}

private final class TicketClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date()
    func read() -> Date { lock.lock(); defer { lock.unlock() }; return date }
    func advance(by interval: TimeInterval) { lock.lock(); defer { lock.unlock() }; date.addTimeInterval(interval) }
}

private struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
