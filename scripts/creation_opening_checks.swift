import AppKit
import FileMintCore

@MainActor
enum CreationOpeningChecks {
    struct CheckFailure: Error { let message: String }

    private static func check(_ value: Bool, _ message: String) throws {
        if !value { throw CheckFailure(message: message) }
    }

    private static func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<150 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CheckFailure(message: "Timed out waiting for creation/opening")
    }

    private static func application(at url: URL) throws -> CreationApplication {
        let captured = try OpenWithApplicationAccess.capture(url)
        return .init(id: captured.id, hint: .init(bundleIdentifier: captured.bundleIdentifier, displayName: captured.name),
                     url: captured.url, bookmark: captured.bookmark)
    }

    private static func assets(in root: URL) -> DocumentTemplateStore {
        .init(directory: root.appendingPathComponent("assets"),
              bundledDirectory: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OfficeTemplates"))
    }

    private static func received(_ url: URL) async throws {
        let receipt = url.deletingLastPathComponent().appendingPathComponent("receipt.json")
        try await wait { FileManager.default.fileExists(atPath: receipt.path) }
        let actual = try JSONDecoder().decode([URL].self, from: Data(contentsOf: receipt))
        try check(actual == [url], "Native receiver got a different file")
        try FileManager.default.removeItem(at: receipt)
    }

    private static func expect(_ key: TemplateWorkflowText, _ operation: () async throws -> Void) async throws {
        do {
            try await operation()
            throw CheckFailure(message: "Expected opening failure: \(key)")
        } catch let failure as PostCreationActionExecutor.Failure {
            try check(failure.textKey == key, "Incorrect recovery message: \(failure)")
        }
    }

    static func run(root: URL) async throws {
        let receiver = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/TemplateReceiver.app")
        let local = try application(at: receiver)
        var preferences = FileMintPreferences.default
        preferences.creationOpeningEnabled = true
        preferences.creationApplications = [local]
        var gate = CreationOpeningGate(enabled: true)
        let selected = TemplateCreationAction(.openWithApplication, application: local.hint, localApplicationID: local.id)
        func follow(_ action: TemplateCreationAction) -> CreationFollowUp {
            .init(selection: .override(action), template: nil, preferences: preferences, gate: gate)
        }
        let writer = FileCreationService(documentTemplates: assets(in: root))
        var results: [FileCreationResult] = []
        for suffix in ["js", "docx", "xlsx"] {
            let template = TemplateCatalog.builtInTemplates.first { $0.fileExtension == suffix }!
            results.append(try writer.createFile(.init(destinationDirectory: root, template: template)))
        }
        results.append(try writer.createFile(.init(destinationDirectory: root, template: TemplateCatalog.builtInTemplates[0],
            requestedFileName: "binary.bin", fileData: Data([0, 1, 2, 255]))))
        let executor = PostCreationActionExecutor(gate: { gate })
        for result in results {
            let bytes = try Data(contentsOf: result.createdURL)
            let request = follow(selected)
            try check(await executor.complete(result, followUp: request, language: .english, presentFailures: false),
                "Explicit application did not open \(result.contentKind)")
            try await received(result.createdURL)
            try check(try Data(contentsOf: result.createdURL) == bytes, "Opening changed created bytes")
            try check(!(await executor.complete(result, followUp: request, language: .english, presentFailures: false)),
                "Duplicate completion was accepted")
        }
        print("PASS explicit native receiver: JS, DOCX, XLSX, binary and duplicate completion")

        var defaultURLs: [URL] = [], selectedCalls = 0
        let directDefault = PostCreationActionExecutor(gate: { gate }, nativeOpen: { _, _ in selectedCalls += 1 },
            nativeOpenDefault: { defaultURLs.append($0) })
        for result in results {
            try await directDefault.execute(result, action: .init(.openWithDefaultApp), application: nil, followUp: follow(.init(.openWithDefaultApp)))
        }
        try check(defaultURLs == results.map(\.createdURL) && selectedCalls == 0,
            "Default opening filtered content or chose an explicit application")

        // The runner registers only this disposable receiver's unique file type.
        // Existing JS/Office/default associations are never changed by the test.
        let fixture = try writer.createFile(.init(destinationDirectory: root, template: TemplateCatalog.builtInTemplates[0],
            requestedFileName: "Default.filemint-opening-fixture"))
        try await wait { NSWorkspace.shared.urlForApplication(toOpen: fixture.createdURL)?.resolvingSymlinksInPath().path == receiver.resolvingSymlinksInPath().path }
        try check(await executor.complete(fixture, followUp: follow(.init(.openWithDefaultApp)), language: .english, presentFailures: false),
            "Native system-default opening failed")
        try await received(fixture.createdURL)
        print("PASS system-default native receiver: macOS association used without an editor profile")

        let saved = results[0]
        let current = follow(selected)
        var attempts = 0
        let failing = PostCreationActionExecutor(gate: { gate }, nativeOpen: { _, _ in attempts += 1; throw OpenWithError.openFailed },
            nativeOpenDefault: { _ in attempts += 1; throw OpenWithError.openFailed })
        var changed = local; changed.hint.bundleIdentifier = "example.replaced"
        var badBookmark = local; badBookmark.bookmark = Data([0])
        for app in [nil, changed, badBookmark] as [CreationApplication?] {
            let action = TemplateCreationAction(.openWithApplication, application: app?.hint ?? local.hint, localApplicationID: local.id)
            try await expect(.openingApplicationUnavailable) {
                try await failing.execute(saved, action: action, application: app, followUp: current)
            }
        }
        try check(attempts == 0, "Unavailable application reached native dispatch")
        let original = try Data(contentsOf: saved.createdURL)
        let entries = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        for _ in 0..<2 {
            try await expect(.applicationOpenFailed) {
                try await failing.execute(saved, action: selected, application: local, followUp: current)
            }
            try await expect(.defaultApplicationOpenFailed) {
                try await failing.execute(saved, action: .init(.openWithDefaultApp), application: nil, followUp: current)
            }
        }
        try check(attempts == 4 && (try Data(contentsOf: saved.createdURL)) == original, "Retry changed the saved file")
        try check(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == entries, "Retry wrote another file")
        let old = follow(selected)
        gate.commit(enabled: false); let off = follow(selected); gate.commit(enabled: true)
        var reveals = 0
        let guarded = PostCreationActionExecutor(gate: { gate }, nativeOpen: { _, _ in attempts += 1 },
            nativeOpenDefault: { _ in attempts += 1 }, reveal: { _ in reveals += 1 })
        for request in [old, off] { await guarded.complete(saved, followUp: request, language: .english, presentFailures: false) }
        try check(reveals == 2 && attempts == 4, "Off or stale request opened an application")
        try FileManager.default.moveItem(at: saved.createdURL, to: saved.createdURL.appendingPathExtension("original"))
        try Data("replacement".utf8).write(to: saved.createdURL)
        for action in [selected, .init(.openWithDefaultApp)] {
            try await expect(.savedUnavailable) {
                try await guarded.execute(saved, action: action, application: local, followUp: follow(action))
            }
        }
        try check(attempts == 4, "Replaced file reached native dispatch")
        print("PASS failed opening/retry, missing app/bookmark, stale gate and replaced-file guards")
        try await testRoutes(root: root.appendingPathComponent("routes"), application: local)
    }

    private static func views(in root: NSView) -> [NSView] { [root] + root.subviews.flatMap { views(in: $0) } }

    private static func panelCreate(model: PreferencesModel, directory: URL, template: FileTemplate,
                                    name: String, override: TemplateCreationAction.Kind? = nil) throws {
        let controller = CustomFileSavePanelController.shared
        controller.present(in: directory, preferences: model.preferences, templateID: template.id, documentTemplates: model.documentTemplates)
        guard let panel = NSApp.windows.first(where: { $0.identifier?.rawValue == "io.github.daigua.filemint.custom-file" }),
              let root = panel.contentView,
              let nameField = views(in: root).compactMap({ $0 as? NSTextField }).first(where: { $0.isEditable && !($0 is NSComboBox) }),
              let button = views(in: root).compactMap({ $0 as? NSButton }).first(where: { $0.action == NSSelectorFromString("createRequestedFile:") }) else {
            throw CheckFailure(message: "Creation panel controls were unavailable")
        }
        nameField.stringValue = name
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: nameField))
        if let override {
            guard let picker = views(in: root).compactMap({ $0 as? NSPopUpButton }).first(where: { $0.action == NSSelectorFromString("changeCreationAction:") }),
                  let index = TemplateCreationAction.Kind.allCases.firstIndex(of: override) else {
                throw CheckFailure(message: "Creation action control was unavailable")
            }
            picker.selectItem(at: index + 1)
            NSApp.sendAction(picker.action!, to: picker.target, from: picker)
        }
        button.performClick(nil)
    }

    private static func model(in root: URL) async throws -> (PreferencesModel, FileMintPreferencesStore, QuickCreationTicketStore) {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = FileMintPreferencesStore(fileURL: root.appendingPathComponent("preferences.json"))
        let tickets = QuickCreationTicketStore(directory: root.appendingPathComponent("requests"))
        var prefs = FileMintPreferences.default
        prefs.monitoredFolderURLs = [root]; prefs.creationOpeningEnabled = true; prefs.language = .english
        prefs.launchAtLogin = false; prefs.showMenuBar = false; prefs.automaticallyChecksForUpdates = false
        for index in prefs.templates.indices where ["js", "docx", "xlsx"].contains(prefs.templates[index].fileExtension) { prefs.templates[index].isEnabled = true }
        try store.save(prefs)
        let model = PreferencesModel(store: store, documentTemplates: assets(in: root), quickCreationTickets: tickets)
        try await wait { !model.isMutatingTemplates && model.templateRecoveryError == nil }
        return (model, store, tickets)
    }

    private static func save(_ template: FileTemplate, action: TemplateCreationAction, application: CreationApplication?, model: PreferencesModel) async throws {
        try await model.saveType(name: template.displayName, suffix: template.fileExtension, content: template.content, id: template.id,
            suggestedFileName: template.suggestedFileName, customMenuIcon: template.customMenuIcon, action: action, application: application)
    }

    private static func testRoutes(root: URL, application local: CreationApplication) async throws {
        let (model, store, tickets) = try await model(in: root)
        var events: [(URL, TemplateCreationAction.Kind)] = []
        model.postCreationExecutor = PostCreationActionExecutor(gate: { model.openingGate }, nativeOpen: { urls, app in
            try check(model.pendingCreationCount > 0, "Opening lost its pending-work guard")
            try check(app.resolvingSymlinksInPath().path == local.url.resolvingSymlinksInPath().path, "Wrong configured app reached dispatch")
            try await OpenWithApplicationAccess.open(urls, with: app)
            try check(model.pendingCreationCount > 0, "Opening released its pending-work guard before completion")
            events.append((urls[0], .openWithApplication))
        }, nativeOpenDefault: { url in
            try check(model.pendingCreationCount > 0, "Default opening lost its pending-work guard")
            events.append((url, .openWithDefaultApp))
        })
        for suffix in ["js", "docx", "xlsx"] {
            for kind in [TemplateCreationAction.Kind.openWithApplication, .openWithDefaultApp] {
                var template = model.preferences.templates.first { $0.fileExtension == suffix }!
                template.suggestedFileName = "Created.\(suffix)"
                let action = TemplateCreationAction(kind, application: local.hint, localApplicationID: local.id)
                try await save(template, action: action, application: local, model: model)
                template = store.load().templates.first { $0.id == template.id }!
                try check(template.afterCreation?.kind == kind, "Action did not survive saving")
                for route in ["quick", "panel"] {
                    let directory = root.appendingPathComponent("\(route)-\(kind.rawValue)-\(suffix)", isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
                    let count = events.count + 1
                    if route == "quick" {
                        model.handle(url: try tickets.enqueue(directory: directory, templateID: template.id))
                    } else {
                        try panelCreate(model: model, directory: directory, template: template, name: template.suggestedFileName)
                    }
                    try await wait { events.count == count && model.pendingCreationCount == 0 }
                    let event = events.last!, expected = directory.appendingPathComponent(template.suggestedFileName)
                    try check(event.0 == expected && event.1 == kind, "Route used the wrong file or action")
                    try check(!CustomFileSavePanelController.shared.hasActiveDraft, "Successful creation did not close the panel")
                    if kind == .openWithApplication { try await received(expected) }
                    if let document = template.document {
                        try check(try Data(contentsOf: expected) == model.documentTemplates.data(for: document), "Office route changed template bytes")
                    }
                    if route == "quick" {
                        let original = try Data(contentsOf: expected), nextCount = events.count + 1
                        model.handle(url: try tickets.enqueue(directory: directory, templateID: template.id))
                        try await wait { events.count == nextCount && model.pendingCreationCount == 0 }
                        let incremented = directory.appendingPathComponent("Created 2.\(suffix)")
                        try check(events.last?.0 == incremented && events.last?.1 == kind, "Collision opened the original requested name")
                        try check(try Data(contentsOf: expected) == original, "Collision changed the original file")
                        if kind == .openWithApplication { try await received(incremented) }
                    }
                }
            }
        }
        // A panel override must affect this creation without rewriting the template.
        let js = model.preferences.templates.first { $0.fileExtension == "js" }!
        let selected = TemplateCreationAction(.openWithApplication, application: local.hint, localApplicationID: local.id)
        try await save(js, action: selected, application: local, model: model)
        let before = try Data(contentsOf: store.location!)
        let count = events.count + 1
        try panelCreate(model: model, directory: root, template: js, name: "Override.js", override: .openWithDefaultApp)
        try await wait { events.count == count && model.pendingCreationCount == 0 }
        try check(events.last?.1 == .openWithDefaultApp && (try Data(contentsOf: store.location!)) == before,
            "Temporary default override changed the saved application")
        let controller = CustomFileSavePanelController.shared
        let countBeforeCancel = events.count
        controller.present(in: root, preferences: model.preferences, templateID: js.id, documentTemplates: model.documentTemplates)
        guard let panel = NSApp.windows.first(where: { $0.identifier?.rawValue == "io.github.daigua.filemint.custom-file" }),
              let rootView = panel.contentView,
              let cancel = views(in: rootView).compactMap({ $0 as? NSButton }).first(where: { $0.action == NSSelectorFromString("cancelPanel:") }) else {
            throw CheckFailure(message: "Could not cancel the creation panel")
        }
        let beforeCancel = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        cancel.performClick(nil)
        try check(!controller.hasActiveDraft && events.count == countBeforeCancel, "Cancel dispatched an application")
        try check(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == beforeCancel, "Cancel created a file")
        print("PASS 12 saved-action quick/panel routes, 6 collision receipts, pending guards, temporary override and cancel")
    }

    static func runInstalledApplications(root: URL) async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let codePath = environment["FILEMINT_QA_CODE_APP"], let officePath = environment["FILEMINT_QA_OFFICE_APP"] else {
            throw CheckFailure(message: "Supply exact installed editor paths for this opt-in check")
        }
        let code = try application(at: URL(fileURLWithPath: codePath))
        let office = try application(at: URL(fileURLWithPath: officePath))
        let (model, _, tickets) = try await model(in: root)
        var delivered: [URL] = []
        model.postCreationExecutor = PostCreationActionExecutor(gate: { model.openingGate }, nativeOpen: { urls, app in
            try check(model.pendingCreationCount > 0, "Installed app handoff lost its pending-work guard")
            let identifier = try OpenWithApplicationAccess.validatedIdentifier(at: app)
            let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty
            try await OpenWithApplicationAccess.open(urls, with: app)
            delivered += urls
            print("CALLBACK explicit \(identifier), wasRunning=\(wasRunning), file=\(urls[0].lastPathComponent)"); fflush(nil)
        }, nativeOpenDefault: { url in
            let handler = NSWorkspace.shared.urlForApplication(toOpen: url)
            try await OpenWithApplicationAccess.openWithDefaultApplication(url)
            delivered.append(url)
            print("CALLBACK system default \(handler?.lastPathComponent ?? "unknown"), file=\(url.lastPathComponent)"); fflush(nil)
        })
        for (suffix, application, route, name) in [
            ("js", code, "panel", "FileMint-QA-VSCode-Panel.js"),
            ("js", code, "quick", "FileMint-QA-VSCode-Quick.js"),
            ("docx", office, "quick", "FileMint-QA-WPS-Word.docx"),
            ("xlsx", office, "panel", "FileMint-QA-WPS-Excel.xlsx")
        ] {
            var template = model.preferences.templates.first { $0.fileExtension == suffix }!
            template.suggestedFileName = name
            if template.document == nil { template.content = "// FileMint creation and opening check\nconst filemintCheck = true;\n" }
            let action = TemplateCreationAction(.openWithApplication, application: application.hint, localApplicationID: application.id)
            try await save(template, action: action, application: application, model: model)
            let count = delivered.count + 1
            if route == "quick" { model.handle(url: try tickets.enqueue(directory: root, templateID: template.id)) }
            else { try panelCreate(model: model, directory: root, template: template, name: name) }
            try await wait { delivered.count == count && model.pendingCreationCount == 0 }
            try check(delivered.last == root.appendingPathComponent(name), "Installed app received the wrong created path")
        }
        var text = model.preferences.templates.first { $0.fileExtension == "txt" }!
        text.suggestedFileName = "FileMint-QA-SystemDefault.txt"
        text.content = "FileMint system-default opening check.\n"
        try await save(text, action: .init(.openWithDefaultApp), application: nil, model: model)
        let count = delivered.count + 1
        model.handle(url: try tickets.enqueue(directory: root, templateID: text.id))
        try await wait { delivered.count == count && model.pendingCreationCount == 0 }
        try check(delivered.last == root.appendingPathComponent(text.suggestedFileName), "Default app received the wrong path")
        print("FIXTURE \(root.path)"); fflush(nil)
    }
}
