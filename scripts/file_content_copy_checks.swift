import AppKit
import FileMintCore

private struct ContentCheckFailure: Error { let message: String }
private func contentCheck(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try value() else { throw ContentCheckFailure(message: message) }
}

private final class ContentReadGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var started = false
    private var allowed = false
    var hasStarted: Bool { condition.lock(); defer { condition.unlock() }; return started }
    func block() {
        condition.lock(); started = true
        while !allowed { condition.wait() }
        condition.unlock()
    }
    func allow() { condition.lock(); allowed = true; condition.broadcast(); condition.unlock() }
}

@MainActor
func runFileContentCopyChecks(in root: URL) async throws {
    func wait(_ description: String, until predicate: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !predicate() {
            guard Date() < deadline else { throw ContentCheckFailure(message: "Timed out: \(description)") }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    let board = NSPasteboard(name: .init("filemint-content-qa-\(UUID())"))
    defer { board.releaseGlobally() }
    func seed(_ text: String = "keep previous clipboard") {
        board.clearContents(); precondition(board.setString(text, forType: .string))
    }

    // Independently authored RTF, not a round trip through the importer/exporter.
    let rtf = Data(#"{\rtf1\ansi\ansicpg1252\deff0\uc1{\fonttbl{\f0\fnil Helvetica;}}{\colortbl;\red255\green0\blue0;}\f0\fs24\qc\b\cf1 Bold \u20013?\u25991?\b0\cf0\par\ql\i Italic\i0\tab last}"#.utf8)
    let expected = "Bold 中文\nItalic\tlast"
    let richPayload = try FileContentClipboard.prepareRTF(rtf)
    try contentCheck(richPayload.rtf == rtf && richPayload.text == expected, "Full RTF bytes and complete Unicode text")
    seed()
    try FileContentClipboard.write(richPayload, to: board, expectedChangeCount: board.changeCount)
    try contentCheck(board.data(forType: .rtf) == rtf, "Original rich bytes were not re-encoded")
    try contentCheck(board.pasteboardItems?.count == 1, "All representations belong to one item")
    let rich = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 180))
    rich.isRichText = true
    try contentCheck(rich.readSelection(from: board), "Native rich NSTextView accepts the real pasteboard")
    try contentCheck(rich.string == expected, "Rich paste contains all text and paragraphs")
    let bold = rich.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    try contentCheck(bold.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true, "Bold font retained")
    // RTF uses calibrated RGB; a display-profile conversion changes components.
    let color = (rich.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?.usingColorSpace(.genericRGB)
    try contentCheck((color?.redComponent ?? 0) > 0.99 && (color?.greenComponent ?? 1) < 0.01
                        && (color?.blueComponent ?? 1) < 0.01,
                     "Text color retained: \(String(describing: color))")
    let paragraph = rich.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    try contentCheck(paragraph?.alignment == .center, "Paragraph alignment retained")
    let italicIndex = (expected as NSString).range(of: "Italic").location
    let italic = rich.textStorage?.attribute(.font, at: italicIndex, effectiveRange: nil) as? NSFont
    try contentCheck(italic.map { NSFontManager.shared.traits(of: $0).contains(.italicFontMask) } == true, "Italic font retained")
    let plain = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 180))
    plain.isRichText = false
    try contentCheck(plain.readSelection(from: board), "Native plain NSTextView accepts the companion text")
    try contentCheck(plain.string == expected, "Plain paste is complete")
    seed()
    let oldCount = board.changeCount
    seed("newer clipboard")
    do {
        try FileContentClipboard.write(richPayload, to: board, expectedChangeCount: oldCount)
        throw ContentCheckFailure(message: "Stale clipboard publication succeeded")
    } catch FileContentCopyError.clipboardChanged {}
    try contentCheck(board.string(forType: .string) == "newer clipboard", "Newer clipboard preserved")
    print("PASS RTF native paste: original bytes; complete Unicode text; rich/plain NSTextView; bold/italic/color/paragraph attributes")

    let directory = root.appendingPathComponent("contents", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    let prefsURL = directory.appendingPathComponent("preferences.json")
    let store = FileMintPreferencesStore(fileURL: prefsURL)
    var prefs = FileMintPreferences.default
    prefs.language = .chinese; prefs.monitoredFolderURLs = [directory]
    prefs.fileTools.isEnabled = true; prefs.fileTools.copyContents = true
    try store.save(prefs)
    let prefsData = try Data(contentsOf: prefsURL)
    let source = directory.appendingPathComponent("代码 🪴.swift")
    let original = Data("// 中文 🪴\r\n\tlet value = \"e\u{301}\"\n\n".utf8)
    try original.write(to: source)
    let tickets = FileOperationTicketStore(directory: directory.appendingPathComponent("tickets"))
    let pending = directory.appendingPathComponent("pending.json")
    let coordinator = FileOperationCoordinator(store: PendingFileMoveStore(file: pending), tickets: tickets,
        preferencesFile: prefsURL, contentPasteboard: board)
    seed()
    let ticket = try tickets.enqueue(.copyContents(selection: FileInfoSelection.capture([source]), pasteboardChangeCount: board.changeCount))
    coordinator.enqueue(ticket)
    try contentCheck(coordinator.isBusy, "Copy intake reserves the operation guard synchronously")
    try await wait("copy completion") { !coordinator.isBusy }
    try contentCheck(coordinator.contentCopyController.didCopy, "Production ticket/controller copied")
    try contentCheck(board.string(forType: .string).map { Data($0.utf8) } == original, "Exact source content including CRLF and combining mark")
    try contentCheck(board.data(forType: .fileURL) == nil && board.data(forType: .rtf) == nil, "Plain text has no file or rich representation")
    try contentCheck(try tickets.consume(ticket) == nil, "Copy ticket cannot replay")
    try contentCheck(try Data(contentsOf: source) == original, "Source bytes unchanged")
    try contentCheck(try Data(contentsOf: prefsURL) == prefsData, "Preferences not changed by copy")
    coordinator.contentCopyController.requestClose()

    let controller = FileContentCopyController(preferencesFile: prefsURL, pasteboard: board)
    defer { controller.requestClose(); coordinator.contentCopyController.requestClose() }
    for (name, bytes) in [("empty.txt", Data()), ("binary.txt", Data([65, 0, 66])), ("legacy.txt", Data([0xD6, 0xD0]))] {
        let file = directory.appendingPathComponent(name); try bytes.write(to: file)
        seed(); let counter = board.changeCount
        await controller.copy(try FileInfoSelection.capture([file]), expectedChangeCount: counter)
        try contentCheck(!controller.didCopy && board.changeCount == counter, "Invalid input preserves board: \(name)")
        controller.requestClose()
    }
    let richFile = directory.appendingPathComponent("sample.rtf")
    try rtf.write(to: richFile)
    try contentCheck(FileContentCopyPolicy.supportsMenuSelection([richFile]), "Validated RTF has a Finder menu candidate")
    seed()
    await controller.copy(try FileInfoSelection.capture([richFile]), expectedChangeCount: board.changeCount)
    try contentCheck(controller.didCopy && board.data(forType: .rtf) == rtf, "Admitted RTF traverses production reader/controller")
    controller.requestClose()
    for (name, bytes) in [("truncated.rtf", Data(#"{\rtf1 lost"#.utf8)),
                          ("attachment.rtf", Data(#"{\rtf1 text {\pict bad}}"#.utf8))] {
        let file = directory.appendingPathComponent(name); try bytes.write(to: file)
        seed(); let counter = board.changeCount
        await controller.copy(try FileInfoSelection.capture([file]), expectedChangeCount: counter)
        try contentCheck(!controller.didCopy && board.changeCount == counter, "Unsupported RTF preserves board")
        controller.requestClose()
    }

    for scenario in ["clipboard", "file", "policy", "cancel"] {
        try original.write(to: source); try store.save(prefs)
        let selection = try FileInfoSelection.capture([source])
        let gate = ContentReadGate()
        let gated = FileOperationCoordinator(store: PendingFileMoveStore(file: pending), tickets: tickets,
            preferencesFile: prefsURL, contentPasteboard: board, contentReader: { selection, token in
                let contents = try FileContentRead.read(selection, cancellation: token)
                gate.block()
                try token.check()
                return contents
            })
        seed(); let counter = board.changeCount
        gated.enqueue(try tickets.enqueue(.copyContents(selection: selection, pasteboardChangeCount: counter)))
        try await wait("worker gate") { gate.hasStarted }
        do {
            if scenario == "clipboard" { seed("newer content during read") }
            if scenario == "file" { try Data("different file content".utf8).write(to: source) }
            if scenario == "policy" { var revoked = prefs; revoked.fileTools.copyContents = false; try store.save(revoked) }
            let refused = try tickets.enqueue(.prepare([source]))
            gated.enqueue(refused)
            let ticketID = URLComponents(url: refused, resolvingAgainstBaseURL: false)!.queryItems![0].value!
            try await wait("busy request consumed") {
                !FileManager.default.fileExists(atPath: directory.appendingPathComponent("tickets/\(ticketID).json").path)
            }
            try contentCheck(gated.isBusy, "Busy rejection cannot release the read guard")
            var cleanupDone = false
            let cancellation: Task<Void, Never>? = scenario == "cancel" ? Task {
                await gated.cancelActiveReadsAndWait(); cleanupDone = true
            } : nil
            if cancellation != nil {
                try await Task.sleep(for: .milliseconds(30))
                try contentCheck(!cleanupDone && gated.isBusy, "Cancellation waits for the real worker")
            }
            gate.allow()
            await cancellation?.value
            try await wait("failure cleanup") { !gated.isBusy }
            try contentCheck(!gated.contentCopyController.didCopy, "No publication after \(scenario) change")
            try contentCheck(board.string(forType: .string) == (scenario == "clipboard" ? "newer content during read" : "keep previous clipboard"), "Clipboard preserved after \(scenario)")
            try contentCheck(!FileManager.default.fileExists(atPath: pending.path), "Busy move was never prepared")
            gated.contentCopyController.requestClose()
        } catch { gate.allow(); await gated.cancelActiveReadsAndWait(); throw error }
    }
    print("PASS file contents: exact production text copy; failures preserve clipboard; change detection; revoked policy; cancellation cleanup; busy tickets consumed")
}
