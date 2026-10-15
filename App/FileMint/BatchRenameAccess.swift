import AppKit
import FileMintCore

/// Each operation owns its active scopes. Normal batches also restore remembered
/// parent grants; operation records remain independent undo/recovery authority.
@MainActor
final class BatchRenameAccess {
    private var active: [URL] = []
    private let store: BatchRenameAccessStore?
    private let chooseDirectory: @MainActor (URL, AppLanguage) -> URL?

    init(store: BatchRenameAccessStore? = nil,
         chooseDirectory: @escaping @MainActor (URL, AppLanguage) -> URL? = BatchRenameAccess.chooseDirectory) {
        self.store = store
        self.chooseDirectory = chooseDirectory
    }

    func release() {
        active.forEach { $0.stopAccessingSecurityScopedResource() }
        active.removeAll()
    }

    func authorize(parent: URL, identity: BatchRenameIdentity, bookmark: Data?,
                   allowRelocation: Bool, language: AppLanguage) async throws -> (URL, Data)? {
        var renewalRequired = false
        if let store {
            let saved = try await Task.detached(priority: .userInitiated) { try store.load() }.value
            for candidate in BatchRenameAccessStore.candidates(for: parent, identity: identity, grants: saved) {
                if let grant = await restore(candidate.grant.bookmark, parent: parent, identity: identity,
                                             allowRelocation: allowRelocation, savedGrant: candidate.grant) { return grant }
                renewalRequired = true
            }
        }
        // A rejected remembered grant needs renewed consent, even if a temporary
        // Powerbox grant still makes the old pathname accessible in this process.
        if !renewalRequired {
            if let bookmark, let grant = await restore(bookmark, parent: parent, identity: identity,
                                                       allowRelocation: allowRelocation) { return grant }
            if let grant = try await usable(parent, expected: parent, identity: identity,
                                            allowRelocation: allowRelocation),
               let held = try await retain(grant, identity: identity) { return held }
        }

        guard let chosen = chooseDirectory(parent, language) else { return nil }
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

    private func restore(_ bookmark: Data, parent: URL, identity: BatchRenameIdentity,
                         allowRelocation: Bool, savedGrant: BatchRenameAccessGrant? = nil) async -> (URL, Data)? {
        let restored = try? await Task.detached(priority: .userInitiated) {
            var stale = false
            return try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                           relativeTo: nil, bookmarkDataIsStale: &stale)
        }.value
        guard let restored, restored.startAccessingSecurityScopedResource() else { return nil }
        active.append(restored)
        do {
            if let grant = try await usable(restored, expected: parent, identity: identity,
                                           allowRelocation: allowRelocation, savedGrant: savedGrant),
               let held = try await retain(grant, identity: identity) { return held }
        } catch { /* A failed saved grant requires the original-parent picker. */ }
        restored.stopAccessingSecurityScopedResource()
        active.removeLast()
        return nil
    }

    static func chooseDirectory(_ parent: URL, language: AppLanguage) -> URL? {
        let picker = NSOpenPanel()
        picker.title = BatchRenameText.title.text(language)
        picker.message = language.resolved() == .chinese
            ? "请选择这次操作原来的父文件夹。将记住此文件夹的授权，不会扩大 Finder 菜单范围。"
            : "Choose this operation’s original parent folder. Access will be remembered without expanding Finder menu scope."
        picker.directoryURL = parent
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.canCreateDirectories = false
        picker.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        return picker.runModal() == .OK ? picker.url : nil
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
                        allowRelocation: Bool, savedGrant: BatchRenameAccessGrant? = nil) async throws -> (URL, Data)? {
        await Task.detached(priority: .userInitiated) {
            do {
                let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
                guard allowRelocation || resolved == expected.standardizedFileURL,
                      try identity.matchesDirectory(at: resolved),
                      FileManager.default.isReadableFile(atPath: resolved.path),
                      FileManager.default.isWritableFile(atPath: resolved.path) else { return nil }
                if let savedGrant {
                    // Resolved bookmark URLs can cache old resource values.
                    var fresh = URL(fileURLWithPath: resolved.path, isDirectory: true)
                    fresh.removeAllCachedResourceValues()
                    let volume = try fresh.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
                    guard savedGrant.matchesIdentity(identity, volumeUUID: volume) else { return nil }
                }
                let data = try candidate.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: [.volumeUUIDStringKey], relativeTo: nil)
                return (resolved, data)
            } catch { return nil }
        }.value
    }
}
