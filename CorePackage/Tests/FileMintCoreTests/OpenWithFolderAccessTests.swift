import FileMintCore
import Foundation
import Testing

@Suite("Open with App folder grants")
struct OpenWithFolderAccessTests {
    private func withStore(_ body: (OpenWithFolderAccessStore) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(OpenWithFolderAccessStore(file: root.appendingPathComponent("private/access.json")))
    }

    @Test("a fresh store restores saved grants with private file permissions")
    func persistence() throws {
        try withStore { store in
            #expect(try store.load().isEmpty)
            let grants = ["/Users/example/工作 🪴": Data([1, 2, 3]), "/Volumes/Work": Data([4, 5])]
            try store.save(grants)
            let reopened = OpenWithFolderAccessStore(file: store.file)
            #expect(try reopened.load() == grants)
            let permissions = try FileManager.default.attributesOfItem(atPath: store.file.path)[.posixPermissions] as? Int
            #expect(permissions == 0o600)
            let parentPermissions = try FileManager.default.attributesOfItem(atPath: store.file.deletingLastPathComponent().path)[.posixPermissions] as? Int
            #expect(parentPermissions == 0o700)
        }
    }

    @Test("only in-scope ancestors are candidates, from narrowest to broadest")
    func scope() {
        let root = URL(fileURLWithPath: "/Users/example/Work", isDirectory: true)
        let child = root.appendingPathComponent("Project", isDirectory: true)
        let grants = [root.path: Data([1]), child.path: Data([2]),
                      "/Users/example": Data([3]), "/Users/example/Work-other": Data([4])]
        #expect(OpenWithFolderAccessStore.candidateDirectories(for: child, bookmarks: grants, folders: [root]) == [child, root])
        #expect(OpenWithFolderAccessStore.candidateDirectories(for: child.appendingPathComponent("sub"),
            bookmarks: grants, folders: [root]) == [child, root])
        #expect(OpenWithFolderAccessStore.candidateDirectories(for: child,
            bookmarks: grants, folders: [child]) == [child])
        for target in [URL(fileURLWithPath: "/Users/example/Work-other/file"),
                       URL(string: "file://server/Users/example/Work/Project")!,
                       URL(string: "https://example.com/Work/Project")!] {
            #expect(OpenWithFolderAccessStore.candidateDirectories(for: target, bookmarks: grants, folders: [root]).isEmpty)
        }
        #expect(OpenWithFolderAccessStore.candidateDirectories(for: child, bookmarks: grants, folders: []).isEmpty)
    }

    @Test("invalid or oversized new grants do not replace the last valid store")
    func rejectedWrites() throws {
        try withStore { store in
            let grants = ["/Users/example/Work": Data([1])]
            try store.save(grants)
            let original = try Data(contentsOf: store.file)
            for invalid in [["relative": Data([1])], ["/Users/example/../other": Data([1])],
                            ["/Users/example/Work": Data()], ["/bad\0path": Data([1])],
                            ["/Users/example/Work": Data(repeating: 1, count: OpenWithFolderAccessStore.maximumBytes)]] {
                #expect(throws: OpenWithError.self) { try store.save(invalid) }
                #expect(try Data(contentsOf: store.file) == original)
            }
        }
    }

    @Test("damaged, oversized and semantically invalid stores are preserved and rejected")
    func damagedStores() throws {
        try withStore { store in
            try FileManager.default.createDirectory(at: store.file.deletingLastPathComponent(), withIntermediateDirectories: true)
            for data in [Data("broken".utf8), Data(#"{"relative":"AQ=="}"#.utf8),
                         Data(#"{"/tmp":""}"#.utf8), Data(repeating: 32, count: OpenWithFolderAccessStore.maximumBytes + 1)] {
                try data.write(to: store.file)
                #expect(throws: OpenWithError.self) { try store.load() }
                #expect(throws: OpenWithError.self) { try store.save(["/tmp": Data([1])]) }
                #expect(try Data(contentsOf: store.file) == data)
            }
        }
    }

    @Test("a symlink cannot redirect access-store reads or writes")
    func redirectedStore() throws {
        try withStore { store in
            let parent = store.file.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let other = parent.appendingPathComponent("other.json")
            let original = Data(#"{"/tmp":"AQ=="}"#.utf8)
            try original.write(to: other)
            try FileManager.default.createSymbolicLink(at: store.file, withDestinationURL: other)
            #expect(throws: OpenWithError.self) { try store.load() }
            #expect(throws: OpenWithError.self) { try store.save(["/tmp": Data([2])]) }
            #expect(try Data(contentsOf: other) == original)
        }
    }
}
