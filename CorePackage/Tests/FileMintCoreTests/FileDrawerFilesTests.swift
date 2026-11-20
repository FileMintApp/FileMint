@testable import FileMintCore
import Foundation
import Testing

@Suite("File drawer filesystem boundaries")
struct FileDrawerFilesTests {
    private func workspace(_ body: (URL, FileDrawerDirectory) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root, FileDrawerDirectory(root: root))
    }

    @Test func metadataAndIdentity() throws {
        try workspace { root, drawer in
            let file = root.appendingPathComponent("brief.md")
            try Data("draft".utf8).write(to: file)
            _ = try drawer.createFolder(named: "Assets")
            try Data([0]).write(to: root.appendingPathComponent("Assets/inside"))
            try Data([1]).write(to: root.appendingPathComponent(".hidden"))
            let rows = try drawer.list()
            #expect(Set(rows.map(\.name)) == ["brief.md", "Assets"])
            #expect(try drawer.list(showHidden: true).count == 3)
            let selected = try #require(rows.first { $0.name == "brief.md" })
            #expect(selected.canPreview && selected.size == 5)
            let writer = try FileHandle(forWritingTo: file)
            try writer.truncate(atOffset: 51_000_000)
            try writer.close()
            let updated = try drawer.refreshed(selected)
            #expect(updated.size == 51_000_000 && updated.isSameItem(as: selected))
            try FileManager.default.moveItem(at: file, to: root.appendingPathComponent("old.md"))
            try Data([2]).write(to: file)
            let replacement = try #require(drawer.list().first { $0.name == "brief.md" })
            #expect(!replacement.isSameItem(as: selected))
            #expect(throws: (any Error).self) { try drawer.rename(selected, to: "renamed") }
            #expect(try Data(contentsOf: file) == Data([2]))
        }
    }

    @Test func searchMatchesPreparedNamesInFolderSortOrder() throws {
        try workspace { root, drawer in
            _ = try drawer.createFolder(named: "Résumé ＱＡ")
            for name in ["Résumé 10 ＱＡ.PDF", "Résumé 2 ＱＡ.PDF", "Résumé.md", "会议纪要.txt"] {
                let file = root.appendingPathComponent(name)
                try Data(name.utf8).write(to: file)
                let second = name.hasSuffix(".md") ? 20.0 : 10.0
                try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: second)],
                                                      ofItemAtPath: file.path)
            }
            try Data().write(to: root.appendingPathComponent("Résumé ＱＡ/nested-only.pdf"))
            let index = try FileDrawerSearchIndex(drawer.list(), sort: .name, ascending: true)
            let matches = try index.matching("  qa    resuME ")
            #expect(matches.entries.map(\.name) == ["Résumé ＱＡ", "Résumé 2 ＱＡ.PDF", "Résumé 10 ＱＡ.PDF"])
            #expect(matches.index(of: matches.entries[1].url) == 1)
            #expect(try index.matching("PDF 10 RESUME").entries.map(\.name) == ["Résumé 10 ＱＡ.PDF"])
            #expect(try index.matching("纪 txt").entries.map(\.name) == ["会议纪要.txt"])
            #expect(try index.matching("nested-only").entries.isEmpty)
            #expect(try index.matching(" \t").entries.count == 5)
            let sizeIndex = try index.ordered(by: .size, ascending: false)
            #expect(try sizeIndex.matching("qa").entries.map(\.name) == ["Résumé ＱＡ", "Résumé 10 ＱＡ.PDF", "Résumé 2 ＱＡ.PDF"])
            let reverseName = try index.ordered(by: .name, ascending: false)
            #expect(try reverseName.matching("qa").entries.map(\.name) == ["Résumé ＱＡ", "Résumé 10 ＱＡ.PDF", "Résumé 2 ＱＡ.PDF"])
            let byKind = try index.ordered(by: .kind, ascending: false)
            #expect(byKind.all.entries.map(\.name) == [
                "Résumé ＱＡ", "会议纪要.txt", "Résumé 2 ＱＡ.PDF", "Résumé 10 ＱＡ.PDF", "Résumé.md"
            ])
            let newest = try index.ordered(by: .date, ascending: false)
            #expect(try newest.matching("résumé").entries.map(\.name) == [
                "Résumé ＱＡ", "Résumé.md", "Résumé 2 ＱＡ.PDF", "Résumé 10 ＱＡ.PDF"
            ])
            // Querying an existing snapshot never reads the filesystem again.
            try FileManager.default.removeItem(at: root.appendingPathComponent("会议纪要.txt"))
            #expect(try index.matching("会议").entries.map(\.name) == ["会议纪要.txt"])
        }
    }

    @Test func navigationReplacementsAndLinks() throws {
        try workspace { root, drawer in
            let childURL = try drawer.createFolder(named: "child")
            let other = try drawer.createFolder(named: "other")
            let directory = try drawer.child(#require(drawer.list().first { $0.name == "child" }))
            #expect(try drawer.child(named: "child").identity == directory.identity)
            try FileManager.default.moveItem(at: childURL, to: root.appendingPathComponent("old"))
            try FileManager.default.createSymbolicLink(at: childURL, withDestinationURL: other)
            let link = try #require(drawer.list().first { $0.name == "child" })
            #expect(link.isLink && !link.canPreview)
            #expect(throws: (any Error).self) { try drawer.child(link) }
            #expect(throws: (any Error).self) { try drawer.child(named: "child") }
            #expect(throws: (any Error).self) { try drawer.child(named: "..") }
            #expect(throws: (any Error).self) { try FileDrawerDirectory(root: childURL) }
            #expect(throws: (any Error).self) { try directory.createFolder(named: "redirected") }
            #expect(!FileManager.default.fileExists(atPath: other.appendingPathComponent("redirected").path))
            #expect(throws: (any Error).self) { try drawer.createFolder(named: "../escape") }
        }
    }

    @Test func transfersAndCollisions() throws {
        try workspace { root, drawer in
            let sourceURL = try drawer.createFolder(named: "assets")
            _ = try drawer.createFolder(named: "output")
            try Data([42]).write(to: sourceURL.appendingPathComponent("photo"))
            let rows = try drawer.list()
            let source = try #require(rows.first { $0.name == "assets" })
            let destination = try drawer.child(#require(rows.first { $0.name == "output" }))
            let nested = try drawer.child(source)
            #expect(throws: (any Error).self) { try drawer.transfer(source, to: nested, move: false) }
            try drawer.transfer(source, to: destination, move: false)
            #expect(try Data(contentsOf: root.appendingPathComponent("output/assets/photo")) == Data([42]))
            #expect(throws: (any Error).self) { try drawer.transfer(source, to: destination, move: true) }
            #expect(throws: (any Error).self) { try drawer.rename(source, to: "output") }
            #expect(try Data(contentsOf: sourceURL.appendingPathComponent("photo")) == Data([42]))
            let photo = try #require(nested.list().first)
            try nested.transfer(photo, to: destination, move: true)
            let moved = try #require(destination.list().first { $0.name == "photo" })
            let renamed = try destination.rename(moved, to: "final.jpg")
            #expect(try Data(contentsOf: renamed) == Data([42]))
            let renamedRow = try #require(destination.list().first { $0.name == "final.jpg" })
            #expect(!renamedRow.isSameItem(as: moved))
            #expect(renamedRow.isSameItem(as: moved, at: renamed))
            try FileManager.default.moveItem(at: renamed, to: destination.url.appendingPathComponent("retained.jpg"))
            try Data([7]).write(to: renamed, options: .withoutOverwriting)
            let replacement = try #require(destination.list().first { $0.name == "final.jpg" })
            #expect(!replacement.isSameItem(as: moved, at: renamed))
            #expect(try nested.list().isEmpty)
            #expect(try drawer.list(showHidden: true).allSatisfy { !$0.name.hasPrefix(".FileMint-drawer-") })
        }
    }

    @Test func trashReceiptAndRestore() throws {
        try workspace { root, drawer in
            let trashURL = try drawer.createFolder(named: "system-trash-fixture")
            let file = root.appendingPathComponent("brief.md")
            try Data([12]).write(to: file)
            let entry = try #require(drawer.list().first { $0.name == "brief.md" })
            #expect(throws: (any Error).self) {
                try drawer.trash(entry) { _ in throw CocoaError(.fileWriteNoPermission) }
            }
            #expect(try Data(contentsOf: file) == Data([12]))
            let receipt = try #require(drawer.trash(entry) { source in
                #expect(source.path == file.path)
                let item = trashURL.appendingPathComponent(source.lastPathComponent)
                try FileManager.default.moveItem(at: source, to: item)
                return item
            })
            try Data([3]).write(to: file)
            #expect(throws: (any Error).self) { try drawer.restore(receipt) }
            #expect(try Data(contentsOf: file) == Data([3]))
            #expect(try Data(contentsOf: trashURL.appendingPathComponent("brief.md")) == Data([12]))
            try FileManager.default.removeItem(at: file)
            try drawer.restore(receipt)
            #expect(try Data(contentsOf: file) == Data([12]))
            #expect(throws: (any Error).self) { try drawer.restore(receipt) }
        }
    }

    @Test func duplicateInSameFolderAndResumeIdentity() throws {
        try workspace { root, drawer in
            let project = try drawer.createFolder(named: "Project")
            let path = project.appendingPathComponent("file.md")
            try Data([31]).write(to: path)
            let projectRow = try #require(drawer.list().first)
            let directory = try drawer.child(projectRow)
            let file = try #require(directory.list().first)
            try directory.transfer(file, to: directory, move: false)
            try directory.transfer(file, to: directory, move: false)
            #expect(try Data(contentsOf: project.appendingPathComponent("file 2.md")) == Data([31]))
            #expect(try Data(contentsOf: project.appendingPathComponent("file 3.md")) == Data([31]))
            #expect(throws: (any Error).self) { try directory.validateTransfer([file], to: directory, move: true) }
            let reopened = try FileDrawerDirectory(root: root)
            #expect(try reopened.child(named: "Project", matching: directory.identity).identity == directory.identity)
            try FileManager.default.moveItem(at: project, to: root.appendingPathComponent("old"))
            _ = try reopened.createFolder(named: "Project")
            #expect(throws: (any Error).self) { try reopened.child(named: "Project", matching: directory.identity) }
        }
    }

    @Test func rejectedChildPreservesSourceAndCleansPrivateCopy() throws {
        try workspace { root, drawer in
            let source = try drawer.createFolder(named: "source")
            _ = try drawer.createFolder(named: "destination")
            let original = root.appendingPathComponent("original")
            try Data([7]).write(to: original)
            try Data([8]).write(to: source.appendingPathComponent("regular"))
            try FileManager.default.createSymbolicLink(at: source.appendingPathComponent("link"), withDestinationURL: original)
            let rows = try drawer.list()
            let destination = try drawer.child(#require(rows.first { $0.name == "destination" }))
            let entry = try #require(rows.first { $0.name == "source" })
            #expect(throws: (any Error).self) { try drawer.transfer(entry, to: destination, move: false) }
            #expect(try destination.list(showHidden: true).isEmpty)
            #expect(try Data(contentsOf: original) == Data([7]))
            #expect(try Data(contentsOf: source.appendingPathComponent("regular")) == Data([8]))
        }
    }
}
