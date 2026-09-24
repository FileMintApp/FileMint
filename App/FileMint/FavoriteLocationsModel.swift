import AppKit
import FileMintCore

@MainActor
final class FavoriteLocationsModel: ObservableObject {
    static let shared = FavoriteLocationsModel()
    @Published private(set) var catalog = FavoriteLocationsCatalog()
    @Published private(set) var recoveryRequired = false
    @Published private(set) var unavailableIDs: Set<UUID> = []
    @Published private(set) var isChecking = false
    @Published private(set) var backupURL: URL?
    @Published var message: String?
    private let store: FavoriteLocationsStore

    init(store: FavoriteLocationsStore = FavoriteLocationsStore()) {
        self.store = store
        do { catalog = try store.load() }
        catch { recoveryRequired = true }
    }

    func backupAndReset(language: AppLanguage) {
        guard recoveryRequired else { return }
        do {
            let backup = try store.backupDamagedAndReset()
            catalog = FavoriteLocationsCatalog()
            unavailableIDs = []
            recoveryRequired = false
            backupURL = backup
            message = String(format: FavoriteText.recovered.text(language), backup.lastPathComponent)
            DistributedNotificationCenter.default().post(
                name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil)
        } catch { message = error.localizedDescription }
    }

    var quickItems: [FavoriteLocation] { catalog.quickItems() }

    private func save(_ changed: FavoriteLocationsCatalog) throws {
        guard !recoveryRequired else { throw FavoriteLocationError.damagedCatalog }
        guard let disk = try? store.load(), disk == catalog else {
            recoveryRequired = true
            throw FavoriteLocationError.damagedCatalog
        }
        do { try store.save(changed) }
        catch { throw FavoriteLocationError.saveFailed }
        catalog = changed
        message = nil
        DistributedNotificationCenter.default().post(
            name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification), object: nil)
    }

    @discardableResult
    func add(_ urls: [URL]) throws -> FavoriteAddResult {
        guard !recoveryRequired, (1...100).contains(urls.count) else { throw FavoriteLocationError.invalidSelection }
        var captured: [FavoriteLocation] = []
        for url in urls {
            let grant = url.startAccessingSecurityScopedResource()
            defer { if grant { url.stopAccessingSecurityScopedResource() } }
            captured.append(try Self.capture(url))
        }
        var changed = catalog
        let result = try changed.add(captured)
        if result.added > 0 { try save(changed) }
        return result
    }

    func chooseItems(language: AppLanguage) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = false
        panel.title = FavoriteText.choose.text(language)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        do {
            let result = try add(panel.urls)
            message = String(format: FavoriteText.added.text(language), result.added, result.duplicates)
        } catch { message = FavoriteText.addFailed.text(language) }
    }

    func remove(_ ids: Set<UUID>) throws {
        var changed = catalog
        changed.items.removeAll { ids.contains($0.id) }
        try save(changed)
        unavailableIDs.subtract(ids)
    }

    func setPinned(_ ids: Set<UUID>, to value: Bool) throws {
        var changed = catalog
        for index in changed.items.indices where ids.contains(changed.items[index].id) {
            changed.items[index].isPinned = value
        }
        try save(changed)
    }

    func movePinned(_ id: UUID, by offset: Int) throws {
        var changed = catalog
        changed.movePinned(id, by: offset)
        if changed != catalog { try save(changed) }
    }

    func movePinned(_ id: UUID, to targetID: UUID) throws {
        var changed = catalog
        changed.movePinned(id, to: targetID)
        if changed != catalog { try save(changed) }
    }

    func setGroup(_ ids: Set<UUID>, to group: String) throws {
        let group = String(group.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        var changed = catalog
        for index in changed.items.indices where ids.contains(changed.items[index].id) {
            changed.items[index].group = group
        }
        try save(changed)
    }

    func rename(_ id: UUID, to name: String) throws {
        let name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !name.isEmpty else { throw FavoriteLocationError.invalidSelection }
        var changed = catalog
        guard let index = changed.items.firstIndex(where: { $0.id == id }) else { throw FavoriteLocationError.unavailable }
        changed.items[index].name = name
        try save(changed)
    }

    func clearRecent() throws {
        var changed = catalog
        for index in changed.items.indices {
            changed.items[index].addedAt = nil
            changed.items[index].lastLocatedAt = nil
        }
        try save(changed)
    }

    func checkAvailability(_ id: UUID) async {
        guard let item = catalog.items.first(where: { $0.id == id }) else { return }
        let available = await Task.detached(priority: .utility) { Self.isAvailable(item) }.value
        guard catalog.items.contains(where: { $0.id == id }) else { return }
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
            unavailableIDs = unavailable
            isChecking = false
        }
    }

    nonisolated private static func isAvailable(_ item: FavoriteLocation) -> Bool {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: item.bookmark,
            options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) else { return false }
        let grant = url.startAccessingSecurityScopedResource()
        defer { if grant { url.stopAccessingSecurityScopedResource() } }
        guard let captured = try? FileMoveItem.capture(url) else { return false }
        return captured.device == item.device && captured.inode == item.inode &&
            (item.createdAt == nil || captured.createdAt == item.createdAt)
    }

    func locate(_ id: UUID) throws { try activate(id, openFile: false) }

    func openFile(_ id: UUID) throws { try activate(id, openFile: true) }

    private func activate(_ id: UUID, openFile: Bool) throws {
        guard let item = catalog.items.first(where: { $0.id == id }) else { throw FavoriteLocationError.unavailable }
        guard !openFile || item.kind == .file else { throw FavoriteLocationError.invalidSelection }
        var stale = false
        guard let resolved = try? URL(resolvingBookmarkData: item.bookmark,
            options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            unavailableIDs.insert(id)
            throw FavoriteLocationError.unavailable
        }
        let grant = resolved.startAccessingSecurityScopedResource()
        defer { if grant { resolved.stopAccessingSecurityScopedResource() } }
        let captured: FavoriteLocation
        do { captured = try Self.capture(resolved, id: id, name: item.name, group: item.group,
            isPinned: item.isPinned, addedAt: item.addedAt, lastLocatedAt: item.lastLocatedAt) }
        catch { unavailableIDs.insert(id); throw FavoriteLocationError.unavailable }
        guard captured.device == item.device, captured.inode == item.inode,
              (item.createdAt == nil || captured.createdAt == item.createdAt),
              captured.kind == item.kind else {
            unavailableIDs.insert(id)
            throw FavoriteLocationError.replaced
        }
        if openFile || item.kind == .folder {
            guard NSWorkspace.shared.open(resolved) else { throw FavoriteLocationError.unavailable }
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([resolved])
        }
        unavailableIDs.remove(id)
        var changed = catalog
        guard let index = changed.items.firstIndex(where: { $0.id == id }) else { return }
        changed.items[index].url = resolved.standardizedFileURL
        if stale { changed.items[index].bookmark = captured.bookmark }
        changed.items[index].lastLocatedAt = Date()
        try save(changed)
    }

    func relink(_ id: UUID, language: AppLanguage) {
        guard let item = catalog.items.first(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = item.kind == .file
        panel.canChooseDirectories = item.kind == .folder
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.title = FavoriteText.relink.text(language)
        panel.directoryURL = item.url.deletingLastPathComponent()
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let grant = url.startAccessingSecurityScopedResource()
            defer { if grant { url.stopAccessingSecurityScopedResource() } }
            let replacement = try Self.capture(url, id: id, name: item.name, group: item.group,
                isPinned: item.isPinned, addedAt: item.addedAt, lastLocatedAt: item.lastLocatedAt)
            guard replacement.kind == item.kind else { throw FavoriteLocationError.invalidSelection }
            guard !catalog.items.contains(where: { $0.id != id &&
                ($0.url.standardizedFileURL == replacement.url.standardizedFileURL ||
                 ($0.device == replacement.device && $0.inode == replacement.inode)) }) else {
                throw FavoriteLocationError.invalidSelection
            }
            var changed = catalog
            guard let index = changed.items.firstIndex(where: { $0.id == id }) else { return }
            changed.items[index] = replacement
            try save(changed)
            unavailableIDs.remove(id)
        } catch { message = FavoriteText.addFailed.text(language) }
    }

    private static func capture(_ url: URL, id: UUID = UUID(), name: String? = nil,
                                group: String = "", isPinned: Bool = false,
                                addedAt: Date? = Date(),
                                lastLocatedAt: Date? = nil) throws -> FavoriteLocation {
        guard OpenWithPolicy.isLocalFileURL(url), url.path != "/" else { throw FavoriteLocationError.invalidSelection }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey,
            .isPackageKey, .isRegularFileKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        guard values.isSymbolicLink != true,
              values.isDirectory == true || values.isRegularFile == true,
              values.isUbiquitousItem != true || values.ubiquitousItemDownloadingStatus == .current ||
                values.ubiquitousItemDownloadingStatus == .downloaded else {
            throw FavoriteLocationError.invalidSelection
        }
        let identity = try FileMoveItem.capture(url)
        let bookmark = try url.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
        guard bookmark.count <= 131_072 else { throw FavoriteLocationError.invalidSelection }
        return FavoriteLocation(id: id, url: url, bookmark: bookmark,
            device: identity.device, inode: identity.inode, createdAt: identity.createdAt,
            kind: values.isDirectory == true && values.isPackage != true ? .folder : .file,
            name: name ?? url.lastPathComponent, group: group,
            isPinned: isPinned, addedAt: addedAt, lastLocatedAt: lastLocatedAt)
    }
}
