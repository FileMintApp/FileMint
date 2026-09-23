import AppKit
import FileMintCore
import UniformTypeIdentifiers

/// The main app is the sole writer of pending state and user files. Requests are
/// serialized across URL callbacks, including native authorization dialogs.
@MainActor
final class FileOperationCoordinator: NSObject, NSSharingServiceDelegate {
    static let shared = FileOperationCoordinator()
    private enum QueuedRequest {
        case ticket(URL)
        case selectedImages(ResourceTool, [URL], grants: [URL])
    }
    private var queue: [QueuedRequest] = []
    private(set) var isBusy = false
    private var access: [URL] = []
    private let store: PendingFileMoveStore
    private let tickets: FileOperationTicketStore
    private let preferencesFile: URL?
    private let aliasAccessStore: DesktopAliasAccessStore
    private let desktopDirectory: URL
    private let resourceController: ResourceToolsController
    private var sharingService: NSSharingService?
    private var sharingContinuation: CheckedContinuation<Void, Error>?
    private var operationTitle: FileMintTextKey = .moveFailed

    init(store: PendingFileMoveStore = PendingFileMoveStore(),
         tickets: FileOperationTicketStore = FileOperationTicketStore(), preferencesFile: URL? = nil,
         aliasAccessStore: DesktopAliasAccessStore = DesktopAliasAccessStore(),
         desktopDirectory: URL = DesktopAliasService.desktopDirectory,
         resourceController: ResourceToolsController = .shared) {
        self.store = store
        self.tickets = tickets
        self.preferencesFile = preferencesFile
        self.aliasAccessStore = aliasAccessStore
        self.desktopDirectory = desktopDirectory
        self.resourceController = resourceController
        super.init()
    }

    func enqueue(_ url: URL) {
        queue.append(.ticket(url))
        consumeQueue()
    }

    /// This app-local entry cannot be constructed from a URL or ticket. The
    /// system picker provides the authority; Finder preferences are unchanged.
    func chooseImages(for tool: ResourceTool) {
        guard !isBusy else {
            if !resourceController.focusExistingPanel() {
                let alert = NSAlert()
                alert.messageText = text(.resourceTools)
                alert.informativeText = InterfaceText.busy.text(currentPreferences.language)
                alert.runModal()
            }
            return
        }
        isBusy = true
        defer { isBusy = false; consumeQueue() }
        let picker = NSOpenPanel()
        picker.title = tool.title(currentPreferences.language)
        picker.message = InterfaceText.chooseImages.text(currentPreferences.language)
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = true
        picker.allowedContentTypes = ResourceToolsPolicy.inputExtensions.sorted().compactMap { UTType(filenameExtension: $0) }
        guard picker.runModal() == .OK else { return }
        guard ResourceToolsPolicy.allowsAppSelection(picker.urls, tool: tool) else {
            operationTitle = .resourceTools
            show(ResourceError.invalidSelection)
            return
        }
        let grants = picker.urls.filter { $0.startAccessingSecurityScopedResource() }
        queue.append(.selectedImages(tool, picker.urls, grants: grants))
    }

    private func consumeQueue() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            while !queue.isEmpty {
                let entry = queue.removeFirst()
                let tickets = self.tickets
                do {
                    if case .selectedImages(let tool, let selection, let grants) = entry {
                        operationTitle = .resourceTools
                        access.append(contentsOf: grants)
                        try await resourceController.present(selection: selection, tool: tool, fromFinder: false)
                        releaseAccess()
                        continue
                    }
                    guard case .ticket(let url) = entry else { continue }
                    let request = try await Task.detached(priority: .userInitiated) {
                        try tickets.consume(url)
                    }.value
                    if let request {
                        switch request {
                        case .prepare, .perform: operationTitle = .moveFailed
                        case .permanentDelete: operationTitle = .permanentDelete
                        case .airDrop: operationTitle = .airDrop
                        case .desktopAlias: operationTitle = .sendAliasToDesktop
                        case .resource: operationTitle = .resourceTools
                        case .openWith: operationTitle = .openWithApps
                        }
                        try await handle(request)
                    }
                } catch { show(error) }
                releaseAccess()
            }
        }
    }

    private func handle(_ request: FileOperationRequest) async throws {
        switch request {
        case .openWith(let reference, let selection):
            guard let application = OpenWithPolicy.application(for: reference, selection: selection,
                preferences: currentPreferences) else { throw OpenWithError.changedConfiguration }
            let applicationURL = try OpenWithApplicationAccess.resolve(application)
            if applicationURL.startAccessingSecurityScopedResource() { access.append(applicationURL) }
            try OpenWithApplicationAccess.validate(application, at: applicationURL)
            var bookmarks: [String: Data] = [:]
            for parent in uniqueParents(selection) {
                guard try authorize(parent, bookmarks: &bookmarks, readOnly: true) else { return }
            }
            try requireResolvedSelection(selection)
            guard OpenWithPolicy.application(for: reference, selection: selection,
                preferences: currentPreferences) != nil else { throw OpenWithError.changedConfiguration }
            try OpenWithApplicationAccess.validate(application, at: applicationURL)
            guard selection.allSatisfy({ FileManager.default.isReadableFile(atPath: $0.path) }) else {
                throw OpenWithError.missingSelection
            }
            try await OpenWithApplicationAccess.open(selection, with: applicationURL)

        case .resource(let tool, let selection):
            guard ResourceToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: currentPreferences).contains(tool) else { throw ResourceError.disabled }
            var bookmarks: [String: Data] = [:]
            for parent in uniqueParents(selection) {
                guard try authorize(parent, bookmarks: &bookmarks, readOnly: true) else { return }
            }
            try requireResolvedSelection(selection)
            guard ResourceToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: currentPreferences).contains(tool) else { throw ResourceError.disabled }
            try await resourceController.present(selection: selection, tool: tool)

        case .prepare(let selection):
            guard FileToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: currentPreferences).contains(.move) else { throw FileMoveError.disabled }
            var bookmarks: [String: Data] = [:]
            for parent in uniqueParents(selection) {
                guard try authorize(parent, bookmarks: &bookmarks) else { return }
            }
            try requireResolvedSelection(selection)
            guard FileToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: currentPreferences).contains(.move) else { throw FileMoveError.disabled }
            let savedBookmarks = bookmarks
            let store = self.store
            try await Task.detached(priority: .userInitiated) {
                let pending = try PendingFileMove.capture(selection: selection, bookmarks: savedBookmarks)
                try store.save(pending)
            }.value

        case .permanentDelete(let items, let confirmation):
            let selection = items.map(\.source)
            try require(.permanentDelete, selection: selection)
            var bookmarks: [String: Data] = [:]
            for parent in uniqueParents(selection) {
                guard try authorize(parent, bookmarks: &bookmarks) else { return }
            }
            try requireResolvedSelection(selection)
            try require(.permanentDelete, selection: selection)
            try await Task.detached(priority: .userInitiated) { try FileDeletionService.validate(items) }.value
            let requiresConfirmation = DeleteConfirmation.isRequired(captured: confirmation, current: currentPreferences.fileTools.deleteConfirmation)
            if requiresConfirmation {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = String(format: text(.deleteConfirmTitle), items.count)
                alert.informativeText = text(.deleteConfirmMessage)
                alert.addButton(withTitle: text(.cancel))
                alert.addButton(withTitle: text(.permanentDelete))
                alert.buttons[0].keyEquivalent = "\r"
                alert.buttons[1].keyEquivalent = ""
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertSecondButtonReturn else { return }
            }
            try requireResolvedSelection(selection)
            try require(.permanentDelete, selection: selection)
            let preferencesFile = self.preferencesFile
            try await Task.detached(priority: .userInitiated) {
                try FileDeletionService.performPerItem(items: items) { item in
                    let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
                    return FileToolsPolicy.availableTools(selection: [item.source], isItemMenu: true,
                        preferences: preferences).contains(.permanentDelete) &&
                        FolderScope.containsResolvedItem(item.source, in: preferences.monitoredFolderURLs) &&
                        (requiresConfirmation || preferences.fileTools.deleteConfirmation == .silent)
                }
            }.value

        case .airDrop(let selection):
            try require(.airDrop, selection: selection)
            var bookmarks: [String: Data] = [:]
            for parent in uniqueParents(selection) {
                guard try authorize(parent, bookmarks: &bookmarks, readOnly: true) else { return }
            }
            try requireResolvedSelection(selection)
            try require(.airDrop, selection: selection)
            guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: selection) else {
                showMessage(.airDropUnavailable)
                return
            }
            sharingService = service
            service.delegate = self
            defer { sharingService?.delegate = nil; sharingService = nil }
            NSApp.activate(ignoringOtherApps: true)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                sharingContinuation = continuation
                service.perform(withItems: selection)
            }

        case .desktopAlias(let items):
            let selection = items.map(\.source)
            try require(.desktopAlias, selection: selection)
            var bookmarks = try aliasAccessStore.load()
            for parent in uniqueParents(selection) {
                guard try authorize(parent, bookmarks: &bookmarks, readOnly: true) else { return }
                try aliasAccessStore.save(bookmarks)
            }
            guard try authorize(desktopDirectory, bookmarks: &bookmarks,
                                message: .desktopAliasAuthorize) else { return }
            try aliasAccessStore.save(bookmarks)
            try requireResolvedSelection(selection)
            try require(.desktopAlias, selection: selection)
            let directory = desktopDirectory
            let preferencesFile = self.preferencesFile
            _ = try await Task.detached(priority: .userInitiated) {
                try DesktopAliasService.performPerItem(items: items, in: directory) { item in
                    let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
                    return FileToolsPolicy.availableTools(selection: [item.source], isItemMenu: true,
                        preferences: preferences).contains(.desktopAlias)
                        && FolderScope.containsResolvedItem(item.source, in: preferences.monitoredFolderURLs)
                }
            }.value

        case .perform(let batchID, let destination):
            guard var pending = try store.load(), pending.id == batchID else { throw FileMoveError.staleRequest }
            try validate(pending, destination: destination)
            var bookmarks = pending.bookmarks
            for parent in uniqueParents(pending.items.map(\.source)) {
                guard try authorize(parent, bookmarks: &bookmarks) else { return }
            }
            guard try authorize(destination, bookmarks: &bookmarks) else { return }
            try requireResolvedSelection(pending.items.map(\.source))
            guard FolderScope.containsResolvedDirectory(destination, in: currentPreferences.monitoredFolderURLs) else {
                throw FileMoveError.disabled
            }
            // Preserve new folder grants even if a later item cannot be moved.
            pending.bookmarks = bookmarks
            try store.save(pending)
            let store = self.store
            let preferencesFile = self.preferencesFile
            try await Task.detached(priority: .userInitiated) {
                try FileMoveService().performPerItem(batchID: batchID, to: destination, store: store) { item in
                    let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
                    return FileToolsPolicy.availableTools(selection: [item.source], isItemMenu: true,
                        preferences: preferences).contains(.move) &&
                        FolderScope.containsResolvedDirectory(destination, in: preferences.monitoredFolderURLs) &&
                        FolderScope.containsResolvedItem(item.source, in: preferences.monitoredFolderURLs)
                }
            }.value
        }
    }

    private func text(_ key: FileMintTextKey) -> String {
        FileMintStrings.text(key, language: currentPreferences.language)
    }

    private func require(_ tool: FileTool, selection: [URL]) throws {
        guard FileToolsPolicy.availableTools(selection: selection, isItemMenu: true,
            preferences: currentPreferences).contains(tool) else { throw FileMoveError.disabled }
    }

    private func requireResolvedSelection(_ selection: [URL]) throws {
        let roots = currentPreferences.monitoredFolderURLs
        guard selection.allSatisfy({ FolderScope.containsResolvedItem($0, in: roots) }) else {
            throw FileMoveError.disabled
        }
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        let continuation = sharingContinuation
        sharingContinuation = nil
        continuation?.resume()
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        let continuation = sharingContinuation
        sharingContinuation = nil
        if (error as NSError).code == NSUserCancelledError {
            continuation?.resume()
        } else { continuation?.resume(throwing: error) }
    }

    private var currentPreferences: FileMintPreferences { FileMintPreferencesStore(fileURL: preferencesFile).load() }

    private func validate(_ pending: PendingFileMove, destination: URL) throws {
        let preferences = currentPreferences
        guard FileMovePolicy.isEnabled(preferences, pending: pending),
              FolderScope.contains(destination, in: preferences.monitoredFolderURLs) else { throw FileMoveError.disabled }
        try FileMovePolicy.validateDestination(destination, items: pending.items)
    }

    private func uniqueParents(_ selection: [URL]) -> [URL] {
        var seen = Set<String>()
        return selection.map { $0.deletingLastPathComponent().standardizedFileURL }
            .filter { seen.insert($0.path).inserted }
    }

    /// Grants never expand the configured Finder menu scope. Existing folder
    /// bookmarks are already held by PreferencesModel; additional grants belong
    /// to the operation's private store (pending moves or desktop aliases).
    /// Active access is released after the request.
    private func authorize(_ directory: URL, bookmarks: inout [String: Data], readOnly: Bool = false,
                           message: FileMintTextKey = .fileOperationAuthorize) throws -> Bool {
        if let data = bookmarks[directory.path] {
            var stale = false
            if let restored = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                relativeTo: nil, bookmarkDataIsStale: &stale),
               restored.standardizedFileURL.path == directory.standardizedFileURL.path,
               restored.startAccessingSecurityScopedResource() {
                access.append(restored)
                if stale {
                    bookmarks[directory.path] = try restored.bookmarkData(options: .withSecurityScope,
                        includingResourceValuesForKeys: nil, relativeTo: nil)
                }
            }
        }
        let manager = FileManager.default
        if manager.isReadableFile(atPath: directory.path) && (readOnly || manager.isWritableFile(atPath: directory.path)) { return true }
        let language = currentPreferences.language
        let panel = NSOpenPanel()
        panel.title = FileMintStrings.text(operationTitle, language: language)
        panel.message = FileMintStrings.text(message, language: language)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = directory
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let chosen = panel.url else { return false }
        guard chosen.resolvingSymlinksInPath().standardizedFileURL.path ==
            directory.resolvingSymlinksInPath().standardizedFileURL.path else {
            showMessage(.moveChooseExactFolder)
            return false
        }
        let started = chosen.startAccessingSecurityScopedResource()
        if started { access.append(chosen) }
        bookmarks[directory.path] = try chosen.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
        return true
    }

    private func releaseAccess() {
        for url in access { url.stopAccessingSecurityScopedResource() }
        access = []
    }

    private func show(_ error: Error) {
        if operationTitle == .openWithApps {
            showMessage((error as? OpenWithError)?.messageKey ?? .openWithFailed)
            return
        }
        if let error = error as? ResourceError {
            let alert = NSAlert()
            alert.messageText = text(.resourceTools)
            alert.informativeText = error.message(currentPreferences.language)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        if let failure = error as? DesktopAliasFailure {
            let alert = NSAlert()
            alert.messageText = text(.sendAliasToDesktop)
            alert.informativeText = String(format: text(.desktopAliasFailedCount), failure.completed, failure.total - failure.completed)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        if let failure = error as? FileDeletionFailure {
            let alert = NSAlert()
            alert.messageText = text(.permanentDelete)
            alert.informativeText = String(format: text(.deleteFailedCount), failure.completed, failure.total - failure.completed)
            if let url = failure.recoveryURL {
                alert.informativeText += "\n" + String(format: text(.fileOperationRecoveryPath), url.path)
            }
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        if operationTitle != .moveFailed {
            showMessage(.fileOperationFailed)
            return
        }
        if let error = error as? FileMoveError {
            if let recovery = error.recoveryURL {
                let alert = NSAlert()
                alert.messageText = text(.moveFailed)
                alert.informativeText = String(format: text(.fileOperationRecoveryPath), recovery.path)
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
                return
            }
            let key: FileMintTextKey = switch error {
            case .invalidSelection: .moveInvalidSelection
            case .sourceChanged: .moveSourceChanged
            case .invalidDestination: .moveInvalidDestination
            case .destinationExists: .moveDestinationExists
            case .staleRequest: .moveStaleRequest
            case .disabled: .moveDisabled
            case .recoveryRequired: .moveSourceChanged
            }
            showMessage(key)
        } else {
            let alert = NSAlert()
            alert.messageText = FileMintStrings.text(operationTitle, language: currentPreferences.language)
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private func showMessage(_ key: FileMintTextKey) {
        let alert = NSAlert()
        alert.messageText = FileMintStrings.text(operationTitle, language: currentPreferences.language)
        alert.informativeText = FileMintStrings.text(key, language: currentPreferences.language)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
