import AppKit
import FileMintCore

@MainActor
final class FavoriteLocationsModel: ObservableObject {
    private static var sharedInstance: FavoriteLocationsModel?
    static var shared: FavoriteLocationsModel {
        if let sharedInstance { return sharedInstance }
        let instance = FavoriteLocationsModel()
        sharedInstance = instance
        return instance
    }
    static var sharedIsBusy: Bool { sharedInstance?.isBusy ?? false }
    @Published private(set) var catalog = FavoriteLocationsCatalog()
    @Published private(set) var recoveryRequired = false
    @Published private(set) var unavailableIDs: Set<UUID> = []
    @Published private(set) var isChecking = false
    @Published private(set) var isLoading = true
    @Published private(set) var pendingOperations = 0
    var isBusy: Bool { isLoading || pendingOperations > 0 }
    @Published private(set) var backupURL: URL?
    @Published var message: String?
    private let repository: FavoriteLocationsRepository
    private var revision: UInt64 = 0
    private var hasSnapshot = false
    private var loading: Task<Void, Never>?

    init(store: FavoriteLocationsStore = FavoriteLocationsStore()) {
        repository = FavoriteLocationsRepository(store: store)
        loading = Task {
            defer { isLoading = false }
            do { apply(try await repository.snapshot()) }
            catch { recoveryRequired = true }
        }
    }

    func waitUntilLoaded() async { await loading?.value }

    func backupAndReset(language: AppLanguage) async {
        guard recoveryRequired else { return }
        pendingOperations += 1
        defer { pendingOperations -= 1 }
        do {
            let (backup, snapshot) = try await repository.backupAndReset()
            apply(snapshot)
            unavailableIDs = []
            recoveryRequired = false
            backupURL = backup
            message = String(format: FavoriteText.recovered.text(language), backup.lastPathComponent)
            DistributedNotificationCenter.default().post(
                name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil)
        } catch { message = error.localizedDescription }
    }

    var quickItems: [FavoriteLocation] { catalog.quickItems() }

    private func apply(_ snapshot: FavoriteLocationsSnapshot) {
        guard !hasSnapshot || snapshot.revision > revision else { return }
        hasSnapshot = true
        revision = snapshot.revision
        catalog = snapshot.catalog
    }

    private func edit<Result: Sendable>(
        _ change: @Sendable (inout FavoriteLocationsCatalog) throws -> Result
    ) async throws -> Result {
        pendingOperations += 1
        defer { pendingOperations -= 1 }
        await waitUntilLoaded()
        guard !recoveryRequired else { throw FavoriteLocationError.damagedCatalog }
        do {
            let (result, snapshot) = try await repository.update(change)
            apply(snapshot)
            message = nil
            DistributedNotificationCenter.default().post(
                name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil)
            return result
        } catch {
            if error as? FavoriteLocationError == .damagedCatalog { recoveryRequired = true }
            throw error
        }
    }

    @discardableResult
    func add(_ urls: [URL], isAllowed: @escaping @Sendable () -> Bool = { true }) async throws -> FavoriteAddResult {
        pendingOperations += 1
        defer { pendingOperations -= 1 }
        await waitUntilLoaded()
        guard !recoveryRequired, (1...100).contains(urls.count) else { throw FavoriteLocationError.invalidSelection }
        let captured = try await Task.detached(priority: .userInitiated) {
            try urls.map { url in
                let grant = url.startAccessingSecurityScopedResource()
                defer { if grant { url.stopAccessingSecurityScopedResource() } }
                return try Self.capture(url)
            }
        }.value
        return try await edit {
            guard isAllowed() else { throw FavoriteLocationError.invalidSelection }
            return try $0.add(captured)
        }
    }

    func chooseItems(language: AppLanguage) {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = false
        panel.title = FavoriteText.choose.text(language)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task {
            do {
                let result = try await add(urls)
                message = String(format: FavoriteText.added.text(language), result.added, result.duplicates)
            } catch { message = FavoriteText.addFailed.text(language) }
        }
    }

    func remove(_ ids: Set<UUID>) async throws {
        try await edit { $0.items.removeAll { ids.contains($0.id) } }
        unavailableIDs.subtract(ids)
    }

    func setPinned(_ ids: Set<UUID>, to value: Bool) async throws {
        try await edit { changed in
            for index in changed.items.indices where ids.contains(changed.items[index].id) {
                changed.items[index].isPinned = value
            }
        }
    }

    func movePinned(_ id: UUID, by offset: Int) async throws {
        try await edit { $0.movePinned(id, by: offset) }
    }

    func movePinned(_ id: UUID, to targetID: UUID) async throws {
        try await edit { $0.movePinned(id, to: targetID) }
    }

    func setGroup(_ ids: Set<UUID>, to group: String) async throws {
        let group = String(group.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        try await edit { changed in
            for index in changed.items.indices where ids.contains(changed.items[index].id) {
                changed.items[index].group = group
            }
        }
    }

    func updateDetails(_ id: UUID, name: String, group: String) async throws {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        let group = String(group.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !name.isEmpty else { throw FavoriteLocationError.invalidSelection }
        try await edit { changed in
            guard let index = changed.items.firstIndex(where: { $0.id == id }) else { throw FavoriteLocationError.unavailable }
            changed.items[index].name = name
            changed.items[index].group = group
        }
    }

    func clearRecent() async throws {
        try await edit { changed in
            for index in changed.items.indices {
                changed.items[index].addedAt = nil
                changed.items[index].lastLocatedAt = nil
            }
        }
    }

    func checkAvailability(_ id: UUID) async {
        guard let item = catalog.items.first(where: { $0.id == id }) else { return }
        let available = await Task.detached(priority: .utility) { Self.isAvailable(item) }.value
        guard catalog.items.first(where: { $0.id == id }) == item else { return }
        if available { unavailableIDs.remove(id) }
        else { unavailableIDs.insert(id) }
    }

    func checkAllAvailability() {
        guard !isChecking else { return }
        isChecking = true
        let items = catalog.items
        Task {
            let unavailable = await Task.detached(priority: .utility) {
                Set(items.filter { !Self.isAvailable($0) }.map(\.id))
            }.value
            // A relink or removal while the check is running must not restore
            // an obsolete warning from the previous bookmark.
            let current = Dictionary(uniqueKeysWithValues: catalog.items.map { ($0.id, $0) })
            for item in items where current[item.id] == item {
                if unavailable.contains(item.id) { unavailableIDs.insert(item.id) }
                else { unavailableIDs.remove(item.id) }
            }
            isChecking = false
        }
    }

    nonisolated private static func isAvailable(_ item: FavoriteLocation) -> Bool {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: item.bookmark,
            options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) else { return false }
        let grant = url.startAccessingSecurityScopedResource()
        defer { if grant { url.stopAccessingSecurityScopedResource() } }
        return (try? validate(url, for: item)) != nil
    }

    func locate(_ id: UUID) async throws { try await activate(id, openFile: false) }

    func openFile(_ id: UUID) async throws { try await activate(id, openFile: true) }

    private func activate(_ id: UUID, openFile: Bool) async throws {
        pendingOperations += 1
        defer { pendingOperations -= 1 }
        await waitUntilLoaded()
        guard let item = catalog.items.first(where: { $0.id == id }) else { throw FavoriteLocationError.unavailable }
        guard !openFile || item.kind == .file else { throw FavoriteLocationError.invalidSelection }
        let access: ResolvedFavorite
        do {
            access = try await Task.detached(priority: .userInitiated) { try Self.resolve(item) }.value
        }
        catch {
            if catalog.items.first(where: { $0.id == id })?.bookmark == item.bookmark { unavailableIDs.insert(id) }
            throw error
        }
        let resolved = access.url
        defer { if access.granted { resolved.stopAccessingSecurityScopedResource() } }
        guard catalog.items.first(where: { $0.id == id })?.bookmark == item.bookmark else {
            throw FavoriteLocationError.unavailable
        }
        if openFile || item.kind == .folder {
            guard NSWorkspace.shared.open(resolved) else { throw FavoriteLocationError.unavailable }
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([resolved])
        }
        unavailableIDs.remove(id)
        try await edit { changed in
            guard let index = changed.items.firstIndex(where: { $0.id == id }),
                  changed.items[index].bookmark == item.bookmark else { return }
            changed.items[index].url = resolved.standardizedFileURL
            if let refreshed = access.bookmark { changed.items[index].bookmark = refreshed }
            changed.items[index].lastLocatedAt = Date()
        }
    }

    private struct ResolvedFavorite: Sendable {
        let url: URL
        let granted: Bool
        let bookmark: Data?
    }

    nonisolated private static func resolve(_ item: FavoriteLocation) throws -> ResolvedFavorite {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: item.bookmark,
            options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil,
            bookmarkDataIsStale: &stale) else { throw FavoriteLocationError.unavailable }
        let granted = url.startAccessingSecurityScopedResource()
        do {
            try validate(url, for: item)
            // Renewal failure must not prevent opening an otherwise valid item.
            return ResolvedFavorite(url: url, granted: granted, bookmark: stale ? try? bookmark(for: url) : nil)
        } catch {
            if granted { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    func relink(_ id: UUID, language: AppLanguage, pickerDidClose: (() -> Void)? = nil) async {
        await waitUntilLoaded()
        guard let item = catalog.items.first(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = item.kind == .file
        panel.canChooseDirectories = item.kind == .folder
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.title = FavoriteText.relink.text(language)
        panel.directoryURL = item.url.deletingLastPathComponent()
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        pickerDidClose?()
        guard response == .OK, let url = panel.url else { return }
        pendingOperations += 1
        defer { pendingOperations -= 1 }
        do {
            let replacement = try await Task.detached(priority: .userInitiated) {
                let grant = url.startAccessingSecurityScopedResource()
                defer { if grant { url.stopAccessingSecurityScopedResource() } }
                return try Self.capture(url, id: id)
            }.value
            guard replacement.kind == item.kind else { throw FavoriteLocationError.invalidSelection }
            try await edit { changed in
                guard let index = changed.items.firstIndex(where: { $0.id == id }),
                      changed.items[index].bookmark == item.bookmark else { throw FavoriteLocationError.unavailable }
                guard !changed.containsTarget(replacement, excluding: id) else {
                    throw FavoriteLocationError.invalidSelection
                }
                var refreshed = replacement
                let current = changed.items[index]
                refreshed.name = current.name
                refreshed.group = current.group
                refreshed.isPinned = current.isPinned
                refreshed.addedAt = current.addedAt
                refreshed.lastLocatedAt = current.lastLocatedAt
                changed.items[index] = refreshed
            }
            unavailableIDs.remove(id)
        } catch { message = FavoriteText.addFailed.text(language) }
    }

    nonisolated private static func metadata(_ url: URL) throws ->
        (identity: FileMoveItem, kind: FavoriteLocationKind, volumeUUID: String?) {
        guard OpenWithPolicy.isLocalFileURL(url), url.path != "/" else { throw FavoriteLocationError.invalidSelection }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey,
            .isPackageKey, .isRegularFileKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
            .volumeUUIDStringKey])
        guard values.isSymbolicLink != true,
              values.isDirectory == true || values.isRegularFile == true,
              values.isUbiquitousItem != true || values.ubiquitousItemDownloadingStatus == .current ||
                values.ubiquitousItemDownloadingStatus == .downloaded else {
            throw FavoriteLocationError.invalidSelection
        }
        let identity = try FileMoveItem.capture(url)
        return (identity, values.isDirectory == true && values.isPackage != true ? .folder : .file,
                values.volumeUUIDString)
    }

    nonisolated private static func validate(_ url: URL, for item: FavoriteLocation) throws {
        let captured: (identity: FileMoveItem, kind: FavoriteLocationKind, volumeUUID: String?)
        do { captured = try metadata(url) }
        catch { throw FavoriteLocationError.unavailable }
        guard item.matchesIdentity(captured.identity, kind: captured.kind, volumeUUID: captured.volumeUUID) else {
            throw FavoriteLocationError.replaced
        }
    }

    nonisolated private static func bookmark(for url: URL) throws -> Data {
        let bookmark = try url.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: [.volumeUUIDStringKey], relativeTo: nil)
        guard bookmark.count <= 131_072 else { throw FavoriteLocationError.invalidSelection }
        return bookmark
    }

    nonisolated private static func capture(_ url: URL, id: UUID = UUID(), name: String? = nil,
                                group: String = "", isPinned: Bool = false,
                                addedAt: Date? = Date(),
                                lastLocatedAt: Date? = nil) throws -> FavoriteLocation {
        let captured = try metadata(url)
        let identity = captured.identity
        let bookmark = try bookmark(for: url)
        return FavoriteLocation(id: id, url: url, bookmark: bookmark,
            device: identity.device, inode: identity.inode, createdAt: identity.createdAt,
            kind: captured.kind,
            name: name ?? url.lastPathComponent, group: group,
            isPinned: isPinned, addedAt: addedAt, lastLocatedAt: lastLocatedAt)
    }
}
