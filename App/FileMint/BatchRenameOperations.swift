import AppKit
import FileMintCore
import SwiftUI
import UniformTypeIdentifiers

/// Main-app authorization and lifecycle adapter. All filesystem work is delegated
/// off the main actor. Its caller owns FileOperationCoordinator until panels close.
@MainActor
final class BatchRenameOperations: ObservableObject {
    static let shared = BatchRenameOperations()
    @Published private(set) var hasRecovery = false
    @Published private(set) var canUndo = false
    @Published private(set) var isCorrupt = false
    @Published private(set) var requiresMetadataFinalization = false
    @Published private(set) var requiresCommittedCleanup = false
    private let store: BatchRenameStore
    private let accessStore: BatchRenameAccessStore
    private let controller: BatchRenameController
    private var preferencesFile: URL?
    private let feedback: ((String) -> Void)?
    private var statusGeneration = UUID()

    init(store: BatchRenameStore = BatchRenameStore(), accessStore: BatchRenameAccessStore = BatchRenameAccessStore(),
         controller: BatchRenameController = .shared,
         preferencesFile: URL? = nil, feedback: ((String) -> Void)? = nil) {
        self.store = store
        self.accessStore = accessStore
        self.controller = controller
        self.feedback = feedback
        self.preferencesFile = preferencesFile
    }

    func refreshStatus() {
        Task { await reloadStatus() }
    }

    @discardableResult
    private func reloadStatus() async -> BatchRenameStoreStatus {
        let generation = UUID()
        statusGeneration = generation
        let store = self.store
        let status = await Task.detached(priority: .utility) { store.status() }.value
        if generation == statusGeneration {
            hasRecovery = status.hasUnresolvedOperation
            canUndo = status.canUndo
            isCorrupt = status.isCorrupt
            requiresMetadataFinalization = status.requiresMetadataFinalization
            requiresCommittedCleanup = status.requiresCommittedCleanup
        }
        return status
    }

    private var language: AppLanguage { FileMintPreferencesStore(fileURL: preferencesFile).load().language }

    func present(selection: BatchRenameSelection, preferencesFile: URL?) async throws {
        self.preferencesFile = preferencesFile
        let access = BatchRenameAccess(store: accessStore)
        defer { access.release(); refreshStatus() }
        let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
        guard FileToolsPolicy.availableTools(selection: selection.items.map(\.source), isItemMenu: true,
                                             preferences: preferences).contains(.batchRename) else {
            throw BatchRenameError.disabled
        }
        let initialStatus = await reloadStatus()
        guard !initialStatus.hasUnresolvedOperation else {
            let action = await recoveryPanel()
            try await perform(action, preferencesFile: preferencesFile)
            return
        }
        let operationStore = store
        let previousAuthority = try await Task.detached(priority: .userInitiated) {
            try operationStore.undoAuthorization()
        }.value
        let previousBookmark = previousAuthority?.parentIdentity == selection.parentIdentity
            ? previousAuthority?.parentBookmark : nil
        guard let (_, bookmark) = try await access.authorize(parent: selection.parent,
            identity: selection.parentIdentity,
            bookmark: preferences.monitoredFolderBookmarks[selection.parent.path] ?? previousBookmark,
            allowRelocation: false, language: language) else { return }
        let service = BatchRenameService(store: store)
        let roots = observationRoots(preferences)
        let locations = privateLocations
        let accessStore = self.accessStore
        let session = try await Task.detached(priority: .userInitiated) {
            guard Self.allowsForward(parent: selection.parent, preferencesFile: preferencesFile) else {
                throw BatchRenameError.disabled
            }
            let session = try service.prepare(selection: selection, parentBookmark: bookmark,
                                              observationRoots: roots, privateLocations: locations)
            guard Self.allowsForward(parent: session.parentURL, preferencesFile: preferencesFile) else {
                throw BatchRenameError.disabled
            }
            try accessStore.remember(parent: session.parentURL, identity: selection.parentIdentity, bookmark: bookmark)
            return session
        }.value
        let controlStore = store
        let action = try await controller.present(session: session, language: language,
            checkTargets: { try service.observeTargets(preview: $0, session: session) },
            status: { controlStore.status() }, execute: { plan, keepGoing in
                let protectedPaths = plan.rows.filter { $0.source.kind == .directory }.flatMap { row in
                    [session.parentURL.appendingPathComponent(row.source.originalName),
                     session.parentURL.appendingPathComponent(row.proposedName ?? row.source.originalName)]
                }
                return try service.execute(plan: plan, session: session) {
                    keepGoing() && Self.allowsForward(parent: session.parentURL, preferencesFile: preferencesFile,
                                                      protectedPaths: protectedPaths)
                }
            })
        await reloadStatus()
        try await perform(action, preferencesFile: preferencesFile)
    }

    func perform(_ requested: BatchRenamePanelAction, preferencesFile: URL?) async throws {
        self.preferencesFile = preferencesFile
        var action = requested
        while action != .closed {
            let access = BatchRenameAccess()
            defer { access.release() }
            do {
                let currentStatus = await reloadStatus()
                let service = BatchRenameService(store: store)
                let store = self.store
                switch action {
                case .closed: break
                case .undo:
                    let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
                    guard preferences.fileTools.allows(.batchRename), !currentStatus.hasUnresolvedOperation else {
                        throw BatchRenameError.disabled
                    }
                    guard let authority = try await Task.detached(priority: .userInitiated, operation: {
                        try store.undoAuthorization()
                    }).value else { throw BatchRenameError.stateChanged }
                    guard let (parent, bookmark) = try await access.authorize(parent: authority.parentURL,
                        identity: authority.parentIdentity, bookmark: authority.parentBookmark,
                        allowRelocation: true, language: language) else { return }
                    let roots = observationRoots(preferences)
                    let locations = privateLocations
                    let preview = try await Task.detached(priority: .userInitiated) {
                        guard Self.allowsForward(parent: parent, preferencesFile: preferencesFile) else {
                            throw BatchRenameError.disabled
                        }
                        return try service.undoPreview(parentURL: parent, parentBookmark: bookmark, observationRoots: roots, privateLocations: locations)
                    }.value
                    action = await controller.presentUndo(preview: preview, language: language, status: { store.status() }) { keepGoing in
                        let protectedPaths = preview.rows.flatMap {
                            [parent.appendingPathComponent($0.currentName), parent.appendingPathComponent($0.originalName)]
                        }
                        return try service.undo(preview: preview) {
                            keepGoing() && Self.allowsForward(parent: parent, preferencesFile: preferencesFile,
                                                              protectedPaths: protectedPaths)
                        }
                    }
                case .restore:
                    guard !currentStatus.isCorrupt else { action = await recoveryPanel(); break }
                    guard let authority = try await Task.detached(priority: .userInitiated, operation: {
                        try store.recoveryAuthorization()
                    }).value else { action = await recoveryPanel(); break }
                    guard let (parent, _) = try await access.authorize(parent: authority.parentURL,
                        identity: authority.parentIdentity, bookmark: authority.parentBookmark,
                        allowRelocation: true, language: language) else { return }
                    let result = try await Task.detached(priority: .userInitiated) {
                        try service.restore(parentURL: parent)
                    }.value
                    let completedStatus = await reloadStatus()
                    action = await controller.presentResult(result, language: language, canUndo: completedStatus.canUndo, status: { store.status() })
                case .exportAndUnblock:
                    guard confirmManualResolution() else { return }
                    let picker = NSSavePanel()
                    picker.title = BatchRenameText.exportAndUnblock.text(language)
                    picker.nameFieldStringValue = "FileMint-Recovery-\(UUID().uuidString).json"
                    picker.allowedContentTypes = [.json]
                    picker.canCreateDirectories = true
                    guard picker.runModal() == .OK, let destination = picker.url, destination.isFileURL else { return }
                    let started = destination.startAccessingSecurityScopedResource()
                    do {
                        try await Task.detached(priority: .userInitiated) {
                            try store.exportAndRetire(to: destination)
                        }.value
                    } catch {
                        if started { destination.stopAccessingSecurityScopedResource() }
                        throw error
                    }
                    if started { destination.stopAccessingSecurityScopedResource() }
                    await reloadStatus()
                    showMessage(language.resolved() == .chinese
                        ? "恢复记录已人工关闭。此操作没有恢复或验证用户文件，剩余暂存文件保持原位。"
                        : "The recovery record was manually closed. This did not restore or verify files; remaining staged files stay in place.")
                    action = .closed
                case .finishRetirement:
                    try await Task.detached(priority: .userInitiated) {
                        try store.finalizeCompletedOperation()
                    }.value
                    await reloadStatus()
                    showMessage(language.resolved() == .chinese
                        ? "私有操作记录已完成收口。未执行新的用户文件操作。"
                        : "Private operation records were finalized. No new user-file operation was performed.")
                    action = .closed
                }
                access.release()
            } catch {
                access.release()
                await reloadStatus()
                throw error
            }
        }
        await reloadStatus()
    }

    private func recoveryPanel() async -> BatchRenamePanelAction {
        let status = await reloadStatus()
        return await controller.presentRecovery(language: language,
            message: status.isCorrupt
                ? (language.resolved() == .chinese ? "恢复记录无法读取。已保留原始记录，可以导出证据后人工关闭。"
                   : "The recovery record cannot be read. Its original bytes are preserved for evidence export and manual closure.")
                : BatchRenameText.recoveryNeeded.text(language),
            canRestore: status.hasUnresolvedOperation && !status.isCorrupt && !status.requiresMetadataFinalization,
            requiresFinalization: status.requiresMetadataFinalization,
            requiresCommittedCleanup: status.requiresCommittedCleanup, canExport: status.hasUnresolvedOperation)
    }

    private var privateLocations: [URL] { [FileMintStorage.directory, store.directory, accessStore.file] }

    private func observationRoots(_ preferences: FileMintPreferences) -> [URL] {
        Array(FolderScope.observationRoots(for: preferences.monitoredFolderURLs,
            home: DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)))
    }

    nonisolated private static func allowsForward(parent: URL, preferencesFile: URL?,
                                                  protectedPaths: [URL] = []) -> Bool {
        let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
        guard preferences.fileTools.allows(.batchRename),
              FolderScope.containsResolvedDirectory(parent, in: preferences.monitoredFolderURLs) else { return false }
        // A directory newly configured as an observation root must not be
        // renamed by an older preview, including after another row publishes.
        let sources = Set(protectedPaths.map { $0.standardizedFileURL.path })
        return !observationRootsForCheck(preferences).contains {
            sources.contains($0.resolvingSymlinksInPath().standardizedFileURL.path)
        }
    }

    nonisolated private static func observationRootsForCheck(_ preferences: FileMintPreferences) -> [URL] {
        Array(FolderScope.observationRoots(for: preferences.monitoredFolderURLs,
            home: DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)))
    }

    private func confirmManualResolution() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = BatchRenameText.manualTitle.text(language)
        alert.informativeText = BatchRenameText.manualWarning.text(language)
        alert.addButton(withTitle: BatchRenameText.cancel.text(language))
        alert.addButton(withTitle: BatchRenameText.manualContinue.text(language))
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = ""
        let acknowledgement = NSButton(checkboxWithTitle: BatchRenameText.manualAcknowledgement.text(language),
                                       target: nil, action: nil)
        acknowledgement.frame = NSRect(x: 0, y: 0, width: 440, height: 40)
        alert.accessoryView = acknowledgement
        let gate = BatchRenameAcknowledgement(checkbox: acknowledgement, button: alert.buttons[1])
        NSApp.activate(ignoringOtherApps: true)
        return withExtendedLifetime(gate) {
            alert.runModal() == .alertSecondButtonReturn && acknowledgement.state == .on
        }
    }

    func showBusy() {
        _ = controller.focusExistingPanel()
        showMessage(BatchRenameText.busy.text(language))
    }
    func showInvalidRequest() { showMessage(BatchRenameText.invalidPreview.text(language)) }
    func show(_ error: Error) {
        if error is CancellationError { return }
        let chinese = language.resolved() == .chinese
        if error is BatchRenameAccessStoreError {
            showMessage(chinese ? "无法读取或保存文件夹授权，本次未开始重命名。"
                                : "Folder access could not be read or saved. This rename has not started.")
            refreshStatus()
            return
        }
        let message: String
        switch error as? BatchRenameError {
        case .invalidSelection, .unsupportedItem:
            message = chinese ? "请选择同一文件夹中的 2–1,000 个普通本地文件或文件夹。链接、替身和包不支持。"
                              : "Select 2–1,000 ordinary local files or folders in one parent. Links, aliases and packages are unsupported."
        case .sourceChanged, .parentChanged:
            message = chinese ? "原项目或父文件夹已变化。操作已停止，请重新选择。"
                              : "An original item or its parent changed. The operation stopped; select the items again."
        case .unsupportedFilesystem:
            message = chinese ? "此位置不满足本地可写 APFS 和独占改名要求。未使用复制或覆盖方式继续。"
                              : "This location does not meet the writable local APFS and exclusive-rename requirements."
        case .protectedItem, .unresolvedProtection:
            message = chinese ? "所选项目包含受保护目录，或无法确认目录保护边界。"
                              : "The selection includes a protected directory, or its protection boundary could not be verified."
        case .invalidBookmark, .unavailable:
            message = chinese ? "无法访问原来的父文件夹。请选择同一个文件夹并确认写入权限。"
                              : "The original parent folder is unavailable. Choose that same folder and confirm write access."
        case .disabled:
            message = chinese ? "批量重命名已关闭，或项目已不在当前 Finder 范围内。"
                              : "Batch rename is disabled, or the items are outside the current Finder scope."
        case .occupiedTarget: message = BatchRenameText.occupiedTarget.text(language)
        case .recoveryRequired, .corruptStore, .storeTooLarge:
            message = chinese ? "存在需要处理的恢复记录。请在文件（夹）工具中恢复，或导出证据并人工关闭。"
                              : "A recovery record needs attention. Restore it or export evidence and close it manually in File & Folder Tools."
        case .stalePlan, .stateChanged: message = BatchRenameText.invalidPreview.text(language)
        case nil:
            message = FolderAccess.isPermissionError(error)
                ? (chinese ? "系统拒绝访问。未扩大授权；请检查原父文件夹权限。" : "The system denied access. Check the original parent folder’s permissions.")
                : BatchRenameText.operationFailed.text(language)
        }
        showMessage(message)
        refreshStatus()
    }
    private func showMessage(_ message: String) {
        if let feedback { feedback(message); return }
        let alert = NSAlert()
        alert.messageText = BatchRenameText.title.text(language)
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

struct BatchRenameRecoveryCard: View {
    @ObservedObject var operations = BatchRenameOperations.shared
    let language: AppLanguage
    var body: some View {
        if operations.hasRecovery {
            VStack(alignment: .leading, spacing: 10) {
                Label(BatchRenameText.recoveryNeeded.text(language), systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text(language.resolved() == .chinese
                     ? "未完成记录会阻止新的批量重命名和撤销。关闭功能后仍可处理恢复。"
                     : "An unresolved record blocks new batch renames and undo. Recovery remains available while the feature is off.")
                    .foregroundStyle(.secondary)
                HStack {
                    if !operations.isCorrupt {
                        Button((operations.requiresMetadataFinalization ? BatchRenameText.finishRetirement
                                : operations.requiresCommittedCleanup ? .finishCommitted : .restore).text(language)) {
                            FileOperationCoordinator.shared.batchRenameAction(operations.requiresMetadataFinalization ? .finishRetirement : .restore)
                        }.accessibilityIdentifier("batchRename.recover")
                    }
                    Button(BatchRenameText.exportAndUnblock.text(language)) {
                        FileOperationCoordinator.shared.batchRenameAction(.exportAndUnblock)
                    }.accessibilityIdentifier("batchRename.exportRecovery")
                }
            }.padding(16).background(.quaternary.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

@MainActor
private final class BatchRenameAcknowledgement: NSObject {
    private let checkbox: NSButton
    private let button: NSButton
    init(checkbox: NSButton, button: NSButton) {
        self.checkbox = checkbox; self.button = button
        super.init()
        button.isEnabled = false
        checkbox.target = self
        checkbox.action = #selector(changed)
    }
    @objc private func changed() { button.isEnabled = checkbox.state == .on }
}
