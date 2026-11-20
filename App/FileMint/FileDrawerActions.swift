import AppKit
import FileMintCore

extension FileDrawerModel {
    func openSelection() {
        guard !busy, selectedEntries.count == 1, let item = selectedEntries.first, let location else { return }
        if item.isDirectory { navigate(item.url); return }
        guard item.isRegular, !item.isLink, !item.isOffline else {
            message = text("Use Show in Finder for this item.", "请在 Finder 中查看此项目。")
            return
        }
        Task {
            do {
                try await Task.detached { try location.folder.validate(item) }.value
                guard presented, self.location?.folder === location.folder else { return }
                guard NSWorkspace.shared.open(item.url) else { throw CocoaError(.fileReadUnknown) }
            } catch { report(error) }
        }
    }

    func reveal() {
        guard !busy else { return }
        let urls = selectedEntries.map(\.url)
        NSWorkspace.shared.activateFileViewerSelecting(urls.isEmpty ? [directory].compactMap { $0 } : urls)
    }

    func favorite() {
        guard !busy, let source = location else { return }
        let items = selectedEntries
        let urls = items.isEmpty ? [source.folder.url] : items.map(\.url)
        Task {
            // The caller keeps the source grant through the repository's async capture.
            defer { withExtendedLifetime(source) {} }
            do {
                try await Task.detached {
                    try source.folder.validate()
                    for item in items { try source.folder.validate(item) }
                }.value
                let result = try await favorites.add(urls)
                message = String(format: FavoriteText.added.text(settings.preferences.language), result.added, result.duplicates)
            } catch { report(error) }
        }
    }

    func copyPaths() {
        let paths = selectedEntries.map { $0.url.path }
        guard !paths.isEmpty else { return }
        let board = NSPasteboard.general
        board.clearContents()
        if !board.setString(paths.joined(separator: "\n"), forType: .string) {
            message = text("Could not copy the paths.", "无法拷贝所选路径。")
        }
    }

    func newFile() {
        presentNewFile(in: nil)
    }

    func newFileInSelectedFolder() {
        guard selection.count == 1, let entry = selectedEntries.first, entry.canEnterDirectory else { return }
        presentNewFile(in: entry)
    }

    private func presentNewFile(in child: FileDrawerEntry?) {
        guard presented, !busy, !interacting, let location else { return }
        let creation = CustomFileSavePanelController.shared
        draftWindow = creation.panel
        if creation.focusExistingPanel() { return }
        guard settings.pendingCreationCount == 0, !FileOperationCoordinator.shared.isBusy else {
            message = text("Another file operation is in progress.", "另一项文件操作正在进行中。")
            return
        }
        do {
            let preferences = settings.committedPreferences
            let seed = try ExternalDraftRequest().resolve(preferences: preferences, capturedAt: Date())
            let session = UUID(), directory = child?.url ?? location.folder.url
            let access = ExternalDraftDirectoryAccess(url: directory, nativeGrantURL: location.grant.started ?? location.grant.url)
            let context = ExternalDraftPresentation(sessionID: session, seed: seed, source: .fileDrawer, directory: access,
                validateTemplate: { [weak settings] id in
                    guard let id else { return true }
                    return settings?.committedPreferences.templates.contains { $0.id == id && $0.isEnabled } == true
                }, didClose: { [weak self, weak origin = window] in
                    guard let self, let origin, self.window === origin, self.presented else { return }
                    self.draftWindow = nil
                    if NSApp.isActive { origin.makeKeyAndOrderFront(nil) }
                    if self.directory == location.folder.url { self.refresh() }
                })
            creation.present(in: directory, preferences: preferences, documentTemplates: settings.documentTemplates, external: context)
            if creation.ownsExternalSession(session) {
                draftWindow = creation.externalWindow
                access.prepare(using: {
                    let folder = try child.map { try location.folder.child($0) } ?? location.folder
                    try folder.validate()
                    let identity = try CreationDirectoryIdentity.capture(directory)
                    try folder.validate()
                    return ExternalDirectoryResolution(url: directory, identity: identity, startedScopeURL: nil)
                }, didChange: { creation.externalDirectoryDidChange(session) })
            } else { access.releaseWhenIdle() }
        } catch { report(error) }
    }

    func newFolder() {
        guard !busy, let source = location else { return }
        askName(title: text("New Folder", "新建文件夹"), initial: text("Untitled Folder", "未命名文件夹")) { name in
            self.batch([name], work: { try source.folder.createFolder(named: $0) }, finished: { _ in })
        }
    }

    func rename() {
        guard presented, !busy, !interacting, let item = selectedEntries.first, selection.count == 1 else { return }
        message = nil
        renameDraft = item.name
        interacting = true
        renamingEntry = item
    }

    func cancelRename() {
        guard renamingEntry != nil else { return }
        renamingEntry = nil
        renameDraft = ""
        interacting = false
        message = nil
    }

    func commitRename(_ name: String, of item: FileDrawerEntry) {
        guard renamingEntry?.isSameItem(as: item) == true, selection == [item.url], let source = location else { return }
        renameDraft = name
        runWrite({
            Result { try source.folder.rename(item, to: name) }
        }) { result in
            guard self.location?.folder === source.folder else { return }
            switch result {
            case .success(let destination):
                self.cancelRename()
                self.refreshAfterRename(item, to: destination)
            case .failure(let error):
                if error as? FileMoveError == .sourceChanged {
                    self.cancelRename()
                    self.selection.remove(item.url)
                    self.refresh()
                }
                self.report(error)
            }
        }
    }

    private func askName(title: String, initial: String, action: @escaping @MainActor (String) -> Void) {
        guard let window, !interacting else { return }
        let input = NSTextField(string: initial)
        input.frame.size = .init(width: 300, height: 24)
        input.setAccessibilityLabel(title)
        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = input
        alert.addButton(withTitle: title)
        alert.addButton(withTitle: text("Cancel", "取消"))
        alert.window.initialFirstResponder = input
        interacting = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.interacting = false
            if self.presented, response == .alertFirstButtonReturn { action(input.stringValue) }
        }
    }

    func copySelection(move: Bool) {
        guard !busy, let source = location, !selectedEntries.isEmpty else { return }
        transfer = Transfer(source: source, items: selectedEntries, move: move)
        clipboardAvailable = true
        message = text("Selection ready. Navigate to the destination and choose Paste.", "已暂存选区。进入目标文件夹后选「粘贴」。")
    }

    func paste() {
        guard let transfer, let target = location else { return }
        runTransfer(transfer, target: { target }, fromClipboard: true)
    }

    func moveSelection(to folder: URL) {
        guard let source = location, let destination = entries.first(where: { $0.url == folder && $0.isDirectory }) else { return }
        let request = Transfer(source: source, items: selectedEntries, move: true)
        runTransfer(request, target: { try source.child(destination) })
    }

    func chooseDestination(move: Bool) {
        guard let source = location, !selectedEntries.isEmpty else { return }
        let request = Transfer(source: source, items: selectedEntries, move: move)
        pickFolder { url in
            let grant = FileDrawerGrant.selected(url)
            self.runTransfer(request, target: { try FileDrawerLocation(grant: grant) })
        }
    }

    private func runTransfer(_ request: Transfer, target: @escaping @Sendable () throws -> FileDrawerLocation,
                             fromClipboard: Bool = false) {
        guard !busy else { return }
        // Resolve the destination just once, before starting the batch.
        performBatch(request.items, prepare: {
            let destination = try target()
            try request.source.folder.validateTransfer(request.items, to: destination.folder, move: request.move)
            return { item in
                try request.source.folder.transfer(item, to: destination.folder, move: request.move)
                return item.url
            }
        }, finished: { completed in
            if fromClipboard, request.move {
                let done = Set(completed)
                let pending = request.items.filter { !done.contains($0.url) }
                self.transfer = pending.isEmpty ? nil : Transfer(source: request.source, items: pending, move: true)
                self.clipboardAvailable = !pending.isEmpty
            }
        })
    }

    func trash() {
        guard !busy, !interacting, let window, let source = location else { return }
        let items = selectedEntries
        guard !items.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = text("Move \(items.count) items to Trash?", "将 \(items.count) 项移到废纸篓？")
        alert.addButton(withTitle: text("Cancel", "取消"))
        alert.addButton(withTitle: text("Move to Trash", "移到废纸篓"))
        interacting = true
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.interacting = false
            guard self.presented, response == .alertSecondButtonReturn else { return }
            self.batch(items, work: { try source.folder.trash($0) }, finished: { receipts in
                let available = receipts.compactMap { $0 }
                if !available.isEmpty { self.trashReceipts.append((available, source.grant)) }
                if available.count < receipts.count {
                    self.message = self.text("Some trashed items can only be restored in Finder.", "部分项目需要在 Finder 的废纸篓中放回。")
                }
                self.canRestore = !self.trashReceipts.isEmpty
            })
        }
    }

    func restore() {
        guard !busy, let (receipts, grant) = trashReceipts.last else { return }
        batch(receipts, work: { item in
            defer { withExtendedLifetime(grant) {} }
            try item.directory.restore(item)
            return item.originalURL
        }, finished: { results in
            let remaining = Array(receipts.dropFirst(results.count))
            self.trashReceipts.removeLast()
            if !remaining.isEmpty { self.trashReceipts.append((remaining, grant)) }
            self.canRestore = !self.trashReceipts.isEmpty
        })
    }

    private func batch<Item: Sendable, Value: Sendable>(_ items: [Item],
                work: @escaping @Sendable (Item) throws -> Value, finished: @escaping ([Value]) -> Void) {
        performBatch(items, prepare: { work }, finished: finished)
    }

    private func performBatch<Item: Sendable, Value: Sendable>(_ items: [Item],
                prepare: @escaping @Sendable () throws -> (@Sendable (Item) throws -> Value),
                finished: @escaping ([Value]) -> Void) {
        guard !items.isEmpty else { return }
        runWrite({
            var values: [Value] = []
            do {
                let work = try prepare()
                for item in items { values.append(try work(item)) }
                return (values, nil as Error?)
            } catch { return (values, error) }
        }) { values, error in
            self.refresh()
            finished(values)
            if let error {
                self.message = self.text("Completed \(values.count)/\(items.count). ", "已完成 \(values.count)/\(items.count) 项。") + self.errorText(error)
            }
        }
    }

    private func runWrite<Value: Sendable>(_ work: @escaping @Sendable () -> Value, finished: @escaping (Value) -> Void) {
        guard presented, !busy else { return }
        guard settings.pendingCreationCount == 0, !CustomFileSavePanelController.shared.hasActiveWrite,
              !UpdateModel.shared.isCommittingInstallation,
              let release = FileOperationCoordinator.shared.reserveExternalPresentation() else {
            message = text("Another file operation is in progress.", "另一项文件操作正在进行中。")
            return
        }
        closePreview()
        writing = true
        busy = true
        Task {
            let result = await Task.detached(priority: .userInitiated, operation: work).value
            writing = false
            busy = false
            release()
            guard presented else { return }
            finished(result)
        }
    }
}
