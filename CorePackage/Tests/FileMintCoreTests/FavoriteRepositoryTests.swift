import Foundation
import Testing
@testable import FileMintCore

@Suite("Favorite catalog transactions")
struct FavoriteRepositoryTests {
    private func item(_ index: Int, pinned: Bool = false, added: Date? = nil) -> FavoriteLocation {
        FavoriteLocation(url: URL(fileURLWithPath: "/synthetic/item-\(index)"), bookmark: Data([1]),
            device: 1, inode: UInt64(index + 1), kind: .file, name: "Item \(index)",
            isPinned: pinned, addedAt: added)
    }

    @Test("cleared history keeps only pinned shortcuts and never pads recent slots")
    func clearedRecent() {
        let pinned = item(0, pinned: true)
        var catalog = FavoriteLocationsCatalog(items: [pinned] + (1...20).map { item($0) })
        #expect(catalog.quickItems().map(\.id) == [pinned.id])
        catalog.items[10].lastLocatedAt = Date(timeIntervalSince1970: 500)
        #expect(catalog.quickItems().map(\.id) == [pinned.id, catalog.items[10].id])
        catalog.items[10].lastLocatedAt = nil
        catalog.items[0].isPinned = false
        #expect(catalog.quickItems().isEmpty)
    }

    @Test("Finder projection keeps only bounded shortcuts and can show Search All without shortcuts")
    func finderProjection() {
        let catalog = FavoriteLocationsCatalog(items: (0..<1_000).map {
            item($0, pinned: $0 < 10, added: Date(timeIntervalSince1970: Double($0)))
        })
        let menu = FavoriteFinderMenu(catalog: catalog)
        #expect(menu.hasSavedItems && menu.rows.count == 10)
        #expect(menu.rows.map(\.id) == catalog.quickItems().map(\.id))
        let cleared = FavoriteFinderMenu(catalog: .init(items: [item(0)]))
        #expect(cleared.hasSavedItems && cleared.rows.isEmpty)
        #expect(!FavoriteFinderMenu(catalog: .init()).hasSavedItems)
    }

    @Test("concurrent edits use the newest catalog and run outside the main thread")
    @MainActor func serializedEdits() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("favorites-repository-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FavoriteLocationsStore(file: root.appendingPathComponent("catalog.json"))
        let repository = FavoriteLocationsRepository(store: store)
        _ = try await repository.snapshot()
        let entries = (0..<100).map { item($0, added: Date(timeIntervalSince1970: 1)) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for entry in entries {
                group.addTask {
                    let (offMain, _) = try await repository.update { catalog in
                        _ = try catalog.add([entry])
                        return !Thread.isMainThread
                    }
                    #expect(offMain)
                }
            }
            try await group.waitForAll()
        }
        let snapshot = try await repository.snapshot()
        #expect(snapshot.revision == 100)
        #expect(Set(snapshot.catalog.items.map(\.id)) == Set(entries.map(\.id)))
        #expect(try store.load() == snapshot.catalog)
    }

    @Test("failed, externally changed and damaged transactions preserve original bytes")
    func failedEdits() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("favorites-failure-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FavoriteLocationsStore(file: root.appendingPathComponent("catalog.json"))
        let original = FavoriteLocationsCatalog(items: [item(1)])
        try store.save(original)
        let repository = FavoriteLocationsRepository(store: store)
        _ = try await repository.snapshot()
        let bytes = try Data(contentsOf: store.file)
        do {
            _ = try await repository.update { changed in
                changed.items.removeAll()
                throw FavoriteLocationError.invalidSelection
            }
            Issue.record("Invalid transaction unexpectedly succeeded")
        } catch { #expect(error as? FavoriteLocationError == .invalidSelection) }
        #expect(try Data(contentsOf: store.file) == bytes)
        let damaged = Data("{broken".utf8)
        try damaged.write(to: store.file)
        do {
            _ = try await repository.update { $0.items.removeAll() }
            Issue.record("Damaged catalog was overwritten")
        } catch { #expect(error as? FavoriteLocationError == .damagedCatalog) }
        #expect(try Data(contentsOf: store.file) == damaged)
        let (backup, snapshot) = try await repository.backupAndReset()
        #expect(try Data(contentsOf: backup) == damaged)
        #expect(snapshot.catalog.items.isEmpty && snapshot.revision == 1)
        let restoredItem = item(2)
        let (_, saved) = try await repository.update { try $0.add([restoredItem]) }
        #expect(saved.catalog.items.map(\.id) == [restoredItem.id])
    }
}
