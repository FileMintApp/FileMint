import FileMintCore
import Foundation
import Testing
import UniformTypeIdentifiers

@Suite("Change default application")
struct DefaultApplicationTests {
    @Test("only an explicitly enabled, single known local file is offered")
    func eligibility() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let document = root.appendingPathComponent("sample.pdf")
        let unknown = root.appendingPathComponent("sample.filemint-unknown-type")
        let link = root.appendingPathComponent("link.pdf")
        try Data().write(to: document)
        try Data().write(to: unknown)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: document)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true
        func offered(_ urls: [URL], item: Bool = true) -> Bool {
            FileToolsPolicy.availableTools(selection: urls, isItemMenu: item, preferences: preferences).contains(.defaultApplication)
        }
        let partial = try JSONDecoder().decode(FileToolsPreferences.self,
            from: Data(#"{"isEnabled":true,"defaultApplication":"invalid","copyPaths":false}"#.utf8))
        #expect(!partial.defaultApplication && !partial.copyPaths)
        #expect(!offered([document]))
        preferences.fileTools.setEnabled(true, for: .defaultApplication)
        #expect(offered([document]))
        #expect(!offered([document], item: false))
        for invalid in [[document, unknown], [link], [unknown], [root], [URL(string: "file://example.com/a.pdf")!]] {
            #expect(!offered(invalid))
        }
        #expect(!FileToolsPolicy.availableTools(target: .directory(root), preferences: preferences).contains(.defaultApplication))
        preferences.fileTools.mainMenuTools = [.defaultApplication]
        let saved = try JSONDecoder().decode(FileToolsPreferences.self, from: JSONEncoder().encode(preferences.fileTools))
        let layout = FileToolsMenuLayout(tools: [.defaultApplication], hasMoveDestination: false, preferences: saved)
        #expect(layout.main == [.defaultApplication] && layout.submenu.isEmpty)
    }

    @Test("capture freezes the type and rejects a replaced file and mismatched type")
    func frozenType() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let document = root.appendingPathComponent("sample.pdf")
        try Data("fixture".utf8).write(to: document)
        let selection = try DefaultApplicationSelection.capture([document])
        #expect(try selection.validate(in: [root]) == .pdf)
        #expect(throws: FileInfoError.disabled) { try selection.validate(in: [root.appendingPathComponent("other")]) }
        let json = try JSONEncoder().encode(selection)
        var wrong = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
        wrong["typeIdentifier"] = UTType.png.identifier
        let tampered = try JSONDecoder().decode(DefaultApplicationSelection.self,
            from: JSONSerialization.data(withJSONObject: wrong))
        #expect(throws: FileInfoError.changed) { try tampered.validate(in: [root]) }
        try FileManager.default.moveItem(at: document, to: root.appendingPathComponent("original.pdf"))
        try Data("replacement".utf8).write(to: document)
        #expect(throws: FileInfoError.changed) { try selection.validate(in: [root]) }
    }

    @Test("the association request is type-bound, single-use and expiring")
    func ticket() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let document = root.appendingPathComponent("sample.txt")
        try Data().write(to: document)
        let request = try FileOperationRequest.defaultApplication(DefaultApplicationSelection.capture([document]))
        let store = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
        let now = Date()
        let url = try store.enqueue(request, now: now)
        #expect(FileOperationTicketStore.isDefaultApplicationURL(url))
        #expect(FileOperationTicketStore.handlesRoute(url))
        #expect(try store.consume(url, now: now) == request)
        #expect(try store.consume(url, now: now) == nil)
        let expired = try store.enqueue(request, now: now)
        #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
        #expect(try store.consume(URL(string: "filemint://default-application?type=public.plain-text")!) == nil)
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("filemint-default-application-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }
}
