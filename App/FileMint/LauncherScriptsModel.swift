import AppKit
import Combine
import FileMintCore

struct LauncherScriptEdit: Sendable {
    let record: LauncherScriptRecord
    let snapshot: LauncherScriptSnapshot
    let command: LauncherCommand
    let url: URL
}

@MainActor
final class LauncherScriptsModel: ObservableObject {
    @Published private(set) var records: [LauncherScriptRecord] = []
    @Published private(set) var isWorking = false
    @Published private(set) var error: String?
    let store: LauncherScriptStore
    private let language: () -> AppLanguage

    init(store: LauncherScriptStore, language: @escaping () -> AppLanguage) {
        self.store = store
        self.language = language
        do { records = try store.load() }
        catch { report(error) }
    }

    func text(_ en: String, _ zh: String) -> String { language().resolved() == .chinese ? zh : en }

    func register(_ url: URL, id: UUID? = nil) async throws {
        let record = try await Task.detached(priority: .userInitiated) {
            try Self.record(url, id: id)
        }.value
        try remember(record)
    }

    private func remember(_ record: LauncherScriptRecord) throws {
        var next = try store.load()
        next.removeAll { $0.id == record.id || $0.url == record.url }
        next.append(record)
        try store.save(next)
        records = next
        error = nil
    }

    nonisolated private static func record(_ url: URL, id: UUID? = nil) throws -> LauncherScriptRecord {
        let snapshot = try LauncherScriptSnapshot.read(at: url)
        let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        return try LauncherScriptRecord(id: id ?? UUID(), url: url, bookmark: bookmark, snapshot: snapshot)
    }

    nonisolated private static func withAccess<T: Sendable>(_ record: LauncherScriptRecord,
        operation: (URL) throws -> T) throws -> T {
        var stale = false
        let url = try URL(resolvingBookmarkData: record.bookmark, options: [.withSecurityScope, .withoutUI],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        // A resolved, unchanged file can refresh its stale bookmark after a save.
        return try operation(url)
    }

    func edit(_ record: LauncherScriptRecord, bundleIdentifier: String, scheme: String) async throws -> LauncherScriptEdit {
        try await Task.detached(priority: .userInitiated) {
            try Self.withAccess(record) { url in
                let snapshot = try record.read(at: url), contents = try snapshot.contents()
                guard contents.bundleIdentifier == bundleIdentifier, contents.scheme == scheme else { throw LauncherScriptError.invalidScript }
                return LauncherScriptEdit(record: record, snapshot: snapshot, command: contents.command, url: url)
            }
        }.value
    }

    /// The caller owns the same settings-work reservation as an ordinary export.
    func update(_ edit: LauncherScriptEdit, command: LauncherCommand, bundleIdentifier: String, scheme: String) async throws -> (url: URL, edit: LauncherScriptEdit?) {
        let (url, refreshed) = try await Task.detached(priority: .userInitiated) {
            try Self.withAccess(edit.record) { url in
                _ = try edit.record.read(at: url)
                try command.exportRaycast(to: url, bundleIdentifier: bundleIdentifier, scheme: scheme, replacing: edit.snapshot)
                // File publication has succeeded. A later bookmark/index failure
                // must not report that the script itself failed to save.
                let refreshed = Result {
                    let record = try Self.record(url, id: edit.record.id)
                    return LauncherScriptEdit(record: record, snapshot: try record.read(at: url), command: command, url: url)
                }
                return (url, refreshed)
            }
        }.value
        var source: LauncherScriptEdit?
        do {
            let value = try refreshed.get()
            source = value
            try remember(value.record)
        }
        catch {
            self.error = text("Script updated, but its list entry could not be saved. Add the existing script again.",
                              "脚本已更新，但未能保存列表记录。请重新添加已有脚本。")
        }
        return (url, source)
    }

    func addExisting(owner: NSWindow, bundleIdentifier: String, scheme: String, finished: @escaping @MainActor () -> Void) {
        guard !isWorking, owner.attachedSheet == nil else { return }
        let picker = NSOpenPanel()
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.message = text("Choose a script exported by FileMint. The script will be read, never executed.", "选择 FileMint 导出的脚本。添加时只读取配置，不运行脚本。")
        isWorking = true
        picker.beginSheetModal(for: owner) { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                defer { self.isWorking = false; finished() }
                guard response == .OK, let url = picker.url else { return }
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                do {
                    let record = try await Task.detached(priority: .userInitiated) {
                        let snapshot = try LauncherScriptSnapshot.read(at: url), contents = try snapshot.contents()
                        guard contents.bundleIdentifier == bundleIdentifier, contents.scheme == scheme else { throw LauncherScriptError.invalidScript }
                        return try Self.record(url)
                    }.value
                    try self.remember(record)
                } catch { self.report(error) }
            }
        }
    }

    func reveal(_ record: LauncherScriptRecord) {
        Task {
            do {
                let url = try await Task.detached { try Self.withAccess(record) { $0 } }.value
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch { report(error) }
        }
    }

    func forget(_ record: LauncherScriptRecord) {
        do { try removeRecord(record) }
        catch { report(error) }
    }

    private func removeRecord(_ record: LauncherScriptRecord) throws {
        let next = try store.load().filter { $0.id != record.id }
        try store.save(next)
        records = next
        error = nil
    }

    func trash(_ record: LauncherScriptRecord, finished: @escaping @MainActor () -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false; finished() }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try Self.withAccess(record) { url in
                        var coordinationError: NSError?
                        var result: Result<Void, Error>?
                        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forDeleting,
                            error: &coordinationError) { target in
                                result = Result {
                                    guard target.standardizedFileURL == url.standardizedFileURL else { throw LauncherScriptError.changedScript }
                                    _ = try record.read(at: target)
                                    try FileManager.default.trashItem(at: target, resultingItemURL: nil)
                                }
                            }
                        if let coordinationError { throw coordinationError }
                        guard let result else { throw LauncherScriptError.unavailable }
                        try result.get()
                    }
                }.value
                do { try removeRecord(record) }
                catch {
                    self.error = text("Script moved to Trash, but its list entry could not be removed. Remove the entry after fixing the list access.",
                                      "脚本已移到废纸篓，但未能移除列表记录。恢复列表访问后可仅移除记录。")
                }
            } catch { report(error) }
        }
    }

    func report(_ failure: Error) {
        error = switch failure as? LauncherScriptError {
        case .invalidScript: text("Choose an unmodified script exported by this FileMint app.", "请选择由当前 FileMint 导出且未经外部修改的脚本。")
        case .changedScript: text("The script changed outside FileMint. Its contents were preserved. Reveal it in Finder, or remove only its list entry.", "脚本已在 FileMint 外发生变化，现有内容已保留。可在 Finder 中查看，或仅移除列表记录。")
        case .invalidIndex: text("The script list could not be read or saved. Its existing data has been preserved.", "无法读取或保存脚本列表，原有记录已保留。")
        default: text("The script is unavailable or access has expired. Reveal it in Finder or add the existing script again.", "脚本不可用或访问权限已失效。请在 Finder 中检查，或重新添加已有脚本。")
        }
    }

    func reportSavedIndexFailure() {
        error = text("Script saved, but it could not be added to the list. Use Add Existing Script to try again.",
                     "脚本已保存，但未能加入管理列表。可用“添加已有脚本”重试。")
    }
}
