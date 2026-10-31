import AppKit
import FileMintCore

/// Holds sandbox access for exactly the folders selected by the user.
@MainActor
final class FolderAccess {
    private var activeURLs: [URL] = []

    func restore(_ preferences: FileMintPreferences) {
        for url in activeURLs { url.stopAccessingSecurityScopedResource() }
        activeURLs = preferences.monitoredFolderURLs.compactMap { pathURL in
            guard let data = preferences.monitoredFolderBookmarks[pathURL.path] else { return nil }
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                                     relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { return nil }
            guard url.resolvingSymlinksInPath().standardizedFileURL ==
                    pathURL.resolvingSymlinksInPath().standardizedFileURL else {
                url.stopAccessingSecurityScopedResource()
                return nil
            }
            return url
        }
    }

    static func remember(_ url: URL, in preferences: inout FileMintPreferences) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        if !preferences.monitoredFolderURLs.contains(url) { preferences.monitoredFolderURLs.append(url) }
        preferences.monitoredFolderBookmarks[url.path] = data
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let error = error as NSError
        return (error.domain == NSPOSIXErrorDomain && [1, 13].contains(error.code))
            || (error.domain == NSCocoaErrorDomain && [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(error.code))
    }

    /// Reacquire a matching saved grant for one external session rather than
    /// relying on the settings controller's grant surviving later preference edits.
    nonisolated static func externalDirectory(_ directory: URL, preferences: FileMintPreferences) throws -> ExternalDirectoryResolution {
        let roots = preferences.monitoredFolderURLs.filter { FolderScope.contains(directory, in: [$0]) }
            .sorted { $0.path.count > $1.path.count }
        for root in roots {
            guard let data = preferences.monitoredFolderBookmarks[root.path] else { continue }
            var stale = false
            guard let resolved = try? URL(resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil,
                bookmarkDataIsStale: &stale), resolved.startAccessingSecurityScopedResource() else { continue }
            do {
                guard resolved.resolvingSymlinksInPath().standardizedFileURL == root.resolvingSymlinksInPath().standardizedFileURL,
                      FolderScope.containsResolvedDirectory(directory, in: [resolved]) else {
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
