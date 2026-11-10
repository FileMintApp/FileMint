import AppKit
import Darwin
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
private func checkAuthorizationPanelAndDenial(in root: URL) throws {
    let file = root.appendingPathComponent("authorization.txt")
    try Data("fixture".utf8).write(to: file)
    let filePanel = FolderAccess.authorizationPanel(for: file, selection: .file, language: .chinese)
    try contentCheck(filePanel.prompt == "授权" && filePanel.message.contains("允许 FileMint 读取文件“authorization.txt”")
        && filePanel.canChooseFiles && !filePanel.canChooseDirectories, "Chinese authorization panel names the file and confirms authorization")
    let folderPanel = FolderAccess.authorizationPanel(for: root, selection: .folder, language: .english)
    try contentCheck(folderPanel.prompt == "Authorize" && folderPanel.message.contains(root.lastPathComponent)
        && !folderPanel.canChooseFiles && folderPanel.canChooseDirectories, "English authorization panel names the folder and confirms authorization")

    try FolderAccess.checkDirectory(root, mode: W_OK)
    try FolderAccess.checkAccess(to: file, mode: R_OK)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
    do {
        try FolderAccess.checkAccess(to: file, mode: R_OK)
        throw ContentCheckFailure(message: "Fixture did not deny access")
    } catch where FolderAccess.isPermissionError(error) {}

    let missing = root.appendingPathComponent("missing-folder", isDirectory: true)
    var prompts = 0
    let access = try OpenWithFolderAccess(store: OpenWithFolderAccessStore(file: root.appendingPathComponent("test-access.json")),
        chooseDirectory: { _, _ in prompts += 1; return nil })
    defer { access.release() }
    do {
        _ = try access.authorize(missing, folders: [root], language: .english)
        throw ContentCheckFailure(message: "Missing directory did not report its own failure")
    } catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT) {
        try contentCheck(prompts == 0 && !FolderAccess.isPermissionError(error), "Missing directories never request authorization")
    }
    print("PASS native file/folder authorization labels and permission-only fallback")
}

@MainActor
private func checkRememberedReadAccess(in root: URL, pasteboard: NSPasteboard) async throws {
    let workspace = root.appendingPathComponent("remembered-read-access", isDirectory: true)
    let parent = workspace.appendingPathComponent("parent", isDirectory: true)
    let child = parent.appendingPathComponent("nested", isDirectory: true)
    try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
    let first = parent.appendingPathComponent("first.txt")
    let second = child.appendingPathComponent("second.txt")
    let text = "remembered authorization\n"
    for url in [first, second] { try Data(text.utf8).write(to: url) }
    let firstSelection = try FileInfoSelection.capture([first])
    let secondSelection = try FileInfoSelection.capture([second])
    let preferencesURL = workspace.appendingPathComponent("preferences.json")
    var preferences = FileMintPreferences.default
    preferences.monitoredFolderURLs = [workspace]
    preferences.fileTools.isEnabled = true; preferences.fileTools.copyContents = true
    try FileMintPreferencesStore(fileURL: preferencesURL).save(preferences)
    let store = ScopedBookmarkStore(file: workspace.appendingPathComponent("file-read-access.json"))
    let granted = FileInfoReadAccess(preferencesFile: preferencesURL)
    defer { granted.release() }
    try granted.remember(first, for: firstSelection, in: preferences.monitoredFolderURLs)
    granted.release()
    let reopened = FileInfoReadAccess(preferencesFile: preferencesURL)
    defer { reopened.release() }
    reopened.restore(for: firstSelection, preferences: preferences)
    try contentCheck(reopened.activeScopes.map(\.path) == [firstSelection.resolvedSource.path], "Fresh read restores exact file grant")
    reopened.release()
    reopened.restore(for: secondSelection, preferences: preferences)
    try contentCheck(reopened.activeScopes.isEmpty, "Exact file grant does not cover siblings")
    let saved = try Data(contentsOf: store.file)
    do {
        try granted.remember(workspace, for: firstSelection, in: preferences.monitoredFolderURLs)
        throw ContentCheckFailure(message: "Picker accepted an unrelated ancestor")
    } catch FileInfoError.invalidSelection {}
    try contentCheck(try Data(contentsOf: store.file) == saved, "Rejected selection preserves existing grants")

    try granted.remember(parent, for: firstSelection, in: preferences.monitoredFolderURLs)
    granted.release()
    reopened.restore(for: secondSelection, preferences: preferences)
    try contentCheck(reopened.activeScopes.map(\.path) == [firstSelection.parent.path], "Saved parent covers nested file after scope release")
    reopened.release()
    let shared = RememberedFileAccess(preferencesFile: preferencesURL)
    let writeFromRead = shared.start(for: child, folder: true, mode: .write, roots: preferences.monitoredFolderURLs)
    defer { writeFromRead.forEach { $0.stopAccessingSecurityScopedResource() } }
    try contentCheck(writeFromRead.isEmpty, "Read-only grant cannot satisfy a write")

    let openWithStore = OpenWithFolderAccessStore(file: workspace.appendingPathComponent("open-with-access.json"))
    let unrelated = try workspace.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                               includingResourceValuesForKeys: nil, relativeTo: nil)
    try openWithStore.save([child.standardizedFileURL.path: unrelated])
    var openWithPrompts = 0
    let openWith = try OpenWithFolderAccess(store: openWithStore, remembered: shared,
        chooseDirectory: { _, _ in openWithPrompts += 1; return nil })
    defer { openWith.release() }
    try contentCheck(try openWith.authorize(child, folders: preferences.monitoredFolderURLs, language: .english)
        && openWithPrompts == 0, "Independently authorized parent satisfies another read tool despite a rejected legacy entry")
    openWith.release()
    var narrowed = preferences
    narrowed.monitoredFolderURLs = [child]
    reopened.restore(for: secondSelection, preferences: narrowed)
    try contentCheck(reopened.activeScopes.map(\.path) == [firstSelection.parent.path], "Ancestor grant covers a target inside narrower Finder scope")
    reopened.release()
    narrowed.monitoredFolderURLs = [workspace.appendingPathComponent("elsewhere")]
    reopened.restore(for: secondSelection, preferences: narrowed)
    try contentCheck(reopened.activeScopes.isEmpty, "Saved grant does not expand Finder scope")

    let copy = FileContentCopyController(preferencesFile: preferencesURL, pasteboard: pasteboard)
    defer { copy.requestClose() }
    await copy.copy(secondSelection, expectedChangeCount: pasteboard.changeCount)
    try contentCheck(copy.didCopy && pasteboard.string(forType: .string) == text, "Fresh copy controller can use saved parent")

    let writeScope = try shared.remember(parent, target: firstSelection.parent, folder: true, mode: .write,
                                         roots: preferences.monitoredFolderURLs)
    writeScope.stopAccessingSecurityScopedResource()
    do {
        let restoredWrites = shared.start(for: child, folder: true, mode: .write, roots: preferences.monitoredFolderURLs)
        defer { restoredWrites.forEach { $0.stopAccessingSecurityScopedResource() } }
        try contentCheck(restoredWrites.map(\.path) == [firstSelection.parent.path], "Explicit write grant covers nested destination")
    }
    try shared.forgetDirectoryWrite(at: firstSelection.parent.path)
    let afterRemoval = RememberedFileAccess(preferencesFile: preferencesURL)
    let writesAfterRemoval = afterRemoval.start(for: child, folder: true, mode: .write, roots: preferences.monitoredFolderURLs)
    defer { writesAfterRemoval.forEach { $0.stopAccessingSecurityScopedResource() } }
    try contentCheck(writesAfterRemoval.isEmpty, "Removing a saved write grant stops reuse")
    try contentCheck(try afterRemoval.directoryWritePaths().isEmpty, "Removed grants stay absent from fresh store instances")

    try FileManager.default.moveItem(at: parent, to: workspace.appendingPathComponent("moved-parent"))
    try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
    try Data(text.utf8).write(to: second)
    reopened.restore(for: try FileInfoSelection.capture([second]), preferences: preferences)
    try contentCheck(reopened.activeScopes.isEmpty, "Replacement folder does not inherit the old folder's bookmark")
    let attributes = try FileManager.default.attributesOfItem(atPath: store.file.path)
    try contentCheck(attributes[.posixPermissions] as? Int == 0o600, "Remembered bookmark store is private")
    print("PASS remembered grants: file-only, nested reuse, cross-tool read, separate write authority, scope and identity")
}

@MainActor
private func checkSavedAncestorCopy(in root: URL, pasteboard: NSPasteboard) async throws {
    let folder = root.appendingPathComponent("saved-folder", isDirectory: true)
    let child = folder.appendingPathComponent("nested", isDirectory: true)
    let alias = root.appendingPathComponent("saved-alias", isDirectory: true)
    try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: folder)
    let source = alias.appendingPathComponent("nested/vite.config.ts")
    let expected = "export default { value: '中文' };\n"
    try Data(expected.utf8).write(to: source)
    let selection = try FileInfoSelection.capture([source])
    let bookmark = try folder.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                           includingResourceValuesForKeys: nil, relativeTo: nil)
    var preferences = FileMintPreferences.default
    preferences.fileTools.isEnabled = true
    preferences.fileTools.copyContents = true
    preferences.monitoredFolderURLs = [alias]
    preferences.monitoredFolderBookmarks = [alias.path: bookmark]
    let parent = source.deletingLastPathComponent()
    try contentCheck(!FolderScope.contains(selection.parent, in: [alias]), "Fixture needs different configured and real path spellings")
    do {
        let scopes = FolderAccess.startSavedAccess(to: parent, resolved: selection.parent, in: preferences)
        defer { scopes.forEach { $0.stopAccessingSecurityScopedResource() } }
        try contentCheck(scopes.count == 1, "A saved folder bookmark covers the captured nested parent")
    }
    var mismatched = preferences
    mismatched.monitoredFolderBookmarks[alias.path] = try child.bookmarkData(options: .withSecurityScope,
        includingResourceValuesForKeys: nil, relativeTo: nil)
    let scopes = FolderAccess.startSavedAccess(to: parent, resolved: selection.parent, in: mismatched)
    defer { scopes.forEach { $0.stopAccessingSecurityScopedResource() } }
    try contentCheck(scopes.isEmpty, "A bookmark resolving to a different folder cannot authorize the configured root")

    let preferencesURL = root.appendingPathComponent("ancestor-preferences.json")
    try FileMintPreferencesStore(fileURL: preferencesURL).save(preferences)
    let controller = FileContentCopyController(preferencesFile: preferencesURL, pasteboard: pasteboard)
    defer { controller.requestClose() }
    await controller.copy(selection, expectedChangeCount: pasteboard.changeCount)
    try contentCheck(controller.didCopy && controller.panel == nil && pasteboard.string(forType: .string) == expected,
                     "Nested TypeScript source copies with the saved ancestor bookmark")
    print("PASS Copy File Contents reuses a saved ancestor bookmark for a nested selection and rejects mismatched bookmarks")
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
    seed()
    try checkAuthorizationPanelAndDenial(in: root)
    try await checkRememberedReadAccess(in: root, pasteboard: board)
    try await checkSavedAncestorCopy(in: root, pasteboard: board)

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

    // Independent expectations cover the admitted subset, including Cocoa's
    // unsigned UTF-16 spelling and non-1252 headers with Unicode-only body text.
    let cocoaRTF = #"""
    {\rtf1\ansi\ansicpg936\cocoartf2908
    \cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fnil\fcharset0 HelveticaNeue;}
    {\colortbl;\red255\green255\blue255;}{\*\expandedcolortbl;;}
    \pard\tx560\pardirnatural\partightenfactor0
    \f0\fs26\cf0\uc0\u27979 \u35797  \u55358 \u57012 \
    line\tab 2}
    """#
    let admittedRTF: [(String, String)] = [
        (cocoaRTF, "测试 🪴\nline\t2"),
        (#"{\rtf1\ansi\ansicpg1252 Caf\'e9 e\u769? \u-10178?\u-8524?}"#, "Café e\u{301} 🪴"),
        (#"{\rtf1\ansi\uc1\u20013?{\uc0\u25991}\u20013?}"#, "中文中"),
        (#"{\rtf1\ansi\uc1\u20013\{\u25991\'3f}"#, "中文"),
        (#"{\rtf1\ansi A\line B\par C}"#, "A\u{2028}B\nC"),
        (#"{\rtf1\ansi\uc0\u65279\u65279 A}"#, "\u{FEFF}\u{FEFF}A")
    ]
    for (source, expectedText) in admittedRTF {
        let bytes = Data(source.utf8)
        let payload = try FileContentClipboard.prepareRTF(bytes)
        try contentCheck(payload.text.utf8.elementsEqual(expectedText.utf8), "Independent RTF body is byte-exact")
        seed()
        try FileContentClipboard.write(payload, to: board, expectedChangeCount: board.changeCount)
        try contentCheck(board.data(forType: .rtf) == bytes, "Admitted RTF keeps its original bytes")
        for isRich in [true, false] {
            let receiver = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 180))
            receiver.isRichText = isRich
            try contentCheck(receiver.readSelection(from: board), "Admitted RTF pastes into native receiver")
            try contentCheck(receiver.string.utf8.elementsEqual(expectedText.utf8), "Native paste preserves complete Unicode bytes")
        }
    }

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
    try contentCheck(coordinator.contentCopyController.panel == nil, "Successful copy leaves no feedback panel")
    try contentCheck(board.string(forType: .string).map { Data($0.utf8) } == original, "Exact source content including CRLF and combining mark")
    try contentCheck(board.data(forType: .fileURL) == nil && board.data(forType: .rtf) == nil, "Plain text has no file or rich representation")
    try contentCheck(try tickets.consume(ticket) == nil, "Copy ticket cannot replay")
    try contentCheck(try Data(contentsOf: source) == original, "Source bytes unchanged")
    try contentCheck(try Data(contentsOf: prefsURL) == prefsData, "Preferences not changed by copy")
    try await Task.sleep(for: .milliseconds(400))
    try contentCheck(coordinator.contentCopyController.panel == nil, "Completed copy cannot show a delayed progress panel")
    coordinator.contentCopyController.requestClose()

    let successGate = ContentReadGate()
    let slowCopy = FileContentCopyController(preferencesFile: prefsURL, pasteboard: board, reader: { selection, token in
        let contents = try FileContentRead.read(selection, cancellation: token)
        successGate.block()
        try token.check()
        return contents
    })
    seed(); let slowCounter = board.changeCount
    let slowSelection = try FileInfoSelection.capture([source])
    let slowTask = Task { await slowCopy.copy(slowSelection, expectedChangeCount: slowCounter) }
    do {
        try await wait("slow copy progress") { successGate.hasStarted && slowCopy.panel?.isVisible == true }
        let progressPanel = slowCopy.panel
        try contentCheck(slowCopy.isWorking && !slowCopy.didCopy && board.changeCount == slowCounter,
                         "Slow work shows progress before publishing the clipboard")
        successGate.allow()
        await slowTask.value
        try contentCheck(slowCopy.didCopy && !slowCopy.isWorking, "Slow copy completes successfully")
        try contentCheck(slowCopy.panel == nil && progressPanel?.isVisible == false,
                         "Success closes the existing progress panel immediately")
        try contentCheck(board.string(forType: .string).map { Data($0.utf8) } == original,
                         "Silent slow success copies the complete original text")
    } catch {
        successGate.allow(); await slowCopy.cancelAndWait(); await slowTask.value
        slowCopy.requestClose()
        throw error
    }

    let controller = FileContentCopyController(preferencesFile: prefsURL, pasteboard: board)
    defer { controller.requestClose(); coordinator.contentCopyController.requestClose() }
    let bomFile = directory.appendingPathComponent("leading-feff.txt")
    try Data([0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF, 0x41]).write(to: bomFile)
    seed()
    await controller.copy(try FileInfoSelection.capture([bomFile]), expectedChangeCount: board.changeCount)
    try contentCheck(controller.didCopy && board.string(forType: .string).map { Data($0.utf8) } == Data("\u{FEFF}A".utf8),
                     "Production text copy removes only the encoding BOM")
    try contentCheck(controller.panel == nil, "Plain-text success stays silent")
    for isRich in [true, false] {
        let receiver = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 180))
        receiver.isRichText = isRich
        try contentCheck(receiver.readSelection(from: board), "Leading-FEFF text pastes into native receiver")
        try contentCheck(receiver.string.utf8.elementsEqual("\u{FEFF}A".utf8), "Native receiver preserves leading content FEFF")
    }
    controller.requestClose()
    for (name, bytes) in [("empty.txt", Data()), ("binary.txt", Data([65, 0, 66])), ("legacy.txt", Data([0xD6, 0xD0]))] {
        let file = directory.appendingPathComponent(name); try bytes.write(to: file)
        seed(); let counter = board.changeCount
        await controller.copy(try FileInfoSelection.capture([file]), expectedChangeCount: counter)
        try contentCheck(!controller.didCopy && board.changeCount == counter, "Invalid input preserves board: \(name)")
        try contentCheck(controller.panel?.isVisible == true, "Copy failures retain a visible explanation: \(name)")
        controller.requestClose()
        try contentCheck(controller.panel == nil, "Failure feedback can be dismissed")
    }
    let richFile = directory.appendingPathComponent("sample.rtf")
    try rtf.write(to: richFile)
    try contentCheck(FileContentCopyPolicy.supportsMenuSelection([richFile]), "Validated RTF has a Finder menu candidate")
    seed()
    await controller.copy(try FileInfoSelection.capture([richFile]), expectedChangeCount: board.changeCount)
    try contentCheck(controller.didCopy && board.data(forType: .rtf) == rtf, "Admitted RTF traverses production reader/controller")
    try contentCheck(controller.panel == nil, "RTF success stays silent after an earlier failure")
    controller.requestClose()
    let rejectedRTF: [(String, String)] = [
        ("truncated", #"{\rtf1 lost"#),
        ("attachment", #"{\rtf1 text {\pict bad}}"#),
        ("footnote", #"{\rtf1\ansi Main{\footnote missing} end}"#),
        ("header", #"{\rtf1\ansi {\header missing}Main}"#),
        ("unicode-alternative", #"{\rtf1\ansi A{\upr{?}{\*\ud\u20013?}}B}"#),
        ("unicode-missing", #"{\rtf1\ansi begin\u? end}"#),
        ("unicode-range", #"{\rtf1\ansi begin\u99999999? end}"#),
        ("unicode-surrogate", #"{\rtf1\ansi begin\u-10179? end}"#),
        ("discretionary-hyphen", #"{\rtf1\ansi A\-B}"#),
        ("quarter-em-space", #"{\rtf1\ansi A\qmspace B}"#),
        ("unknown-destination", #"{\rtf1\ansi A{\*\unknown missing}B}"#),
        ("late-font-table", #"{\rtf1\ansi A{\fonttbl\f0 missing;}B}"#),
        ("legacy-high-byte", #"{\rtf1\ansi\ansicpg936 A\'e9B}"#),
        ("field", #"{\rtf1\ansi A{\field{\*\fldinst DATE}{\fldrslt date}}B}"#),
        ("table", #"{\rtf1\ansi\trowd\intbl Cell\cell\row}"#)
    ]
    for (name, sourceRTF) in rejectedRTF {
        let name = name + ".rtf", bytes = Data(sourceRTF.utf8)
        let file = directory.appendingPathComponent(name); try bytes.write(to: file)
        seed(); let counter = board.changeCount
        await controller.copy(try FileInfoSelection.capture([file]), expectedChangeCount: counter)
        try contentCheck(!controller.didCopy && board.changeCount == counter, "Unsupported RTF preserves board")
        try contentCheck(board.string(forType: .string) == "keep previous clipboard", "Rejected RTF preserves previous text")
        try contentCheck(try Data(contentsOf: file) == bytes, "Rejected RTF leaves source intact")
        controller.requestClose()
    }
    print("PASS strict RTF subset: Cocoa Unicode; exact decomposed text; original bytes; rich/plain paste; unsupported/malformed inputs preserve clipboard; leading FEFF retained")

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
            if scenario == "cancel" {
                try contentCheck(gated.contentCopyController.panel == nil, "Cancellation closes progress without feedback")
            } else {
                try contentCheck(gated.contentCopyController.panel?.isVisible == true, "Read failures keep their explanation visible")
            }
            gated.contentCopyController.requestClose()
        } catch { gate.allow(); await gated.cancelActiveReadsAndWait(); throw error }
    }
    print("PASS file contents feedback: silent text/RTF success; no delayed panel; slow progress closes immediately; failures stay visible; cancellation stays silent")
    print("PASS file contents: exact production text copy; failures preserve clipboard; change detection; revoked policy; cancellation cleanup; busy tickets consumed")
}
