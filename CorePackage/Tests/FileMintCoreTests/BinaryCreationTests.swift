import Foundation
import Testing
@testable import FileMintCore

struct BinaryCreationTests {
    @Test func exactBytesAndExclusivePublication() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("图片.png")
        try Data("keep".utf8).write(to: original)
        let bytes = Data([0, 255, 0, 128]) + Data("{{date}}".utf8)
        let request = FileCreationRequest(destinationDirectory: root, template: TemplateCatalog.builtInTemplates[0],
            requestedFileName: "图片.png", fileData: bytes)
        let result = try FileCreationService().createFile(request)
        #expect(result.createdURL.lastPathComponent == "图片 2.png")
        #expect(try Data(contentsOf: result.createdURL) == bytes)
        #expect(try Data(contentsOf: original) == Data("keep".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["图片 2.png", "图片.png"])
        var replace = request
        replace.collisionStrategy = .replace
        #expect(throws: FileMintError.self) { try FileCreationService().createFile(replace) }
        #expect(try Data(contentsOf: original) == Data("keep".utf8))
        let dangling = root.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(atPath: dangling.path, withDestinationPath: root.appendingPathComponent("missing").path)
        let output = try BinaryFileWriter.create(bytes, in: root, name: "link.png")
        #expect(output.createdURL.lastPathComponent == "link 2.png")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("missing").path))
    }

    @Test func clipboardTicketsRequireScopeAgeAndSingleUse() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = QuickCreationTicketStore(directory: root)
        let destination = root.appendingPathComponent("目标")
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [destination]
        preferences.templates = []
        let now = Date(timeIntervalSince1970: 1_000)
        let url = try store.enqueueClipboardImage(directory: destination, now: now)
        let ticket = try #require(try store.consume(url, preferences: preferences, now: now))
        #expect(ticket.clipboardImage == true && ticket.directory == destination)
        #expect(try store.consume(url, preferences: preferences, now: now) == nil)
        let expired = try store.enqueueClipboardImage(directory: destination, now: now)
        #expect(try store.consume(expired, preferences: preferences, now: now.addingTimeInterval(61)) == nil)
        let outside = try store.enqueueClipboardImage(directory: root, now: now)
        #expect(try store.consume(outside, preferences: preferences, now: now) == nil)
        #expect(try store.consume(URL(string: "filemint://quick?directory=/tmp&clipboardImage=true")!, preferences: preferences) == nil)
    }
}
