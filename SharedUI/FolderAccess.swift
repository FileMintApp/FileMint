import AppKit
import Darwin
import FileMintCore

@MainActor
enum FolderAccess {
    enum Selection: Equatable { case file, folder, item }

    /// Legacy Finder bookmarks are still usable and individually removable.
    /// Scope applies to the requested directory, independently of the grant root.
    nonisolated static func startSavedAccess(to directory: URL, resolved: URL? = nil,
                                             in preferences: FileMintPreferences,
                                             requiresFinderScope: Bool = true) -> [URL] {
        startLegacyAccess(to: directory, resolved: resolved, bookmarks: preferences.monitoredFolderBookmarks,
                          finderRoots: requiresFinderScope ? preferences.monitoredFolderURLs : nil)
    }

    nonisolated static func startLegacyAccess(to directory: URL, resolved: URL? = nil,
                                               bookmarks: [String: Data], finderRoots: [URL]?) -> [URL] {
        let grantRoots = bookmarks.keys.filter { $0.hasPrefix("/") }.sorted().map { URL(fileURLWithPath: $0, isDirectory: true) }
        let scopes = startSavedAccess(to: directory, resolved: resolved, roots: grantRoots, bookmarks: bookmarks)
        if let finderRoots, !scopes.isEmpty, !FolderScope.containsResolvedDirectory(directory, in: finderRoots) {
            scopes.forEach { $0.stopAccessingSecurityScopedResource() }
            return []
        }
        return scopes
    }

    nonisolated static func startSavedAccess(to directory: URL, resolved: URL? = nil,
                                             roots: [URL], bookmarks: [String: Data]) -> [URL] {
        let realParent = resolved ?? directory.resolvingSymlinksInPath().standardizedFileURL
        return roots.compactMap { root in
            guard FolderScope.contains(directory, in: [root]) || FolderScope.contains(realParent, in: [root]),
                  let data = bookmarks[root.path],
                  let url = startSavedAccess(to: root, bookmark: data, withoutMounting: true) else { return nil }
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

    static func directoryWritePanel(for target: URL? = nil, language: AppLanguage) -> NSOpenPanel {
        authorizationPanel(for: target, selection: .folder, language: language,
                           detail: FileMintStrings.text(.directoryWriteAuthorizationHint, language: language))
    }

    /// Saved grants only cover metadata preparation here. Create reacquires
    /// them so an open draft cannot keep a forgotten grant alive.
    nonisolated static func externalDirectory(_ directory: URL, preferences: FileMintPreferences,
                                              remembered: RememberedFileAccess? = nil) throws -> ExternalDirectoryResolution {
        let scopes = startSavedAccess(to: directory, in: preferences) + (remembered?.start(for: directory,
            folder: true, mode: .write, roots: preferences.monitoredFolderURLs, allowExactOutsideScope: true) ?? [])
        defer { scopes.forEach { $0.stopAccessingSecurityScopedResource() } }
        return try ExternalDraftDirectoryAccess.resolveDirectory(directory)
    }
}

/// General authorization granted by an explicit file-operation picker. These
/// stores are independent of Finder configuration and tool-specific records.
struct RememberedFileAccess: Sendable {
    enum Mode: Sendable { case read, write }
    static let directoryWritesChanged = Notification.Name("FileMintDirectoryWritesChanged")
    private static let identityKeys: Set<URLResourceKey> = [.fileResourceIdentifierKey, .creationDateKey, .volumeUUIDStringKey]
    private let directory: URL

    init(preferencesFile: URL?) {
        directory = preferencesFile?.deletingLastPathComponent() ?? FileMintStorage.directory
    }

    private func store(_ mode: Mode) -> ScopedBookmarkStore {
        ScopedBookmarkStore(file: directory.appendingPathComponent(mode == .read ? "file-read-access.json" : "file-write-access.json"))
    }

    func directoryWritePaths() throws -> [String] { try store(.write).load().keys.sorted() }

    @MainActor
    func forgetDirectoryWrite(at path: String) throws {
        let store = store(.write)
        var bookmarks = try store.load()
        guard bookmarks.removeValue(forKey: path) != nil else { return }
        try store.save(bookmarks)
        NotificationCenter.default.post(name: Self.directoryWritesChanged, object: nil)
    }

    @MainActor
    func rememberWriteDirectory(_ chosen: URL, expected: URL? = nil) throws {
        let target = chosen.resolvingSymlinksInPath().standardizedFileURL
        if let expected, target.path != expected.resolvingSymlinksInPath().standardizedFileURL.path {
            throw FileInfoError.invalidSelection
        }
        let scope = try remember(chosen, target: target, folder: true, mode: .write, roots: nil)
        scope.stopAccessingSecurityScopedResource()
    }

    func start(for target: URL, folder: Bool, mode: Mode, roots: [URL]?, allowExactOutsideScope: Bool = false) -> [URL] {
        start(for: [target], folders: folder, mode: mode, roots: roots, allowExactOutsideScope: allowExactOutsideScope)
    }

    func start(for targets: [URL], folders: Bool, mode: Mode, roots: [URL]?, allowExactOutsideScope: Bool = false) -> [URL] {
        var seen = Set<String>()
        let modes: [Mode] = mode == .read ? [.read, .write] : [.write]
        let stores = modes.compactMap { try? store($0).load() }
        return targets.compactMap { target in
            let candidates = Self.candidates(for: target, folder: folders)
            for (index, bookmarks) in stores.enumerated() {
                for (offset, candidate) in candidates.enumerated() {
                    guard let bookmark = bookmarks[candidate.url.path],
                          let scope = Self.start(bookmark, target: candidate.url, folder: candidate.folder) else { continue }
                    // Validate the request after acquiring the grant. Validating
                    // its ancestor against the menu list would reject wider grants.
                    let coverage = Self.contains(target, folder: folders, in: [scope])
                    let allowed = roots.map { Self.contains(target, folder: folders, in: $0) } ?? true
                    if coverage && (allowed || (allowExactOutsideScope && offset == 0)) {
                        if seen.insert("\(index):\(candidate.url.path)").inserted { return scope }
                        scope.stopAccessingSecurityScopedResource()
                        return nil
                    }
                    scope.stopAccessingSecurityScopedResource()
                }
            }
            return nil
        }
    }

    private static func contains(_ target: URL, folder: Bool, in roots: [URL]) -> Bool {
        folder ? FolderScope.containsResolvedDirectory(target, in: roots) : FolderScope.containsResolvedItem(target, in: roots)
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

    @MainActor
    func remember(_ chosen: URL, target: URL, folder: Bool, mode: Mode, roots: [URL]?,
                  validate: () throws -> Void = {}) throws -> URL {
        let started = chosen.startAccessingSecurityScopedResource()
        defer { if started { chosen.stopAccessingSecurityScopedResource() } }
        try validate()
        let options: URL.BookmarkCreationOptions = mode == .read ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess] : .withSecurityScope
        let bookmark = try chosen.bookmarkData(options: options, includingResourceValuesForKeys: Self.identityKeys, relativeTo: nil)
        guard let scope = Self.start(bookmark, target: target, folder: folder) else { throw FileInfoError.accessDenied }
        do {
            if let roots, !Self.contains(target, folder: folder, in: roots) { throw FileInfoError.accessDenied }
            try validate()
            let store = store(mode)
            do {
                var bookmarks = try store.load()
                bookmarks[target.path] = bookmark
                try store.save(bookmarks)
            } catch { throw FileInfoError.accessSaveFailed }
            if mode == .write { NotificationCenter.default.post(name: Self.directoryWritesChanged, object: nil) }
            return scope
        } catch {
            scope.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    private static func start(_ bookmark: Data, target: URL, folder: Bool) -> URL? {
        guard let url = FolderAccess.startSavedAccess(to: target, bookmark: bookmark, withoutMounting: true) else { return nil }
        guard matchesIdentity(target, bookmark: bookmark, folder: folder) else {
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
