import AppKit
import Darwin
import FileMintCore

/// Holds sandbox access for exactly the folders selected by the user.
@MainActor
final class FolderAccess {
    enum Selection: Equatable { case file, folder, item }
    private var activeURLs: [URL] = []

    func restore(_ preferences: FileMintPreferences) {
        for url in activeURLs { url.stopAccessingSecurityScopedResource() }
        activeURLs = preferences.monitoredFolderURLs.compactMap { pathURL in
            guard let data = preferences.monitoredFolderBookmarks[pathURL.path] else { return nil }
            return Self.startSavedAccess(to: pathURL, bookmark: data)
        }
    }

    /// Match both path spellings, then verify the grant covers the real parent.
    /// The caller owns the returned access until its read worker finishes.
    nonisolated static func startSavedAccess(to directory: URL, resolved: URL? = nil,
                                             in preferences: FileMintPreferences) -> [URL] {
        startSavedAccess(to: directory, resolved: resolved, roots: preferences.monitoredFolderURLs,
                         bookmarks: preferences.monitoredFolderBookmarks)
    }

    nonisolated static func startSavedAccess(to directory: URL, resolved: URL? = nil,
                                             roots: [URL], bookmarks: [String: Data]) -> [URL] {
        let realParent = resolved ?? directory.resolvingSymlinksInPath().standardizedFileURL
        return roots.compactMap { root in
            guard FolderScope.contains(directory, in: [root]) || FolderScope.contains(realParent, in: [root]),
                  let data = bookmarks[root.path],
                  let url = startSavedAccess(to: root, bookmark: data) else { return nil }
            guard FolderScope.containsResolvedDirectory(directory, in: [url]) else {
                url.stopAccessingSecurityScopedResource()
                return nil
            }
            return url
        }
    }

    nonisolated static func startSavedAccess(to target: URL, bookmark: Data,
                                             withoutMounting: Bool = false) -> URL? {
        var stale = false
        var options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
        if withoutMounting { options.insert(.withoutMounting) }
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: options,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource() else { return nil }
        guard url.resolvingSymlinksInPath().standardizedFileURL.path ==
                target.resolvingSymlinksInPath().standardizedFileURL.path else {
            url.stopAccessingSecurityScopedResource()
            return nil
        }
        return url
    }

    static func remember(_ url: URL, in preferences: inout FileMintPreferences) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        if !preferences.monitoredFolderURLs.contains(url) { preferences.monitoredFolderURLs.append(url) }
        preferences.monitoredFolderBookmarks[url.path] = data
    }

    nonisolated static func isPermissionError(_ error: Error) -> Bool {
        if (error as? FileInfoError) == .accessDenied { return true }
        let error = error as NSError
        return (error.domain == NSPOSIXErrorDomain && [Int(EPERM), Int(EACCES)].contains(error.code))
            || (error.domain == NSCocoaErrorDomain && [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(error.code))
    }

    /// Non-mutating kernel check for operations that must not be attempted twice.
    nonisolated static func checkAccess(to url: URL, mode: Int32, followSymbolicLinks: Bool = true) throws {
        try url.withUnsafeFileSystemRepresentation { path in
            guard url.isFileURL, let path else { throw CocoaError(.fileReadUnsupportedScheme) }
            let flags = AT_EACCESS | (followSymbolicLinks ? 0 : AT_SYMLINK_NOFOLLOW)
            guard faccessat(AT_FDCWD, path, mode, flags) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        }
    }

    nonisolated static func checkDirectory(_ directory: URL, mode: Int32) throws {
        guard directory.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        let descriptor = open(directory.path, O_SEARCH | O_CLOEXEC)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(descriptor) }
        guard faccessat(descriptor, ".", mode | X_OK, AT_EACCESS) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    static func authorizationPanel(for target: URL? = nil, selection: Selection,
                                   language: AppLanguage, detail: String? = nil) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = FileMintStrings.text(.authorizationTitle, language: language)
        panel.prompt = FileMintStrings.text(.authorizeAccess, language: language)
        let message: String
        if let target {
            let key: FileMintTextKey = switch selection {
            case .file: .authorizeNamedFile
            case .folder: .authorizeNamedFolder
            case .item: .authorizeNamedItem
            }
            message = String(format: FileMintStrings.text(key, language: language), target.lastPathComponent)
        } else {
            message = FileMintStrings.text(.authorizeSelectedFolders, language: language)
        }
        panel.message = detail.map { message + "\n" + $0 } ?? message
        panel.canChooseFiles = selection != .folder
        panel.canChooseDirectories = selection != .file
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.directoryURL = selection == .folder ? target : target?.deletingLastPathComponent()
        return panel
    }

    /// Reacquire a matching saved grant for one external session rather than
    /// relying on the settings controller's grant surviving later preference edits.
    nonisolated static func externalDirectory(_ directory: URL, preferences: FileMintPreferences,
                                              remembered: RememberedFileAccess? = nil) throws -> ExternalDirectoryResolution {
        let resolvedPath = directory.resolvingSymlinksInPath().standardizedFileURL
        let roots = preferences.monitoredFolderURLs.filter {
            FolderScope.contains(directory, in: [$0]) || FolderScope.contains(resolvedPath, in: [$0])
        }
            .sorted { $0.path.count > $1.path.count }
        for root in roots {
            guard let data = preferences.monitoredFolderBookmarks[root.path],
                  let resolved = startSavedAccess(to: root, bookmark: data, withoutMounting: true) else { continue }
            do {
                guard FolderScope.containsResolvedDirectory(directory, in: [resolved]) else {
                    resolved.stopAccessingSecurityScopedResource()
                    continue
                }
                let target = directory.resolvingSymlinksInPath().standardizedFileURL
                return try .init(url: target, identity: CreationDirectoryIdentity.capture(target), startedScopeURL: resolved)
            } catch {
                resolved.stopAccessingSecurityScopedResource()
                throw error
            }
        }
        let scopes = remembered?.start(for: directory, folder: true, mode: .write,
                                       roots: preferences.monitoredFolderURLs + [directory]) ?? []
        if let scope = scopes.first {
            scopes.dropFirst().forEach { $0.stopAccessingSecurityScopedResource() }
            do {
                let target = directory.resolvingSymlinksInPath().standardizedFileURL
                return try .init(url: target, identity: CreationDirectoryIdentity.capture(target), startedScopeURL: scope)
            } catch {
                scope.stopAccessingSecurityScopedResource()
                throw error
            }
        }
        return try ExternalDraftDirectoryAccess.resolveDirectory(directory)
    }

    static func persist(_ directory: URL) throws {
        let store = FileMintPreferencesStore()
        try store.update { try remember(directory, in: &$0) }
        DistributedNotificationCenter.default().post(
            name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil
        )
    }
}

/// General authorization granted by an explicit file-operation picker. These
/// stores are independent of Finder configuration and tool-specific records.
struct RememberedFileAccess: Sendable {
    enum Mode: Sendable { case read, write }
    private static let identityKeys: Set<URLResourceKey> = [.fileResourceIdentifierKey, .creationDateKey, .volumeUUIDStringKey]
    private let directory: URL

    init(preferencesFile: URL?) {
        directory = preferencesFile?.deletingLastPathComponent() ?? FileMintStorage.directory
    }

    private func store(_ mode: Mode) -> ScopedBookmarkStore {
        ScopedBookmarkStore(file: directory.appendingPathComponent(mode == .read ? "file-read-access.json" : "file-write-access.json"))
    }

    func start(for target: URL, folder: Bool, mode: Mode, roots: [URL]) -> [URL] {
        start(for: [target], folders: folder, mode: mode, roots: roots)
    }

    func start(for targets: [URL], folders: Bool, mode: Mode, roots: [URL]) -> [URL] {
        var seen = Set<String>()
        let candidates = targets.flatMap { Self.candidates(for: $0, folder: folders) }.filter { seen.insert($0.url.path).inserted }
        let modes: [Mode] = mode == .read ? [.write, .read] : [.write]
        return modes.flatMap { savedMode -> [URL] in
            guard let bookmarks = try? store(savedMode).load() else { return [] }
            return candidates.compactMap { target in
                guard let bookmark = bookmarks[target.url.path] else { return nil }
                return Self.start(bookmark, target: target.url, folder: target.folder, roots: roots)
            }
        }
    }

    private static func candidates(for target: URL, folder: Bool) -> [(url: URL, folder: Bool)] {
        guard OpenWithPolicy.isLocalFileURL(target), target.path.hasPrefix("/") else { return [] }
        let canonicalParent = target.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let canonical = folder ? target.resolvingSymlinksInPath().standardizedFileURL
            : canonicalParent.appendingPathComponent(target.lastPathComponent)
        var candidates = [(url: canonical, folder: folder)]
        var parent = canonical.deletingLastPathComponent()
        while parent.path.hasPrefix("/"), parent.path != canonical.path {
            candidates.append((parent, true))
            if parent.path == "/" { break }
            parent.deleteLastPathComponent()
        }
        return candidates
    }

    func remember(_ chosen: URL, target: URL, folder: Bool, mode: Mode, roots: [URL],
                  validate: () throws -> Void = {}) throws -> URL {
        let started = chosen.startAccessingSecurityScopedResource()
        defer { if started { chosen.stopAccessingSecurityScopedResource() } }
        try validate()
        let options: URL.BookmarkCreationOptions = mode == .read ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess] : .withSecurityScope
        let bookmark = try chosen.bookmarkData(options: options, includingResourceValuesForKeys: Self.identityKeys, relativeTo: nil)
        guard let scope = Self.start(bookmark, target: target, folder: folder, roots: roots) else { throw FileInfoError.accessDenied }
        do {
            try validate()
            let store = store(mode)
            do {
                var bookmarks = try store.load()
                bookmarks[target.path] = bookmark
                try store.save(bookmarks)
            } catch { throw FileInfoError.accessSaveFailed }
            return scope
        } catch {
            scope.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    private static func start(_ bookmark: Data, target: URL, folder: Bool, roots: [URL]) -> URL? {
        guard let url = FolderAccess.startSavedAccess(to: target, bookmark: bookmark, withoutMounting: true) else { return nil }
        let inScope = folder ? FolderScope.containsResolvedDirectory(target, in: roots)
            : FolderScope.containsResolvedItem(target, in: roots)
        guard inScope, matchesIdentity(target, bookmark: bookmark, folder: folder) else {
            url.stopAccessingSecurityScopedResource()
            return nil
        }
        return url
    }

    private static func matchesIdentity(_ target: URL, bookmark: Data, folder: Bool) -> Bool {
        let saved = NSURL.resourceValues(forKeys: Array(identityKeys), fromBookmarkData: bookmark)
        let fresh = URL(fileURLWithPath: target.path, isDirectory: folder)
        guard let expected = saved?[.fileResourceIdentifierKey] as? NSObject,
              let values = try? fresh.resourceValues(forKeys: identityKeys.union([.isDirectoryKey, .isSymbolicLinkKey])),
              values.isSymbolicLink == false, !folder || values.isDirectory == true,
              let actual = values.fileResourceIdentifier, expected.isEqual(actual),
              saved?[.creationDateKey] as? Date == values.creationDate,
              saved?[.volumeUUIDStringKey] as? String == values.volumeUUIDString else { return false }
        return true
    }
}
