import AppKit
import FileMintCore
import SwiftUI

@MainActor
final class FileInfoController: NSObject, ObservableObject, NSWindowDelegate {
    typealias Reader = @Sendable (FileInfoSelection, FileDigestChoice, FileDigestCancellation,
                                 @Sendable (FileDigestProgress) -> Void) throws -> FileDigestResult
    @Published private(set) var selection: FileInfoSelection?
    @Published private(set) var metadata: FileInfoMetadata?
    @Published private(set) var choice: FileDigestChoice = .sha256
    @Published private(set) var result: FileDigestResult?
    @Published private(set) var progress: FileDigestProgress?
    @Published private(set) var isPreparing = false
    @Published private(set) var isRunning = false
    @Published private(set) var isCancelling = false
    @Published private(set) var feedback: FileInfoText?
    @Published var expectedChecksum = ""
    private(set) var language: AppLanguage = .system
    private(set) var panel: NSPanel?
    private let preferencesFile: URL?
    private let acquire: @MainActor () -> Bool
    private let release: @MainActor () -> Void
    private let reader: Reader
    private var worker: Task<FileDigestResult, Error>?
    private var cancellation: FileDigestCancellation?
    private var grants: [URL] = []
    private var itemBookmark: Data?
    private var authorizationPanel: NSOpenPanel?
    private var closeRequested = false
    private var cleanupWaiters: [CheckedContinuation<Void, Never>] = []

    init(preferencesFile: URL? = nil, acquire: @escaping @MainActor () -> Bool,
         release: @escaping @MainActor () -> Void,
         reader: @escaping Reader = { try FileDigestService.calculate($0, choice: $1, cancellation: $2, progress: $3) }) {
        self.preferencesFile = preferencesFile; self.acquire = acquire; self.release = release; self.reader = reader
        super.init()
    }

    var isWorking: Bool { isPreparing || isRunning }
    var canCalculate: Bool { !isWorking && metadata?.canCalculate == true }
    var comparison: FileDigestComparison { FileInfoPolicy.compare(expectedChecksum, choice: choice, result: result) }
    func text(_ key: FileInfoText) -> String { key.text(language) }

    func select(_ value: FileDigestChoice) {
        guard !isWorking, choice != value else { return }
        choice = value; result = nil; progress = nil; feedback = nil
    }

    /// The coordinator owns preparation until this method returns. An idle
    /// window then gives ownership back, and Calculate reserves it anew.
    func present(_ selected: FileInfoSelection) async throws {
        guard !isWorking else { showBusy(); return }
        selection = selected; metadata = nil; result = nil; progress = nil
        choice = .sha256; expectedChecksum = ""; feedback = nil; itemBookmark = nil
        closeRequested = false; isPreparing = true; isCancelling = false
        language = preferences.language
        let token = FileDigestCancellation(); cancellation = token
        makePanel()
        defer { finishActivity() }
        do {
            try validatePolicy(selected)
            guard try await authorize(selected, readContent: false) else { throw FileInfoError.cancelled }
            try token.check()
            let roots = preferences.monitoredFolderURLs
            metadata = try await Task.detached(priority: .userInitiated) {
                try Self.validate(selected, roots: roots)
                return try FileDigestService.inspect(selected)
            }.value
            try token.check()
            try validatePolicy(selected)
        } catch { feedback = ((error as? FileInfoError) ?? .unavailable).text }
    }

    func calculate() {
        guard canCalculate, let selection else { return }
        guard acquire() else { showBusy(); return }
        result = nil; progress = nil; feedback = nil
        isRunning = true; isCancelling = false
        let frozen = choice
        let token = FileDigestCancellation(); cancellation = token
        Task {
            defer { finishActivity(); release() }
            do {
                try validatePolicy(selection)
                guard try await authorize(selection, readContent: true) else { throw FileInfoError.cancelled }
                try token.check()
                try validatePolicy(selection)
                let roots = preferences.monitoredFolderURLs
                let reader = self.reader
                let report: @Sendable (FileDigestProgress) -> Void = { [self] value in
                    Task { @MainActor [self] in
                        guard cancellation === token, !isCancelling else { return }
                        progress = value
                    }
                }
                let operation = Task.detached(priority: .userInitiated) {
                    try Self.validate(selection, roots: roots)
                    return try reader(selection, frozen, token, report)
                }
                worker = operation
                let calculated = try await operation.value
                try token.check()
                try validatePolicy(selection)
                // Selection identity remains fixed; content can legitimately
                // change between separate explicit calculations.
                metadata = calculated.metadata
                result = calculated
                feedback = .complete
            } catch { feedback = ((error as? FileInfoError) ?? .unavailable).text }
        }
    }

    func cancel() {
        guard isWorking else { return }
        isCancelling = true; result = nil
        authorizationPanel?.cancel(nil)
        cancellation?.cancel(); worker?.cancel()
    }

    func requestClose() {
        if isWorking { closeRequested = true; panel?.orderOut(nil); cancel() }
        else { panel?.close() }
    }

    /// Used by quit and updater guards: keep ownership until the descriptor and
    /// scoped access have actually been released, even when the window is hidden.
    func cancelAndWait() async {
        guard isWorking else { return }
        cancel()
        await withCheckedContinuation { cleanupWaiters.append($0) }
    }

    func focus() -> Bool {
        guard let panel else { return false }
        panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func showBusy() {
        if focus() { feedback = .busy; return }
        let alert = NSAlert()
        alert.messageText = text(.title); alert.informativeText = text(.busy)
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }

    func showInvalidRequest() {
        let alert = NSAlert()
        alert.messageText = text(.title); alert.informativeText = text(.invalidSelection)
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }

    /// Clipboard access is exclusively user-triggered. Injectable pasteboard
    /// keeps automated checks out of the user's general clipboard.
    @discardableResult
    func copy(_ value: String, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        let success = pasteboard.setString(value, forType: .string)
        feedback = success ? .copied : .copyFailed
        return success
    }

    func copyResult(_ algorithm: FileDigestAlgorithm? = nil, to pasteboard: NSPasteboard = .general) {
        guard !isWorking, let result, result.choice == choice else { return }
        if let algorithm, let value = result.values.first(where: { $0.algorithm == algorithm }) {
            copy(value.hexadecimal, to: pasteboard)
        } else if algorithm == nil { copy(result.clipboardText, to: pasteboard) }
    }

    private var preferences: FileMintPreferences { FileMintPreferencesStore(fileURL: preferencesFile).load() }

    private func validatePolicy(_ selection: FileInfoSelection) throws {
        guard FileInfoPolicy.isEnabled(for: [selection.source], preferences: preferences) else {
            throw FileInfoError.disabled
        }
    }

    nonisolated private static func validate(_ selection: FileInfoSelection, roots: [URL]) throws {
        try selection.validate()
        guard FolderScope.containsResolvedItem(selection.source, in: roots) else { throw FileInfoError.disabled }
    }

    private func authorize(_ selection: FileInfoSelection, readContent: Bool) async throws -> Bool {
        // Reuse only existing configured grants or this window's explicit exact
        // item bookmark. Never persist a new folder or expand observation scope.
        var bookmarks = preferences.monitoredFolderURLs.compactMap { url -> Data? in
            guard FolderScope.contains(selection.parent, in: [url]) else { return nil }
            return preferences.monitoredFolderBookmarks[url.path]
        }
        if let itemBookmark { bookmarks.append(itemBookmark) }
        for data in bookmarks {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                relativeTo: nil, bookmarkDataIsStale: &stale), url.startAccessingSecurityScopedResource() {
                grants.append(url)
            }
        }
        let permitted = try await Task.detached(priority: .userInitiated) {
            do {
                try selection.validate()
                return !readContent || FileManager.default.isReadableFile(atPath: selection.resolvedSourceForAccess.path)
            } catch FileInfoError.accessDenied { return false }
        }.value
        try cancellation?.check()
        if permitted { return true }
        let picker = NSOpenPanel()
        picker.title = text(.title); picker.message = text(.authorize)
        picker.directoryURL = selection.parent
        picker.canChooseFiles = true; picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false; picker.canCreateDirectories = false
        picker.resolvesAliases = false
        authorizationPanel = picker
        defer { authorizationPanel = nil }
        guard picker.runModal() == .OK, let chosen = picker.url,
              chosen.standardizedFileURL == selection.source.standardizedFileURL
                || chosen.standardizedFileURL == selection.resolvedSourceForAccess else { return false }
        let started = chosen.startAccessingSecurityScopedResource()
        defer { if started { chosen.stopAccessingSecurityScopedResource() } }
        let bookmark = try chosen.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil)
        var stale = false
        let restored = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
            relativeTo: nil, bookmarkDataIsStale: &stale)
        if restored.startAccessingSecurityScopedResource() { grants.append(restored) }
        itemBookmark = bookmark
        return true
    }

    private func finishActivity() {
        for url in grants { url.stopAccessingSecurityScopedResource() }
        grants = []; worker = nil; cancellation = nil
        isPreparing = false; isRunning = false; isCancelling = false
        if closeRequested { panel?.close() }
        let waiters = cleanupWaiters; cleanupWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    private func makePanel() {
        if panel == nil {
            let panel = FileInfoPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            panel.contentMinSize = NSSize(width: 520, height: 480)
            panel.backgroundColor = FileMintStyle.backgroundNS
            panel.isReleasedWhenClosed = false; panel.delegate = self
            panel.identifier = NSUserInterfaceItemIdentifier("fileInfoPanel")
            panel.onClose = { [weak self] in self?.requestClose() }
            panel.onCalculate = { [weak self] in self?.calculate() }
            panel.contentView = NSHostingView(rootView: FileInfoView(model: self))
            self.panel = panel; panel.center()
            if let visible = panel.screen?.visibleFrame, !visible.contains(panel.frame) {
                panel.minSize = NSSize(width: min(panel.minSize.width, visible.width), height: min(panel.minSize.height, visible.height))
                panel.setFrame(panel.frame.intersection(visible), display: false)
            }
        }
        panel?.title = text(.title)
        _ = focus()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isWorking { requestClose(); return false }
        return true
    }
    func windowWillClose(_ notification: Notification) {
        itemBookmark = nil; result = nil; selection = nil; metadata = nil
        expectedChecksum = ""; progress = nil; panel = nil
    }
}

private extension FileInfoSelection {
    var resolvedSourceForAccess: URL { parent.appendingPathComponent(source.lastPathComponent) }
}

@MainActor
private final class FileInfoPanel: NSPanel {
    var onClose: (() -> Void)?
    var onCalculate: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { onClose?() }
    override func sendEvent(_ event: NSEvent) {
        if routeKey(event) { return }
        super.sendEvent(event)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if routeKey(event) { return true }
        return super.performKeyEquivalent(with: event)
    }
    private func routeKey(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty, event.keyCode == 53 { onClose?(); return true }
        if modifiers == .command, event.charactersIgnoringModifiers == "w" { onClose?(); return true }
        if modifiers.isEmpty, event.keyCode == 36 || event.keyCode == 76 {
            if let editor = firstResponder as? NSTextView, editor.isEditable && !editor.isFieldEditor { return false }
            onCalculate?(); return true
        }
        return false
    }
}
