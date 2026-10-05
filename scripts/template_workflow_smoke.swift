import AppKit
import FileMintCore
import SwiftUI

@main @MainActor
final class TemplateWorkflowSmoke: NSObject, NSApplicationDelegate {
    #if !TEMPLATE_RECEIVER
    private var window: NSWindow?
    private var model: PreferencesModel?
    private var fixture: URL?
    #endif
    static func main() {
        let app=NSApplication.shared, delegate=TemplateWorkflowSmoke()
        app.delegate=delegate; app.setActivationPolicy(.accessory); app.run()
        withExtendedLifetime(delegate) {}
    }
    func application(_ app:NSApplication,open urls:[URL]) {
        #if TEMPLATE_RECEIVER
        guard let url=urls.first else { exit(2) }
        do { try JSONEncoder().encode(urls).write(to:url.deletingLastPathComponent().appendingPathComponent("receipt.json"),options:.atomic); exit(0) }
        catch { exit(2) }
        #endif
    }
    func applicationWillTerminate(_ notification: Notification) {
        #if !TEMPLATE_RECEIVER
        cleanup()
        #endif
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        #if !TEMPLATE_RECEIVER
        Task {
            do {
                try await run()
                if ProcessInfo.processInfo.environment["FILEMINT_TEMPLATE_QA_MODE"] == "review-fixes" {
                    print("PASS pre-release fixes: copied compound suffix and native automatic-update deferral")
                    fflush(nil); cleanup(); exit(0)
                }
                print("PASS template workflow: production model, gates, copy/assets, dispatch, receipt identity and native preview cleanup")
                fflush(nil)
                if ProcessInfo.processInfo.environment["FILEMINT_TEMPLATE_QA_MODE"] == "screenshots" {
                    try await renderSnapshots(); exit(0)
                }
                if ProcessInfo.processInfo.environment["FILEMINT_TEMPLATE_QA_MODE"] == "ui" { showUI() }
                else { cleanup(); exit(0) }
            } catch { print("FAIL template workflow: \(error)"); fflush(nil); cleanup(); exit(1) }
        }
        #endif
    }
    #if !TEMPLATE_RECEIVER
    struct CheckFailure:Error { let message:String }
    private func check(_ condition:Bool,_ message:String) throws { if !condition { throw CheckFailure(message:message) } }
    private func wait(_ condition:() -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for:.milliseconds(100))
        }
        throw CheckFailure(message:"Timed out waiting for a fixture callback")
    }
    private func run() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("FileMint-template-qa-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:false)
        fixture=root
        let assets=DocumentTemplateStore(directory:root.appendingPathComponent("assets"),bundledDirectory:Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/OfficeTemplates"))
        let store=FileMintPreferencesStore(fileURL:root.appendingPathComponent("preferences.json"))
        var preferences=FileMintPreferences.default
        preferences.monitoredFolderURLs=[root]; preferences.launchAtLogin=false; preferences.showMenuBar=false
        try store.save(preferences)
        let model=PreferencesModel(store:store,documentTemplates:assets); self.model=model
        try await wait { !model.isMutatingTemplates && model.templateRecoveryError == nil }
        try await testCopiedCompoundSuffix(model: model, store: store, root: root)
        if ProcessInfo.processInfo.environment["FILEMINT_TEMPLATE_QA_MODE"] == "review-fixes" {
            try await testAutomaticUpdateDeferral(model: model, store: store)
            return
        }
        try await testReviewRegressions(model: model, store: store, assets: assets)
        try check(!model.preferences.creationOpeningEnabled && !model.preferences.templatePreviewEnabled,"Feature gates were not off")
        for (opening,preview) in [(false,false),(true,false),(false,true),(true,true)] {
            model.setCreationFeature(opening:opening,preview:preview)
            try check(store.load().creationOpeningEnabled==opening && store.load().templatePreviewEnabled==preview,"Gate persistence")
        }
        let oldGate=model.openingGate.permission, prior=try Data(contentsOf:store.location!)
        try Data("corrupt fixture".utf8).write(to:store.location!)
        model.setCreationFeature(opening:false)
        try check(model.openingGate.permission==oldGate && model.preferences.creationOpeningEnabled,"Failed save changed a committed gate")
        try prior.write(to:store.location!,options:.atomic)
        model.setCreationFeature(opening:true,preview:false)
        let bundled=TemplateCatalog.builtInTemplates.first { $0.document != nil }!
        let source=root.appendingPathComponent("source.docx"); try assets.data(for:bundled.document!).write(to:source)
        let reference=try assets.importDocument(at:source)
        var document=TemplateCatalog.copyDraft(bundled,copySuffix:"source")
        document.document=reference
        model.preferences.templates.append(document); try check(model.save(),"Save source template")
        let copy=TemplateCatalog.copyDraft(document,copySuffix:"Copy")
        let action=TemplateCreationAction(.openWithDefaultApp)
        try await model.saveType(name:copy.displayName,suffix:copy.fileExtension,content:"",id:nil,suggestedFileName:copy.suggestedFileName,
            customMenuIcon:copy.customMenuIcon,copy:copy,sourceID:document.id,action:action)
        let sourceIndex=model.preferences.templates.firstIndex { $0.id==document.id }!
        try check(model.preferences.templates[sourceIndex+1].id==copy.id && model.preferences.templates[sourceIndex+1].document==reference,"Document copy lost identity or reference")
        model.setCreationFeature(opening:false)
        try await model.saveType(name:copy.displayName+" edited",suffix:"docx",content:"",id:copy.id,customMenuIcon:copy.customMenuIcon)
        try check(model.preferences.templates.first { $0.id==copy.id }?.afterCreation==action,"Hidden action was cleared")
        model.removeType(document.id); try await wait { !model.isMutatingTemplates }
        try check(try assets.data(for:reference)==Data(contentsOf:source),"Shared document asset was deleted")
        model.removeType(copy.id); try await wait { !model.isMutatingTemplates }
        do { _=try assets.data(for:reference); throw CheckFailure(message:"Unreferenced document remained") } catch is DocumentTemplateError {}
        try check(model.preferences.openWith.applications.isEmpty,"Creation app was exposed to Finder")
        print("PASS production model: gate combinations, failed save, copy and reference cleanup"); fflush(nil)
        try await testExecutor(root:root)
        print("PASS production executor: native receiver, stale gate, duplicate completion and replacement rejection"); fflush(nil)
        for builtin in TemplateCatalog.builtInTemplates where builtin.document != nil {
            let reference = builtin.document!
            let surface=TemplatePreviewSurface(), previewWindow=NSWindow(contentRect:NSRect(x:0,y:0,width:560,height:360),styleMask:[.titled],backing:.buffered,defer:false)
            previewWindow.isReleasedWhenClosed=false
            previewWindow.contentView=surface; previewWindow.makeKeyAndOrderFront(nil)
            let original=try assets.data(for:reference)
            surface.show(builtin,assets:assets,language:.english,capturedAt:CreationContentResolver.exampleDate)
            try await wait { surface.state=="available" || surface.state=="unavailable" || surface.state=="invalid" }
            try check(surface.state != "invalid","Valid bundled preview was invalid")
            print("Native preview \(reference.kind.rawValue): \(surface.state)"); fflush(nil)
            let snapshot=surface.ownedSnapshotURL
            surface.close(); previewWindow.close()
            if let snapshot { try check(!FileManager.default.fileExists(atPath:snapshot.path),"Preview snapshot leaked") }
            try check(try assets.data(for:reference)==original,"Preview modified the original")
            surface.show(builtin,assets:assets,language:.english,capturedAt:.now)
            surface.close(); try await Task.sleep(for:.milliseconds(250))
            try check(surface.state=="idle" && surface.ownedSnapshotURL==nil,"Stale preview returned after close")
        }
        let missing=TemplatePreviewSurface()
        var damaged=bundled; damaged.document = .init(id:UUID(),kind:.docx,byteCount:1,sha256:String(repeating:"0",count:64))
        missing.show(damaged,assets:assets,language:.chinese,capturedAt:.now)
        try await wait { missing.state=="invalid" }
        missing.close()
        try await testApplicationIcons(model: model, root: root, assets: assets)
        model.setCreationFeature(opening:false,preview:false)
    }
    private func testCopiedCompoundSuffix(model: PreferencesModel, store: FileMintPreferencesStore, root: URL) async throws {
        let original = model.preferences
        let source = FileTemplate(id: "custom-compound", displayName: "Definition", suggestedFileName: "Untitled.d.ts",
            group: "Custom", content: "keep {{fileName}}", rank: 1000, fileExtension: "d.ts")
        model.preferences.templates.append(source)
        try check(model.save(), "Could not prepare compound-suffix template")
        let copy = TemplateCatalog.copyDraft(source, copySuffix: "Copy")
        try await model.saveType(name: copy.displayName, suffix: "md", content: copy.content, id: nil,
            suggestedFileName: copy.suggestedFileName, customMenuIcon: nil, copy: copy, sourceID: source.id)
        let saved = store.load()
        guard let copied = saved.templates.first(where: { $0.id == copy.id }) else {
            throw CheckFailure(message: "Copied template was not persisted")
        }
        try check(copied.suggestedFileName == "Untitled.md" && copied.fileExtension == "md",
                  "Copy retained part of its old compound suffix")
        try check(saved.templates.first { $0.id == source.id }?.suggestedFileName == "Untitled.d.ts",
                  "Copy changed the source template")
        let result = try await Task.detached {
            try FileCreationService().createFile(.init(destinationDirectory: root, template: copied))
        }.value
        try check(result.createdURL.lastPathComponent == "Untitled.md" &&
                  (try String(contentsOf: result.createdURL, encoding: .utf8)) == "keep Untitled.md",
                  "Copied template created the wrong name or content")
        model.preferences = original
        try check(model.save(), "Could not restore isolated copy preferences")
        print("PASS copied compound suffix: production saveType, persisted reload and actual output bytes"); fflush(nil)
    }
    @MainActor private final class UpdateCheckProbe {
        var requests = 0
        var cancellations = 0
        var holdRequest = false
        var modalPreservedSettings = false
        func check() async throws -> AppUpdate? {
            requests += 1
            if holdRequest {
                do { try await Task.sleep(for: .seconds(10)) }
                catch { cancellations += 1; throw error }
            }
            return nil
        }
    }
    private func testAutomaticUpdateDeferral(model: PreferencesModel, store: FileMintPreferencesStore) async throws {
        model.preferences.automaticallyChecksForUpdates = false
        model.preferences.lastUpdateCheckAttempt = nil
        try check(model.save(), "Could not prepare updater fixture preferences")
        let probe = UpdateCheckProbe()
        // Only the metadata transport and startup delay are injected. Timers,
        // native modal detection, preference writes and cancellation are production.
        let updater = UpdateModel(preferencesModel: model, automaticCheckStartupDelay: 0.15) { _ in
            try await probe.check()
        }
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 180),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        parent.title = "FileMint · isolated updater check"
        parent.isReleasedWhenClosed = false; sheet.isReleasedWhenClosed = false
        defer {
            model.setAutomaticallyChecksForUpdates(false)
            if parent.attachedSheet != nil { parent.endSheet(sheet) }
            sheet.orderOut(nil); parent.close()
        }
        parent.makeKeyAndOrderFront(nil)
        parent.beginSheet(sheet, completionHandler: { _ in })
        updater.startAutomaticChecks()
        model.setAutomaticallyChecksForUpdates(true)
        let before = try Data(contentsOf: store.location!)
        let reviewRevision = try TemplateImportPlanner.revision(store.load())
        try await Task.sleep(for: .milliseconds(400))
        try check(probe.requests == 0 && (try Data(contentsOf: store.location!)) == before,
                  "An automatic check started or wrote preferences under an existing sheet")
        try check(try TemplateImportPlanner.revision(store.load()) == reviewRevision,
                  "An automatic check invalidated the import review")
        parent.endSheet(sheet); sheet.orderOut(nil)
        try await wait { probe.requests == 1 && updater.state == .upToDate }
        try check(store.load().lastUpdateCheckAttempt != nil, "Resumed check did not persist its attempt")
        try await Task.sleep(for: .milliseconds(350))
        try check(probe.requests == 1, "Modal dismissal scheduled duplicate checks")

        // Also block a timer that was already armed before the sheet appeared.
        model.setAutomaticallyChecksForUpdates(false)
        model.preferences.lastUpdateCheckAttempt = nil
        try check(model.save(), "Could not reset the isolated cooldown")
        model.setAutomaticallyChecksForUpdates(true)
        try await Task.sleep(for: .milliseconds(40))
        parent.beginSheet(sheet, completionHandler: { _ in })
        let armedBefore = try Data(contentsOf: store.location!)
        try await Task.sleep(for: .milliseconds(350))
        try check(probe.requests == 1 && (try Data(contentsOf: store.location!)) == armedBefore,
                  "An armed timer ignored a newly opened sheet")
        model.setAutomaticallyChecksForUpdates(false)
        parent.endSheet(sheet); sheet.orderOut(nil)
        try await Task.sleep(for: .milliseconds(350))
        try check(probe.requests == 1 && store.load().lastUpdateCheckAttempt == nil,
                  "Disabling automatic checks revived deferred work")

        // App-modal dialogs can order out without NSWindow.willCloseNotification.
        model.setAutomaticallyChecksForUpdates(true)
        try await Task.sleep(for: .milliseconds(40))
        let modal = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        modal.isReleasedWhenClosed = false
        let preferencesURL = store.location!, modalBefore = try Data(contentsOf: preferencesURL)
        let dismissal = Timer(timeInterval: 0.35, repeats: false) { _ in
            MainActor.assumeIsolated {
                probe.modalPreservedSettings = probe.requests == 1 && (try? Data(contentsOf: preferencesURL)) == modalBefore
                NSApp.stopModal(); modal.orderOut(nil)
            }
        }
        RunLoop.main.add(dismissal, forMode: .common)
        NSApp.runModal(for: modal)
        dismissal.invalidate()
        try check(probe.modalPreservedSettings, "An automatic check wrote under an app-modal dialog")
        try await wait { probe.requests == 2 && updater.state == .upToDate }
        modal.close()
        model.setAutomaticallyChecksForUpdates(false)

        // Explicit checks remain available with automatic discovery switched off.
        updater.checkForUpdates()
        try await wait { probe.requests == 3 && updater.state == .upToDate }
        model.preferences.lastUpdateCheckAttempt = nil
        try check(model.save(), "Could not reset the isolated cancellation fixture")
        probe.holdRequest = true
        model.setAutomaticallyChecksForUpdates(true)
        try await wait { probe.requests == 4 && updater.isBusy }
        model.setAutomaticallyChecksForUpdates(false)
        try await wait { probe.cancellations == 1 && !updater.isBusy }
        try check(store.load().lastUpdateCheckAttempt != nil, "Cancellation erased the weekly cooldown")
        print("PASS automatic-update scheduler: existing/new sheets, app-modal order-out, unchanged review, one-shot resume, disable, manual and cancellation"); fflush(nil)
    }
    private func testApplicationIcons(model: PreferencesModel, root: URL, assets: DocumentTemplateStore) async throws {
        let captured = try await Task.detached {
            try OpenWithApplicationAccess.capture(URL(fileURLWithPath: "/System/Applications/TextEdit.app"))
        }.value
        let application = CreationApplication(id: captured.id,
            hint: .init(bundleIdentifier: captured.bundleIdentifier, displayName: captured.name),
            url: captured.url, bookmark: captured.bookmark)
        guard let expected = await CreationApplicationPresentation.icon(for: application) else {
            throw CheckFailure(message: "Selected TextEdit icon unavailable")
        }
        var invalid = application
        invalid.hint.bundleIdentifier = "invalid.editor"
        try check(await CreationApplicationPresentation.icon(for: invalid) == nil,
                  "An invalid local identity supplied an application icon")
        let original = model.preferences
        var preferences = original
        preferences.creationOpeningEnabled = true
        preferences.creationApplications = [application]
        preferences.templates[0].afterCreation = .init(.openWithApplication,
            application: application.hint, localApplicationID: application.id)
        model.preferences = preferences
        try check(model.save(), "Could not prepare selected-app icon fixture")
        let controller = CustomFileSavePanelController.shared
        controller.present(in: root, preferences: preferences, templateID: preferences.templates[0].id,
                           documentTemplates: assets)
        let panel = NSApp.windows.first { $0.identifier?.rawValue == "io.github.daigua.filemint.custom-file" }
        defer { panel?.close(); model.preferences = original; _ = model.save() }
        func button(in view: NSView?) -> NSButton? {
            guard let view else { return nil }
            if let button = view as? NSButton, button.accessibilityIdentifier() == "creation.chooseApplication" { return button }
            return view.subviews.lazy.compactMap { button(in: $0) }.first
        }
        guard let selected = button(in: panel?.contentView) else { throw CheckFailure(message: "Missing selected-app button") }
        try await wait { selected.image?.tiffRepresentation == expected.tiffRepresentation }
        try check(selected.title == application.hint.displayName && !selected.isHiddenOrHasHiddenAncestor,
                  "Saved application did not show its name and native icon")
        model.setCreationFeature(opening: false)
        try check(selected.isHiddenOrHasHiddenAncestor && selected.image == nil, "Disabled opening retained application presentation")
        model.setCreationFeature(opening: true)
        try await wait { selected.image?.tiffRepresentation == expected.tiffRepresentation }
        print("PASS application presentation: native icon/name, invalid-identity fallback, gate hide and restoration"); fflush(nil)
    }
    private func testReviewRegressions(model: PreferencesModel, store: FileMintPreferencesStore, assets: DocumentTemplateStore) async throws {
        let original = model.preferences, before = try Data(contentsOf: store.location!)
        let gate = model.openingGate.permission
        model.isMutatingTemplates = true
        model.setCreationFeature(opening: true)
        let recorded = model.recordUpdateCheckAttempt(Date(timeIntervalSince1970: 1234))
        model.isMutatingTemplates = false
        try check(!recorded && model.preferences == original && model.openingGate.permission == gate,
                  "An ordinary save bypassed the import guard")
        try check(try Data(contentsOf: store.location!) == before, "Busy save changed persisted preferences")
        do {
            try await model.saveType(name: "Invalid app", suffix: "txt", content: "", id: nil,
                customMenuIcon: nil, action: .init(.openWithApplication))
            throw CheckFailure(message: "Missing selected-app identity was saved")
        } catch is TemplateCreationActionError {}
        try check(try Data(contentsOf: store.location!) == before, "Invalid action changed saved templates")

        // A real settings-limit failure must invalidate the old reviewed plan.
        let body = String(repeating: "x", count: 7 * 1024 * 1024)
        let large = (0..<4).map { index in
            FileTemplate(id: "custom-review-\(index)", displayName: "Review \(index)", suggestedFileName: "Review.txt",
                         group: "Custom", content: body, rank: 1000 + index)
        }
        model.preferences.templates += large
        try check(model.save(), "Could not prepare bounded review fixture")
        let small = FileTemplate(id: "custom-reviewed-small", displayName: "Small", suggestedFileName: "Small.txt",
                                 group: "Custom", content: "accepted", rank: 2000)
        let package = try TemplatePackageCodec.decode(TemplatePackageCodec.encode(
            templates: [large[0], small], defaults: [:], assets: assets))
        let initial = try TemplateImportPlanner.plan(package, into: model.committedPreferences)
        let review = TemplatePackageReview(package: package, plan: initial)
        model.packageReview = review
        let reviewBefore = try Data(contentsOf: store.location!)
        review.choices[large[0].id] = .copy
        model.rebuildTemplateReview(review)
        try check(!review.canConfirm, "Old plan remained confirmable during replan")
        try await wait { !review.isPlanning }
        try check(!review.canConfirm && review.message != nil, "Failed replan left an executable old plan")
        await model.confirmTemplateImport(review)
        try check(try Data(contentsOf: store.location!) == reviewBefore, "Failed review committed the old plan")
        review.choices[large[0].id] = .skip
        model.rebuildTemplateReview(review)
        try await wait { !review.isPlanning }
        try check(review.canConfirm && review.plan.acceptedCount == 1, "Corrected review could not be submitted")
        await model.confirmTemplateImport(review)
        try check(model.packageReview == nil && store.load().templates.contains { $0.id == small.id }, "Corrected review was not committed")
        model.preferences = original
        try check(model.save(), "Could not restore isolated fixture preferences")
        print("PASS review regressions: busy-save rollback, invalid app rejection, failed-review blocking and corrected import")
        fflush(nil)
    }
    private func testExecutor(root:URL) async throws {
        var gate=CreationOpeningGate(enabled:false), dispatches=0, reveals=0
        let spy=PostCreationActionExecutor(gate:{ gate },nativeOpen:{ _,_ in dispatches += 1 },reveal:{ _ in reveals += 1 })
        var prefs=FileMintPreferences.default; prefs.creationOpeningEnabled=true
        var template=TemplateCatalog.builtInTemplates[0]; template.afterCreation = .init(.openWithDefaultApp)
        let saved=try FileCreationService().createFile(.init(destinationDirectory:root,template:template))
        let off=CreationFollowUp(template:template,preferences:prefs,gate:gate)
        gate.commit(enabled:true)
        await spy.complete(saved,followUp:off,language:.english)
        try check(dispatches==0 && reveals==1,"Off-origin request acquired launch permission")
        let pending=CreationFollowUp(template:template,preferences:prefs,gate:gate)
        gate.commit(enabled:false); gate.commit(enabled:true)
        await spy.complete(saved,followUp:pending,language:.english)
        try check(dispatches==0 && reveals==2,"Disable/re-enable revived a request")
        let receiver=Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/TemplateReceiver.app")
        let app=try OpenWithApplicationAccess.capture(receiver)
        let local=CreationApplication(id:app.id,hint:.init(bundleIdentifier:app.bundleIdentifier,displayName:app.name),url:app.url,bookmark:app.bookmark)
        prefs.creationApplications=[local]
        template.afterCreation = .init(.openWithApplication,application:local.hint,localApplicationID:local.id)
        let followUp=CreationFollowUp(template:template,preferences:prefs,gate:gate)
        let executor=PostCreationActionExecutor(gate:{ gate },defaultHandler:{ _ in receiver },editingPolicy:{ id,_ in id=="io.github.daigua.filemint.template-receiver" },verifyEditor:{ _,_ in })
        try check(await executor.complete(saved,followUp:followUp,language:.english,presentFailures:false),"Native receiver handoff failed")
        let receipt=root.appendingPathComponent("receipt.json")
        try await wait { FileManager.default.fileExists(atPath:receipt.path) }
        let urls=try JSONDecoder().decode([URL].self,from:Data(contentsOf:receipt))
        try check(urls==[saved.createdURL],"Native receiver received the wrong file")
        try FileManager.default.removeItem(at:receipt)
        await executor.complete(saved,followUp:followUp,language:.english)
        try await Task.sleep(for:.milliseconds(250))
        try check(!FileManager.default.fileExists(atPath:receipt.path),"Duplicate completion dispatched twice")
        let negative=PostCreationActionExecutor(gate:{ gate },nativeOpen:{ _,_ in dispatches += 1 },defaultHandler:{ _ in receiver })
        do { try await negative.execute(saved,action:.init(.openWithDefaultApp),application:nil,followUp:followUp); throw CheckFailure(message:"Unverified default handler dispatched") }
        catch PostCreationActionExecutor.Failure.editorRequired {}
        do { try CreationEditorIdentity.validate(identifier: "com.apple.TextEdit", at: receiver); throw CheckFailure(message: "Forged editor identity accepted") }
        catch PostCreationActionExecutor.Failure.editorRequired {}
        let previous=saved.createdURL.appendingPathExtension("original")
        try FileManager.default.moveItem(at:saved.createdURL,to:previous)
        try Data("replacement".utf8).write(to:saved.createdURL)
        do { try await executor.execute(saved,action:.init(.revealInFinder),application:nil,followUp:followUp); throw CheckFailure(message:"Replaced file opened") }
        catch PostCreationActionExecutor.Failure.savedItemChanged {}
        try check(dispatches==0,"Negative case dispatched")
        // Inspect only the two explicit supported installations; no app discovery.
        for (identifier, path) in [("com.apple.TextEdit", "/System/Applications/TextEdit.app"), ("com.microsoft.VSCode", "/Applications/Visual Studio Code.app")] {
            let url=URL(fileURLWithPath:path)
            if FileManager.default.fileExists(atPath:path) {
                do {
                    try await Task.detached { try CreationEditorIdentity.validate(identifier:identifier,at:url) }.value
                    print("PASS editor signing identity: "+identifier); fflush(nil)
                } catch {
                    if identifier == "com.apple.TextEdit" { throw error }
                    print("BLOCKED editor signing identity: "+identifier+" (installed bundle fails strict validation)"); fflush(nil)
                }
            }
        }
    }
    private func showUI() {
        guard let model,let fixture else { return }
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:760,height:650),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title="FileMint · Template QA (isolated)"; window.isReleasedWhenClosed=false
        window.contentView=NSHostingView(rootView:TemplateQARoot(directory:fixture).environmentObject(model))
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true); self.window=window
    }
    private func cleanup() {
        if ProcessInfo.processInfo.environment["FILEMINT_TEMPLATE_QA_MODE"] != "screenshots", let fixture { try? FileManager.default.removeItem(at:fixture) }
    }
    private func renderSnapshots() async throws {
        guard let model, let fixture else { return }
        let output=fixture.appendingPathComponent("snapshots",isDirectory:true)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:false)
        func save(_ window:NSWindow,_ name:String) throws {
            guard let view=window.contentView else { throw CheckFailure(message:"No view to render") }
            view.layoutSubtreeIfNeeded(); window.display()
            guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else { throw CheckFailure(message:"No native bitmap") }
            view.cacheDisplay(in:view.bounds,to:bitmap)
            let opaque=NSImage(size:view.bounds.size)
            opaque.lockFocus()
            window.backgroundColor.setFill(); NSBezierPath(rect:NSRect(origin:.zero,size:view.bounds.size)).fill()
            bitmap.draw(in:NSRect(origin:.zero,size:view.bounds.size))
            opaque.unlockFocus()
            guard let tiff=opaque.tiffRepresentation, let composite=NSBitmapImageRep(data:tiff),
                  let png=composite.representation(using:.png,properties:[:]) else { throw CheckFailure(message:"No PNG") }
            try png.write(to:output.appendingPathComponent(name+".png"))
        }
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:710,height:660),styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false
        for language in [AppLanguage.english,.chinese] {
            model.preferences.language=language; _=model.save()
            for (opening,preview) in [(false,false),(true,false),(false,true),(true,true)] {
                model.setCreationFeature(opening:opening,preview:preview)
                model.setAppearance(preview ? .dark : .light)
                let name="\(language.rawValue)-\(opening)-\(preview)"
                window.contentView=NSHostingView(rootView:TemplateQARoot(directory:fixture,types:true).environmentObject(model))
                window.makeKeyAndOrderFront(nil)
                try await Task.sleep(for:.milliseconds(450))
                try save(window,"templates-"+name)
                window.contentView=NSHostingView(rootView:TemplateQARoot(directory:fixture).environmentObject(model))
                try await Task.sleep(for:.milliseconds(200))
                try save(window,"settings-"+name)
                CustomFileSavePanelController.shared.present(in:fixture,preferences:model.preferences,documentTemplates:model.documentTemplates)
                try await Task.sleep(for:.milliseconds(200))
                if let panel=NSApp.windows.first(where: { $0.identifier?.rawValue=="io.github.daigua.filemint.custom-file" }) {
                    try save(panel,"creation-"+name); panel.close()
                } else { throw CheckFailure(message:"No creation panel") }
            }
        }
        window.close()
        print("SNAPSHOTS "+output.path); fflush(nil)
    }
    #endif
}

#if !TEMPLATE_RECEIVER
private struct TemplateQARoot:View {
    @EnvironmentObject var model:PreferencesModel
    let directory:URL
    @State var types=false
    var body:some View {
        VStack {
            HStack {
                Button("Creation Behavior") { types=false }
                Button("Templates & Types") { types=true }
                Button("New File") { CustomFileSavePanelController.shared.present(in:directory,preferences:model.preferences,documentTemplates:model.documentTemplates) }
                Spacer()
                Button("Finish QA") { NSApp.terminate(nil) }
            }
            if types { TypesPane(selectionID: "word-document") } else { CreationSettingsPane() }
        }.padding(24).background(FileMintStyle.background).tint(FileMintStyle.accent)
    }
}
#endif
