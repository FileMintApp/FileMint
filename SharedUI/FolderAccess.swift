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

    static func persist(_ directory: URL) throws {
        let store = FileMintPreferencesStore()
        var preferences = store.load()
        try remember(directory, in: &preferences)
        try store.save(preferences)
        DistributedNotificationCenter.default().post(
            name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil
        )
    }
}
