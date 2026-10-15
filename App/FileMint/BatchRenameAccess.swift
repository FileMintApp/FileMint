import AppKit
import FileMintCore

/// Operation-local exact-parent grants. These bookmarks are only written to the
/// rename control record; authorization never changes Finder observation scope.
@MainActor
final class BatchRenameAccess {
    private var active: [URL] = []

    func release() {
        active.forEach { $0.stopAccessingSecurityScopedResource() }
        active.removeAll()
    }

    func authorize(parent: URL, identity: BatchRenameIdentity, bookmark: Data?,
                   allowRelocation: Bool, language: AppLanguage) async throws -> (URL, Data)? {
        if let bookmark {
            let restored = try? await Task.detached(priority: .userInitiated) {
                var stale = false
                return try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                               relativeTo: nil, bookmarkDataIsStale: &stale)
            }.value
            if let restored {
                let started = restored.startAccessingSecurityScopedResource()
                if started { active.append(restored) }
                if let grant = try await usable(restored, expected: parent, identity: identity,
                                                allowRelocation: allowRelocation),
                   let held = try await retain(grant, identity: identity) { return held }
                if started {
                    restored.stopAccessingSecurityScopedResource()
                    active.removeLast()
                }
            }
        }
        if let grant = try await usable(parent, expected: parent, identity: identity,
                                        allowRelocation: allowRelocation),
           let held = try await retain(grant, identity: identity) { return held }

        let picker = NSOpenPanel()
        picker.title = BatchRenameText.title.text(language)
        picker.message = language.resolved() == .chinese
            ? "请选择这次操作原来的父文件夹。授权不会扩大 Finder 菜单范围。"
            : "Choose this operation’s original parent folder. This does not expand Finder menu scope."
        picker.directoryURL = parent
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.canCreateDirectories = false
        picker.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let chosen = picker.url else { return nil }
        if chosen.startAccessingSecurityScopedResource() { active.append(chosen) }
        guard let grant = try await usable(chosen, expected: parent, identity: identity,
                                          allowRelocation: allowRelocation) else {
            throw BatchRenameError.invalidBookmark
        }
        guard let held = try await retain(grant, identity: identity) else {
            throw BatchRenameError.invalidBookmark
        }
        return held
    }

    /// Keep our own exact-parent extension alive even if preferences releases an
    /// ancestor grant while the panel is open. Rollback must retain its authority.
    private func retain(_ grant: (URL, Data), identity: BatchRenameIdentity) async throws -> (URL, Data)? {
        let (parent, data) = grant
        let restored = try await Task.detached(priority: .userInitiated) {
            var stale = false
            return try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                           relativeTo: nil, bookmarkDataIsStale: &stale)
        }.value
        guard restored.startAccessingSecurityScopedResource() else { return nil }
        do {
            let valid = try await Task.detached(priority: .userInitiated) {
                guard restored.resolvingSymlinksInPath().standardizedFileURL == parent else { return false }
                return try identity.matchesDirectory(at: parent)
            }.value
            guard valid else { restored.stopAccessingSecurityScopedResource(); return nil }
        } catch {
            restored.stopAccessingSecurityScopedResource()
            throw error
        }
        active.append(restored)
        return grant
    }

    private func usable(_ candidate: URL, expected: URL, identity: BatchRenameIdentity,
                        allowRelocation: Bool) async throws -> (URL, Data)? {
        await Task.detached(priority: .userInitiated) {
            do {
                let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
                guard allowRelocation || resolved == expected.standardizedFileURL,
                      try identity.matchesDirectory(at: resolved),
                      FileManager.default.isReadableFile(atPath: resolved.path),
                      FileManager.default.isWritableFile(atPath: resolved.path) else { return nil }
                let data = try candidate.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: nil, relativeTo: nil)
                return (resolved, data)
            } catch { return nil }
        }.value
    }
}
