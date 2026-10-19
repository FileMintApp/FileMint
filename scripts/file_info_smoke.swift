import AppKit
import FileMintCore

private enum SmokeFailure: Error { case failed(String) }
private func check(_ condition: @autoclosure () throws -> Bool, _ description: String) throws {
    if try !condition() { throw SmokeFailure.failed(description) }
}

/// A deliberate blocked read tests cleanup ownership without timing assumptions.
private final class ReadGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var started = false
    private var permitted = false
    var hasStarted: Bool { condition.lock(); defer { condition.unlock() }; return started }
    func block() {
        condition.lock(); started = true
        while !permitted { condition.wait() }
        condition.unlock()
    }
    func allow() { condition.lock(); permitted = true; condition.broadcast(); condition.unlock() }
}

@main
@MainActor
final class FileInfoSmoke: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = FileInfoSmoke()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                try await runChecks()
                print("PASS file information: metadata-only open; five algorithms; copy/compare; cancellation; serialized tickets; source preserved")
                exit(0)
            } catch { print("FAIL file information: \(error)"); exit(1) }
        }
    }

    private func wait(_ description: String, until predicate: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !predicate() {
            guard Date() < deadline else { throw SmokeFailure.failed("Timed out: \(description)") }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func runChecks() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("file-info-qa-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("校验 example 🪴.txt")
        let original = Data("abc".utf8)
        try original.write(to: source)
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: source.path)
        let selection = try FileInfoSelection.capture([source])
        let prefsURL = root.appendingPathComponent("preferences.json")
        let store = FileMintPreferencesStore(fileURL: prefsURL)
        var preferences = FileMintPreferences.default
        preferences.language = .chinese; preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true; preferences.fileTools.fileInfo = true
        try store.save(preferences)
        var reserved = false
        let model = FileInfoController(preferencesFile: prefsURL, acquire: {
            if reserved { return false }; reserved = true; return true
        }, release: { reserved = false })
        try await model.present(selection)
        try check(model.choice == .sha256 && model.result == nil && model.metadata?.logicalSize == 3, "Initial information and SHA-256")
        try check(!model.isWorking && !reserved && model.progress == nil, "Opening must not calculate or retain guard")
        for choice in FileDigestChoice.allCases {
            model.select(choice); model.calculate()
            try check(reserved && model.isRunning && model.result == nil, "Calculation reserves guard and invalidates results")
            model.select(choice == .md5 ? .sha1 : .md5)
            try check(model.choice == choice, "Selection is frozen")
            try await wait("calculation") { !model.isWorking }
            try check(!reserved && model.result?.choice == choice, "Guard released on completion")
            try check(model.result?.values.map(\.algorithm) == choice.algorithms, "Exact selected algorithms")
        }
        let board = NSPasteboard(name: .init("filemint-info-qa-\(UUID())"))
        defer { board.releaseGlobally() }
        model.copyResult(to: board)
        let all = board.string(forType: .string) ?? ""
        try check(all.hasPrefix("MD5: 900150983cd24fb0d6963f7d28e17f72\nSHA-1: a9993e364706816aba3e25717850c26c9cd0d89d\n"), "Copy all exact order")
        try check(all.split(separator: "\n").count == 4 && !all.hasSuffix("\n") && !all.contains(source.path), "Copy contains only digests")
        model.copyResult(.sha512, to: board)
        try check(board.string(forType: .string)?.count == 128, "SHA-512 copies continuous text")
        try render(model, name: "zh-light-all")
        model.select(.sha256)
        try check(model.result == nil, "Selection invalidates completed results")
        model.copyResult(to: board)
        try check(board.string(forType: .string)?.count == 128, "Stale copy does not change clipboard")
        model.calculate()
        try await wait("SHA-256") { !model.isWorking }
        model.expectedChecksum = " BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD\n"
        try check(model.comparison == .match, "Comparison binding")
        model.expectedChecksum = String(repeating: "0", count: 64)
        try check(model.comparison == .mismatch, "Mismatch binding")
        guard let infoPanel = model.panel else { throw SmokeFailure.failed("Missing information panel") }
        let returnKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: infoPanel.windowNumber, context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
        let multiline = NSTextView(frame: NSRect(x: 0, y: 0, width: 180, height: 60))
        infoPanel.contentView!.addSubview(multiline)
        try check(infoPanel.makeFirstResponder(multiline), "Native multiline editing focus")
        infoPanel.sendEvent(returnKey)
        try check(!model.isRunning && multiline.string.contains("\n"), "Return edits multiline input without calculating")
        multiline.removeFromSuperview()
        let singleLine = NSTextField(string: "single line")
        singleLine.frame = NSRect(x: 0, y: 0, width: 180, height: 24)
        infoPanel.contentView!.addSubview(singleLine)
        try check(infoPanel.makeFirstResponder(singleLine), "Native single-line editing focus")
        infoPanel.sendEvent(returnKey)
        try check(model.isRunning, "Return in single-line editing runs the enabled primary action")
        try await wait("Return calculation") { !model.isWorking }
        singleLine.removeFromSuperview()
        let commandW = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: infoPanel.windowNumber, context: nil, characters: "w", charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13)!
        try check(infoPanel.performKeyEquivalent(with: commandW), "Command-W is handled by the information panel")
        try check(model.panel == nil && model.result == nil, "Closed window retains no digest")

        // Coordinator owns intake and reading separately; new requests are
        // consumed immediately while the actual production reader is blocked.
        let ticketsURL = root.appendingPathComponent("tickets")
        let tickets = FileOperationTicketStore(directory: ticketsURL)
        let gate = ReadGate()
        let coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: root.appendingPathComponent("pending.json")),
            tickets: tickets, preferencesFile: prefsURL, fileInfoReader: { selection, choice, token, progress in
                try FileDigestService.calculate(selection, choice: choice, cancellation: token) { value in
                    progress(value)
                    if value.bytesRead == 0 { gate.block() }
                }
            })
        coordinator.enqueue(try tickets.enqueue(.fileInfo(selection)))
        try check(coordinator.isBusy, "Intake reserves ownership synchronously")
        try await wait("information intake") { !coordinator.isBusy }
        let controller = coordinator.fileInfoController
        try check(controller.panel != nil && controller.result == nil && controller.choice == .sha256 && !gate.hasStarted, "Ticket opens information without content reads")
        controller.calculate()
        try await wait("read gate") { gate.hasStarted }
        try check(coordinator.isBusy, "Active read blocks mutation")
        for request in [FileOperationRequest.fileInfo(selection), .prepare([source])] {
            let url = try tickets.enqueue(request)
            let id = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems![0].value!
            coordinator.enqueue(url)
            try await wait("busy consumption") {
                !FileManager.default.fileExists(atPath: ticketsURL.appendingPathComponent("\(id).json").path)
            }
            try check(try tickets.consume(url) == nil, "Busy ticket is single-use and never queued")
        }
        controller.requestClose()
        try check(controller.isCancelling && coordinator.isBusy && controller.result == nil, "Close waits for descriptor cleanup")
        var cleanupFinished = false
        let waiter = Task { await controller.cancelAndWait(); cleanupFinished = true }
        await Task.yield()
        try check(!cleanupFinished && coordinator.isBusy, "Termination waits while a read still owns its descriptor")
        gate.allow()
        await waiter.value
        try await wait("close cleanup") { !coordinator.isBusy && controller.panel == nil }
        try check(!FileManager.default.fileExists(atPath: root.appendingPathComponent("pending.json").path), "Rejected move never prepared later")

        // Current policy changes are authoritative even for an already open panel.
        preferences.language = .english
        try store.save(preferences)
        try await model.present(selection)
        model.select(.md5)
        try render(model, name: "en-dark-legacy", dark: true)
        preferences.fileTools.fileInfo = false; try store.save(preferences)
        model.calculate()
        try await wait("revoked policy") { !model.isWorking }
        try check(model.result == nil && model.feedback == .disabled && !reserved, "Revoked switch rejects old panel")
        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: model.panel!.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
        try check(model.panel!.performKeyEquivalent(with: escape) && model.panel == nil, "Escape closes and clears the panel")
        try check(try Data(contentsOf: source) == original, "Read-only source is preserved")
        try check(NSApp.windows.allSatisfy { !$0.isVisible }, "No settings window opened")
    }

    private func render(_ model: FileInfoController, name: String, dark: Bool = false) throws {
        guard let panel = model.panel, let view = panel.contentView else { throw SmokeFailure.failed("Missing native panel") }
        panel.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        panel.setContentSize(NSSize(width: 520, height: 480))
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw SmokeFailure.failed("Missing native render") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw SmokeFailure.failed("Missing PNG") }
        if ProcessInfo.processInfo.environment["FILEMINT_FILE_INFO_EXPORT_ARTIFACTS"] == "1" {
            let record: [String: String] = ["artifact": name, "pngBase64": png.base64EncodedString()]
            print(String(decoding: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), as: UTF8.self))
        }
    }
}
