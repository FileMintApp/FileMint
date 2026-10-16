import AppKit
import Combine
import FileMintCore
import SwiftUI

enum BatchRenamePanelAction: Equatable { case closed, undo, restore, exportAndUnblock, finishRetirement }
private enum BatchRenamePanelError: Error { case busy }

struct BatchRenameRuleDraft: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case replace, delete, prepend, append, numbering, uppercase, lowercase
        var label: BatchRenameText {
            switch self {
            case .replace: .replace
            case .delete: .delete
            case .prepend: .prepend
            case .append: .append
            case .numbering: .numbering
            case .uppercase: .uppercase
            case .lowercase: .lowercase
            }
        }
    }
    let id: UUID
    var kind: Kind
    var text = ""
    var replacement = ""
    var start = "1"
    var step = "1"
    var width = "3"
    var separator = "_"
    var before = false
    var unified = false
    var unifiedText = ""

    init(kind: Kind) { id = UUID(); self.kind = kind }

    func rule(index: Int) throws -> BatchRenameRule {
        switch kind {
        case .replace: return .replace(search: text, replacement: replacement)
        case .delete: return .replace(search: text, replacement: "")
        case .prepend: return .prepend(text)
        case .append: return .append(text)
        case .uppercase: return .uppercase
        case .lowercase: return .lowercase
        case .numbering:
            guard let start = Int64(start), let step = Int64(step), let width = Int(width) else {
                throw BatchRenameRuleError.invalidNumbering(ruleIndex: index)
            }
            return .number(.init(start: start, step: step, width: width, separator: separator,
                                 position: before ? .before : .after,
                                 body: unified ? .unified(unifiedText) : .current))
        }
    }
}

struct BatchRenameDisplayRow: Identifiable {
    let id: UUID
    let original: String
    let target: String
    let state: String
    let issue: String?
    let location: URL?
    let isError: Bool

    var changesName: Bool { !original.utf8.elementsEqual(target.utf8) }
}

private final class BatchRenameStopToken: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    var canContinue: Bool { lock.lock(); defer { lock.unlock() }; return !stopped }
    func stop() { lock.lock(); stopped = true; lock.unlock() }
}

/// One panel owns one immutable batch until it closes. The coordinator retains
/// authorization and its busy guard throughout every awaited presentation.
@MainActor
final class BatchRenameController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = BatchRenameController()
    enum Mode: String, Sendable { case rules, nameList }
    typealias CheckTargets = @Sendable (BatchRenamePreview) throws -> BatchRenameTargetSnapshot
    typealias Execute = @Sendable (BatchRenamePlan, @Sendable () -> Bool) throws -> BatchRenameResult
    typealias Undo = @Sendable (@Sendable () -> Bool) throws -> BatchRenameResult
    typealias ReadStatus = @Sendable () -> BatchRenameStoreStatus

    @Published private(set) var language: AppLanguage = .system
    @Published private(set) var rules: [BatchRenameRuleDraft] = []
    @Published private(set) var mode: Mode = .rules
    @Published private(set) var order: BatchRenameOrder = .ascending
    @Published private(set) var listText = ""
    @Published private(set) var rows: [BatchRenameDisplayRow] = []
    @Published private(set) var isChecking = false
    @Published private(set) var isRunning = false
    @Published private(set) var isStopping = false
    @Published private(set) var message: String?
    @Published private(set) var result: BatchRenameResult?
    @Published private(set) var isUndo = false
    @Published private(set) var isRecovery = false
    @Published private(set) var canRestore = false
    @Published private(set) var canUndo = false
    @Published private(set) var canExport = false
    @Published private(set) var requiresFinalization = false
    @Published private(set) var requiresCommittedCleanup = false
    @Published var selectedRowID: UUID?

    private var panel: NSPanel?
    private var continuation: CheckedContinuation<BatchRenamePanelAction, Never>?
    private var session: BatchRenameSession?
    private var preview: BatchRenamePreview?
    private var undoPreview: BatchRenameUndoPreview?
    private var checkTargets: CheckTargets?
    private var execute: Execute?
    private var executeUndo: Undo?
    private var readStatus: ReadStatus?
    private var previewWorker: Task<Void, Never>?
    private var revision: UInt64 = 0
    private var listOrder: BatchRenameOrder = .ascending
    private var stopToken = BatchRenameStopToken()
    private var closeRequested = false
    private var operationFailed = false

    var isEditing: Bool { !isRunning && result == nil && !isRecovery && !isUndo && !operationFailed }
    var canSubmit: Bool {
        guard !isRunning, !isChecking, result == nil, !isRecovery, !operationFailed, !closeRequested else { return false }
        if isUndo { return undoPreview?.rows.isEmpty == false }
        return preview?.reference.revision == revision && preview?.canFreeze == true
    }
    var submitTitle: String {
        let count = isUndo ? (undoPreview?.rows.count ?? 0) : (preview?.proposedChangeCount ?? 0)
        return String(format: text(isUndo ? .undoCount : .renameCount), count)
    }
    var countText: String {
        if let result {
            let changed = result.rows.filter { !$0.originalName.utf8.elementsEqual($0.targetName.utf8) }
            let unresolved = result.outcome == .recoveryRequired && !requiresFinalization
                ? changed.filter { requiresCommittedCleanup ? $0.state != .target : $0.state != .original }.count : 0
            let renamed = changed.filter { $0.state == .target }.count
            let restored = changed.filter { $0.state == .original }.count
            return String(format: text(.resultCounts), renamed, result.rows.count - changed.count, restored, unresolved)
        }
        if isUndo { return String(format: text(.counts), rows.count, 0, 0, 0) }
        guard let preview else {
            return String(format: text(.counts), 0, 0, isChecking ? 0 : rows.filter(\.isError).count,
                          isChecking ? rows.count : 0)
        }
        let count = preview.counts
        return String(format: text(.counts), count.changed, count.unchanged, count.errors, count.checking)
    }
    var selectedRow: BatchRenameDisplayRow? { rows.first { $0.id == selectedRowID } }
    var hasRowErrors: Bool { !isChecking && rows.contains(where: \.isError) }
    var statusTitle: String {
        if isStopping { return text(.stopping) }
        if isRunning { return text(.executing) }
        if isChecking { return text(.checking) }
        if requiresCommittedCleanup || requiresFinalization { return text(.stoppedCleanup) }
        if let result {
            return text(result.outcome == .renamed ? .success : result.outcome == .undone ? .undone
                : result.outcome == .restored ? .restored : .recoveryNeeded)
        }
        if isRecovery { return text(.recordBlocked) }
        if operationFailed { return text(.operationFailed) }
        if hasRowErrors { return text(.reviewIssues) }
        if canSubmit { return isUndo ? text(.undoLast) : text(.ready) }
        return text(mode == .rules && rules.isEmpty ? .chooseRule : .noChanges)
    }
    func selectFirstIssue() {
        guard !isChecking, let row = rows.first(where: \.isError) else { return }
        selectedRowID = row.id
    }
    func text(_ key: BatchRenameText) -> String { key.text(language) }

    func focusExistingPanel() -> Bool {
        guard let panel else { return false }
        if panel.isMiniaturized { panel.deminiaturize(nil) }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func present(session: BatchRenameSession, language: AppLanguage,
                 checkTargets: @escaping CheckTargets, status: ReadStatus? = nil,
                 execute: @escaping Execute) async throws -> BatchRenamePanelAction {
        guard panel == nil else { _ = focusExistingPanel(); throw BatchRenamePanelError.busy }
        reset(language: language)
        self.session = session
        self.checkTargets = checkTargets
        self.execute = execute
        self.readStatus = status
        rows = session.batch.sources.map {
            .init(id: $0.id, original: $0.originalName, target: $0.originalName,
                  state: text(.checking), issue: nil, location: nil, isError: false)
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showPanel()
            invalidatePreview()
        }
    }

    func presentUndo(preview: BatchRenameUndoPreview, language: AppLanguage,
                     status: ReadStatus? = nil, execute: @escaping Undo) async -> BatchRenamePanelAction {
        guard panel == nil else { _ = focusExistingPanel(); return .closed }
        reset(language: language)
        isUndo = true
        undoPreview = preview
        executeUndo = execute
        readStatus = status
        rows = preview.rows.map {
            .init(id: $0.id, original: $0.currentName, target: $0.originalName,
                  state: text(.changed), issue: nil, location: nil, isError: false)
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showPanel()
        }
    }

    /// This only displays private-store status. It never probes user folders.
    func presentRecovery(language: AppLanguage, message: String, canRestore: Bool,
                         requiresFinalization: Bool = false, requiresCommittedCleanup: Bool = false, canExport: Bool = true,
                         result: BatchRenameResult? = nil) async -> BatchRenamePanelAction {
        guard panel == nil else { _ = focusExistingPanel(); return .closed }
        reset(language: language)
        isRecovery = true
        self.message = message
        self.canRestore = canRestore
        self.canExport = canExport
        self.requiresFinalization = requiresFinalization
        self.requiresCommittedCleanup = requiresCommittedCleanup
        if let result { showResult(result) }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showPanel()
        }
    }

    func presentResult(_ result: BatchRenameResult, language: AppLanguage,
                       canUndo: Bool, status: ReadStatus? = nil) async -> BatchRenamePanelAction {
        guard panel == nil else { _ = focusExistingPanel(); return .closed }
        reset(language: language)
        showResult(result)
        self.canUndo = canUndo
        if let status { applyStatus(await Task.detached(priority: .utility, operation: status).value) }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            showPanel()
        }
    }

    private func reset(language: AppLanguage) {
        self.language = language
        rules = []; mode = .rules; order = .ascending; listOrder = .ascending; listText = ""
        rows = []; preview = nil; session = nil; undoPreview = nil; selectedRowID = nil
        result = nil; message = nil; isChecking = false; isRunning = false; isStopping = false
        isUndo = false; isRecovery = false; canRestore = false; canUndo = false; canExport = false
        requiresFinalization = false; requiresCommittedCleanup = false; closeRequested = false; operationFailed = false
        checkTargets = nil; execute = nil; executeUndo = nil; readStatus = nil; stopToken = BatchRenameStopToken()
        revision &+= 1
    }

    private func showPanel() {
        let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1120, height: 800)
        let size = NSSize(width: min(1120, available.width - 32), height: min(740, available.height - 64))
        let panel = BatchRenamePanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = text(isUndo ? .undoLast : .title)
        panel.identifier = NSUserInterfaceItemIdentifier("batchRenamePanel")
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = FileMintStyle.backgroundNS
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.delegate = self
        panel.submitHandler = { [weak self] in self?.submit() }
        panel.cancelHandler = { [weak self] in self?.requestClose() }
        let minimum = NSSize(width: min(900, size.width), height: min(560, size.height))
        let host = NSHostingView(rootView: BatchRenameView(model: self)
            .frame(minWidth: minimum.width, minHeight: minimum.height))
        // Export only the explicit minimum to AppKit. Changing drafts must not
        // resize the window to SwiftUI's ideal or maximum content dimensions.
        host.sizingOptions = [.minSize]
        host.frame = NSRect(origin: .zero, size: size)
        panel.contentView = host
        panel.contentMinSize = minimum
        self.panel = panel
        panel.center()
        _ = focusExistingPanel()
        Task { @MainActor [weak self, weak panel] in
            await Task.yield()
            guard let self, let panel, self.panel === panel else { return }
            _ = self.focusExistingPanel()
        }
    }

    func addRule(_ kind: BatchRenameRuleDraft.Kind) {
        guard isEditing, rules.count < BatchRenameRuleEngine.maximumRuleCount else { return }
        rules.append(.init(kind: kind)); invalidatePreview()
    }
    func updateRule(_ draft: BatchRenameRuleDraft) {
        guard isEditing, let index = rules.firstIndex(where: { $0.id == draft.id }) else { return }
        rules[index] = draft; invalidatePreview()
    }
    func removeRule(_ id: UUID) {
        guard isEditing else { return }
        rules.removeAll { $0.id == id }; invalidatePreview()
    }
    func moveRule(_ id: UUID, by offset: Int) {
        guard isEditing, let index = rules.firstIndex(where: { $0.id == id }), rules.indices.contains(index + offset) else { return }
        rules.swapAt(index, index + offset); invalidatePreview()
    }
    func setListText(_ value: String) {
        guard isEditing else { return }
        guard value.utf8.count <= BatchRenameNameList.maximumBytes else { rejectOversizedList(); return }
        listText = value
        listOrder = order
        invalidatePreview()
    }
    func rejectOversizedList() { message = text(.listTooLarge) }
    func pasteList() {
        guard isEditing, let value = NSPasteboard.general.string(forType: .string) else { return }
        setListText(value)
    }
    func chooseMode(_ requested: Mode) {
        guard isEditing, requested != mode else { return }
        if requested == .nameList, !listText.isEmpty, listOrder != order {
            guard confirmReassignment() else { return }
            listOrder = order
        }
        mode = requested; invalidatePreview()
    }
    func chooseOrder(_ requested: BatchRenameOrder) {
        guard isEditing, requested != order else { return }
        if mode == .nameList, !listText.isEmpty {
            guard confirmReassignment() else { return }
            listOrder = requested
        }
        order = requested; invalidatePreview()
    }
    private func confirmReassignment() -> Bool {
        let alert = NSAlert()
        alert.messageText = text(.reassignTitle)
        alert.informativeText = text(.reassignMessage)
        alert.addButton(withTitle: text(.cancel)).keyEquivalent = "\r"
        alert.addButton(withTitle: text(.reassign)).keyEquivalent = ""
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func invalidatePreview() {
        revision &+= 1
        preview = nil
        message = nil
        isChecking = true
        // One worker at a time bounds metadata work. An obsolete worker can
        // finish, but only the newest complete reference can enable submission.
        guard previewWorker == nil else { return }
        previewWorker = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, !self.closeRequested,
                  let session = self.session, let check = self.checkTargets {
                let capturedRevision = self.revision
                let drafts = self.rules, mode = self.mode, list = self.listText, order = self.order
                let worker = Task.detached(priority: .userInitiated) { () throws -> BatchRenamePreview in
                    let selectedMode: BatchRenameMode
                    if mode == .rules {
                        selectedMode = .rules(try drafts.enumerated().map { try $0.element.rule(index: $0.offset) })
                    } else {
                        selectedMode = .nameList(try .init(text: list, rowIDs: BatchRenamePlanner.orderedRowIDs(in: session.batch, order: order)))
                    }
                    let proposed = try BatchRenamePlanner.preview(batch: session.batch, revision: capturedRevision,
                        mode: selectedMode, order: order, caseSensitivity: session.caseSensitivity,
                        nativeNameByteLimit: session.nativeNameByteLimit)
                    // Invalid names remain visible; valid rows are still checked.
                    let snapshot: BatchRenameTargetSnapshot
                    do { snapshot = try check(proposed) }
                    catch {
                        snapshot = .init(preview: proposed, observations: proposed.rows.compactMap {
                            guard let name = $0.proposedName else { return nil }
                            return .init(rowID: $0.source.id, targetName: name, state: .failed)
                        })
                    }
                    return try BatchRenamePlanner.checkingTargets(of: proposed, using: snapshot)
                }
                let value = await worker.result
                guard !Task.isCancelled, !self.closeRequested else { break }
                guard capturedRevision == self.revision else { continue }
                self.isChecking = false
                switch value {
                case .success(let preview):
                    self.preview = preview
                    self.rows = preview.rows.map { self.display($0) }
                    self.message = preview.canFreeze || preview.counts.errors > 0 ? nil
                        : (preview.counts.checking > 0 ? self.text(.checking) : self.text(.noChanges))
                case .failure(let error):
                    self.preview = nil
                    self.message = self.describe(error)
                    self.rows = BatchRenamePlanner.orderedRowIDs(in: session.batch, order: order).compactMap { id in
                        guard let source = session.batch.sources.first(where: { $0.id == id }) else { return nil }
                        return .init(id: source.id, original: source.originalName, target: "—",
                                     state: self.text(.invalid), issue: self.message, location: nil, isError: true)
                    }
                }
                break
            }
            self.previewWorker = nil
        }
    }

    func submit() {
        guard canSubmit else { return }
        let token = stopToken
        let operation: @Sendable () throws -> BatchRenameResult
        if isUndo, let executeUndo {
            operation = { try executeUndo { token.canContinue } }
        } else {
            guard let preview, let execute, let plan = try? BatchRenamePlanner.freeze(preview) else { return }
            operation = { try execute(plan, { token.canContinue }) }
        }
        isRunning = true; message = nil
        let readStatus = self.readStatus
        Task {
            let (value, status) = await Task.detached(priority: .userInitiated) {
                (Result(catching: operation), readStatus?())
            }.value
            self.isRunning = false; self.isStopping = false
            switch value {
            case .success(let result): self.showResult(result)
            case .failure(let error):
                self.operationFailed = true
                self.message = self.describe(error)
                self.canRestore = (error as? BatchRenameError) == .recoveryRequired
                self.canExport = self.canRestore || (error as? BatchRenameError) == .corruptStore
            }
            if let status { self.applyStatus(status) }
        }
    }

    private func applyStatus(_ status: BatchRenameStoreStatus) {
        canUndo = status.canUndo && !status.hasUnresolvedOperation
        requiresFinalization = status.requiresMetadataFinalization
        requiresCommittedCleanup = status.requiresCommittedCleanup
        canRestore = status.hasUnresolvedOperation && !status.isCorrupt && !requiresFinalization
        canExport = status.hasUnresolvedOperation
        if requiresFinalization || requiresCommittedCleanup, let result {
            message = text(requiresCommittedCleanup ? .committedCleanup : .stoppedCleanup)
            rows = rows.map { row in
                guard let actual = result.rows.first(where: { $0.id == row.id }), actual.state == .target else { return row }
                return .init(id: row.id, original: row.original, target: row.target,
                             state: text(isUndo || result.outcome == .undone ? .undone : .success),
                             issue: row.issue, location: row.location, isError: false)
            }
        }
    }

    private func showResult(_ result: BatchRenameResult) {
        self.result = result
        canUndo = result.outcome == .renamed
        canRestore = result.outcome == .recoveryRequired
        canExport = result.outcome == .recoveryRequired
        message = text(result.outcome == .renamed ? .success : result.outcome == .undone ? .undone
            : result.outcome == .restored ? .restored : .recoveryNeeded)
        if let stage = result.failureStage {
            let stageText: BatchRenameText = switch stage {
            case "stage": .stoppedStaging
            case "publish": .stoppedPublishing
            case "commit": .stoppedCommitting
            case "cleanup": .stoppedCleanup
            default: .interrupted
            }
            message = (message ?? "") + "\n" + text(stageText)
        }
        rows = result.rows.map {
            let unchanged = $0.originalName.utf8.elementsEqual($0.targetName.utf8)
            let state: BatchRenameText = switch $0.state {
            case .original: unchanged ? .unchanged : .restored
            case .target: result.outcome == .recoveryRequired ? .renamedNeedsRecovery
                : result.outcome == .undone ? .undone : .success
            case .staged, .missing, .ambiguous: .recoveryNeeded
            }
            return .init(id: $0.id, original: $0.originalName, target: $0.targetName,
                         state: text(state), issue: nil, location: $0.location,
                         isError: result.outcome == .recoveryRequired && $0.state != .original)
        }
    }

    func requestStop() {
        guard isRunning else { return }
        isStopping = true
        stopToken.stop()
    }
    func requestClose() {
        if isRunning { requestStop(); return }
        guard !closeRequested else { return }
        closeRequested = true
        revision &+= 1
        previewWorker?.cancel()
        Task {
            // Retain the coordinator's grants until any in-flight read finishes.
            await previewWorker?.value
            finish(.closed)
        }
    }
    func chooseResultAction(_ action: BatchRenamePanelAction) {
        guard !isRunning, !isChecking else { return }
        finish(action)
    }
    private func finish(_ action: BatchRenamePanelAction) {
        let continuation = self.continuation
        self.continuation = nil
        panel?.delegate = nil
        panel?.close()
        panel = nil
        session = nil; checkTargets = nil; execute = nil; executeUndo = nil; undoPreview = nil; readStatus = nil
        continuation?.resume(returning: action)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { requestClose(); return false }

    private func display(_ row: BatchRenameRow) -> BatchRenameDisplayRow {
        let state: BatchRenameText = switch row.state {
        case .checking: .checking
        case .changed: .changed
        case .unchanged: .unchanged
        case .invalid: .invalid
        case .conflict: .conflict
        }
        return .init(id: row.source.id, original: row.source.originalName, target: row.proposedName ?? "—",
                     state: text(state), issue: row.issue.map(describe), location: nil,
                     isError: row.state == .invalid || row.state == .conflict)
    }
    private func describe(_ issue: BatchRenameRowIssue) -> String {
        switch issue {
        case .name(let error): return describe(error)
        case .rule(let error): return describe(error)
        case .blankNameListLine: return text(.blankLine)
        case .duplicateTarget: return text(.duplicateTarget)
        case .occupiedTarget: return text(.occupiedTarget)
        case .originalTargetMissing: return text(.missingSource)
        case .targetCheckFailed: return text(.checkFailed)
        }
    }
    private func describe(_ error: Error) -> String {
        if let error = error as? RenameNameError {
            let key: BatchRenameText = switch error {
            case .emptyBody: .emptyBody
            case .hiddenStatusChange: .hiddenChange
            case .extensionChange: .extensionChange
            case .leadingOrTrailingWhitespace: .whitespace
            case .trailingPeriod: .trailingPeriod
            case .outputNameTooLong, .originalNameTooLong: .longName
            default: .invalidCharacter
            }
            return text(key)
        }
        if let error = error as? BatchRenameRuleError {
            let key: BatchRenameText = switch error {
            case .emptySearch: .emptySearch
            case .literalTooLong: .oversizedLiteral
            case .invalidNumbering: .invalidNumber
            case .numberingOverflow: .overflow
            case .workingBodyTooLong: .oversizedBody
            default: .invalidPreview
            }
            return text(key)
        }
        if let error = error as? BatchRenamePlanningError {
            if case let .nameListLineCount(expected, actual) = error {
                return String(format: text(.lineCount), expected, actual)
            }
            return text(error == .nameListTooLarge ? .listTooLarge : .invalidList)
        }
        if let error = error as? BatchRenameError {
            let key: BatchRenameText = switch error {
            case .sourceChanged, .parentChanged: .missingSource
            case .unsupportedFilesystem, .unsupportedItem, .invalidSelection: .unsupported
            case .protectedItem, .unresolvedProtection: .protectedItem
            case .disabled: .featureDisabled
            case .invalidBookmark, .unavailable: .accessDenied
            case .recoveryRequired, .corruptStore, .storeTooLarge: .recordBlocked
            case .occupiedTarget: .occupiedTarget
            case .stalePlan, .stateChanged: .invalidPreview
            }
            return text(key)
        }
        return text(isRunning || operationFailed ? .operationFailed : .checkFailed)
    }
}

/// Ordinary Return remains owned by the field/editor. Only Command-Return is
/// routed to submit(), which independently checks the current preview revision.
private final class BatchRenamePanel: NSPanel {
    var submitHandler: (() -> Void)?
    var cancelHandler: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        // NSTextField's field editor and the list's NSTextView can consume key
        // equivalents before the responder chain reaches this panel. Route our
        // two explicit operation keys at the window boundary as well.
        if routeOperationKey(event) { return }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if routeOperationKey(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func routeOperationKey(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
        if event.keyCode == 36, modifiers == .command {
            // An unfinished input-method composition is not part of the checked
            // draft. Let ordinary Return finish composing before submission.
            if (firstResponder as? NSTextView)?.hasMarkedText() != true { submitHandler?() }
            return true
        }
        if event.keyCode == 53, modifiers.isEmpty {
            cancelHandler?()
            return true
        }
        return false
    }
    override func cancelOperation(_ sender: Any?) { cancelHandler?() }
}
