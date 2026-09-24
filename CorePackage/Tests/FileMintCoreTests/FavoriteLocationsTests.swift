import Foundation
import Testing
import FileMintCore

@Suite("Favorite locations")
struct FavoriteLocationsTests {
    private let root = URL(fileURLWithPath: "/Users/example/Work", isDirectory: true)

    private func item(_ number: Int, pinned: Bool = false, used: Date? = nil,
                      name: String? = nil) -> FavoriteLocation {
        FavoriteLocation(url: root.appendingPathComponent("item-\(number).txt"),
            bookmark: Data([1, 2, 3]), device: 1, inode: UInt64(number + 1),
            kind: .file, name: name ?? "项目 \(number)", group: number.isMultiple(of: 2) ? "工作" : "个人",
            isPinned: pinned, lastLocatedAt: used)
    }

    @Test("Finder add is direct, complete-selection scoped, and independently switchable")
    func finderScope() throws {
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        let file = root.appendingPathComponent("a.txt")
        let folder = root.appendingPathComponent("B", isDirectory: true)
        #expect(FavoriteLocationsPolicy.canAdd([file, folder], isItemMenu: true, preferences: preferences))
        #expect(!FavoriteLocationsPolicy.canAdd([file, folder], isItemMenu: false, preferences: preferences))
        #expect(!FavoriteLocationsPolicy.canAdd([file, file], isItemMenu: true, preferences: preferences))
        #expect(!FavoriteLocationsPolicy.canAdd([file, URL(fileURLWithPath: "/outside/B")],
            isItemMenu: true, preferences: preferences))
        preferences.favoriteLocations.showAddInFinder = false
        #expect(!FavoriteLocationsPolicy.canAdd([file], isItemMenu: true, preferences: preferences))
        let restored = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(!restored.favoriteLocations.showAddInFinder && restored.favoriteLocations.showListInFinder)
    }

    @Test("hundreds of saved entries keep the quick menu bounded and search name first")
    func largeCatalog() throws {
        var catalog = FavoriteLocationsCatalog()
        let stamp = Date(timeIntervalSince1970: 10_000)
        let all = (0..<1_000).map { item($0, pinned: $0 < 20,
            used: $0 >= 20 && $0 < 200 ? stamp.addingTimeInterval(Double($0)) : nil) }
        #expect(try catalog.add(all.prefix(100).map { $0 }).added == 100)
        for batch in stride(from: 100, to: 1_000, by: 100) {
            _ = try catalog.add(Array(all[batch..<batch + 100]))
        }
        #expect(catalog.items.count == 1_000)
        let quick = catalog.quickItems()
        #expect(quick.count == 10)
        #expect(Array(quick.prefix(6)).allSatisfy { $0.isPinned })
        #expect(Set(quick.map(\.id)).count == quick.count)
        #expect(catalog.search("项目 22").first?.name == "项目 22")
        #expect(catalog.search("工作").allSatisfy { $0.group == "工作" })
    }

    @Test("duplicates are skipped while malformed whole batches leave catalog unchanged")
    func addAndValidation() throws {
        var catalog = FavoriteLocationsCatalog()
        let first = item(1)
        #expect(try catalog.add([first, first]).added == 1)
        #expect(catalog.items.count == 1)
        #expect(catalog.quickItems().first?.id == first.id)
        let anotherPathSameIdentity = FavoriteLocation(url: root.appendingPathComponent("renamed.txt"),
            bookmark: Data([4]), device: first.device, inode: first.inode, kind: .file, name: "Renamed")
        #expect(try catalog.add([anotherPathSameIdentity]).duplicates == 1)
        let invalid = FavoriteLocation(url: URL(string: "https://example.com/a")!, bookmark: Data(),
            device: 1, inode: 55, kind: .file, name: "Remote")
        #expect(throws: FavoriteLocationError.invalidSelection) { try catalog.add([item(2), invalid]) }
        #expect(catalog.items.count == 1)
    }

    @Test("pinned ordering changes only when explicitly moved")
    func pinnedOrder() {
        var catalog = FavoriteLocationsCatalog(items: [item(1, pinned: true), item(2),
            item(3, pinned: true), item(4, pinned: true)])
        let ids = catalog.items.map(\.id)
        catalog.movePinned(ids[2], by: -1)
        #expect(catalog.quickItems(pinnedLimit: 3, recentLimit: 0).map(\.id) == [ids[2], ids[0], ids[3]])
        catalog.movePinned(ids[2], to: ids[3])
        #expect(catalog.quickItems(pinnedLimit: 3, recentLimit: 0).map(\.id) == [ids[0], ids[3], ids[2]])
        #expect(catalog.items.contains { $0.id == ids[1] })
    }

    @Test("catalog is private, round-trips, and preserves damaged bytes for recovery")
    func store() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("favorites-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("favorites.json")
        let store = FavoriteLocationsStore(file: file)
        #expect(try store.load().items.isEmpty)
        let catalog = FavoriteLocationsCatalog(items: [item(1)])
        try store.save(catalog)
        #expect(try store.load() == catalog)
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let bad = Data("{broken".utf8)
        try bad.write(to: file)
        #expect(throws: FavoriteLocationError.damagedCatalog) { try store.load() }
        #expect(try Data(contentsOf: file) == bad)
        let backup = try store.backupDamagedAndReset()
        #expect(try Data(contentsOf: backup) == bad)
        #expect(try store.load().items.isEmpty)
    }

    @Test("Finder tickets carry only explicit favorite actions")
    func tickets() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("favorite-tickets-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileOperationTicketStore(directory: folder)
        let request = FileOperationRequest.favoriteAdd([root.appendingPathComponent("a.txt")])
        let now = Date(timeIntervalSince1970: 1_000)
        let ticket = try store.enqueue(request, now: now)
        #expect(try store.consume(ticket, now: now) == request)
        #expect(try store.consume(ticket, now: now) == nil)
        var registry = FileMenuActionRegistry()
        let id = UUID()
        let tag = registry.register([FileMenuAction(directory: root, favoriteAction: .locate(id))])[0]
        #expect(registry.takeAction(for: tag)?.favoriteAction == .locate(id))
    }
}
