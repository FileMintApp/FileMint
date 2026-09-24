import Foundation
import Testing
import FileMintCore

@Suite("Resource tool policies")
struct ResourceToolsTests {
    @Test("explicit app selections are independent of Finder switches and folder scope")
    func appSelection() {
        let images = [URL(fileURLWithPath: "/chosen/a.png"), URL(fileURLWithPath: "/chosen/b.jpg")]
        let preferences = FileMintPreferences.default
        #expect(ResourceToolsPolicy.availableTools(selection: images, isItemMenu: true, preferences: preferences).isEmpty)
        #expect(ResourceToolsPolicy.allowsAppSelection(images, tool: .stitch))
        #expect(!ResourceToolsPolicy.allowsAppSelection([images[0]], tool: .stitch))
        #expect(!ResourceToolsPolicy.allowsAppSelection([images[0], images[0]], tool: .convert))
        #expect(!ResourceToolsPolicy.allowsAppSelection([URL(string: "https://example.com/a.png")!], tool: .convert))
        #expect(!ResourceToolsPolicy.allowsAppSelection([URL(fileURLWithPath: "/chosen/a.webp")], tool: .convert))
    }

    @Test("old preferences leave resources off and preserve saved settings")
    func migration() throws {
        let old = try JSONDecoder().decode(FileMintPreferences.self, from: Data(#"{"language":"zh-Hans","showMenuBar":false}"#.utf8))
        #expect(!old.resourceTools.isEnabled)
        #expect(old.resourceTools.enabledTools.count == 7)
        #expect(old.language == .chinese && !old.showMenuBar)
        var preferences = old
        preferences.resourceTools.enabledTools = [.ocr]
        let roundTrip = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(preferences))
        #expect(roundTrip.resourceTools.enabledTools == [.ocr])
        #expect(!roundTrip.resourceTools.isEnabled)
        let savedSix = Data(#"{"isEnabled":true,"enabledTools":["convert","compress","resize","icons","stitch","ocr"]}"#.utf8)
        let migrated = try JSONDecoder().decode(ResourceToolsPreferences.self, from: savedSix)
        #expect(migrated.isEnabled && !migrated.enabledTools.contains(.removeMetadata))
    }

    @Test("menu scope includes all selected image names and no unrelated resources")
    func scope() {
        let root = URL(fileURLWithPath: "/fixture", isDirectory: true)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.resourceTools.isEnabled = true
        let a = root.appendingPathComponent("A.PNG"), b = root.appendingPathComponent("B.heic")
        #expect(ResourceToolsPolicy.availableTools(selection: [a], isItemMenu: true, preferences: preferences).count == 6)
        #expect(ResourceToolsPolicy.availableTools(selection: [a], isItemMenu: true, preferences: preferences).contains(.removeMetadata))
        #expect(!ResourceToolsPolicy.allowsAppSelection([root.appendingPathComponent("a.gif")], tool: .removeMetadata))
        #expect(ResourceToolsPolicy.availableTools(selection: [a, b], isItemMenu: true, preferences: preferences).contains(.stitch))
        for selection in [[a, a], [a, root.appendingPathComponent("b.webp")], [a, root.appendingPathComponent("b.pdf")],
                          [a, URL(fileURLWithPath: "/outside/b.png")], [root.appendingPathComponent("folder.png", isDirectory: true)]] {
            #expect(ResourceToolsPolicy.availableTools(selection: selection, isItemMenu: true, preferences: preferences).isEmpty)
        }
        #expect(ResourceToolsPolicy.availableTools(selection: [a], isItemMenu: false, preferences: preferences).isEmpty)
        preferences.resourceTools.enabledTools = []
        #expect(ResourceToolsPolicy.availableTools(selection: [a], isItemMenu: true, preferences: preferences).isEmpty)
    }

    @Test("resource action snapshots and tickets preserve captured selection and expire")
    func tickets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let urls = [URL(fileURLWithPath: "/fixture/a.png"), URL(fileURLWithPath: "/fixture/b.png")]
        let request = FileOperationRequest.resource(tool: .stitch, selection: urls)
        let store = FileOperationTicketStore(directory: root)
        let now = Date(timeIntervalSince1970: 1000)
        let ticket = try store.enqueue(request, now: now)
        #expect(try store.consume(ticket, now: now) == request)
        #expect(try store.consume(ticket, now: now) == nil)
        let expired = try store.enqueue(request, now: now)
        #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
        #expect(try store.consume(URL(string: "filemint://move?path=/fixture/a.png")!, now: now) == nil)
        var registry = FileMenuActionRegistry()
        let id = registry.register([FileMenuAction(directory: root, resourceTool: .stitch, selection: urls)])[0]
        #expect(registry.takeAction(for: id)?.selection == urls)
    }

    @Test("resize never enlarges and dimensions reject overflow before allocation")
    func dimensions() throws {
        #expect(try ImageDimensions(width: 4000, height: 3000).fitting(longestEdge: 1000) == ImageDimensions(width: 1000, height: 750))
        #expect(try ImageDimensions(width: 80, height: 40).fitting(longestEdge: 1000) == ImageDimensions(width: 80, height: 40))
        for size in [ImageDimensions(width: Int.max, height: 2), ImageDimensions(width: 0, height: 1),
                     ImageDimensions(width: 5000, height: 5000)] {
            #expect(throws: ResourceError.dimensionsTooLarge) { try size.validate() }
        }
        #expect(throws: ResourceError.invalidOptions) { try ImageDimensions(width: 40, height: 20).fitting(longestEdge: 0) }
    }

    @Test("stitch layout follows orientation and rejects oversized combined canvas")
    func layout() throws {
        let inputs = [ImageDimensions(width: 400, height: 200), ImageDimensions(width: 100, height: 200)]
        #expect(try ImageStitchLayout(inputs: inputs, edge: 100, horizontal: false).canvas == ImageDimensions(width: 100, height: 250))
        #expect(try ImageStitchLayout(inputs: inputs, edge: 100, horizontal: true).canvas == ImageDimensions(width: 250, height: 100))
        #expect(throws: ResourceError.dimensionsTooLarge) {
            try ImageStitchLayout(inputs: Array(repeating: ImageDimensions(width: 1000, height: 1000), count: 20), edge: 1000, horizontal: false)
        }
    }

    @Test("options reject invalid formats and non-finite quality")
    func options() {
        var options = ImageJobOptions()
        options.quality = .nan
        #expect(throws: ResourceError.invalidOptions) { try options.validate(for: .convert) }
        options = ImageJobOptions()
        options.format = .icns
        #expect(throws: ResourceError.invalidOptions) { try options.validate(for: .resize) }
        #expect(!ImageOutputFormat.allCases.contains { $0.rawValue == "webp" })
    }
}
