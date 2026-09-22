import FileMintCore
import Foundation
import Testing

@Suite("Focused creation")
struct FocusedCreationTests {
    @Test("background menus preserve the container even when directory metadata is unavailable")
    func backgroundMenuDestination() {
        let desktop = URL(fileURLWithPath: "/Users/test/Desktop", isDirectory: true)
        let downloads = URL(fileURLWithPath: "/Users/test/Downloads", isDirectory: true)
        for target in [desktop, downloads, downloads.appendingPathComponent("中文", isDirectory: true)] {
            #expect(FileMenuDestination.directory(target: target, isContainer: true,
                targetIsDirectory: false, monitoredFolders: [desktop, downloads]) == target)
        }
    }

    @Test("missing or out-of-scope menu targets never guess a destination")
    func missingMenuDestination() {
        let desktop = URL(fileURLWithPath: "/Users/test/Desktop", isDirectory: true)
        for isContainer in [true, false] {
            #expect(FileMenuDestination.directory(target: nil, isContainer: isContainer,
                targetIsDirectory: false, monitoredFolders: [desktop]) == nil)
        }
        for folders in [[], [URL(fileURLWithPath: "/Users/test/Desk", isDirectory: true)]] {
            #expect(FileMenuDestination.directory(target: desktop, isContainer: true,
                targetIsDirectory: false, monitoredFolders: folders) == nil)
        }
        #expect(FileMenuDestination.directory(target: URL(string: "https://example.com"), isContainer: true,
            targetIsDirectory: false, monitoredFolders: [desktop]) == nil)
        let file = desktop.appendingPathComponent("note.txt")
        #expect(FileMenuDestination.directory(target: file, isContainer: false,
            targetIsDirectory: false, monitoredFolders: [desktop]) == desktop)
    }

    @Test("observing the parent of protected folders does not expand menu scope")
    func protectedFolderObservation() {
        let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        let documents = home.appendingPathComponent("Documents", isDirectory: true)
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        let pictures = home.appendingPathComponent("Pictures", isDirectory: true)
        let folders = [desktop, documents, downloads]
        #expect(FolderScope.observationRoots(for: folders, home: home) == Set(folders + [home]))
        #expect(FolderScope.observationRoots(for: [downloads], home: home) == [downloads])
        #expect(FolderScope.observationRoots(for: [], home: home).isEmpty)
        #expect(FolderScope.observationRoots(for: [desktop], home: home) == [desktop, home])
        #expect(FileMenuDestination.directory(target: documents, isContainer: true,
            targetIsDirectory: false, monitoredFolders: [desktop]) == nil)
        for target in [home, pictures, home.appendingPathComponent("Documents 2", isDirectory: true)] {
            #expect(!FolderScope.contains(target, in: folders))
            #expect(FileMenuDestination.directory(target: target, isContainer: true,
                targetIsDirectory: false, monitoredFolders: folders) == nil)
        }
        #expect(FolderScope.contains(documents.appendingPathComponent("Work", isDirectory: true), in: folders))
        #expect(!FolderScope.contains(documents, in: [URL(string: "https://example.com/")!]))
    }

    @Test("a desktop background action creates in Desktop through the existing single-use ticket flow")
    func desktopMenuCreation() throws {
        let parent = try workspace()
        defer { try? FileManager.default.removeItem(at: parent) }
        let desktop = parent.appendingPathComponent("Desktop", isDirectory: true)
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [desktop]
        let destination = try #require(FileMenuDestination.directory(target: desktop, isContainer: true,
            targetIsDirectory: false, monitoredFolders: preferences.monitoredFolderURLs))
        let store = QuickCreationTicketStore(directory: parent.appendingPathComponent("requests"))
        let template = TemplateCatalog.builtInTemplates[0]
        let route = try store.enqueue(directory: destination, templateID: template.id)
        let ticket = try #require(try store.consume(route, preferences: preferences))
        let result = try FileCreationService().createFile(.init(destinationDirectory: ticket.directory, template: template))
        #expect(result.createdURL.deletingLastPathComponent() == desktop)
        #expect(FileManager.default.fileExists(atPath: result.createdURL.path))
        #expect(try store.consume(route, preferences: preferences) == nil)
        #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent(template.suggestedFileName).path))
    }

    private func workspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("placeholder-looking filenames stay literal during template expansion")
    func templateExpansionIsSinglePass() {
        var template = TemplateCatalog.builtInTemplates[0]
        template.content = "{{fileName}} / {{year}} / {{unknown}}"
        let value = TemplateRenderer.render(template, context: .init(
            fileName: "{{year}}.md", createdAt: Date(timeIntervalSince1970: 1_704_067_200)))
        #expect(value == "{{year}}.md / 2024 / {{unknown}}")
    }

    @Test("pasted text is byte-for-byte literal, including placeholders and CRLF")
    func literalContent() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        var template = TemplateCatalog.builtInTemplates[0]
        template.content = "  中文 🌱\r\n{{fileName}} {{year}}\n\t"
        let result = try FileCreationService().createFile(.init(
            destinationDirectory: folder, template: template, contentMode: .verbatim
        ))
        #expect(try Data(contentsOf: result.createdURL) == Data(template.content.utf8))
    }

    @Test("simultaneous requests never overwrite and all receive unique names")
    func concurrentCreation() async throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = try await withThrowingTaskGroup(of: URL.self) { group in
            for index in 0..<40 {
                group.addTask {
                    var template = TemplateCatalog.builtInTemplates[0]
                    template.content = "payload-\(index)"
                    return try FileCreationService().createFile(.init(
                        destinationDirectory: folder, template: template
                    )).createdURL
                }
            }
            var results: [URL] = []
            for try await url in group { results.append(url) }
            return results
        }
        #expect(Set(urls).count == 40)
        let contents = try Set(urls.map { try String(contentsOf: $0, encoding: .utf8) })
        #expect(contents == Set((0..<40).map { "payload-\($0)" }))
    }

    @Test("dangling symlinks and existing directories occupy their names")
    func occupiedNames() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appendingPathComponent("missing.txt")
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("Untitled.txt"), withDestinationURL: target)
        let template = TemplateCatalog.builtInTemplates[0]
        let result = try FileCreationService().createFile(.init(destinationDirectory: folder, template: template))
        #expect(result.createdURL.lastPathComponent == "Untitled 2.txt")
        #expect(!FileManager.default.fileExists(atPath: target.path))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("directory.txt"), withIntermediateDirectories: true)
        #expect(throws: FileMintError.self) {
            try FileCreationService().createFile(.init(destinationDirectory: folder, template: template,
                requestedFileName: "directory.txt", collisionStrategy: .replace))
        }
    }

    @Test("a confirmed replacement replaces the link, never its target")
    func replaceSymlink() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appendingPathComponent("original.txt")
        try Data("keep".utf8).write(to: target)
        let link = folder.appendingPathComponent("Untitled.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        _ = try FileCreationService().createFile(.init(destinationDirectory: folder,
            template: TemplateCatalog.builtInTemplates[0], collisionStrategy: .replace))
        #expect(try String(contentsOf: target, encoding: .utf8) == "keep")
        #expect(try String(contentsOf: link, encoding: .utf8) == "")
    }

    @Test("path traversal and control characters cannot become file paths")
    func validNames() {
        for name in [".", "..", "\u{0}", "a\nb", "a\\b"] {
            let safe = FilenamePolicy.sanitizedFileName(name)
            #expect(safe != "." && safe != "..")
            #expect(!safe.contains("\u{0}") && !safe.contains("\n") && !safe.contains("\\"))
        }
        for suffix in ["", ".", "..", "a..b", "txt.", "x\u{0}", "a/b", "a:b", "a\\b", "x\ny"] {
            #expect(FilenamePolicy.normalizedFileExtension(suffix) == nil)
        }
        #expect(FilenamePolicy.fileName("types.d.ts", applyingFileExtension: "md", replacingFileExtension: "d.ts") == "types.md")
    }

    @Test("quick tickets are single-use, expire, and cannot target unconfigured folders")
    func quickTickets() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = QuickCreationTicketStore(directory: folder.appendingPathComponent("requests"))
        var prefs = FileMintPreferences.default
        prefs.monitoredFolderURLs = [folder]
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let good = try store.enqueue(directory: folder, templateID: "plain-text", now: now)
        #expect(try store.consume(good, preferences: prefs, now: now)?.directory == folder)
        #expect(try store.consume(good, preferences: prefs, now: now) == nil)
        let expired = try store.enqueue(directory: folder, templateID: "plain-text", now: now)
        #expect(try store.consume(expired, preferences: prefs, now: now.addingTimeInterval(61)) == nil)
        let outside = try store.enqueue(directory: folder.deletingLastPathComponent(), templateID: "plain-text", now: now)
        #expect(try store.consume(outside, preferences: prefs, now: now) == nil)
        #expect(try store.consume(URL(string: "filemint://quick?id=../preferences")!, preferences: prefs, now: now) == nil)
    }

    @Test("quick routes never consume directories or symlinked requests")
    func malformedTicketFiles() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = QuickCreationTicketStore(directory: folder)
        let id = UUID().uuidString
        let path = folder.appendingPathComponent("\(id).json")
        let route = URL(string: "filemint://quick?id=\(id)")!
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
        #expect(try store.consume(route, preferences: .default) == nil)
        #expect(FileManager.default.fileExists(atPath: path.path))
        try FileManager.default.removeItem(at: path)
        let destination = folder.appendingPathComponent("keep.json")
        try Data("keep".utf8).write(to: destination)
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: destination)
        #expect(try store.consume(route, preferences: .default) == nil)
        #expect(try Data(contentsOf: destination) == Data("keep".utf8))
    }

    @Test("Finder action tags keep their original destination across later menus")
    func menuActionSnapshots() throws {
        let a = FileMenuAction(directory: URL(fileURLWithPath: "/tmp/a"), templateID: "json")
        let b = FileMenuAction(directory: URL(fileURLWithPath: "/tmp/b"), templateID: "plain-text")
        var registry = FileMenuActionRegistry(retainingMenus: 2)
        let aTag = registry.register([a])[0]
        let bTag = registry.register([b])[0]
        #expect(registry.takeAction(for: aTag) == a)
        #expect(registry.takeAction(for: aTag) == nil)
        #expect(registry.takeAction(for: bTag) == b)
        let stale = registry.register([a])[0]
        _ = registry.register([b]); _ = registry.register([b])
        #expect(registry.takeAction(for: stale) == nil)
    }

    @Test("reopening the Finder menu after creation keeps creating distinct files")
    func repeatedMenuCreation() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = QuickCreationTicketStore(directory: folder.appendingPathComponent("requests"))
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [folder]
        let template = try #require(TemplateCatalog.template(withID: "plain-text", in: preferences.templates))
        var registry = FileMenuActionRegistry(retainingMenus: 2)

        for attempt in 1...5 {
            let tags = registry.register([FileMenuAction(directory: folder, templateID: template.id)])
            let selectedAction = registry.takeAction(for: tags[0])
            let action = try #require(selectedAction)
            let route = try store.enqueue(directory: action.directory, templateID: try #require(action.templateID))
            let ticket = try #require(try store.consume(route, preferences: preferences))
            let created = try FileCreationService().createFile(.init(
                destinationDirectory: ticket.directory, template: template))
            #expect(created.createdURL.lastPathComponent == (attempt == 1 ? "Untitled.txt" : "Untitled \(attempt).txt"))
            #expect(try Data(contentsOf: created.createdURL).isEmpty)
            #expect(registry.takeAction(for: tags[0]) == nil)
            #expect(try store.consume(route, preferences: preferences) == nil)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("requests").path).isEmpty)
    }

    @Test("Finder routes preserve Unicode locations and cannot contain write instructions")
    func route() throws {
        let directory = URL(fileURLWithPath: "/tmp/工作 & notes #1", isDirectory: true)
        let route = try #require(CreationRoute.url(for: directory))
        #expect(CreationRoute.directory(from: route)?.path == directory.path)
        #expect(CreationRoute.directory(from: URL(string: "filemint://new?directory=/tmp&content=bad")!) == nil)
        #expect(CreationRoute.directory(from: URL(string: "filemint://new?directory=relative")!) == nil)
        #expect(CreationRoute.directory(from: URL(string: "https://new?directory=/tmp")!) == nil)
    }

    @Test("a user-entered demo.js is saved with exactly that name and extension")
    func explicitFilename() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let suffix = try #require(FilenamePolicy.inferredFileExtension(from: "demo.js"))
        #expect(suffix == "js")
        let name = try #require(FilenamePolicy.fileName("demo.js", applyingFileExtension: suffix))
        #expect(name == "demo.js")
        var template = TemplateCatalog.builtInTemplates[0]
        template.content = "console.log('demo');\n"
        let result = try FileCreationService().createFile(.init(destinationDirectory: folder,
            template: template, requestedFileName: name, contentMode: .verbatim))
        #expect(result.createdURL.lastPathComponent == "demo.js")
        #expect(try String(contentsOf: result.createdURL, encoding: .utf8) == template.content)
        #expect(FilenamePolicy.inferredFileExtension(from: "demo.custom") == "custom")
        #expect(FilenamePolicy.inferredFileExtension(from: "types.d.ts", knownExtensions: ["ts", "d.ts"]) == "d.ts")
        #expect(FilenamePolicy.inferredFileExtension(from: "demo") == nil)
    }

    @Test("saved custom templates are searchable and allow independent same-suffix entries")
    func customTypes() throws {
        var types = TemplateCatalog.builtInTemplates
        let type = try TemplateCatalog.customTemplate(name: "Config", fileExtension: " .TOML ", content: "key = 1\n", in: types)
        types.append(type)
        #expect(type.suggestedFileName == "Untitled.toml")
        #expect(FileFormatCatalog.matching("config", in: FileFormatCatalog.options(from: types)).first?.fileExtension == "toml")
        #expect(CustomFileDraft(extensionInput: "toml", templates: types).content == "key = 1\n")
        let other = try TemplateCatalog.customTemplate(name: "Other config", fileExtension: "TOML", content: "other", in: types)
        #expect(other.id != type.id && other.fileExtension == type.fileExtension)
        #expect(throws: TemplateValidationError.self) {
            try TemplateCatalog.customTemplate(name: "", fileExtension: "conf", content: "", in: types)
        }
        var draft = CustomFileDraft(templates: types)
        draft.updateContent("{{year}}")
        draft.updateExtensionInput("toml", templates: types)
        #expect(draft.content == "{{year}}")
    }

    @Test("separate stores observe saved settings and preserve custom types on disk")
    func preferenceStorage() throws {
        let folder = try workspace()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("nested/preferences.json")
        let writer = FileMintPreferencesStore(fileURL: url)
        let reader = FileMintPreferencesStore(fileURL: url)
        var preferences = FileMintPreferences.default
        preferences.language = .chinese
        let custom = try TemplateCatalog.customTemplate(name: "Config", fileExtension: "toml", content: "key = 1", in: preferences.templates)
        preferences.templates.append(custom)
        try writer.save(preferences)
        #expect(reader.load() == preferences)
        #expect(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int == 0o600)
    }

    @Test("legacy preferences preserve custom types and reject replace as a quick default")
    func migrationAndRoundtrip() throws {
        var original = FileMintPreferences.default
        original.templates = Array(original.templates.prefix(2))
        original.templates[0].isEnabled = false
        let custom = try TemplateCatalog.customTemplate(name: "Config", fileExtension: "conf", content: "sample", in: original.templates)
        original.templates.append(custom)
        original.language = .chinese
        original.collisionStrategy = .replace
        original.monitoredFolderBookmarks = ["/tmp/example": Data([1, 2, 3])]
        let decoded = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(original))
        #expect(decoded.templates.contains(custom))
        #expect(decoded.templates[0].isEnabled == false)
        #expect(decoded.collisionStrategy == .increment)
        #expect(decoded.language == .chinese)
        #expect(decoded.monitoredFolderBookmarks == original.monitoredFolderBookmarks)
        #expect(Set(decoded.templates.map(\.id)).count == decoded.templates.count)
        #expect(TemplateCatalog.restoringBuiltIns(in: decoded.templates).contains { $0.id == custom.id })
    }
}
