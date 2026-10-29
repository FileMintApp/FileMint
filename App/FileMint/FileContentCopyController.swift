import AppKit
import FileMintCore
import SwiftUI

@MainActor
final class FileContentCopyController: NSObject, ObservableObject, NSWindowDelegate {
    typealias Reader = @Sendable (FileInfoSelection, FileDigestCancellation) throws -> FileContentRead
    @Published private(set) var isWorking = false
    @Published private(set) var message = ""
    private(set) var panel: NSPanel?
    private(set) var didCopy = false
    private let preferencesFile: URL?
    private let pasteboard: NSPasteboard
    private let reader: Reader
    private var cancellation: FileDigestCancellation?
    private var worker: Task<(FileContentRead, FileContentClipboardPayload), Error>?
    private var authorizationPanel: NSOpenPanel?
    private var grants: [URL] = []
    private var closeRequested = false
    private var cleanupWaiters: [CheckedContinuation<Void, Never>] = []
    private var generation = UUID()
    private var language: AppLanguage = .system

    init(preferencesFile: URL? = nil, pasteboard: NSPasteboard = .general,
         reader: @escaping Reader = { try FileContentRead.read($0, cancellation: $1) }) {
        self.preferencesFile = preferencesFile; self.pasteboard = pasteboard; self.reader = reader
        super.init()
    }

    var title: String { FileMintStrings.text(.copyFileContents, language: language) }
    var closeTitle: String { FileInfoText.close.text(language) }
    var cancelTitle: String { FileInfoText.cancel.text(language) }
    private var preferences: FileMintPreferences { FileMintPreferencesStore(fileURL: preferencesFile).load() }
    private func text(_ en: String, _ zh: String) -> String { language.resolved() == .chinese ? zh : en }

    /// The coordinator owns the guard across this entire call, including all
    /// detached-worker cleanup. Only the final synchronous step writes the board.
    func copy(_ selection: FileInfoSelection, expectedChangeCount: Int) async {
        guard !isWorking else { showBusy(); return }
        language = preferences.language
        generation = UUID(); let current = generation
        panel?.close(); panel = nil
        closeRequested = false; didCopy = false; isWorking = true
        message = text("Reading file contents…", "正在读取文件内容…")
        let token = FileDigestCancellation(); cancellation = token
        let delayedPanel = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, generation == current, isWorking, !closeRequested else { return }
            showPanel()
        }
        defer {
            delayedPanel.cancel()
            for url in grants { url.stopAccessingSecurityScopedResource() }
            grants = []; worker = nil; cancellation = nil; authorizationPanel = nil; isWorking = false
            if closeRequested { panel?.close(); panel = nil }
            let waiters = cleanupWaiters; cleanupWaiters = []
            waiters.forEach { $0.resume() }
        }
        do {
            try Task.checkCancellation()
            try validatePolicy(selection)
            guard pasteboard.changeCount == expectedChangeCount else { throw FileContentCopyError.clipboardChanged }
            guard try await authorize(selection) else { throw FileInfoError.cancelled }
            try token.check(); try validatePolicy(selection)
            let roots = preferences.monitoredFolderURLs
            let reader = self.reader
            let operation = Task.detached(priority: .userInitiated) {
                guard FolderScope.containsResolvedItem(selection.source, in: roots) else { throw FileInfoError.disabled }
                let contents = try reader(selection, token)
                try token.check()
                let payload = try FileContentClipboard.prepare(contents)
                try token.check(); try contents.validate()
                return (contents, payload)
            }
            worker = operation
            let (contents, payload) = try await operation.value
            try token.check(); try validatePolicy(selection)
            let latestRoots = preferences.monitoredFolderURLs
            try await Task.detached(priority: .userInitiated) {
                guard FolderScope.containsResolvedItem(selection.source, in: latestRoots) else { throw FileInfoError.disabled }
                try contents.validate()
            }.value
            try token.check(); try validatePolicy(selection)
            try FileContentClipboard.write(payload, to: pasteboard, expectedChangeCount: expectedChangeCount)
            didCopy = true
            panel?.close(); panel = nil
        } catch {
            if error is CancellationError || (error as? FileInfoError) == .cancelled {
                closeRequested = true
            } else {
                message = errorMessage(error)
                showPanel()
            }
        }
    }

    func showBusy() {
        if isWorking { showPanel(); return }
        generation = UUID()
        language = preferences.language
        message = FileInfoText.busy.text(language); didCopy = false
        showPanel()
    }

    func showInvalidRequest() {
        generation = UUID()
        language = preferences.language
        message = text("This request expired or is invalid. Select the file again in Finder.",
                       "请求已过期或无效，请在 Finder 中重新选择文件。")
        didCopy = false; showPanel()
    }

    func requestClose() {
        closeRequested = true
        cancellation?.cancel(); worker?.cancel(); authorizationPanel?.cancel(nil)
        if !isWorking { panel?.close(); panel = nil }
        else { message = text("Cancelling…", "正在取消…") }
    }

    func cancelAndWait() async {
        guard isWorking else { return }
        requestClose()
        await withCheckedContinuation { cleanupWaiters.append($0) }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { requestClose(); return false }

    private func validatePolicy(_ selection: FileInfoSelection) throws {
        guard FileContentCopyPolicy.isEnabled(for: selection, preferences: preferences) else { throw FileInfoError.disabled }
    }

    private func authorize(_ selection: FileInfoSelection) async throws -> Bool {
        let snapshot = preferences
        for root in snapshot.monitoredFolderURLs where FolderScope.contains(selection.parent, in: [root]) {
            guard let data = snapshot.monitoredFolderBookmarks[root.path] else { continue }
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                relativeTo: nil, bookmarkDataIsStale: &stale), url.startAccessingSecurityScopedResource() {
                grants.append(url)
            }
        }
        let readable = try await Task.detached(priority: .userInitiated) {
            do {
                try selection.validate()
                return FileManager.default.isReadableFile(atPath: selection.source.path)
            } catch FileInfoError.accessDenied { return false }
        }.value
        try cancellation?.check()
        if readable { return true }
        let picker = NSOpenPanel()
        picker.title = title
        picker.message = text("Choose this exact file to allow read access.", "请选择同一文件以授予读取权限。")
        picker.directoryURL = selection.parent
        picker.canChooseFiles = true; picker.canChooseDirectories = false
        picker.allowsMultipleSelection = false; picker.canCreateDirectories = false; picker.resolvesAliases = false
        authorizationPanel = picker
        defer { authorizationPanel = nil }
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let chosen = picker.url,
              chosen.standardizedFileURL == selection.source.standardizedFileURL
                || chosen.standardizedFileURL == selection.parent.appendingPathComponent(selection.source.lastPathComponent) else {
            return false
        }
        let started = chosen.startAccessingSecurityScopedResource()
        defer { if started { chosen.stopAccessingSecurityScopedResource() } }
        let data = try chosen.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                           includingResourceValuesForKeys: nil, relativeTo: nil)
        var stale = false
        let restored = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                               relativeTo: nil, bookmarkDataIsStale: &stale)
        if restored.startAccessingSecurityScopedResource() { grants.append(restored) }
        return true
    }

    private func showPanel() {
        if let panel { panel.orderFrontRegardless(); return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 390, height: 140),
                            styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = title; panel.delegate = self; panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: FileContentCopyView(model: self))
        panel.center(); self.panel = panel; panel.orderFrontRegardless()
    }

    private func errorMessage(_ error: Error) -> String {
        switch error {
        case FileContentCopyError.tooLarge:
            return text("The file or decoded text exceeds 8 MiB. Nothing was copied.", "文件或解码后的文本超过 8 MiB，未拷贝。")
        case FileContentCopyError.empty:
            return text("This file has no text content. The clipboard was kept.", "文件没有文本内容，已保留原剪贴板。")
        case FileContentCopyError.invalidEncoding:
            return text("This is not supported text. Use UTF-8 or UTF-16 with a BOM.", "内容不是支持的文本，请使用 UTF-8 或带 BOM 的 UTF-16 编码。")
        case FileContentCopyError.invalidRTF:
            return text("This RTF uses unsupported formatting or invalid text. Export as UTF-8 text and try again.",
                        "RTF 含不支持的格式或无效文字。请导出为 UTF-8 文本后重试。")
        case FileContentCopyError.unsupported, FileInfoError.unsupported:
            return text("Only code/text files and RTF with basic text and styles are supported.",
                        "仅支持代码、文本及含基础文字和样式的 RTF 文件。")
        case FileContentCopyError.clipboardChanged:
            return text("The clipboard changed while reading. Its newer content was kept; copy this file again if needed.",
                        "读取期间剪贴板已变化，已保留较新的内容；如需拷贝此文件，请重新操作。")
        case FileContentCopyError.clipboardWriteFailed:
            return FileInfoText.copyFailed.text(language)
        case FileInfoError.changed:
            return text("The file or its folder changed. Nothing was copied; select the file again.",
                        "文件或所在文件夹已变化，未拷贝；请重新选择文件。")
        case FileInfoError.disabled:
            return text("Copy File Contents is disabled or the file is outside the configured Finder folders.",
                        "拷贝文件内容已关闭，或文件不在配置的 Finder 范围内。")
        case FileInfoError.placeholder: return FileInfoText.placeholder.text(language)
        case FileInfoError.accessDenied: return FileInfoText.accessDenied.text(language)
        default: return FileInfoText.readFailed.text(language)
        }
    }
}

private struct FileContentCopyView: View {
    @ObservedObject var model: FileContentCopyController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if model.isWorking { ProgressView().controlSize(.small) }
                Text(model.message).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("copyContents.status")
            }
            HStack {
                Spacer()
                Button(model.isWorking ? model.cancelTitle : model.closeTitle) { model.requestClose() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("copyContents.close")
            }
        }.padding(20).frame(width: 390, alignment: .leading)
    }
}
