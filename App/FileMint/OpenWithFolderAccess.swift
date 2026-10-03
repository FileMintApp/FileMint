import AppKit
import FileMintCore

/// One operation's read-only access. Saving is explicit so cancellation and
/// post-picker policy failures cannot publish newly captured grants.
@MainActor
final class OpenWithFolderAccess {
    private let store: OpenWithFolderAccessStore
    private let original: [String: Data]
    private var bookmarks: [String: Data]
    private var active: [URL] = []
    private let chooseDirectory: @MainActor (URL, AppLanguage) -> URL?
    private static let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
    private static let identityKeys: Set<URLResourceKey> = [.fileResourceIdentifierKey, .volumeUUIDStringKey, .creationDateKey]

    init(store: OpenWithFolderAccessStore,
         chooseDirectory: @escaping @MainActor (URL, AppLanguage) -> URL? = OpenWithFolderAccess.chooseDirectory) throws {
        self.store = store
        let stored = try store.load()
        self.original = stored
        self.bookmarks = stored
        self.chooseDirectory = chooseDirectory
    }

    func authorize(_ directory: URL, folders: [URL], language: AppLanguage) throws -> Bool {
        var rejectedIdentity = false
        for savedDirectory in OpenWithFolderAccessStore.candidateDirectories(for: directory,
            bookmarks: bookmarks, folders: folders) {
            guard let data = bookmarks[savedDirectory.path] else { continue }
            var stale = false
            guard let restored = try? URL(resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil,
                bookmarkDataIsStale: &stale), OpenWithPolicy.isLocalFileURL(restored) else {
                bookmarks.removeValue(forKey: savedDirectory.path)
                continue
            }
            guard restored.startAccessingSecurityScopedResource() else { continue }
            guard restored.resolvingSymlinksInPath().standardizedFileURL ==
                    savedDirectory.resolvingSymlinksInPath().standardizedFileURL,
                  FolderScope.containsResolvedDirectory(restored, in: folders),
                  matchesIdentity(of: restored, bookmark: data) else {
                restored.stopAccessingSecurityScopedResource()
                bookmarks.removeValue(forKey: savedDirectory.path)
                rejectedIdentity = true
                continue
            }
            active.append(restored)
            if stale { bookmarks[savedDirectory.path] = try bookmark(for: restored) }
            if FileManager.default.isReadableFile(atPath: directory.path) { return true }
        }
        // Configured folder grants held by PreferencesModel also cover this case.
        if !rejectedIdentity && FileManager.default.isReadableFile(atPath: directory.path) { return true }
        guard let chosen = chooseDirectory(directory, language) else { return false }
        if chosen.startAccessingSecurityScopedResource() { active.append(chosen) }
        guard chosen.resolvingSymlinksInPath().standardizedFileURL ==
                directory.resolvingSymlinksInPath().standardizedFileURL else {
            throw OpenWithError.wrongAuthorizationFolder
        }
        guard FileManager.default.isReadableFile(atPath: directory.path) else { throw OpenWithError.folderAccessFailed }
        bookmarks[directory.standardizedFileURL.path] = try bookmark(for: chosen)
        return true
    }

    /// Call only after rechecking the entire captured request and app identity.
    func save() throws {
        if bookmarks != original { try store.save(bookmarks) }
    }

    func release() {
        for url in active { url.stopAccessingSecurityScopedResource() }
        active.removeAll()
    }

    private func bookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(options: Self.bookmarkOptions,
                includingResourceValuesForKeys: Self.identityKeys, relativeTo: nil)
        } catch { throw OpenWithError.folderAccessFailed }
    }

    private func matchesIdentity(of url: URL, bookmark: Data) -> Bool {
        // A bookmark can fall back to a replacement at its old path. Compare the
        // captured resource identity with fresh filesystem metadata, not the
        // resource values cached on the resolved bookmark URL.
        let saved = NSURL.resourceValues(forKeys: Array(Self.identityKeys), fromBookmarkData: bookmark)
        var fresh = URL(fileURLWithPath: url.path, isDirectory: true)
        fresh.removeAllCachedResourceValues()
        guard let expected = saved?[.fileResourceIdentifierKey] as? NSObject,
              let values = try? fresh.resourceValues(forKeys: Self.identityKeys.union([.isDirectoryKey])),
              values.isDirectory == true, let actual = values.fileResourceIdentifier,
              expected.isEqual(actual),
              saved?[.creationDateKey] as? Date == values.creationDate,
              saved?[.volumeUUIDStringKey] as? String == values.volumeUUIDString else { return false }
        return true
    }

    static func chooseDirectory(_ directory: URL, language: AppLanguage) -> URL? {
        let panel = NSOpenPanel()
        panel.title = FileMintStrings.text(.openWithApps, language: language)
        panel.message = FileMintStrings.text(.openWithAuthorizeFolder, language: language)
        panel.prompt = FileMintStrings.text(.allowFolder, language: language)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = directory
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
