import AppKit
import Combine
import FileMintCore
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct FileDrawerPathComponent: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var title: String { url.path == "/" ? "/" : url.lastPathComponent }
    var isAuthorized: Bool { chainIndex != nil }
    fileprivate let chainIndex: Int?
    fileprivate let generation: UUID
}

struct FileDrawerPathMenu: Identifiable {
    let id: UUID
    let component: FileDrawerPathComponent
    var entries: [FileDrawerEntry] = []
    var isLoading = false
    var error: String?
}

/// The chosen root owns the grant. Navigation, workers and drafts retain it
/// independently, so a panel closing cannot revoke access underneath a worker.
final class FileDrawerGrant: Sendable {
    enum Source: Sendable { case picked, remembered, favorite(UUID) }
    let url: URL
    let started: URL?
    let bookmark: Data?
    let source: Source
    init(url: URL, started: URL?, bookmark: Data?, source: Source = .picked) {
        self.url = url
        self.started = started
        self.bookmark = bookmark
        self.source = source
    }
    deinit { started?.stopAccessingSecurityScopedResource() }

    static func selected(_ url: URL) -> FileDrawerGrant {
        let started = url.startAccessingSecurityScopedResource()
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        return .init(url: url, started: started ? url : nil, bookmark: bookmark)
    }

    static func restored(to target: URL, preferences: FileMintPreferences, access: RememberedFileAccess) -> FileDrawerGrant? {
        guard preferences.fileDrawer.enabled else { return nil }
        return restoreSavedAccess(to: target, preferences: preferences, access: access)
    }

    static func restoreSavedAccess(to target: URL, preferences: FileMintPreferences, access: RememberedFileAccess) -> FileDrawerGrant? {
        var scope = access.start(for: target, folder: true, mode: .write, roots: nil).first
        if scope == nil {
            let legacy = FolderAccess.startSavedAccess(to: target, in: preferences, requiresFinderScope: false)
            scope = legacy.first
            for extra in legacy.dropFirst() { extra.stopAccessingSecurityScopedResource() }
        }
        return scope.map { .init(url: target, started: $0, bookmark: nil, source: .remembered) }
    }

    static func favorite(_ favorite: FavoriteLocation?, at url: URL) -> FileDrawerGrant? {
        guard let favorite, let resolved = try? FavoriteLocationsModel.resolveDraftDirectory(favorite) else { return nil }
        guard resolved.url.path == url.path else {
            resolved.startedScopeURL?.stopAccessingSecurityScopedResource()
            return nil
        }
        return .init(url: resolved.url, started: resolved.startedScopeURL, bookmark: nil, source: .favorite(favorite.id))
    }
}

private enum FileDrawerNavigationError: Error {
    case needsFolderGrant(URL)
}

struct FileDrawerLocation: Sendable {
    let grant: FileDrawerGrant
    let chain: [FileDrawerDirectory]
    var folder: FileDrawerDirectory { chain[chain.count - 1] }

    init(grant: FileDrawerGrant) throws {
        self.grant = grant
        chain = [try FileDrawerDirectory(root: grant.url)]
    }

    init(grant: FileDrawerGrant, chain: [FileDrawerDirectory]) {
        precondition(!chain.isEmpty)
        self.grant = grant
        self.chain = chain
    }

    func child(_ item: FileDrawerEntry) throws -> Self {
        try .init(grant: grant, chain: chain + [folder.child(item)])
    }
}

@MainActor
final class FileDrawerModel: ObservableObject {
    let settings: PreferencesModel
    let favorites: FavoriteLocationsModel
    private let placeHome: URL
    weak var window: NSWindow?
    private var draftCloseObserver: AnyCancellable?
    weak var draftWindow: NSWindow? {
        didSet {
            // A draft opened elsewhere has its own completion handler. Observe
            // its native close as well when New File brings it to the front.
            draftCloseObserver = draftWindow.map { window in
                NotificationCenter.default.publisher(for: NSWindow.willCloseNotification, object: window)
                    .first().sink { [weak self] _ in self?.draftWindow = nil }
            }
            if draftWindow == nil { finishPendingRootChange() }
        }
    }
    var dragging = false { didSet { if !dragging { finishPendingRootChange() } } }
    var entries: [FileDrawerEntry] { searchIndex?.all.entries ?? [] }
    @Published var selection: Set<URL> = [] {
        didSet {
            if selection != oldValue {
                closeActionPalette()
                if let renamingEntry, selection != [renamingEntry.url] { cancelRename() }
                schedulePreview()
            }
        }
    }
    @Published var query = "" { didSet { if oldValue != query { cancelRename(); updateSearch() } } }
    @Published var renamingEntry: FileDrawerEntry?
    @Published private(set) var actionPalette: FileDrawerActionSession?
    private var actionValidation: Task<Void, Error>?
    @Published private(set) var applicationList: FileDrawerApplicationList?
    private var applicationDiscovery: Task<Void, Never>?
    private var applicationTask: Task<Void, Never>?
    private weak var applicationPanel: NSOpenPanel?
    var renameDraft = ""
    private struct SortOrder: Equatable {
        let field: FileDrawerSort
        let ascending: Bool
        init(_ options: FileDrawerPreferences) {
            field = options.sort
            ascending = options.sortAscending
        }
    }
    @Published private var order: SortOrder
    private var orderObserver: AnyCancellable?
    private var locationMemoryObserver: AnyCancellable?
    var sort: FileDrawerSort {
        get { order.field }
        set {
            guard order.field != newValue else { return }
            saveSort(newValue, ascending: newValue.defaultAscending)
        }
    }
    var sortAscending: Bool {
        get { order.ascending }
        set { if order.ascending != newValue { saveSort(order.field, ascending: newValue) } }
    }
    @Published private(set) var isSearching = false
    @Published private(set) var resultsVersion = 0
    var viewMode: FileDrawerViewMode { settings.committedPreferences.fileDrawer.viewMode }
    func setViewMode(_ mode: FileDrawerViewMode) {
        var preferences = settings.committedPreferences.fileDrawer
        preferences.viewMode = mode
        settings.setFileDrawer(preferences)
    }
    @Published var pinned = false
    @Published var placesVisible = true
    func togglePlaces() { placesVisible.toggle() }
    @Published var busy = false { didSet { if !busy { finishPendingRootChange() } } }
    @Published var message: String?
    @Published private(set) var defaultLocationNeedingAccess: URL?
    @Published private(set) var previewURL: URL?
    @Published private(set) var location: FileDrawerLocation? {
        didSet {
            let components = directory?.pathComponents ?? []
            activePlace = FileDrawerPlace.allCases.filter { components.starts(with: placeURL($0).pathComponents) }
                .max { placeURL($0).pathComponents.count < placeURL($1).pathComponents.count }
        }
    }
    @Published private(set) var pathMenu: FileDrawerPathMenu?
    @Published private(set) var pathSelectionVersion = 0
    @Published var clipboardAvailable = false
    @Published var canRestore = false
    var directory: URL? { location?.folder.url }
    var rootURL: URL? { location?.grant.url }
    var pathComponents: [FileDrawerPathComponent] {
        guard let location else { return [] }
        let indices = Dictionary(uniqueKeysWithValues: location.chain.enumerated().map { ($1.url.path, $0) })
        var prefix = URL(fileURLWithPath: "/", isDirectory: true)
        return location.folder.url.pathComponents.map { name in
            if name != "/" { prefix.appendPathComponent(name, isDirectory: true) }
            return FileDrawerPathComponent(url: prefix, chainIndex: indices[prefix.path], generation: navigation)
        }
    }
    var canBack: Bool { historyIndex > 0 }
    var canForward: Bool { historyIndex + 1 < history.count }
    var canUp: Bool { directory.map { $0.path != "/" } ?? false }
    func placeURL(_ place: FileDrawerPlace) -> URL { place.directory(in: placeHome) }
    private(set) var activePlace: FileDrawerPlace?
    func isInPlace(_ place: FileDrawerPlace) -> Bool { activePlace == place }
    var selectedEntries: [FileDrawerEntry] {
        guard !isSearching else { return [] }
        return selection.compactMap { results.index(of: $0) }.sorted().map { results.entries[$0] }
    }
    var visibleEntries: [FileDrawerEntry] { results.entries }
    func visibleIndex(for url: URL) -> Int? { results.index(of: url) }

    struct Transfer: Sendable {
        let source: FileDrawerLocation
        let items: [FileDrawerEntry]
        let move: Bool
    }
    var transfer: Transfer?
    var trashReceipts: [(items: [FileDrawerTrashReceipt], grant: FileDrawerGrant)] = []
    private var history: [FileDrawerLocation] = []
    private var historyIndex = -1
    private var navigation = UUID()
    private var previewTask: Task<Void, Never>?
    private var pendingThumbnail: (id: UUID, request: QLThumbnailGenerator.Request)?
    private struct SavedDirectory: Codable, Sendable {
        let name: String
        let identity: BatchRenameIdentity
    }
    private struct SavedLocation: Codable, Sendable {
        let root: URL
        let chain: [SavedDirectory]
        let favoriteID: UUID?

        func restore(with grant: FileDrawerGrant) throws -> FileDrawerLocation {
            var result = try FileDrawerLocation(grant: grant)
            guard result.folder.url.path == root.path, chain.first?.identity == result.folder.identity else {
                throw FileMoveError.sourceChanged
            }
            for component in chain.dropFirst() {
                try Task.checkCancellation()
                let child = try result.folder.child(named: component.name, matching: component.identity)
                result = .init(grant: grant, chain: result.chain + [child])
            }
            return result
        }
    }
    private let lastLocationKey: String
    private var sessionBookmark: Data?
    private var listingTask: Task<(FileDrawerSearchIndex, FileDrawerLocation), Error>?
    private var searchIndex: FileDrawerSearchIndex?
    private var results = FileDrawerSearchResults.empty
    private var searchTask: Task<(FileDrawerSearchIndex, FileDrawerSearchResults), Error>?
    private var searchGeneration = UUID()
    private var selectFirstAfterSearch = false
    private var pathListingTask: Task<[FileDrawerEntry], Error>?
    var writing = false
    var interacting = false { didSet { if !interacting { finishPendingRootChange() } } }
    var presented = false
    private var rootObserver: AnyCancellable?
    private var rootChangePending = false

    init(settings: PreferencesModel, favorites: FavoriteLocationsModel,
         placeHome: URL = DefaultFolders.resolvedUserHomeDirectory(fileManager: .default),
         lastLocationKey: String = "fileDrawer.lastLocation") {
        self.settings = settings
        self.favorites = favorites
        self.placeHome = placeHome.standardizedFileURL
        self.lastLocationKey = lastLocationKey
        order = SortOrder(settings.committedPreferences.fileDrawer)
        rootObserver = settings.drawerAccessChanged.sink { [weak self] in
            guard let self, self.presented else { return }
            self.rootChangePending = true
            self.applyRootChangeIfIdle()
        }
        orderObserver = settings.$committedPreferences.map { SortOrder($0.fileDrawer) }
            .removeDuplicates().sink { [weak self] value in
                guard let self, self.order != value else { return }
                self.order = value
                self.updateSearch()
            }
        locationMemoryObserver = settings.$committedPreferences.map(\.fileDrawer.remembersLastLocation)
            .removeDuplicates().sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    if let location = self.location { self.saveLastLocation(location) }
                } else {
                    self.sessionBookmark = nil
                    UserDefaults.standard.removeObject(forKey: self.lastLocationKey)
                }
            }
    }

    private func saveSort(_ field: FileDrawerSort, ascending: Bool) {
        var options = settings.committedPreferences.fileDrawer
        options.sort = field
        options.sortAscending = ascending
        if !settings.setFileDrawer(options) { message = settings.lastError }
    }

    func text(_ english: String, _ chinese: String) -> String {
        settings.preferences.language.resolved() == .chinese ? chinese : english
    }

    func selectFirstSearchResult() {
        guard presented, !busy else { return }
        if isSearching {
            selectFirstAfterSearch = true
        } else if let first = results.entries.first {
            selection = [first.url]
            pathSelectionVersion &+= 1
        }
    }

    private func cancelSearch() {
        searchGeneration = UUID()
        searchTask?.cancel()
        searchTask = nil
        selectFirstAfterSearch = false
        isSearching = false
    }

    private func updateSearch() {
        closeActionPalette()
        cancelSearch()
        guard presented, listingTask == nil, let index = searchIndex else { return }
        if query.isEmpty && sort == index.sort && sortAscending == index.ascending {
            applyResults(index.all)
            return
        }
        isSearching = true
        let generation = searchGeneration, requestedQuery = query, requestedOrder = order
        let search = Task.detached(priority: .userInitiated) {
            let ordered = try index.ordered(by: requestedOrder.field, ascending: requestedOrder.ascending)
            return (ordered, try ordered.matching(requestedQuery))
        }
        searchTask = search
        Task {
            let result = await search.result
            guard presented, searchGeneration == generation else { return }
            searchTask = nil
            isSearching = false
            if case let .success((ordered, matches)) = result {
                searchIndex = ordered
                applyResults(matches)
                if selectFirstAfterSearch { selectFirstSearchResult() }
            }
            selectFirstAfterSearch = false
        }
    }

    private func applyResults(_ matches: FileDrawerSearchResults) {
        results = matches
        resultsVersion &+= 1
        if !selection.isEmpty {
            let remaining = selection.filter { matches.index(of: $0) != nil }
            if remaining != selection {
                selection = remaining
            } else if previewURL == nil {
                schedulePreview()
            }
        }
    }

    func chooseFolder() {
        pickFolder { [weak self] url in self?.openFolder(url) }
    }

    func pickFolder(startingAt directory: URL? = nil, _ selected: @escaping @MainActor (URL) -> Void) {
        guard !busy, !interacting, let window else { return }
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.resolvesAliases = false
        picker.allowsMultipleSelection = false
        if let directory { picker.directoryURL = directory }
        interacting = true
        picker.beginSheetModal(for: window) { [weak self] result in
            guard let self else { return }
            self.interacting = false
            if self.presented, result == .OK, let url = picker.url { selected(url) }
        }
    }

    func openFolder(_ url: URL) {
        load { try FileDrawerLocation(grant: .selected(url)) }
    }

    func openPlace(_ place: FileDrawerPlace) { openDirectoryDestination(placeURL(place)) }

    private func openDirectoryDestination(_ url: URL, returningFrom child: FileDrawerDirectory? = nil) {
        guard presented, !busy, !interacting else { return }
        let parts = url.pathComponents
        if let location, let base = location.chain.lastIndex(where: { parts.starts(with: $0.url.pathComponents) }) {
            let same = url.path == directory?.path
            let ancestor = location.chain[base]
            let components = parts.dropFirst(ancestor.url.pathComponents.count)
            load(index: same ? historyIndex : nil, resetFilter: true, returningFrom: child) {
                var chain = Array(location.chain.prefix(base + 1))
                var current = ancestor
                for component in components {
                    try Task.checkCancellation()
                    current = try current.child(named: component)
                    chain.append(current)
                }
                return FileDrawerLocation(grant: location.grant, chain: chain)
            }
        } else {
            let preferences = settings.committedPreferences, access = settings.rememberedFileAccess
            let favorite = favorites.catalog.items.first { $0.kind == .folder && $0.url.path == url.path }
            load(resetFilter: true, returningFrom: child) {
                guard let grant = FileDrawerGrant.restored(to: url, preferences: preferences, access: access)
                        ?? FileDrawerGrant.favorite(favorite, at: url) else {
                    throw FileDrawerNavigationError.needsFolderGrant(url)
                }
                return try FileDrawerLocation(grant: grant)
            }
        }
    }

    func authorizeDefaultLocation() {
        guard !busy, directory == nil, let url = defaultLocationNeedingAccess,
              url.path == settings.committedPreferences.fileDrawer.defaultDirectoryPath else { return }
        requestFolderGrant(url, generation: navigation, returningFrom: nil, isDefaultLocation: true)
    }

    private func requestFolderGrant(_ url: URL, generation: UUID, returningFrom child: FileDrawerDirectory?,
                                    isDefaultLocation: Bool = false) {
        guard presented, generation == navigation, !interacting, settings.committedPreferences.fileDrawer.enabled,
              let window else { return }
        let picker = FolderAccess.directoryWritePanel(for: url, language: settings.preferences.language)
        interacting = true
        picker.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            defer { self.interacting = false }
            guard self.presented, self.navigation == generation, response == .OK, let chosen = picker.url else { return }
            defer { chosen.stopAccessingSecurityScopedResource() }
            if isDefaultLocation && self.settings.committedPreferences.fileDrawer.defaultDirectoryPath != url.path { return }
            do {
                let access = self.settings.rememberedFileAccess
                try access.rememberWriteDirectory(chosen, expected: url)
                let preferences = self.settings.committedPreferences
                self.load(resetFilter: true, returningFrom: child) {
                    guard let grant = FileDrawerGrant.restored(to: url, preferences: preferences, access: access) else {
                        throw FileInfoError.accessDenied
                    }
                    return try FileDrawerLocation(grant: grant)
                }
            } catch FileInfoError.invalidSelection { self.message = self.settings.text(.moveChooseExactFolder) }
            catch { self.report(error) }
        }
    }

    func goFavorite(_ id: UUID) {
        guard let favorite = favorites.catalog.items.first(where: { $0.id == id && $0.kind == .folder }) else { return }
        load {
            let resolved = try FavoriteLocationsModel.resolveDraftDirectory(favorite)
            let grant = FileDrawerGrant(url: resolved.url, started: resolved.startedScopeURL, bookmark: nil, source: .favorite(favorite.id))
            return try FileDrawerLocation(grant: grant)
        }
    }

    func navigate(_ url: URL) {
        guard let location, let item = searchIndex?.all.entry(at: url), item.isDirectory else { return }
        load { try location.child(item) }
    }

    func navigateAncestor(_ url: URL) {
        guard let location, let index = location.chain.firstIndex(where: { $0.url == url }) else { return }
        let target = FileDrawerLocation(grant: location.grant, chain: Array(location.chain.prefix(index+1)))
        load { target }
    }

    private func pathLocation(_ component: FileDrawerPathComponent) -> FileDrawerLocation? {
        guard let location, component.generation == navigation, let index = component.chainIndex,
              location.chain.indices.contains(index), location.chain[index].url.path == component.url.path else { return nil }
        return .init(grant: location.grant, chain: Array(location.chain.prefix(index + 1)))
    }

    @discardableResult func showPathMenu(_ component: FileDrawerPathComponent) -> UUID? {
        guard presented, !busy, !interacting, component.generation == navigation,
              pathComponents.contains(component) else { return nil }
        dismissPathMenu()
        let token = UUID()
        let target = pathLocation(component)
        pathMenu = .init(id: token, component: component, isLoading: target != nil)
        // Above-root components are lexical labels until explicitly granted in a picker.
        guard let target else { return token }
        let listing = Task.detached(priority: .userInitiated) {
            defer { withExtendedLifetime(target.grant) {} }
            return try target.folder.list().sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
        pathListingTask = listing
        Task {
            let result = await listing.result
            guard var menu = pathMenu, menu.id == token, presented, navigation == component.generation else { return }
            pathListingTask = nil
            menu.isLoading = false
            switch result {
            case let .success(items): menu.entries = items
            case let .failure(error): menu.error = errorText(error)
            }
            pathMenu = menu
        }
        return token
    }

    func closePathMenu(_ id: UUID) {
        if pathMenu?.id == id { dismissPathMenu() }
    }

    private func dismissPathMenu() {
        pathListingTask?.cancel()
        pathListingTask = nil
        if pathMenu != nil { pathMenu = nil }
    }

    func goToPathComponent(_ menuID: UUID) {
        guard presented, !busy, !interacting, let menu = pathMenu, menu.id == menuID,
              menu.component.generation == navigation else { return }
        dismissPathMenu()
        goToPathComponent(menu.component)
    }

    func goToPathComponent(_ component: FileDrawerPathComponent) {
        guard presented, !busy, !interacting, component.generation == navigation, pathComponents.contains(component) else { return }
        if let target = pathLocation(component) {
            load(index: target.folder === location?.folder ? historyIndex : nil, resetFilter: true) { target }
        } else {
            openDirectoryDestination(component.url)
        }
    }

    func choosePathItem(_ item: FileDrawerEntry, in menuID: UUID) {
        guard presented, !busy, !interacting, let menu = pathMenu, menu.id == menuID,
              menu.entries.contains(item), let target = pathLocation(menu.component) else { return }
        dismissPathMenu()
        if item.isDirectory && !item.isPackage && !item.isLink {
            load(index: item.url.path == directory?.path ? historyIndex : nil) { try target.child(item) }
        } else {
            let index = target.folder === location?.folder ? historyIndex : nil
            load(index: index, selecting: item) { target }
        }
    }

    func copyDirectoryPath() {
        guard presented, let directory else { return }
        NSPasteboard.general.clearContents()
        if !NSPasteboard.general.setString(directory.path, forType: .string) {
            message = text("Could not copy the folder path.", "无法拷贝文件夹路径。")
        }
    }

    func back() { if canBack { jump(historyIndex - 1) } }
    func forward() { if canForward { jump(historyIndex + 1) } }
    private func jump(_ index: Int) {
        let target = history[index]
        load(index: index) { target }
    }
    func up() {
        guard canUp, let location else { return }
        openDirectoryDestination(location.folder.url.deletingLastPathComponent(), returningFrom: location.folder)
    }
    func refresh() { if location != nil { jump(historyIndex) } }

    func refreshAfterRename(_ original: FileDrawerEntry, to url: URL) {
        guard let location else { return }
        load(index: historyIndex, renamed: (original, url)) { location }
    }

    private func load(index: Int? = nil, selecting item: FileDrawerEntry? = nil, resetFilter: Bool = false,
                      returningFrom child: FileDrawerDirectory? = nil,
                      renamed: (entry: FileDrawerEntry, url: URL)? = nil,
                      onFailure: ((Error) -> Void)? = nil,
                      _ resolve: @escaping @Sendable () throws -> FileDrawerLocation) {
        guard presented, !writing else { return }
        closeActionPalette()
        cancelRename()
        dismissPathMenu()
        let token = UUID()
        navigation = token
        let preserved = renamed.map { [$0.url: $0.entry] }
            ?? (index == historyIndex && !resetFilter ? Dictionary(uniqueKeysWithValues: selectedEntries.map { ($0.url, $0) }) : [:])
        cancelSearch()
        closePreview()
        busy = true
        message = nil
        listingTask?.cancel()
        let requestedOrder = order
        let listing = Task.detached(priority: .userInitiated) {
            let destination = try resolve()
            try Task.checkCancellation()
            let rows = try destination.folder.list()
            if let item {
                guard rows.contains(where: { $0.isSameItem(as: item) }) else { throw FileMoveError.sourceChanged }
                try destination.folder.validate(item)
            }
            return (try FileDrawerSearchIndex(rows, sort: requestedOrder.field, ascending: requestedOrder.ascending), destination)
        }
        listingTask = listing
        Task {
            let result = await listing.result
            guard navigation == token, presented else { return }
            listingTask = nil
            busy = false
            do {
                let (children, target) = try result.get()
                if let index {
                    history[index] = target
                    historyIndex = index
                }
                else {
                    history.removeLast(history.count - historyIndex - 1)
                    history.append(target)
                    if history.count > 40 { history.removeFirst() }
                    historyIndex = history.count - 1
                }
                let clearQuery = resetFilter || item != nil || location?.folder.url != target.folder.url
                cancelSearch()
                results = .empty
                location = target
                defaultLocationNeedingAccess = nil
                if settings.committedPreferences.fileDrawer.remembersLastLocation { saveLastLocation(target) }
                searchIndex = children
                let departed = child.flatMap { folder in
                    children.all.entry(at: folder.url)?.isSameDirectory(as: folder) == true ? folder.url : nil
                }
                if let reveal = item?.url ?? departed {
                    selection = [reveal]
                    pathSelectionVersion &+= 1
                } else {
                    selection = Set(preserved.compactMap { url, row in
                        children.all.entry(at: url)?.isSameItem(as: row, at: url) == true ? url : nil
                    })
                }
                if clearQuery && !query.isEmpty { query = "" } else { updateSearch() }
            } catch FileDrawerNavigationError.needsFolderGrant(let url) {
                updateSearch()
                requestFolderGrant(url, generation: token, returningFrom: child)
            } catch {
                updateSearch()
                if let onFailure { onFailure(error) } else { report(error) }
            }
        }
    }

    func start() {
        presented = true
        let options = settings.committedPreferences.fileDrawer
        if favorites.isLoading,
           options.defaultDirectoryPath != nil || (options.remembersLastLocation && UserDefaults.standard.data(forKey: lastLocationKey) != nil) {
            let token = navigation
            busy = true
            Task {
                await favorites.waitUntilLoaded()
                guard presented, navigation == token else { return }
                busy = false
                openInitialLocation()
            }
        } else {
            openInitialLocation()
        }
    }

    private func openInitialLocation() {
        let preferences = settings.committedPreferences
        guard preferences.fileDrawer.remembersLastLocation,
              let data = UserDefaults.standard.data(forKey: lastLocationKey), data.count <= 64 * 1024,
              let saved = try? JSONDecoder().decode(SavedLocation.self, from: data) else {
            openDefaultLocation()
            return
        }
        let access = settings.rememberedFileAccess
        let favorite = saved.favoriteID.flatMap { id in favorites.catalog.items.first { $0.id == id } }
        let bookmark = sessionBookmark
        load(onFailure: { [weak self] _ in self?.openDefaultLocation() }) {
            if let grant = FileDrawerGrant.restored(to: saved.root, preferences: preferences, access: access)
                ?? FileDrawerGrant.favorite(favorite, at: saved.root) {
                return try saved.restore(with: grant)
            }
            guard let bookmark else { throw FileInfoError.accessDenied }
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            return try saved.restore(with: .selected(url))
        }
    }

    private func openDefaultLocation() {
        let preferences = settings.committedPreferences
        defaultLocationNeedingAccess = nil
        guard let path = preferences.fileDrawer.defaultDirectoryPath else { return }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let access = settings.rememberedFileAccess
        let favorite = favorites.catalog.items.first { $0.kind == .folder && $0.url.path == path }
        load(onFailure: { [weak self] error in
            guard let self, self.settings.committedPreferences.fileDrawer.defaultDirectoryPath == path else { return }
            if FolderAccess.isPermissionError(error) { self.defaultLocationNeedingAccess = url }
            else { self.report(error) }
        }) {
            guard let grant = FileDrawerGrant.restored(to: url, preferences: preferences, access: access)
                ?? FileDrawerGrant.favorite(favorite, at: url) else {
                throw FileInfoError.accessDenied
            }
            return try FileDrawerLocation(grant: grant)
        }
    }

    private func saveLastLocation(_ location: FileDrawerLocation) {
        let chain = location.chain.map { SavedDirectory(name: $0.url.lastPathComponent, identity: $0.identity) }
        let favoriteID: UUID? = if case let .favorite(id) = location.grant.source { id } else { nil }
        let saved = SavedLocation(root: location.chain[0].url, chain: chain, favoriteID: favoriteID)
        sessionBookmark = location.grant.bookmark
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(saved), data != UserDefaults.standard.data(forKey: lastLocationKey) {
            UserDefaults.standard.set(data, forKey: lastLocationKey)
        }
    }

    // Sheet/draft callbacks may immediately start a write. Let the callback finish
    // before retiring the old session, and retain the worker's grant until it ends.
    private func finishPendingRootChange() {
        guard rootChangePending else { return }
        Task { [weak self] in self?.applyRootChangeIfIdle() }
    }

    private func applyRootChangeIfIdle() {
        guard rootChangePending, presented, !busy, !writing, !interacting, !dragging, draftWindow == nil else { return }
        rootChangePending = false
        var validPaths: [URL: Bool] = [:]
        func valid(_ grant: FileDrawerGrant) -> Bool {
            switch grant.source {
            case .picked, .favorite: return true
            case .remembered:
                if let result = validPaths[grant.url] { return result }
                let result = settings.restoreDrawerAccess(to: grant.url) != nil
                validPaths[grant.url] = result
                return result
            }
        }
        if let transfer, !valid(transfer.source.grant) { self.transfer = nil; clipboardAvailable = false }
        trashReceipts.removeAll { !valid($0.grant) }
        canRestore = !trashReceipts.isEmpty
        if location.map({ !valid($0.grant) }) ?? true {
            clearDirectory()
            openDefaultLocation()
        } else {
            let retained = history.prefix(historyIndex + 1).filter { valid($0.grant) }.count
            history.removeAll { !valid($0.grant) }
            historyIndex = retained - 1
        }
    }

    func end() {
        presented = false
        rootChangePending = false
        draftWindow = nil
        clearDirectory()
        transfer = nil
        clipboardAvailable = false
        trashReceipts = []
        canRestore = false
        pinned = false
        if !writing { busy = false }
    }

    private func clearDirectory() {
        closeActionPalette()
        cancelRename()
        dismissPathMenu()
        navigation = UUID()
        closePreview()
        listingTask?.cancel()
        listingTask = nil
        location = nil
        defaultLocationNeedingAccess = nil
        history = []
        historyIndex = -1
        cancelSearch()
        searchIndex = nil
        results = .empty
        resultsVersion &+= 1
        selection = []
        query = ""
        message = nil
    }
    func close() { window?.performClose(nil) }

    func setAutoPreview(_ value: Bool) {
        var p = settings.committedPreferences.fileDrawer
        p.autoPreview = value
        settings.setFileDrawer(p)
    }
    func schedulePreview() { requestPreview(manual: false) }
    func preview() { requestPreview(manual: true) }
    func closePreview() {
        previewTask?.cancel()
        previewTask = nil
        if let pendingThumbnail { QLThumbnailGenerator.shared.cancel(pendingThumbnail.request) }
        pendingThumbnail = nil
        previewURL = nil
    }
    private func requestPreview(manual: Bool) {
        closePreview()
        guard presented, !busy, manual || settings.committedPreferences.fileDrawer.autoPreview,
              selection.count == 1, let item = selectedEntries.first, item.canPreview, let location else { return }
        previewTask = Task {
            do {
                if !manual { try await Task.sleep(for: .milliseconds(230)) }
                try Task.checkCancellation()
                let fresh = try await Task.detached(priority: .userInitiated) {
                    let entry = try location.folder.refreshed(item)
                    if entry.canPreview { try FolderAccess.checkAccess(to: entry.url, mode: R_OK) }
                    return entry
                }.value
                try Task.checkCancellation()
                guard fresh.canPreview, manual || fresh.size.map({ (0...50_000_000).contains($0) }) == true else { return }
                let type = UTType(filenameExtension: fresh.url.pathExtension)
                let standard = [UTType.text, .image, .pdf, .audiovisualContent].contains { type?.conforms(to: $0) == true }
                if manual || standard {
                    previewURL = fresh.url
                } else {
                    prepareProviderPreview(fresh, at: location)
                }
            } catch { /* Selection and availability can change during preview preparation. */ }
        }
    }

    private func prepareProviderPreview(_ entry: FileDrawerEntry, at location: FileDrawerLocation) {
        let request = QLThumbnailGenerator.Request(fileAt: entry.url, size: CGSize(width: 64, height: 64),
                                                   scale: 1, representationTypes: .thumbnail)
        let id = UUID()
        pendingThumbnail = (id, request)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { @Sendable [weak self] thumbnail, error in
            let available = error == nil && thumbnail?.type == .thumbnail
            Task { @MainActor in
                guard let self, self.pendingThumbnail?.id == id else { return }
                guard available else { self.pendingThumbnail = nil; return }
                let current = try? await Task.detached { try location.folder.refreshed(entry) }.value
                guard self.pendingThumbnail?.id == id else { return }
                self.pendingThumbnail = nil
                guard let current, current.canPreview, current.size.map({ (0...50_000_000).contains($0) }) == true else { return }
                self.previewURL = current.url
            }
        }
    }
    func errorText(_ error: Error) -> String {
        if let error = error as? FileDrawerTransferError, case .crossVolumeMove = error {
            return text("Choose Copy to Folder to transfer items to another volume.", "跨卷传输请使用「拷贝到文件夹」。")
        }
        if let error = error as? FileInfoError { return error.text.text(settings.preferences.language) }
        if let error = error as? FileMoveError {
            let key: FileMintTextKey = switch error {
            case .sourceChanged: .moveSourceChanged
            case .destinationExists: .moveDestinationExists
            case .invalidDestination: .moveInvalidDestination
            default: .moveInvalidSelection
            }
            return settings.text(key)
        }
        return error.localizedDescription
    }
    func report(_ error: Error) {
        message = errorText(error)
    }
}

struct FileDrawerActionSession: Identifiable, Sendable {
    let id = UUID()
    let location: FileDrawerLocation
    let items: [FileDrawerEntry]
}

extension FileDrawerModel {
    func toggleActionPalette() {
        if actionPalette != nil { closeActionPalette(); return }
        guard presented, !busy, !interacting, !dragging, !isSearching, pathMenu == nil,
              draftWindow?.isVisible != true, window?.attachedSheet == nil, let location else { return }
        let items = selectedEntries
        guard !items.isEmpty, items.count == selection.count else { return }
        actionPalette = FileDrawerActionSession(location: location, items: items)
    }

    func closeActionPalette() {
        actionValidation?.cancel()
        actionValidation = nil
        backFromApplications()
        if actionPalette != nil { actionPalette = nil }
    }

    func performPaletteAction(_ action: FileDrawerAction, session id: UUID) {
        guard let session = actionPalette, session.id == id, actionValidation == nil, applicationList == nil,
              action.enabled(self), location?.folder === session.location.folder else { return }
        let validation = Task.detached(priority: .userInitiated) {
            for entry in session.items {
                try Task.checkCancellation()
                try session.location.folder.validate(entry)
            }
        }
        actionValidation = validation
        Task {
            let result = await validation.result
            guard actionPalette?.id == id else { return }
            actionValidation = nil
            guard presented, location?.folder === session.location.folder, action.enabled(self),
                  session.items.elementsEqual(selectedEntries, by: { $0.isSameItem(as: $1) }) else { return }
            switch result {
            case .success where action == .openWith:
                showApplications(for: session)
            case .success:
                closeActionPalette()
                action.run(self)
            case .failure(let error):
                closeActionPalette()
                refresh()
                report(error)
            }
        }
    }

    func requestOpenWith() {
        if actionPalette == nil { toggleActionPalette() }
        if let session = actionPalette { performPaletteAction(.openWith, session: session.id) }
    }

    private func showApplications(for session: FileDrawerActionSession) {
        let page = FileDrawerApplicationList()
        applicationList = page
        let configured = settings.committedPreferences.openWith.applications
        applicationDiscovery = Task {
            do {
                let apps = try await FileDrawerOpenWith.candidates(for: session.items, configured: configured)
                guard applicationList?.id == page.id else { return }
                applicationList?.candidates = apps
            } catch {
                guard applicationList?.id == page.id else { return }
                applicationList?.candidates = []
                applicationList?.error = errorText(error)
            }
        }
    }

    func backFromApplications() {
        applicationDiscovery?.cancel()
        applicationDiscovery = nil
        applicationTask?.cancel()
        applicationTask = nil
        if applicationList != nil { applicationList = nil }
        applicationPanel?.cancel(nil)
    }

    func chooseOtherApplication(page id: UUID) {
        guard applicationList?.id == id, applicationList?.opening == false, !interacting,
              let window, window.attachedSheet == nil else { return }
        let panel = NSOpenPanel()
        panel.title = text("Choose an Application", "选择应用")
        panel.prompt = text("Open", "打开")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        applicationPanel = panel
        interacting = true
        panel.beginSheetModal(for: window) { [weak self] response in
            let chosen = response == .OK ? panel.url : nil
            defer { chosen?.stopAccessingSecurityScopedResource() }
            guard let self, self.applicationPanel === panel else { return }
            self.applicationPanel = nil
            self.interacting = false
            guard self.applicationList?.id == id, let chosen else { return }
            self.openWithApplication(page: id, pickedURL: chosen) { try await FileDrawerOpenWith.picked(chosen) }
        }
    }

    func openWithApplication(_ app: FileDrawerOpenWith.Candidate, page id: UUID) {
        guard applicationList?.candidates?.contains(where: { $0.id == app.id }) == true else { return }
        openWithApplication(page: id) { app }
    }

    private func openWithApplication(page id: UUID, pickedURL: URL? = nil,
                                     resolve: @escaping @MainActor () async throws -> FileDrawerOpenWith.Candidate) {
        guard let session = actionPalette, applicationList?.id == id, applicationList?.opening == false else { return }
        guard settings.pendingCreationCount == 0, !CustomFileSavePanelController.shared.hasActiveWrite,
              !UpdateModel.shared.isCommittingInstallation, let release = FileOperationCoordinator.shared.reserveExternalPresentation() else {
            applicationList?.error = text("Another file operation is in progress.", "另一项文件操作正在进行中。")
            return
        }
        let appScope = pickedURL.flatMap { $0.startAccessingSecurityScopedResource() ? $0 : nil }
        applicationList?.opening = true
        applicationList?.error = nil
        applicationTask = Task {
            defer {
                appScope?.stopAccessingSecurityScopedResource()
                release()
                withExtendedLifetime(session.location.grant) {}
            }
            do {
                let app = try await resolve()
                try Task.checkCancellation()
                try await FileDrawerOpenWith.open(app, directory: session.location.folder, items: session.items,
                    currentApps: { self.settings.committedPreferences.openWith.applications },
                    isCurrent: { self.presented && self.actionPalette?.id == session.id && self.applicationList?.id == id })
                if applicationList?.id == id { closeActionPalette() }
            } catch {
                guard applicationList?.id == id else { return }
                applicationList?.opening = false
                if error as? FileMoveError == .sourceChanged {
                    closeActionPalette()
                    refresh()
                    report(error)
                } else if !(error is CancellationError) {
                    applicationList?.error = (error as? OpenWithError).map { settings.text($0.messageKey) } ?? errorText(error)
                }
            }
        }
    }
}

struct FileDrawerApplicationList: Identifiable {
    let id = UUID()
    var candidates: [FileDrawerOpenWith.Candidate]?
    var opening = false
    var error: String?
}
