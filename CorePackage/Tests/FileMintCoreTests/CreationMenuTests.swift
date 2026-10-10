import FileMintCore
import Foundation
import Testing

@Suite("Independent Finder creation placement")
struct CreationMenuTests {
    private func preferences() -> FileMintPreferences {
        var value = FileMintPreferences(templates: [
            FileTemplate(id: "one", displayName: "One", suggestedFileName: "One.txt", group: "Custom", content: "first", rank: 10),
            FileTemplate(id: "two", displayName: "Two", suggestedFileName: "Two.txt", group: "Custom", content: "second", rank: 20)
        ], monitoredFolderURLs: [], collisionStrategy: .increment, revealAfterCreation: false, favoritesFirst: false)
        value.removedBuiltInTemplateIDs = TemplateCatalog.builtInTemplates.map(\.id).sorted()
        return value
    }

    private func longMenuPreferences() -> FileMintPreferences {
        var value = preferences()
        value.templates = (0..<80).map {
            FileTemplate(id: "template-\($0)", displayName: "Template \($0)",
                suggestedFileName: "Example.txt", group: "Custom", content: "", rank: $0)
        }
        value.creationMenuPlacements = ["newFile": .main, "clipboardText": .hidden, "clipboardImage": .submenu]
        for index in 0..<80 {
            value.templateMenuPlacements["template-\(index)"] = index.isMultiple(of: 2) ? .main : .submenu
        }
        value.templateMenuPlacements["template-0"] = .hidden
        value.templates[1].isEnabled = false
        return value
    }

    @Test("a long mixed creation menu retains every tag as one batch", arguments: [1, 32])
    func longMenuRegistration(capacity: Int) throws {
        var registry = FileMenuActionRegistry(retainingMenus: capacity)
        let directory = URL(fileURLWithPath: "/tmp/filemint-menu-target", isDirectory: true)
        let menu = registry.registerCreationMenu(CreationMenuLayout(preferences: longMenuPreferences()), directory: directory)
        let expectedMain: [CreationMenuLayout.Entry] = [.action(.newFile), .separator]
            + stride(from: 2, to: 80, by: 2).map { .template("template-\($0)") }
        let expectedSubmenu: [CreationMenuLayout.Entry] = [.action(.clipboardImage), .separator]
            + stride(from: 3, to: 80, by: 2).map { .template("template-\($0)") }
        #expect(menu.main.map(\.content) == expectedMain)
        #expect(menu.submenu.map(\.content) == expectedSubmenu)
        let tags = (menu.main + menu.submenu).compactMap(\.tag)
        #expect(tags.count == 80)
        #expect(Set(tags).count == 80)
        for entry in menu.main + menu.submenu {
            if entry.content == .separator {
                #expect(entry.tag == nil)
                continue
            }
            let tag = try #require(entry.tag)
            let captured = registry.takeAction(for: tag)
            let action = try #require(captured)
            #expect(action.directory == directory)
            if case .template(let id) = entry.content { #expect(action.templateID == id) }
            else { #expect(action.templateID == nil) }
            #expect(registry.takeAction(for: tag) == nil)
        }
    }

    @Test("later menu groups preserve current creation tags and retire complete old batches")
    func menuRegistrationLifetime() throws {
        let layout = CreationMenuLayout(preferences: longMenuPreferences())
        let directory = URL(fileURLWithPath: "/tmp/filemint-menu-target", isDirectory: true)
        var registry = FileMenuActionRegistry()
        let menu = registry.registerCreationMenu(layout, directory: directory)
        // Finder adds other feature groups after creation. They must not evict
        // the first creation entries while this menu is still being built.
        for _ in 0..<31 { _ = registry.register([FileMenuAction(directory: directory, templateID: nil)]) }
        for tag in (menu.main + menu.submenu).compactMap(\.tag) {
            #expect(registry.takeAction(for: tag) != nil)
        }

        var bounded = FileMenuActionRegistry(retainingMenus: 2)
        let old = bounded.registerCreationMenu(layout, directory: directory)
        let secondDirectory = directory.appendingPathComponent("second", isDirectory: true)
        let second = bounded.registerCreationMenu(layout, directory: secondDirectory)
        let thirdDirectory = directory.appendingPathComponent("third", isDirectory: true)
        let third = bounded.registerCreationMenu(layout, directory: thirdDirectory)
        for tag in (old.main + old.submenu).compactMap(\.tag) { #expect(bounded.takeAction(for: tag) == nil) }
        for (menu, expectedDirectory) in [(second, secondDirectory), (third, thirdDirectory)] {
            for tag in (menu.main + menu.submenu).compactMap(\.tag) {
                let captured = bounded.takeAction(for: tag)
                let action = try #require(captured)
                #expect(action.directory == expectedDirectory)
            }
        }
    }

    @Test("an empty creation group does not consume registry retention")
    func emptyRegistration() {
        var registry = FileMenuActionRegistry(retainingMenus: 1)
        let action = FileMenuAction(directory: URL(fileURLWithPath: "/tmp/filemint-menu-target"), templateID: "one")
        let tag = registry.register([action])[0]
        var p = preferences()
        p.templates = []
        for action in CreationMenuAction.allCases { p.creationMenuPlacements[action.rawValue] = .hidden }
        let menu = registry.registerCreationMenu(CreationMenuLayout(preferences: p), directory: action.directory)
        #expect(menu.main.isEmpty && menu.submenu.isEmpty)
        #expect(registry.takeAction(for: tag) == action)
    }

    @Test("all 27 action combinations preserve unique ordered entries across both levels")
    func combinations() {
        let positions = CreationMenuPlacement.allCases
        for first in positions { for second in positions { for third in positions {
            for one in positions { for two in positions {
                var p = preferences()
                let actions = [first, second, third]
                for (action, position) in zip(CreationMenuAction.allCases, actions) { p.creationMenuPlacements[action.rawValue] = position }
                p.templateMenuPlacements = ["one": one, "two": two]
                let layout = CreationMenuLayout(preferences: p)
                for (position, entries) in [(CreationMenuPlacement.main, layout.main), (.submenu, layout.submenu)] {
                    let expectedActions: [CreationMenuLayout.Entry] = zip(CreationMenuAction.allCases, actions)
                        .filter { $0.1 == position }.map { .action($0.0) }
                    var expectedTemplates: [CreationMenuLayout.Entry] = []
                    if one == position { expectedTemplates.append(.template("one")) }
                    if two == position { expectedTemplates.append(.template("two")) }
                    let expected = expectedActions + (expectedActions.isEmpty || expectedTemplates.isEmpty ? [] : [.separator]) + expectedTemplates
                    #expect(entries == expected)
                    #expect(entries.first != .separator && entries.last != .separator)
                }
            } }
        } } }
    }

    @Test("hidden and disabled are independent and empty menus have no separators")
    func enabledAndHidden() {
        var p = preferences()
        for action in CreationMenuAction.allCases { p.creationMenuPlacements[action.rawValue] = .hidden }
        p.templateMenuPlacements = ["one": .hidden, "two": .main]
        p.templates[1].isEnabled = false
        #expect(CreationMenuLayout(preferences: p) == CreationMenuLayout(preferences: {
            var empty = p; empty.templates = []; return empty
        }()))
        #expect(TemplateCatalog.enabledTemplates(from: p.templates).map(\.id) == ["one"])
        #expect(TemplateCatalog.defaultTemplate(forExtension: "txt", in: p.templates)?.id == "one")
        p.templates[1].isEnabled = true
        #expect(CreationMenuLayout(preferences: p).main == [.template("two")])
        #expect(CreationMenuLayout(preferences: p).submenu.isEmpty)
        p.templateMenuPlacements["one"] = .main
        p.templates = TemplateCatalog.reorderedTemplates(p.templates, moving: [1], to: 0)
        #expect(CreationMenuLayout(preferences: p).main == [.template("two"), .template("one")])
    }

    @Test("legacy main/submenu settings migrate each action and existing ID", arguments: ["main", "submenu", "unknown"])
    func migration(legacy: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences())) as? [String: Any])
        object.removeValue(forKey: "creationMenuPlacements")
        object.removeValue(forKey: "templateMenuPlacements")
        object["newFileMenuPlacement"] = legacy
        let decoded = try FileMintPreferencesStore.decode(JSONSerialization.data(withJSONObject: object))
        let expected: CreationMenuPlacement = legacy == "main" ? .main : .submenu
        #expect(CreationMenuAction.allCases.allSatisfy { decoded.creationMenuPlacement(for: $0) == expected })
        #expect(decoded.templates.allSatisfy { decoded.templateMenuPlacement(for: $0.id) == expected })
        #expect(decoded.templates == preferences().templates)
        #expect(try FileMintPreferencesStore.decode(JSONEncoder().encode(decoded)) == decoded)
    }

    @Test("malformed entries recover separately while new upgrade presets remain disabled")
    func malformedAndNewPresets() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences())) as? [String: Any])
        object["newFileMenuPlacement"] = "main"
        object["creationMenuPlacements"] = ["newFile": "hidden", "clipboardText": 42, "clipboardImage": "submenu"] as [String: Any]
        object["templateMenuPlacements"] = ["one": "hidden", "two": ["bad": true]] as [String: Any]
        object["removedBuiltInTemplateIDs"] = []
        let decoded = try FileMintPreferencesStore.decode(JSONSerialization.data(withJSONObject: object))
        #expect(decoded.creationMenuPlacement(for: .newFile) == .hidden)
        #expect(decoded.creationMenuPlacement(for: .clipboardText) == .main)
        #expect(decoded.creationMenuPlacement(for: .clipboardImage) == .submenu)
        #expect(decoded.templateMenuPlacement(for: "one") == .hidden)
        #expect(decoded.templateMenuPlacement(for: "two") == .main)
        #expect(decoded.templates.filter { $0.id != "one" && $0.id != "two" }.allSatisfy {
            !$0.isEnabled && decoded.templateMenuPlacement(for: $0.id) == .submenu
        })
        #expect(try FileMintPreferencesStore.decode(JSONEncoder().encode(decoded)) == decoded)
    }

    private func legacyPreferencesData(placement: String, plist: Bool = false) throws -> Data {
        var p = preferences()
        p.templates[1].isEnabled = false
        p.defaultTemplateIDs = ["txt": "one"]
        p.language = .chinese
        p.showMenuBar = false
        p.removedBuiltInTemplateIDs = ["markdown"]
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as? [String: Any])
        object.removeValue(forKey: "creationMenuPlacements")
        object.removeValue(forKey: "templateMenuPlacements")
        object["newFileMenuPlacement"] = placement
        let json = try JSONSerialization.data(withJSONObject: object)
        return plist ? try PropertyListSerialization.data(fromPropertyList: [FileMintAppGroup.preferencesKey: json],
            format: .binary, options: 0) : json
    }

    @Test("new upgrade presets keep submenu across repeated encoding", arguments: ["main", "submenu", "unknown"])
    func newPresetMigrationRoundTrips(legacy: String) throws {
        let first = try FileMintPreferencesStore.decode(legacyPreferencesData(placement: legacy))
        let newTemplates = first.templates.filter { $0.id != "one" && $0.id != "two" }
        #expect(!newTemplates.isEmpty)
        #expect(!first.templates.contains { $0.id == "markdown" })
        #expect(newTemplates.allSatisfy { !$0.isEnabled && first.templateMenuPlacements[$0.id] == .submenu })
        #expect(first.templateMenuPlacement(for: "one") == (legacy == "main" ? .main : .submenu))
        #expect(first.templateMenuPlacement(for: "two") == (legacy == "main" ? .main : .submenu))
        #expect(first.templates.first { $0.id == "two" }?.isEnabled == false)
        #expect(first.defaultTemplateIDs == ["txt": "one"])
        var current = first
        for _ in 0..<3 {
            current = try FileMintPreferencesStore.decode(JSONEncoder().encode(current))
            #expect(current == first)
        }
    }

    @Test("direct store updates preserve migrated positions without the app model", arguments: [false, true])
    func migrationThroughStoreUpdate(plist: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("preferences.json")
        let legacyData = try legacyPreferencesData(placement: "main", plist: plist)
        let store = FileMintPreferencesStore(fileURL: file)
        var expected = try FileMintPreferencesStore.decode(legacyData)
        if plist {
            // Legacy plists enter through explicit settings import. The live
            // store remains JSON; do not weaken its damaged-file recovery rule.
            try store.save(expected)
        } else {
            try legacyData.write(to: file)
        }
        #expect(store.load() == expected)
        #expect(expected.templateMenuPlacements["swift"] == .submenu)
        for index in 0..<3 {
            let key = "fixture-\(index)"
            let bookmark = Data([1, 2, 3, UInt8(index)])
            // FolderAccess.persist uses this direct atomic store update path.
            // Intentionally do not call normalizeCreationMenuPlacements here.
            try store.update { $0.monitoredFolderBookmarks[key] = bookmark }
            expected.monitoredFolderBookmarks[key] = bookmark
            #expect(store.load() == expected)
            #expect(store.load().templateMenuPlacements["swift"] == .submenu)
        }
        try store.save(expected, ifUnchangedFrom: expected)
        #expect(store.load() == expected)
    }

    @Test("copy inherits local placement; package skip retains it and imports use submenu")
    func copyAndImport() throws {
        var p = preferences()
        p.templateMenuPlacements["one"] = .hidden
        p.newFileMenuPlacement = .main
        let copy = TemplateCatalog.copyDraft(p.templates[0], copySuffix: "Copy", id: "copied")
        let copied = TemplateCatalog.preferencesInsertingCopy(copy, after: "one", in: p)
        #expect(copied.templateMenuPlacement(for: copy.id) == .hidden)
        #expect(copied.templates.first { $0.id == copy.id }?.isEnabled == true)
        let assets = DocumentTemplateStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let package = try TemplatePackageCodec.decode(TemplatePackageCodec.encode(templates: [p.templates[0]], defaults: [:], assets: assets))
        let skipped = try TemplateImportPlanner.plan(package, into: p)
        #expect(skipped.preferences == p)
        let imported = try TemplateImportPlanner.plan(package, into: p, choices: ["one": .copy])
        let id = try #require(imported.rows.first?.resultID)
        #expect(imported.preferences.templateMenuPlacement(for: id) == .submenu)
        #expect(imported.preferences.templateMenuPlacement(for: "one") == .hidden)
        #expect(imported.preferences.newFileMenuPlacement == .main)
    }

    @Test("placement cleanup leaves surviving templates and unrelated preferences intact")
    func deletionAndNormalization() {
        var p = preferences()
        p.templateMenuPlacements = ["one": .main, "two": .hidden, "orphan": .main]
        p.templates.removeAll { $0.id == "one" }
        p.fileTools.isEnabled = true
        p.normalizeCreationMenuPlacements()
        #expect(p.templateMenuPlacements == ["two": .hidden])
        #expect(p.fileTools.isEnabled)
    }

    @Test("list markers preserve explicit defaults, disabled fallback and rank ties")
    func defaultMarkers() {
        var p = preferences()
        #expect(TemplateCatalog.effectiveDefaultTemplateIDs(in: p.templates, defaults: [:]) == ["txt": "one"])
        #expect(TemplateCatalog.effectiveDefaultTemplateIDs(in: p.templates, defaults: ["txt": "two"]) == ["txt": "two"])
        p.templates[1].isEnabled = false
        #expect(TemplateCatalog.effectiveDefaultTemplateIDs(in: p.templates, defaults: ["txt": "two"]) == ["txt": "one"])
        p.templates[1].isEnabled = true
        p.templates[0].rank = 20
        p.templates.reverse()
        #expect(TemplateCatalog.effectiveDefaultTemplateIDs(in: p.templates, defaults: ["txt": "missing"]) == ["txt": "one"])
        p.templates[1].fileExtension = "md"
        #expect(TemplateCatalog.effectiveDefaultTemplateIDs(in: p.templates, defaults: [:]) == ["txt": "two", "md": "one"])
    }

    @Test("atomic save conflicts preserve the committed placement and template")
    func failedSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileMintPreferencesStore(fileURL: root.appendingPathComponent("preferences.json"))
        var original = preferences(); original.normalizeCreationMenuPlacements()
        try store.save(original)
        var draft = original
        draft.templates[0].displayName = "Unsaved"
        draft.templateMenuPlacements["one"] = .hidden
        try store.update { $0.showMenuBar = false }
        #expect(throws: FileMintPreferencesStoreError.stalePreferences) { try store.save(draft, ifUnchangedFrom: original) }
        #expect(store.load().templates[0].displayName == "One")
        #expect(store.load().templateMenuPlacement(for: "one") == .submenu)
        #expect(!store.load().showMenuBar)
    }
}
