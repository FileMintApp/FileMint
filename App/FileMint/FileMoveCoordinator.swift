import AppKit
import FileMintCore

/// The main app is the sole writer of pending state and user files. Requests are
/// serialized across URL callbacks, including native authorization dialogs.
@MainActor
final class FileMoveCoordinator {
    static let shared = FileMoveCoordinator()
    private var queue: [URL] = []
    private(set) var isBusy = false
    private var access: [URL] = []
    private let store: PendingFileMoveStore
    private let tickets: FileMoveTicketStore
    private let preferencesFile: URL?

    init(store: PendingFileMoveStore = PendingFileMoveStore(),
         tickets: FileMoveTicketStore = FileMoveTicketStore(), preferencesFile: URL? = nil) {
        self.store = store
        self.tickets = tickets
        self.preferencesFile = preferencesFile
    }

    func enqueue(_ url: URL) {
        queue.append(url)
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            while !queue.isEmpty {
                let url = queue.removeFirst()
                let tickets = self.tickets
                do {
                    let request = try await Task.detached(priority: .userInitiated) {
                        try tickets.consume(url)
                    }.value
                    if let request { try await handle(request) }
                } catch { show(error) }
                releaseAccess()
            }
        }
    }

    private func handle(_ request: FileMoveRequest) async throws {
        switch request {
        case .prepare(let selection):
            guard FileToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: currentPreferences).contains(.move) else { throw FileMoveError.disabled }
            var bookmarks: [String: Data] = [:]
            for parent in uniqueParents(selection) {
                guard try authorize(parent, bookmarks: &bookmarks) else { return }
            }
            guard FileToolsPolicy.availableTools(selection: selection, isItemMenu: true,
                preferences: currentPreferences).contains(.move) else { throw FileMoveError.disabled }
            let savedBookmarks = bookmarks
            let store = self.store
            try await Task.detached(priority: .userInitiated) {
                let pending = try PendingFileMove.capture(selection: selection, bookmarks: savedBookmarks)
                try store.save(pending)
            }.value

        case .perform(let batchID, let destination):
            guard var pending = try store.load(), pending.id == batchID else { throw FileMoveError.staleRequest }
            try validate(pending, destination: destination)
            var bookmarks = pending.bookmarks
            for parent in uniqueParents(pending.items.map(\.source)) {
                guard try authorize(parent, bookmarks: &bookmarks) else { return }
            }
            guard try authorize(destination, bookmarks: &bookmarks) else { return }
            // Preserve new folder grants even if a later item cannot be moved.
            pending.bookmarks = bookmarks
            try store.save(pending)
            let store = self.store
            let preferencesFile = self.preferencesFile
            try await Task.detached(priority: .userInitiated) {
                try FileMoveService().perform(batchID: batchID, to: destination, store: store) { pending in
                    let preferences = FileMintPreferencesStore(fileURL: preferencesFile).load()
                    return FileMovePolicy.isEnabled(preferences, pending: pending) &&
                        FolderScope.contains(destination, in: preferences.monitoredFolderURLs)
                }
            }.value
        }
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
    /// only to this pending operation and are released after the request.
    private func authorize(_ directory: URL, bookmarks: inout [String: Data]) throws -> Bool {
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
        if manager.isReadableFile(atPath: directory.path) && manager.isWritableFile(atPath: directory.path) { return true }
        let language = currentPreferences.language
        let panel = NSOpenPanel()
        panel.title = FileMintStrings.text(.moveItems, language: language)
        panel.message = FileMintStrings.text(.moveAuthorizeFolder, language: language)
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
        if let error = error as? FileMoveError {
            let key: FileMintTextKey = switch error {
            case .invalidSelection: .moveInvalidSelection
            case .sourceChanged: .moveSourceChanged
            case .invalidDestination: .moveInvalidDestination
            case .destinationExists: .moveDestinationExists
            case .staleRequest: .moveStaleRequest
            case .disabled: .moveDisabled
            }
            showMessage(key)
        } else {
            let alert = NSAlert()
            alert.messageText = FileMintStrings.text(.moveFailed, language: currentPreferences.language)
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    private func showMessage(_ key: FileMintTextKey) {
        let alert = NSAlert()
        alert.messageText = FileMintStrings.text(.moveFailed, language: currentPreferences.language)
        alert.informativeText = FileMintStrings.text(key, language: currentPreferences.language)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
