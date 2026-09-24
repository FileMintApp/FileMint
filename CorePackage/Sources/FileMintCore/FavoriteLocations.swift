import Foundation
import Darwin

public struct FavoriteLocationsPreferences: Codable, Equatable, Sendable {
    public var showAddInFinder = true
    public var showListInFinder = true
    public init() {}
    private enum CodingKeys: CodingKey { case showAddInFinder, showListInFinder }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        showAddInFinder = (try? values.decode(Bool.self, forKey: .showAddInFinder)) ?? true
        showListInFinder = (try? values.decode(Bool.self, forKey: .showListInFinder)) ?? true
    }
}

public enum FavoriteLocationKind: String, Codable, Sendable { case file, folder }

public struct FavoriteLocation: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var url: URL
    public var bookmark: Data
    public var device: UInt64
    public var inode: UInt64
    public var createdAt: Date?
    public var kind: FavoriteLocationKind
    public var name: String
    public var group: String
    public var isPinned: Bool
    public var addedAt: Date?
    public var lastLocatedAt: Date?

    public init(id: UUID = UUID(), url: URL, bookmark: Data, device: UInt64, inode: UInt64,
                createdAt: Date? = nil,
                kind: FavoriteLocationKind, name: String, group: String = "", isPinned: Bool = false,
                addedAt: Date? = Date(), lastLocatedAt: Date? = nil) {
        self.id = id
        self.url = url.standardizedFileURL
        self.bookmark = bookmark
        self.device = device
        self.inode = inode
        self.createdAt = createdAt
        self.kind = kind
        self.name = name
        self.group = group
        self.isPinned = isPinned
        self.addedAt = addedAt
        self.lastLocatedAt = lastLocatedAt
    }
}

public struct FavoriteAddResult: Equatable, Sendable {
    public let added: Int
    public let duplicates: Int
}

public struct FavoriteLocationsCatalog: Codable, Equatable, Sendable {
    public var items: [FavoriteLocation]
    public init(items: [FavoriteLocation] = []) { self.items = items }

    public mutating func add(_ newItems: [FavoriteLocation]) throws -> FavoriteAddResult {
        guard !newItems.isEmpty, newItems.count <= 100,
              newItems.allSatisfy({ OpenWithPolicy.isLocalFileURL($0.url) && $0.url.path != "/" && !$0.name.isEmpty &&
                  (1...131_072).contains($0.bookmark.count) }) else { throw FavoriteLocationError.invalidSelection }
        var knownPaths = Set(items.map { $0.url.standardizedFileURL.path })
        var knownIdentities = Set(items.map { "\($0.device):\($0.inode)" })
        var added = 0, duplicates = 0
        for item in newItems {
            let path = item.url.standardizedFileURL.path
            let identity = "\(item.device):\(item.inode)"
            if knownPaths.contains(path) || knownIdentities.contains(identity) { duplicates += 1; continue }
            items.append(item)
            knownPaths.insert(path)
            knownIdentities.insert(identity)
            added += 1
        }
        return FavoriteAddResult(added: added, duplicates: duplicates)
    }

    public func quickItems(pinnedLimit: Int = 6, recentLimit: Int = 4) -> [FavoriteLocation] {
        let pinned = Array(items.filter(\.isPinned).prefix(max(0, pinnedLimit)))
        let pinnedIDs = Set(pinned.map(\.id))
        let recent = items.filter { !pinnedIDs.contains($0.id) }
            .sorted { max($0.lastLocatedAt ?? .distantPast, $0.addedAt ?? .distantPast) >
                max($1.lastLocatedAt ?? .distantPast, $1.addedAt ?? .distantPast) }
        return pinned + Array(recent.prefix(max(0, recentLimit)))
    }

    public mutating func movePinned(_ id: UUID, by offset: Int) {
        let positions = items.indices.filter { items[$0].isPinned }
        guard let current = positions.firstIndex(where: { items[$0].id == id }),
              positions.indices.contains(current + offset) else { return }
        items.swapAt(positions[current], positions[current + offset])
    }

    public mutating func movePinned(_ id: UUID, to targetID: UUID) {
        let positions = items.indices.filter { items[$0].isPinned }
        guard let source = positions.firstIndex(where: { items[$0].id == id }),
              let target = positions.firstIndex(where: { items[$0].id == targetID }),
              source != target else { return }
        let sourcePosition = positions[source]
        let value = items.remove(at: sourcePosition)
        let targetPosition = items.firstIndex(where: { $0.id == targetID }) ?? items.endIndex
        items.insert(value, at: source < target ? targetPosition + 1 : targetPosition)
    }

    public func search(_ query: String) -> [FavoriteLocation] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.enumerated().compactMap { index, item -> (Int, Int, FavoriteLocation)? in
            let name = item.name.localizedLowercase
            let term = query.localizedLowercase
            let score: Int
            if name == term { score = 0 }
            else if name.hasPrefix(term) { score = 1 }
            else if name.contains(term) { score = 2 }
            else if item.group.localizedLowercase.contains(term) { score = 3 }
            else if item.url.path.localizedLowercase.contains(term) { score = 4 }
            else { return nil }
            return (score, index, item)
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }.map { $0.2 }
    }
}

public enum FavoriteLocationError: Error, LocalizedError, Equatable, Sendable {
    case invalidSelection, unavailable, replaced, damagedCatalog, tooLarge, saveFailed
    public var errorDescription: String? {
        switch self {
        case .invalidSelection: "Choose available local files or folders without links or duplicates."
        case .unavailable: "This saved item is unavailable. Relink it in Favorite Locations."
        case .replaced: "This path now contains a different item. Relink it before opening."
        case .damagedCatalog: "Saved favorite locations could not be read. The catalog was preserved."
        case .tooLarge: "The favorite locations catalog is too large."
        case .saveFailed: "Favorite locations could not be saved."
        }
    }
}

public enum FavoriteLocationsPolicy {
    public static func canAdd(_ selection: [URL], isItemMenu: Bool,
                              preferences: FileMintPreferences) -> Bool {
        isItemMenu && preferences.favoriteLocations.showAddInFinder &&
            (1...100).contains(selection.count) &&
            Set(selection.map(\.standardizedFileURL)).count == selection.count &&
            selection.allSatisfy { OpenWithPolicy.isLocalFileURL($0) && $0.path != "/" &&
                FolderScope.contains($0, in: preferences.monitoredFolderURLs) }
    }
}

public struct FavoriteLocationsStore: Sendable {
    public static let maximumBytes = 16 * 1024 * 1024
    public let file: URL
    public init(file: URL = FileMintStorage.directory.appendingPathComponent("favorite-locations.json")) {
        self.file = file
    }

    public func load() throws -> FavoriteLocationsCatalog {
        var status = stat()
        let readStatus = file.withUnsafeFileSystemRepresentation { path in
            path.map { lstat($0, &status) } ?? -1
        }
        if readStatus != 0 {
            if errno == ENOENT { return FavoriteLocationsCatalog() }
            throw FavoriteLocationError.damagedCatalog
        }
        guard status.st_mode & S_IFMT == S_IFREG, status.st_size >= 0,
              status.st_size <= Int64(Self.maximumBytes) else { throw FavoriteLocationError.damagedCatalog }
        let descriptor = file.withUnsafeFileSystemRepresentation { path in
            path.map { open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) } ?? -1
        }
        guard descriptor >= 0 else { throw FavoriteLocationError.damagedCatalog }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var opened = stat()
        guard fstat(descriptor, &opened) == 0, opened.st_mode & S_IFMT == S_IFREG,
              opened.st_dev == status.st_dev, opened.st_ino == status.st_ino,
              opened.st_size <= Int64(Self.maximumBytes) else { throw FavoriteLocationError.damagedCatalog }
        var data = Data()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            guard data.count <= Self.maximumBytes - chunk.count else { throw FavoriteLocationError.damagedCatalog }
            data.append(chunk)
        }
        guard Int64(data.count) == opened.st_size,
              let catalog = try? JSONDecoder().decode(FavoriteLocationsCatalog.self, from: data),
              Self.isValid(catalog) else { throw FavoriteLocationError.damagedCatalog }
        return catalog
    }

    public func save(_ catalog: FavoriteLocationsCatalog) throws {
        guard Self.isValid(catalog) else { throw FavoriteLocationError.tooLarge }
        let data = try JSONEncoder().encode(catalog)
        guard data.count <= Self.maximumBytes else { throw FavoriteLocationError.tooLarge }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    /// User-triggered recovery retains the original bytes under a new name.
    /// Nothing is reset if the backup cannot be made.
    @discardableResult
    public func backupDamagedAndReset() throws -> URL {
        let backup = file.deletingLastPathComponent()
            .appendingPathComponent("favorite-locations-recovery-\(UUID().uuidString).json")
        do { try FileManager.default.moveItem(at: file, to: backup) }
        catch { throw FavoriteLocationError.damagedCatalog }
        do { try save(FavoriteLocationsCatalog()) }
        catch {
            try? FileManager.default.moveItem(at: backup, to: file)
            throw FavoriteLocationError.saveFailed
        }
        return backup
    }

    private static func isValid(_ catalog: FavoriteLocationsCatalog) -> Bool {
        catalog.items.count <= 10_000 &&
            Set(catalog.items.map(\.id)).count == catalog.items.count &&
            catalog.items.allSatisfy { OpenWithPolicy.isLocalFileURL($0.url) && $0.url.path != "/" &&
                !$0.name.isEmpty && (1...131_072).contains($0.bookmark.count) }
    }
}
