import AppKit
import CoreMedia
import FileMintCore
import MetalKit
import os
import QuartzCore
import QuickLookUI
import ScreenCaptureKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
func checkFileDrawerCadence(settings: PreferencesModel, favorites: FavoriteLocationsModel, root: URL) async throws {
    func refreshRate(_ screen: NSScreen) -> Double {
        let number = NSDeviceDescriptionKey("NSScreenNumber")
        guard let id = screen.deviceDescription[number] as? NSNumber else { return 0 }
        return CGDisplayCopyDisplayMode(id.uint32Value)?.refreshRate ?? 0
    }
    func failure(_ detail: String) -> NSError {
        NSError(domain: "FileDrawerCadenceQA", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    func wait(_ detail: String, until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw failure(detail) }
            try await Task.sleep(for: .milliseconds(12))
        }
    }
    func percentile(_ values: [TimeInterval], _ fraction: Double) -> String {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return "missing" }
        let index = Int((Double(sorted.count - 1) * fraction).rounded(.up))
        return String(format: "%.2f", sorted[index] * 1_000)
    }

    guard let screen = NSScreen.screens.first(where: { (59...61).contains(refreshRate($0)) }) ?? NSScreen.main else {
        throw failure("The drawer cadence check needs a display")
    }
    let modeHz = refreshRate(screen)
    let fixed60Hz = (59...61).contains(modeHz)
    print("DRAWER DISPLAY modeHz=\(modeHz) maximumFPS=\(screen.maximumFramesPerSecond) backingScale=\(screen.backingScaleFactor)")

    let folder = root.appendingPathComponent("DrawerCadence", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    for index in 1...20 { try Data("Fixture".utf8).write(to: folder.appendingPathComponent("Notes \(index).txt")) }
    try settings.rememberedFileAccess.rememberWriteDirectory(folder, expected: folder)
    var options = FileDrawerPreferences()
    options.enabled = true
    options.shortcut.isEnabled = false
    options.defaultDirectoryPath = folder.resolvingSymlinksInPath().path
    let controller = FileDrawerController(settings: settings, favorites: favorites,
                                          lastLocationKey: UUID().uuidString, reduceMotion: { false })
    defer { controller.panel?.close() }

    func sample(_ label: String, opening: Bool) async throws {
        guard let transition = controller.panel?.contentView?.subviews.compactMap({ $0 as? FileDrawerGenieTransition }).first else {
            throw failure("Missing Genie transition for \(label)")
        }
        let timestamps = OSAllocatedUnfairLock(initialState: [TimeInterval]())
        transition.framePresented = { timestamp in timestamps.withLock { $0.append(timestamp) } }
        defer { transition.framePresented = nil }
        try await wait("Genie did not finish \(label)") { transition.superview == nil }
        let delivered = timestamps.withLock { $0 }
        let presented = delivered.filter { $0 > 0 }.sorted()
        guard presented.count > 2, transition.progress == (opening ? 0 : 1) else {
            throw failure("Genie did not present motion and its endpoint for \(label)")
        }
        let intervals = zip(presented, presented.dropFirst()).map { $1 - $0 }
        print("GENIE \(label) \(Int(transition.bounds.width))x\(Int(transition.bounds.height))pt frames=\(presented.count) intervalP50/P95/max=\(percentile(intervals, 0.5))/\(percentile(intervals, 0.95))/\(percentile(intervals, 1))ms")
        if fixed60Hz {
            // Allow occasional scheduling delays, but catch sustained half-rate presentation.
            let missed = intervals.filter { $0 > 1.5 / modeHz }.count
            guard presented.count >= 23, Double(missed) <= Double(intervals.count) * 0.15 else {
                throw failure("Genie missed the 60 Hz cadence for \(label) (\(missed) long intervals)")
            }
        }
    }

    let supportsGlass = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    for glass in supportsGlass ? [true, false] : [false] {
        options.glass = glass
        guard settings.setFileDrawer(options) else { throw failure("Could not set isolated drawer preferences") }
        for cycle in 1...3 {
            let material = glass ? "glass" : "solid"
            controller.show(on: screen)
            controller.model.pinned = true
            try await sample("\(material)-open-\(cycle)", opening: true)
            try await wait("Fixture files did not load") {
                !controller.model.busy && controller.model.entries.contains { $0.name == "Notes 20.txt" }
            }
            controller.model.close()
            try await sample("\(material)-close-\(cycle)", opening: false)
        }
    }
}

@available(macOS 15, *)
@MainActor
private final class DrawerMovie: NSObject, SCRecordingOutputDelegate {
    var started = false
    var finished = false
    var error: Error?

    nonisolated func recordingOutputDidStartRecording(_ output: SCRecordingOutput) {
        Task { @MainActor in started = true }
    }
    nonisolated func recordingOutputDidFinishRecording(_ output: SCRecordingOutput) {
        Task { @MainActor in finished = true }
    }
    nonisolated func recordingOutput(_ output: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in self.error = error }
    }
}

@MainActor
private final class DrawerLocationsMenuProbe: NSObject {
    let title: String
    private(set) var tracked = false

    init(title: String) { self.title = title }

    @objc func began(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu, menu.title == title else { return }
        tracked = true
        // Dismiss in the menu's own event loop, including on hosts that consume the
        // preposted Escape before AppKit starts tracking the popup.
        let dismiss = Timer(timeInterval: 0.05, target: menu,
                            selector: #selector(NSMenu.cancelTrackingWithoutAnimation), userInfo: nil, repeats: false)
        RunLoop.main.add(dismiss, forMode: .eventTracking)
        RunLoop.main.add(dismiss, forMode: .common)
    }
}

@MainActor
private func checkFileDrawerRootAccess(settings: PreferencesModel, folder: URL) throws {
    func require(_ condition: Bool, _ detail: String) throws {
        guard condition else { throw NSError(domain: "FileDrawerRootQA", code: 1, userInfo: [NSLocalizedDescriptionKey: detail]) }
    }
    let originalFinderScope = settings.committedPreferences.monitoredFolderURLs
    let originalGrants = try settings.rememberedFileAccess.directoryWritePaths()
    let picker = settings.fileDrawerDefaultLocationPanel()
    let defaultTitle = settings.preferences.language.resolved() == .chinese ? "默认抽屉激活位置" : "Default Drawer Location"
    try require(picker.directoryURL?.path == DefaultFolders.resolvedUserHomeDirectory(fileManager: .default).path
                && picker.title == defaultTitle
                && picker.canChooseDirectories && !picker.canChooseFiles && !picker.allowsMultipleSelection,
                "The default-location picker did not start at the home folder")
    let rootPicker = settings.fileDrawerDiskRootPanel()
    try require(rootPicker.directoryURL?.path == "/" && rootPicker.title != picker.title
                && rootPicker.canChooseDirectories && !rootPicker.canChooseFiles && !rootPicker.allowsMultipleSelection,
                "Root authorization did not use a separate native folder picker at /")
    try require(settings.setFileDrawerDefaultLocation(folder), "Could not choose the display location")
    let root = folder.resolvingSymlinksInPath().standardizedFileURL.path
    try require(settings.committedPreferences.fileDrawer.defaultDirectoryPath == root &&
                (try settings.rememberedFileAccess.directoryWritePaths()) == originalGrants,
                "Choosing the default display location saved a permission")
    try require(!settings.authorizeFileDrawerDiskRoot(folder) &&
                (try settings.rememberedFileAccess.directoryWritePaths()) == originalGrants,
                "Root authorization accepted a fixture subfolder in place of /")
    try settings.rememberedFileAccess.rememberWriteDirectory(folder, expected: folder)
    try require(settings.committedPreferences.fileDrawer.defaultDirectoryPath == root &&
                settings.committedPreferences.monitoredFolderURLs == originalFinderScope,
                "Authorizing a folder changed the default or Finder scope")
}

@MainActor
func checkFileDrawer(settings: PreferencesModel, favorites: FavoriteLocationsModel, root: URL) async throws {
    func failure(_ detail: String) -> NSError {
        NSError(domain: "FileDrawerQA", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    func require(_ value: Bool, _ detail: String) throws {
        if !value { throw failure(detail) }
    }
    func wait(_ detail: String, until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            if ContinuousClock.now >= deadline { throw failure(detail) }
            try await Task.sleep(for: .milliseconds(30))
        }
    }
    func views<T: NSView>(of type: T.Type, in view: NSView) -> [T] {
        if let match = view as? T { return [match] }
        return view.subviews.flatMap { views(of: type, in: $0) }
    }

    let folder = root.appendingPathComponent("DrawerFixtures", isDirectory: true)
    let nested = folder.appendingPathComponent("Nested", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    let small = folder.appendingPathComponent("Notes.txt")
    let large = folder.appendingPathComponent("Large.txt")
    try Data("Native drawer fixture".utf8).write(to: small)
    try Data().write(to: large)
    let output = try FileHandle(forWritingTo: large)
    do {
        defer { try? output.close() }
        try output.truncate(atOffset: 50_000_001)
    }
    let fixtureHome = root.appendingPathComponent("DrawerHome", isDirectory: true)
    try FileManager.default.createDirectory(at: fixtureHome, withIntermediateDirectories: true)
    let home = fixtureHome.standardizedFileURL
    let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
    let project = downloads.appendingPathComponent("Project", isDirectory: true)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    let lastLocationKey = "fileDrawer.qa.lastLocation." + UUID().uuidString
    defer { UserDefaults.standard.removeObject(forKey: lastLocationKey) }
    var reduceMotionOverride: Bool?
    let controller = FileDrawerController(settings: settings, favorites: favorites, placeHome: home, lastLocationKey: lastLocationKey,
                                          reduceMotion: { reduceMotionOverride ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion })
    let model = controller.model
    controller.toggleFromShortcut()
    try require(!model.presented, "Disabled drawer was shown")
    try await checkDrawerSettingsControls()
    var prefs = settings.committedPreferences.fileDrawer
    prefs.animation = .slide
    prefs.width = 1_000
    prefs.fitsDisplayWidth = false
    prefs.minimumWidth = 340
    prefs.maximumWidth = 590
    guard settings.setFileDrawer(prefs) else { throw failure(settings.lastError ?? "Could not persist fixture preferences") }
    controller.toggleFromShortcut()
    try await wait("Drawer did not appear") { model.window?.isVisible == true }
    guard let window = model.window, let screen = window.screen else { throw failure("No drawer screen") }
    func drawerKeyEvent(_ key: String, _ code: UInt16, _ flags: NSEvent.ModifierFlags = [.command]) throws -> NSEvent {
        guard let target = model.window,
              let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                  timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: target.windowNumber, context: nil,
                  characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code) else {
            throw failure("Could not create drawer key event: " + key)
        }
        return event
    }
    func sendWindowKey(_ key: String, _ code: UInt16, _ flags: NSEvent.ModifierFlags = [.command]) throws {
        guard let target = model.window else { throw failure("Missing drawer window for " + key) }
        let event = try drawerKeyEvent(key, code, flags)
        try require(target.performKeyEquivalent(with: event),
                    "Drawer did not handle \(key) (key window: \(target.isKeyWindow), presented: \(model.presented))")
    }
    func captureDrawer(_ mode: String) throws {
        guard let view = window.contentView else { throw failure("Drawer has no content") }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw failure("Drawer has no layout") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw failure("Could not encode drawer view") }
        try data.write(to: root.appendingPathComponent("drawer-" + mode + ".png"))
    }
    model.pinned = true
    try require(model.directory == nil && window.attachedSheet == nil &&
                settings.committedPreferences.fileDrawer.defaultDirectoryPath == nil,
                "Enabling an unconfigured drawer opened a directory or requested broad access")
    try await wait("Right edge was not docked at the constrained width") {
        abs(window.frame.width - min(screen.visibleFrame.width - 12, 590)) < 1 &&
        abs(window.frame.maxX - screen.visibleFrame.maxX) < 20 &&
        abs(window.frame.midY - screen.visibleFrame.midY) <= 1 &&
        window.frame.height < screen.visibleFrame.height
    }
    guard let container = window.contentView,
          let backdrop = views(of: NSVisualEffectView.self, in: container).first(where: {
              $0.blendingMode == .behindWindow && $0.material == .popover
          }) else {
        throw failure("Floating panel has no system backdrop")
    }
    let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    try require(backdrop.isHidden == reduced && backdrop.alphaValue == 1, "Default panel material or transparency is incorrect")
    prefs = settings.committedPreferences.fileDrawer
    prefs.side = .left
    prefs.width = 0
    prefs.fitsDisplayHeight = false
    prefs.height = 511
    prefs.glass = false
    try require(settings.setFileDrawer(prefs), "Could not save left edge")
    try await wait("Left drawer did not apply its centered fixed height and minimum width") {
        abs(window.frame.width - min(screen.visibleFrame.width - 12, 340)) < 1 &&
        abs(window.frame.height - min(screen.visibleFrame.height - 12, 511)) <= 1 &&
        abs(window.frame.midY - screen.visibleFrame.midY) <= 1 &&
        abs(window.frame.minX - screen.visibleFrame.minX) < 20 && backdrop.isHidden
    }
    prefs = settings.committedPreferences.fileDrawer
    prefs.fitsDisplayHeight = true
    try require(settings.setFileDrawer(prefs), "Could not restore adaptive height")
    try await wait("Adaptive height did not restore independently of width") {
        let height = min(screen.visibleFrame.height - 12, min(1_100, max(480, (screen.visibleFrame.height * 0.72).rounded())))
        return abs(window.frame.height - height) <= 1 && abs(window.frame.midY - screen.visibleFrame.midY) <= 1 &&
            settings.committedPreferences.fileDrawer.height == 511 && !settings.committedPreferences.fileDrawer.fitsDisplayWidth
    }

    try await press("drawer.place.downloads")
    try await wait("First click did not request access to Downloads") { window.attachedSheet is NSOpenPanel }
    guard let firstPicker = window.attachedSheet as? NSOpenPanel else { throw failure("No Downloads picker") }
    try require(firstPicker.directoryURL?.standardizedFileURL.path == downloads.path, "Place picker targeted a different directory")
    firstPicker.cancel(nil)
    try await wait("Cancelling Downloads changed the listing") { !model.interacting && model.directory == nil }
    try settings.rememberedFileAccess.rememberWriteDirectory(downloads, expected: downloads)
    try sendWindowKey("1", 18)
    try await wait("Saved place access did not open Downloads itself") { model.directory?.path == downloads.path && model.activePlace == .downloads }
    model.navigate(project)
    try await wait("Could not open a child of Downloads") { model.directory?.path == project.path && model.activePlace == .downloads && !model.busy }
    try await press("drawer.find")
    try await wait("Search did not take focus before the location shortcut") { window.firstResponder is NSTextView }
    model.query = "previous query"
    try sendWindowKey("1", 18)
    try await wait("Command-1 from search did not return to Downloads and clear the filter") {
        model.directory?.path == downloads.path && model.query.isEmpty
    }
    try await wait("Narrow drawer did not return to the file browser") {
        !model.placesVisible && axElement("drawer.place.downloads") == nil && axElement("drawer.path.copy") != nil
    }
    try sendWindowKey("l", 37)
    try await wait("Command-L did not expand the narrow locations list") {
        model.placesVisible && axElement("drawer.place.downloads") != nil && axElement("drawer.path.copy") != nil
    }
    try require(axElement("drawer.places.switch") == nil && axElement("drawer.placeChooser.search") == nil,
                "Locations still displays a search command")
    try await press("drawer.places.add")
    try await wait("Add Folder did not offer a folder picker") { window.attachedSheet is NSOpenPanel }
    guard let addPicker = window.attachedSheet as? NSOpenPanel, addPicker.canChooseDirectories, !addPicker.canChooseFiles else {
        throw failure("Sidebar add did not restrict its picker to folders")
    }
    addPicker.cancel(nil)
    try await wait("Cancelling Add Folder did not leave the drawer ready") { !model.interacting }
    await model.addSidebarFolder(project)
    guard let favoriteID = favorites.catalog.items.first(where: { $0.url.path == project.path && $0.kind == .folder })?.id else {
        throw failure("Adding a sidebar folder did not persist it in Favorite Locations")
    }
    try await press("drawer.place.favorite." + favoriteID.uuidString)
    try await wait("Clicking a saved sidebar folder did not open it") { model.directory?.path == project.path && !model.busy }
    window.makeKeyAndOrderFront(nil)
    try await wait("Drawer did not regain keyboard focus after the Add Folder interaction") { window.isKeyWindow }
    try sendWindowKey("1", 18)
    try await wait("Window shortcut did not return to Downloads") { model.directory?.path == downloads.path && !model.busy }
    try require(!model.placesVisible, "Direct location shortcut expanded the collapsed sidebar")
    let locationsMenu = model.makePlacesMenu()
    let chinese = settings.preferences.language.resolved() == .chinese
    try require(Array(locationsMenu.items.prefix(12).map(\.title)) == FileDrawerPlace.allCases.map { $0.title(chinese) },
                "Go to Location menu omitted or reordered standard destinations")
    let probe = DrawerLocationsMenuProbe(title: locationsMenu.title)
    NotificationCenter.default.addObserver(probe, selector: #selector(DrawerLocationsMenuProbe.began(_:)),
                                           name: NSMenu.didBeginTrackingNotification, object: nil)
    defer { NotificationCenter.default.removeObserver(probe) }
    NSApp.postEvent(try drawerKeyEvent("\u{1b}", 53, []), atStart: true)
    try sendWindowKey("0", 29)
    try require(probe.tracked && !model.placesVisible && model.directory?.path == downloads.path,
                "Command-0 failed to track a native menu or changed the directory on cancellation")
    guard let favoriteIndex = locationsMenu.items.firstIndex(where: { $0.toolTip == project.path }) else {
        throw failure("Go to Location menu omitted the saved custom folder")
    }
    locationsMenu.performActionForItem(at: favoriteIndex)
    try await wait("Native menu could not navigate to the custom folder") { model.directory?.path == project.path && !model.busy }
    try FileManager.default.createDirectory(at: model.placeURL(.library), withIntermediateDirectories: true)
    guard let libraryIndex = locationsMenu.items.firstIndex(where: { $0.toolTip == model.placeURL(.library).path }) else {
        throw failure("Library entry missing from Go to Location")
    }
    locationsMenu.performActionForItem(at: libraryIndex)
    try await wait("Library menu action did not check its own folder grant") { window.attachedSheet is NSOpenPanel }
    guard let libraryPicker = window.attachedSheet as? NSOpenPanel else { throw failure("Library picker missing") }
    try require(libraryPicker.directoryURL?.standardizedFileURL.path == model.placeURL(.library).path,
                "Library menu action requested a different folder")
    libraryPicker.cancel(nil)
    try await wait("Cancelling location access did not preserve the current folder") { !model.interacting && model.directory?.path == project.path }
    try sendWindowKey("1", 18)
    try await wait("Could not return from location menu scenarios") { model.directory?.path == downloads.path && !model.busy }
    model.up()
    try await wait("Leaving a grant boundary did not request the parent") { window.attachedSheet is NSOpenPanel }
    guard let parentPicker = window.attachedSheet as? NSOpenPanel else { throw failure("No parent picker") }
    try require(parentPicker.directoryURL?.standardizedFileURL.path == home.path, "Parent picker targeted the wrong directory")
    parentPicker.cancel(nil)
    try await wait("Cancelling Parent Folder lost the current location") { !model.interacting && model.directory?.path == downloads.path }
    try settings.rememberedFileAccess.rememberWriteDirectory(home, expected: home)
    model.up()
    try await wait("Parent Folder did not open the separately authorized parent") { model.directory?.path == home.path && model.activePlace == .home }
    try require(settings.forgetDirectoryWriteAccess(path: home.path, legacy: false), "Could not forget the synthetic home grant")
    try await wait("Revoked place access still allowed browsing") { model.directory == nil && !model.canBack }
    try require(settings.forgetDirectoryWriteAccess(path: downloads.path, legacy: false), "Could not forget the Downloads grant")
    try checkFileDrawerRootAccess(settings: settings, folder: folder)
    try await wait("Saved drawer root did not show the expected listing") {
        Set(model.entries.map(\.name)) == ["Notes.txt", "Large.txt", "Nested"]
    }
    try captureDrawer("compact")
    var wide = settings.committedPreferences.fileDrawer
    let narrow = wide
    wide.width = 550
    try require(settings.setFileDrawer(wide), "Could not show the named sidebar")
    try await wait("Wide size change lost the user's collapsed sidebar state") {
        window.frame.width >= 500 && !model.placesVisible && axElement("drawer.place.downloads") == nil
    }
    try await press("drawer.places.toggle")
    try await wait("Named sidebar did not appear at normal width") {
        guard model.placesVisible, axElement("drawer.path.full") != nil, axElement("drawer.place.downloads") != nil,
              let list = views(of: NSCollectionView.self, in: container).first,
              list.numberOfItems(inSection: 0) > 0,
              let width = list.enclosingScrollView?.contentSize.width,
              let first = list.collectionViewLayout?.layoutAttributesForItem(at: IndexPath(item: 0, section: 0)) else { return false }
        return abs(first.size.width - width) <= 1
    }
    try captureDrawer("labeled")

    let accent = settings.preferenceBinding(\.accentColor)
    let originalAccent = accent.wrappedValue
    if let first = model.visibleEntries.first,
       let collection = views(of: NSCollectionView.self, in: container).first {
        let index = IndexPath(item: 0, section: 0)
        model.selection = [first.url]
        try await wait("Drawer did not display the selected row") { collection.selectionIndexPaths == [index] }
        guard let row = collection.item(at: index), let icon = views(of: NSImageView.self, in: row.view).first,
              let originalTint = icon.contentTintColor, let originalFill = row.view.layer?.backgroundColor else {
            throw failure("Selected drawer row has no tint or fill")
        }
        accent.wrappedValue = originalAccent == .blue ? .purple : .blue
        try await wait("Changing the accent did not repaint the open drawer") {
            icon.contentTintColor != originalTint && row.view.layer?.backgroundColor != originalFill
        }
        try require(collection.item(at: index) === row && collection.selectionIndexPaths == [index] && model.selection == [first.url],
                    "Changing the accent replaced or deselected the active row")
        accent.wrappedValue = originalAccent
    } else { throw failure("Missing drawer row for accent repaint") }

    // Activate actions through the drawer and through the actual Command-K menu fallback.
    func actionSearch() async throws -> (NSSearchField, NSTextView) {
        func input() -> NSSearchField? {
            views(of: NSSearchField.self, in: container).first { $0.accessibilityIdentifier() == "drawer.actionSearch" }
        }
        try await wait("Selection actions did not focus their search field") {
            model.actionPalette != nil && input()?.currentEditor() != nil
        }
        guard let field = input(), let editor = field.currentEditor() as? NSTextView, window.firstResponder === editor else {
            throw failure("Action search does not own the field editor")
        }
        return (field, editor)
    }
    func filterActions(_ input: NSSearchField, _ text: String) {
        input.stringValue = text
        input.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: input))
    }
    func actionKey(_ command: Selector, _ input: NSSearchField, _ editor: NSTextView) throws {
        try require(input.delegate?.control?(input, textView: editor, doCommandBy: command) == true,
                    "Action search did not handle its editing command")
    }
    model.selection = []
    try sendWindowKey("k", 40)
    try require(model.actionPalette == nil, "Command-K opened an action panel with no selection")
    guard let targetFolder = model.entries.first(where: { $0.name == "Nested" }),
          let targetFile = model.entries.first(where: { $0.name == "Notes.txt" }),
          let secondFile = model.entries.first(where: { $0.name == "Large.txt" }),
          let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil, characters: "k",
                                     charactersIgnoringModifiers: "k", isARepeat: false, keyCode: 40) else {
        throw failure("Missing action fixtures")
    }
    model.selection = [targetFolder.url]
    try require(FileDrawerController.handleFavoriteMenuKey(key), "File menu did not dispatch its key to the active drawer")
    var (actionField, actionEditor) = try await actionSearch()
    try captureDrawer("actions")
    filterActions(actionField, "no-such-action")
    try await wait("Missing empty action state") { axElement("drawer.noMatchingActions") != nil }
    try actionKey(#selector(NSResponder.insertNewline(_:)), actionField, actionEditor)
    try require(model.actionPalette != nil, "Return activated a hidden action")
    filterActions(actionField, "模板")
    try await wait("Action search did not filter to template creation") {
        axElement("drawer.action.newFileInFolder") != nil && axElement("drawer.action.open") == nil
    }
    filterActions(actionField, "")
    try actionKey(#selector(NSResponder.moveDown(_:)), actionField, actionEditor)
    try actionKey(#selector(NSResponder.moveDown(_:)), actionField, actionEditor)
    try actionKey(#selector(NSResponder.insertNewline(_:)), actionField, actionEditor)
    let creationController = CustomFileSavePanelController.shared
    try await wait("Folder action did not open a template draft targeting the selected child") {
        guard let draft = creationController.externalWindow, draft.isVisible, let view = draft.contentView else { return false }
        return model.actionPalette == nil && views(of: NSPopUpButton.self, in: view).contains { $0.toolTip == targetFolder.url.path }
    }
    creationController.externalWindow?.close()
    try await wait("Cancelling the folder draft lost the original drawer") {
        model.directory == targetFolder.url.deletingLastPathComponent() && !model.busy && model.draftWindow == nil
    }
    try require(try FileManager.default.contentsOfDirectory(atPath: targetFolder.url.path).isEmpty,
                "Opening a folder's creation action wrote a file")
    model.selection = [targetFolder.url]
    try sendWindowKey("k", 40)
    _ = try await actionSearch()
    try sendWindowKey("o", 31)
    try await wait("The action panel's Open shortcut did not enter its selected folder") {
        model.actionPalette == nil && model.directory == targetFolder.url && !model.busy
    }
    model.up()
    try await wait("Could not return from the action panel's Open command") {
        model.directory?.path == targetFolder.url.deletingLastPathComponent().path && !model.busy
    }
    try await checkDrawerApplicationPicker()
    model.selection = [targetFile.url, secondFile.url]
    try await press("drawer.actions")
    (actionField, actionEditor) = try await actionSearch()
    try require(axElement("drawer.action.rename") == nil && axElement("drawer.action.newFileInFolder") == nil,
                "Multi-selection offered a single-item action")
    try actionKey(#selector(NSResponder.cancelOperation(_:)), actionField, actionEditor)
    try await wait("Escape dismissed the drawer or lost the selection") {
        model.actionPalette == nil && model.presented && window.firstResponder is NSCollectionView
            && model.selection == [targetFile.url, secondFile.url]
    }
    model.selection = [targetFile.url]
    try sendWindowKey("k", 40)
    (actionField, actionEditor) = try await actionSearch()
    let retained = folder.appendingPathComponent(".original-for-action-check")
    try FileManager.default.moveItem(at: targetFile.url, to: retained)
    try Data("replacement".utf8).write(to: targetFile.url, options: .withoutOverwriting)
    filterActions(actionField, "重命名")
    try actionKey(#selector(NSResponder.insertNewline(_:)), actionField, actionEditor)
    try await wait("A stale action used the same-name replacement") {
        model.actionPalette == nil && !model.busy && model.renamingEntry == nil &&
            model.message == model.errorText(FileMoveError.sourceChanged)
    }
    try FileManager.default.removeItem(at: targetFile.url)
    try FileManager.default.moveItem(at: retained, to: targetFile.url)
    model.refresh()
    try await wait("Action fixtures did not refresh") { !model.busy && model.entries.contains { $0.isSameItem(as: targetFile) } }

    // Exercise the picker with the QA bundle itself as an explicitly configured app.
    // Native document delivery is checked separately with the signed Open With receiver.
    func checkDrawerApplicationPicker() async throws {
        let previous = settings.committedPreferences.openWith
        let fixtureApp = try OpenWithApplicationAccess.capture(Bundle.main.bundleURL)
        settings.preferences.openWith.add(fixtureApp)
        try require(settings.save(), "Could not configure the fixture application")
        model.selection = [targetFile.url, targetFolder.url]

        func enterApps() async throws -> (NSSearchField, NSTextView) {
            let (input, editor) = try await actionSearch()
            filterActions(input, "open with")
            try actionKey(#selector(NSResponder.insertNewline(_:)), input, editor)
            func search() -> NSSearchField? {
                views(of: NSSearchField.self, in: container).first { $0.accessibilityIdentifier() == "drawer.openWithSearch" }
            }
            try await wait("Open With did not focus its app search or include the configured candidate") {
                model.applicationList?.candidates?.contains { $0.name == fixtureApp.name } == true &&
                    search()?.currentEditor() != nil && search()?.currentEditor() === window.firstResponder
            }
            guard let search = search(), let editor = search.currentEditor() as? NSTextView else {
                throw failure("Open With search has no native field editor")
            }
            return (search, editor)
        }

        try sendWindowKey("k", 40)
        var (appField, appEditor) = try await enterApps()
        try captureDrawer("open-with")
        try sendWindowKey("o", 31)
        try require(model.applicationList != nil && model.selection == [targetFile.url, targetFolder.url],
                    "An action shortcut dispatched a previous-page command")
        filterActions(appField, "no-matching-fixture-app")
        try await wait("App filtering did not show the empty state") { axElement("drawer.openWithEmpty") != nil }
        try actionKey(#selector(NSResponder.insertNewline(_:)), appField, appEditor)
        try require(window.attachedSheet == nil, "Unmatched app query activated an unintended choice")
        try actionKey(#selector(NSResponder.moveDown(_:)), appField, appEditor)
        try actionKey(#selector(NSResponder.insertNewline(_:)), appField, appEditor)
        try await wait("Other Application did not show a native picker") { window.attachedSheet is NSOpenPanel }
        guard let picker = window.attachedSheet as? NSOpenPanel, picker.allowedContentTypes.contains(.applicationBundle),
              !picker.canChooseDirectories && !picker.allowsMultipleSelection else {
            throw failure("Other Application picker did not restrict its choice to one app")
        }
        picker.cancel(nil)
        try await wait("Cancelling Other Application lost the current app query") {
            window.attachedSheet == nil && model.applicationList != nil && !model.interacting &&
                appField.stringValue == "no-matching-fixture-app"
        }
        guard window.makeFirstResponder(appField), let returnedEditor = appField.currentEditor() as? NSTextView else {
            throw failure("App search was unavailable after cancelling the picker")
        }
        try actionKey(#selector(NSResponder.cancelOperation(_:)), appField, returnedEditor)
        _ = try await actionSearch()
        try require(model.applicationList == nil && model.actionPalette != nil, "Escape did not return from apps to actions")

        (appField, appEditor) = try await enterApps()
        filterActions(appField, fixtureApp.name)
        try await wait("App name filter hid the known application") { axElement("drawer.openWithCandidate") != nil }
        guard let page = model.applicationList, let app = page.candidates?.first(where: { $0.name == fixtureApp.name }) else {
            throw failure("Missing configured application on reopened picker")
        }
        model.selection = [targetFile.url]
        try require(model.applicationList == nil && model.actionPalette == nil, "Selecting a different item retained stale applications")
        model.openWithApplication(app, page: page.id)
        try require(!FileOperationCoordinator.shared.isBusy && model.applicationList == nil, "Obsolete app row started an open")
        settings.preferences.openWith = previous
        try require(settings.save(), "Could not restore the fixture app registry")
    }
    guard let narrowList = views(of: NSCollectionView.self, in: container).first,
          let sidebarFileWidth = narrowList.enclosingScrollView?.contentSize.width else { throw failure("No sized file list") }
    try sendWindowKey("l", 37)
    try await wait("Hiding the wide sidebar did not reclaim its width for files") {
        guard !model.placesVisible, axElement("drawer.place.downloads") == nil, axElement("drawer.path.copy") != nil,
              let list = views(of: NSCollectionView.self, in: container).first,
              let width = list.enclosingScrollView?.contentSize.width else { return false }
        return width > sidebarFileWidth + 80
    }
    try require(settings.setFileDrawer(narrow), "Could not restore compact sidebar")
    guard let nestedEntry = model.entries.first(where: { $0.name == "Nested" }) else { throw failure("Missing subdirectory") }
    model.navigate(nestedEntry.url)
    try await wait("Nested directory did not open") { model.directory == nestedEntry.url && model.canUp }
    // The drawer is entered through the browser, then its New File action
    // hands this exact child directory to the ordinary native creation panel.
    model.pinned = false
    window.makeKeyAndOrderFront(nil)
    try await wait("Unpinned drawer could not take focus before New File") { window.isKeyWindow }
    let originalRoot = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
    let originalParent = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    try await press("drawer.find")
    try await wait("Search could not take focus before window commands") { window.firstResponder is NSTextView }
    try sendWindowKey("P", 35, [.command, .shift])
    try require(model.pinned, "Pin shortcut failed from the search field")
    try sendWindowKey("P", 35, [.command, .shift])
    try sendWindowKey("n", 45)
    guard let draft = CustomFileSavePanelController.shared.externalWindow, draft.isVisible,
          let content = draft.contentView,
          let destination = views(of: NSPopUpButton.self, in: content).first(where: {
              $0.toolTip == nestedEntry.url.path
          }),
          destination.selectedItem != nil,
          let name = views(of: NSTextField.self, in: content).first(where: { $0.isEditable && !($0 is NSComboBox) }),
          let editor = views(of: NSTextView.self, in: content).first(where: { $0.isEditable && !$0.isFieldEditor }),
          let create = views(of: NSButton.self, in: content).first(where: {
              $0.action == NSSelectorFromString("createRequestedFile:")
          }) else { throw failure("New File did not open the native draft at the selected subfolder") }
    try await wait("Creation did not finish validating the destination") { create.isEnabled }
    controller.toggleFromShortcut()
    try require(window.isVisible && model.presented && draft.isVisible, "Draft focus or shortcut dismissed the unpinned drawer")
    let filename = "from-file-drawer.txt"
    let expectedContent = "Drawer-created text · 原生创建验收"
    _ = draft.makeFirstResponder(editor)
    name.stringValue = filename
    editor.insertText(expectedContent, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
    try require(editor.string == expectedContent, "Draft text could not be entered")
    try require(try FileManager.default.contentsOfDirectory(atPath: nestedEntry.url.path).isEmpty,
                "Presentation or editing wrote a file")
    create.performClick(nil)
    try await wait("Create did not finish or open the file list again") {
        !draft.isVisible && !model.busy && model.entries.map(\.name) == [filename]
    }
    let saved = nestedEntry.url.appendingPathComponent(filename)
    try require(try Data(contentsOf: saved) == Data(expectedContent.utf8), "Created bytes differ from draft content")
    try require(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == originalRoot,
                "Create changed the configured default folder")
    try require(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == originalParent,
                "Create changed the parent of the selected folder")

    func renameField() -> NSTextField? {
        guard let content = window.contentView else { return nil }
        return views(of: NSTextField.self, in: content).first { $0.accessibilityIdentifier() == "drawer.renameField" }
    }
    func startRename() async throws -> (NSTextField, NSTextView) {
        model.rename()
        try await wait("Filename did not become editable in its cell") {
            window.attachedSheet == nil && renameField()?.currentEditor() is NSTextView
        }
        guard let field = renameField(), let editor = field.currentEditor() as? NSTextView,
              window.firstResponder === editor else { throw failure("Inline filename editor did not own keyboard focus") }
        return (field, editor)
    }
    func sendRenameCommand(_ command: Selector, field: NSTextField, editor: NSTextView) throws {
        try require(field.delegate?.control?(field, textView: editor, doCommandBy: command) == true,
                    "Inline editor did not handle its editing command")
    }
    guard let originalEntry = model.entries.first(where: { $0.name == filename }) else { throw failure("Created row missing") }
    model.selection = [originalEntry.url]
    let (cancelField, cancelEditor) = try await startRename()
    try require(cancelEditor.selectedRange() == NSRange(location: 0, length: ("from-file-drawer" as NSString).length),
                "Rename selected the extension along with the basename")
    controller.toggleFromShortcut()
    try require(window.isVisible && window.firstResponder === cancelEditor, "Global shortcut interrupted rename")
    try sendWindowKey("n", 45)
    try sendWindowKey("w", 13)
    try require(!CustomFileSavePanelController.shared.hasActiveDraft && model.presented && window.firstResponder === cancelEditor,
                "A window or application command interrupted inline rename")
    cancelEditor.insertText("discard", replacementRange: cancelEditor.selectedRange())
    try sendRenameCommand(#selector(NSResponder.cancelOperation(_:)), field: cancelField, editor: cancelEditor)
    try await wait("Cancelling rename closed or blocked the drawer") { window.isVisible && renameField() == nil && !model.interacting }
    try require(try Data(contentsOf: saved) == Data(expectedContent.utf8), "Cancelled inline rename changed the file")

    let occupied = nestedEntry.url.appendingPathComponent("occupied.txt")
    let occupiedBytes = Data("keep".utf8)
    try occupiedBytes.write(to: occupied, options: .withoutOverwriting)
    let (submitField, submitEditor) = try await startRename()
    submitEditor.insertText("occupied.txt", replacementRange: NSRange(location: 0, length: (submitEditor.string as NSString).length))
    try sendRenameCommand(#selector(NSResponder.insertNewline(_:)), field: submitField, editor: submitEditor)
    try await wait("Collision did not restore the inline editor") {
        !model.busy && model.message != nil && model.interacting && submitEditor.isEditable
    }
    try require(submitEditor.string == "occupied.txt" && window.firstResponder === submitEditor &&
                (try Data(contentsOf: occupied)) == occupiedBytes && (try Data(contentsOf: saved)) == Data(expectedContent.utf8),
                "Rename collision lost the draft, the source, or the occupied file")
    let renamed = nestedEntry.url.appendingPathComponent("renamed-note.txt")
    submitEditor.insertText(renamed.lastPathComponent, replacementRange: NSRange(location: 0, length: (submitEditor.string as NSString).length))
    try require(submitEditor.string == renamed.lastPathComponent, "Could not replace the colliding name in the editor")
    try sendRenameCommand(#selector(NSResponder.insertNewline(_:)), field: submitField, editor: submitEditor)
    try await wait("Inline rename did not refresh and select the renamed file") {
        !model.busy && !model.interacting && model.selection == [renamed] && renameField() == nil
    }
    guard let created = model.selectedEntries.first else { throw failure("Renamed row is missing") }
    try require(try Data(contentsOf: renamed) == Data(expectedContent.utf8) && !FileManager.default.fileExists(atPath: saved.path),
                "Committed inline rename changed file bytes or left its original name")
    guard let stale = model.entries.first(where: { $0.url == occupied }) else { throw failure("No source for stale rename") }
    model.selection = [stale.url]
    let (staleField, staleEditor) = try await startRename()
    let original = nestedEntry.url.appendingPathComponent("retained-original.txt")
    let attempted = nestedEntry.url.appendingPathComponent("rejected.txt")
    let replacementBytes = Data("replacement".utf8)
    try FileManager.default.moveItem(at: occupied, to: original)
    try replacementBytes.write(to: occupied, options: .withoutOverwriting)
    staleEditor.insertText(attempted.lastPathComponent, replacementRange: NSRange(location: 0, length: (staleEditor.string as NSString).length))
    try sendRenameCommand(#selector(NSResponder.insertNewline(_:)), field: staleField, editor: staleEditor)
    try await wait("Replacing the source left an obsolete rename editor, selection or listing") {
        !model.busy && !model.interacting && renameField() == nil && model.selection.isEmpty
            && model.message == model.errorText(FileMoveError.sourceChanged)
            && model.entries.contains { $0.url == occupied && !$0.isSameItem(as: stale) }
    }
    try require(try Data(contentsOf: occupied) == replacementBytes && Data(contentsOf: original) == occupiedBytes
                && !FileManager.default.fileExists(atPath: attempted.path), "Stale rename changed the replacement or original file")
    model.pinned = true

    model.back()
    try await wait("Back did not restore directory") { model.canForward && model.entries.count == 3 }

    guard let note = model.entries.first(where: { $0.name == "Notes.txt" }),
          let movie = model.entries.first(where: { $0.name == "Large.txt" }) else { throw failure("Missing preview fixtures") }
    model.selection = [note.url]
    try await Task.sleep(for: .milliseconds(400))
    try require(model.previewURL == nil && model.message == nil, "Default selection started a preview or reported eligibility")
    model.setAutoPreview(true)
    try await wait("Small file did not produce a native preview") {
        guard let host = window.contentView else { return false }
        return model.previewURL == note.url && views(of: QLPreviewView.self, in: host).contains {
            ($0.previewItem as? NSURL) == note.url as NSURL
        }
    }
    model.selection = [movie.url]
    try await Task.sleep(for: .milliseconds(450))
    try await wait("Large automatic preview was not held") {
        guard let host = window.contentView else { return false }
        return model.previewURL == nil && model.message == nil && views(of: QLPreviewView.self, in: host).isEmpty
    }
    guard let host = window.contentView,
          let list = views(of: NSCollectionView.self, in: host).first,
          window.makeFirstResponder(list),
          let space = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                      timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                      context: nil, characters: " ", charactersIgnoringModifiers: " ",
                                      isARepeat: false, keyCode: 49) else { throw failure("Could not focus the native file list") }
    list.keyDown(with: space)
    try await wait("Manual preview did not admit the large selection") { model.previewURL == movie.url }
    window.sendEvent(try drawerKeyEvent("f", 3))
    try await wait("Command-F did not focus the folder search") { window.firstResponder is NSTextView }
    window.sendEvent(try drawerKeyEvent("\u{1b}", 53, []))
    try await wait("Escape from empty Command-F search did not return to files and leave the preview open") {
        window.isVisible && model.presented && window.firstResponder === list && model.query.isEmpty
            && model.selection == [movie.url] && model.previewURL == movie.url
    }
    window.sendEvent(try drawerKeyEvent("\u{1b}", 53, []))
    try await wait("Escape in the file list did not close only the preview") { model.previewURL == nil && model.presented }
    guard let searchField = views(of: NSTextField.self, in: host).first(where: { $0.accessibilityIdentifier() == "drawer.filter" }) else {
        throw failure("Missing native folder search field")
    }
    searchField.selectText(nil)
    try await wait("The folder search field did not take focus directly") {
        searchField.currentEditor() != nil && window.firstResponder === searchField.currentEditor()
    }
    guard let searchEditor = searchField.currentEditor() as? NSTextView else { throw failure("Missing folder search editor") }
    searchEditor.insertText("Large", replacementRange: searchEditor.selectedRange())
    try await wait("Typing in folder search did not filter the listing") {
        model.query == "Large" && !model.isSearching && model.visibleEntries.map(\.url) == [movie.url]
    }
    window.sendEvent(try drawerKeyEvent("\u{1b}", 53, []))
    try await wait("Escape after focusing the field directly closed the drawer or cleared the search") {
        window.isVisible && model.presented && window.firstResponder === list && model.query == "Large"
            && model.visibleEntries.map(\.url) == [movie.url]
    }
    model.selection = []
    searchField.selectText(nil)
    window.sendEvent(try drawerKeyEvent("\r", 36, []))
    try await wait("Return from folder search did not select the result and return to files") {
        window.firstResponder === list && model.query == "Large" && model.selection == [movie.url]
    }
    print("PASS drawer keyboard: Command-F and direct search focus, Escape, Return and preview priority")
    model.query = ""
    model.sort = .size
    try await wait("Size sort did not show folders first and the largest file next") {
        !model.isSearching && model.visibleEntries.map(\.name) == ["Nested", "Large.txt", "Notes.txt"]
    }
    model.sortAscending = true
    try await wait("Changing sort direction lost selection or returned the wrong order") {
        !model.isSearching && model.visibleEntries.map(\.name) == ["Nested", "Notes.txt", "Large.txt"] && model.selection == [movie.url]
    }
    model.sort = .name
    try await wait("Name sort did not settle") { !model.isSearching }
    model.selection = [note.url]
    model.query = "Nested"
    try await wait("Filtering retained hidden selection") {
        !model.isSearching && model.selection.isEmpty && model.visibleEntries.map(\.name) == ["Nested"]
    }
    model.query = "Large"
    model.selectFirstSearchResult()
    model.query = "txt note"
    try await wait("An obsolete search or Return selected an old result") {
        !model.isSearching && model.visibleEntries.map(\.url) == [note.url] && model.selection.isEmpty
    }
    model.query = "nested"
    model.selectFirstSearchResult()
    try await wait("Return did not select the first result of the current query") {
        !model.isSearching && model.selection == [nestedEntry.url]
    }
    try await Task.sleep(for: .milliseconds(400))
    try require(model.previewURL == nil, "A stale preview survived selection change")

    model.setAutoPreview(false)
    model.query = ""
    model.navigate(nestedEntry.url)
    try await wait("Nested directory did not reopen for path navigation") { model.directory == nestedEntry.url && !model.busy }

    func axElement(_ id: String, in host: NSView? = nil) -> NSObject? {
        guard let view = host ?? model.window?.contentView else { return nil }
        var visited: Set<ObjectIdentifier> = []
        func find(_ element: NSObject) -> NSObject? {
            guard visited.insert(ObjectIdentifier(element)).inserted else { return nil }
            if element.responds(to: NSSelectorFromString("accessibilityIdentifier")),
               element.value(forKey: "accessibilityIdentifier") as? String == id { return element }
            let children = element.responds(to: NSSelectorFromString("accessibilityChildren"))
                ? (element.value(forKey: "accessibilityChildren") as? [NSObject] ?? []) : []
            for child in children {
                if let match = find(child) { return match }
            }
            return nil
        }
        return find(view)
    }
    func press(_ id: String, in host: NSView? = nil) async throws {
        try await wait("Missing drawer control: " + id) { axElement(id, in: host) != nil }
        let action = NSSelectorFromString("accessibilityPerformPress")
        guard let control = axElement(id, in: host), control.responds(to: action) else {
            throw failure("Drawer control cannot be pressed: " + id)
        }
        _ = control.perform(action)
    }

    try await press("drawer.shortcuts")
    try await press("drawer.shortcuts.done")
    prefs = settings.committedPreferences.fileDrawer
    prefs.showsShortcutHints = false
    try require(settings.setFileDrawer(prefs), "Could not save hidden shortcut hints")
    try await wait("Hiding hints kept the keyboard guide visible") { axElement("drawer.shortcuts") == nil }
    guard let currentList = views(of: NSCollectionView.self, in: host).first, window.makeFirstResponder(currentList) else {
        throw failure("Could not focus list after closing shortcuts")
    }
    model.selection = [created.url]
    let firstPath = IndexPath(item: 0, section: 0)
    for (character, code, mode, height) in [("1", 18, FileDrawerViewMode.icons, 100), ("3", 20, .compact, 29), ("2", 19, .list, 42)] {
        let event = try drawerKeyEvent(character, UInt16(code), [.command, .option])
        try require(currentList.performKeyEquivalent(with: event), "View shortcut did not reach focused file list")
        try await wait("View shortcut with hidden hints did not update the layout") {
            currentList.layoutSubtreeIfNeeded()
            return model.viewMode == mode && model.selection == [created.url]
                && currentList.collectionViewLayout?.layoutAttributesForItem(at: firstPath)?.size.height == CGFloat(height)
        }
        let (field, editor) = try await startRename()
        try require(editor.string == created.name, "View mode edited a different file")
        try sendRenameCommand(#selector(NSResponder.cancelOperation(_:)), field: field, editor: editor)
        try await wait("Closing inline editor did not return focus to the file list") {
            renameField() == nil && window.firstResponder === currentList
        }
    }

    guard let authorizedRoot = model.location?.chain.first?.url else { throw failure("No authorized root") }
    try require(model.pathComponents.map(\.title) == nestedEntry.url.pathComponents, "Path bar omitted part of the absolute path")
    model.query = "clear by going to this folder"
    try await press("drawer.path.go.\(model.pathComponents.count - 1)")
    try await wait("Breadcrumb label did not restore this folder's unfiltered contents") {
        model.directory == nestedEntry.url && model.query.isEmpty && !model.busy && model.pathMenu == nil
    }
    let components = model.pathComponents
    guard let parentIndex = components.firstIndex(where: { $0.url.path == authorizedRoot.path }),
          let outside = components.first(where: { !$0.isAuthorized }) else { throw failure("Invalid fixture path boundaries") }
    guard let boundary = model.showPathMenu(outside) else { throw failure("Missing protected-prefix prompt") }
    try require(model.pathMenu?.entries.isEmpty == true && model.pathMenu?.isLoading == false,
                "Opening an above-root breadcrumb enumerated its contents")
    model.closePathMenu(boundary)

    // Use the actual UI controls to select a file from a different directory.
    model.query = "not-a-match"
    let browse = model.text("Browse Folder Contents…", "浏览文件夹内容…")
    guard let parentControl = axElement("drawer.path.go.\(parentIndex)"),
          parentControl.responds(to: NSSelectorFromString("accessibilityCustomActions")),
          let actions = parentControl.value(forKey: "accessibilityCustomActions") as? [NSAccessibilityCustomAction],
          let action = actions.first(where: { $0.name == browse }) else {
        throw failure("Path component is missing its secondary browse action")
    }
    if let handler = action.handler {
        try require(handler(), "Path component did not browse its children")
    } else if let target = action.target as? NSObject, let selector = action.selector, target.responds(to: selector) {
        _ = target.perform(selector, with: action)
    } else { throw failure("Path component has no actionable browse handler") }
    try await wait("Parent drop-down did not list its direct children") {
        model.pathMenu?.entries.contains(where: { $0.url == note.url }) == true
    }
    try require(model.pathMenu?.entries.contains(where: { $0.name == created.name }) == false,
                "Path navigation recursively listed a descendant")
    controller.toggleFromShortcut()
    try require(controller.panel === window && model.pathMenu != nil, "Shortcut interrupted path selection")
    try await press("drawer.path.item.\(note.name)")
    try await wait("Choosing a file from a breadcrumb did not reveal the captured item") {
        model.directory == authorizedRoot && model.selection == [note.url] && model.query.isEmpty && !model.busy
    }
    try require(model.previewURL == nil, "Choosing a file forced a preview when automatic preview was off")
    model.back()
    try await wait("Back did not return to the previous path after a file pick") { model.directory == nestedEntry.url && !model.busy }

    // An old menu cannot activate a same-name replacement or a dismissed row.
    let within = model.pathComponents[parentIndex]
    guard let dismissed = model.showPathMenu(within) else { throw failure("No ancestor menu") }
    try await wait("Ancestor menu did not load") { model.pathMenu?.isLoading == false }
    model.closePathMenu(dismissed)
    model.choosePathItem(note, in: dismissed)
    try require(model.directory == nestedEntry.url && !model.busy, "Dismissed path row remained actionable")
    guard let pending = model.showPathMenu(within) else { throw failure("No fresh ancestor menu") }
    try await wait("Fresh ancestor menu did not load") { model.pathMenu?.isLoading == false }
    guard let old = model.pathMenu?.entries.first(where: { $0.url == note.url }) else { throw failure("No captured file") }
    try FileManager.default.moveItem(at: note.url, to: folder.appendingPathComponent("Retained-original.txt"))
    try Data("Replacement".utf8).write(to: note.url)
    model.choosePathItem(old, in: pending)
    try await wait("Replaced file did not report an error") {
        !model.busy && (model.message != nil || model.pathMenu?.error != nil)
    }
    try require(!model.selection.contains(note.url), "A stale row selected a different file")
    if let id = model.pathMenu?.id { model.closePathMenu(id) }

    // Navigate directly from the path drop-down into a newly listed sibling.
    let sibling = authorizedRoot.appendingPathComponent("Sibling", isDirectory: true)
    try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: false)
    guard let parent = model.pathComponents.first(where: { $0.url.path == authorizedRoot.path }) else { throw failure("Parent component disappeared") }
    guard let siblingMenu = model.showPathMenu(parent) else { throw failure("Missing sibling folder menu") }
    try await wait("Sibling directory not listed on demand") { model.pathMenu?.entries.contains(where: { $0.name == "Sibling" }) == true }
    try await wait("Path search field did not attach") {
        views(of: NSSearchField.self, in: host).contains { $0.accessibilityIdentifier() == "drawer.path.search" }
    }
    guard model.pathMenu?.id == siblingMenu,
          let filter = views(of: NSSearchField.self, in: host).first(where: { $0.accessibilityIdentifier() == "drawer.path.search" }),
          window.makeFirstResponder(filter), let fieldEditor = filter.currentEditor() as? NSTextView,
          let delegate = filter.delegate else { throw failure("Could not edit the path filter") }
    // Return in the same event turn must use the newly entered filter.
    filter.stringValue = "Sibling"
    delegate.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: filter))
    try require(delegate.control?(filter, textView: fieldEditor, doCommandBy: #selector(NSResponder.insertNewline(_:))) == true,
                "Path filter did not accept Return")
    try await wait("Folder selection did not enter the sibling directory") { model.directory?.path == sibling.path && !model.busy }

    controller.show()
    try require(model.directory?.path == sibling.path && !model.busy,
                "Refocusing a visible drawer changed its directory")
    window.makeKeyAndOrderFront(nil)
    try await wait("Fixture drawer could not take keyboard focus") { window.isKeyWindow }
    controller.toggleFromShortcut()
    if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        let surface = window.contentView?.subviews.first
        let exit = surface?.layer?.animation(forKey: "drawerVisibility") as? CAAnimationGroup
        let tracks = exit?.animations?.compactMap { $0 as? CABasicAnimation } ?? []
        let fade = tracks.first { $0.keyPath == "opacity" }
        let shift = tracks.first { $0.keyPath == "transform.translation.x" }
        try require((fade?.toValue as? NSNumber)?.floatValue == 0 && (shift?.toValue as? NSNumber)?.doubleValue == -8,
                    "Left drawer did not fade with a short edge offset")
        if screen.maximumFramesPerSecond > 0 {
            try require(exit?.preferredFrameRateRange.maximum == Float(screen.maximumFramesPerSecond),
                        "Drawer animation did not request the display's refresh rate")
        }
        controller.toggleFromShortcut()
        try await Task.sleep(for: .milliseconds(350))
        try require(controller.panel === window && window.isVisible && model.presented,
                    "Interrupted dismissal closed a reopened drawer")
        controller.toggleFromShortcut()
    }
    try await wait("Global shortcut did not close the focused drawer") { !model.presented }
    controller.toggleFromShortcut()
    try await wait("Global shortcut did not reopen the drawer") { model.presented && model.window?.isVisible == true }

    try await wait("With memory on, reopening did not restore the last folder ahead of the default") {
        model.directory?.path == sibling.path && !model.busy
    }
    model.pinned = true
    model.navigateAncestor(authorizedRoot)
    try await wait("Restoration did not retain the authorized parent") { model.directory == authorizedRoot && !model.busy }
    model.selection = [movie.url]
    model.copySelection(move: true)
    try require(model.clipboardAvailable, "Could not stage a configured-root selection")
    try sendWindowKey("N", 45, [.command, .shift])
    guard let reopened = model.window, let nameSheet = reopened.attachedSheet else { throw failure("No folder naming sheet") }
    try require(settings.forgetDirectoryWriteAccess(path: authorizedRoot.path, legacy: false), "Could not revoke visible root")
    try require(!(try settings.rememberedFileAccess.directoryWritePaths()).contains(authorizedRoot.path)
                && model.directory == authorizedRoot && reopened.attachedSheet === nameSheet,
                "Revocation interrupted the user's current interaction")
    reopened.endSheet(nameSheet, returnCode: .alertSecondButtonReturn)
    try await wait("Revoked root survived the completed interaction") {
        model.directory == nil && model.selection.isEmpty && !model.clipboardAvailable && !model.canBack && model.previewURL == nil
    }
    try settings.rememberedFileAccess.rememberWriteDirectory(sibling, expected: sibling)
    try require(settings.setFileDrawerDefaultLocation(sibling), "Could not choose another default")
    try await wait("An empty drawer did not open the available default") { model.directory?.path == sibling.path && !model.busy }
    try settings.rememberedFileAccess.rememberWriteDirectory(folder, expected: folder)
    try require(settings.setFileDrawerDefaultLocation(folder), "Could not change the default location")
    try require(model.directory?.path == sibling.path && !model.busy, "Changing the default moved an open drawer")
    try await turnOffLocationMemory()
    try require(UserDefaults.standard.data(forKey: lastLocationKey) == nil, "Turning memory off kept the old location")
    try sendWindowKey("w", 13)
    try await wait("Drawer did not close after changing the default") { !model.presented }
    controller.show()
    try await wait("With memory off, reopening did not enter the new default") {
        model.directory == authorizedRoot && !model.canBack && !model.busy
    }
    model.pinned = true
    let creation = CustomFileSavePanelController.shared
    creation.present(in: authorizedRoot, preferences: settings.committedPreferences, documentTemplates: settings.documentTemplates)
    guard let existingDraft = creation.panel, existingDraft.isVisible else { throw failure("Independent draft did not open") }
    model.newFile()
    try require(model.draftWindow === existingDraft, "Drawer did not focus the existing draft")
    try require(settings.forgetDirectoryWriteAccess(path: authorizedRoot.path, legacy: false), "Could not remove grant during a draft")
    try require(model.directory == authorizedRoot && existingDraft.isVisible, "Grant removal interrupted the existing draft")
    existingDraft.close()
    try await wait("Closing a draft opened elsewhere did not release the old drawer session") {
        model.directory == nil && model.draftWindow == nil
    }
    try settings.rememberedFileAccess.rememberWriteDirectory(folder, expected: folder)
    try await wait("Drawer did not reopen its authorized folder") { model.directory == authorizedRoot && !model.busy }
    model.openFolder(nested)
    try await wait("Independent folder did not open") {
        model.directory == nestedEntry.url && !model.busy
    }
    try require(settings.forgetDirectoryWriteAccess(path: authorizedRoot.path, legacy: false), "Could not remove configured history")
    try require(model.directory == nestedEntry.url && !model.canBack &&
                !(try settings.rememberedFileAccess.directoryWritePaths()).contains(authorizedRoot.path),
                "Grant removal discarded an independent location or kept configured-root history")

    try sendWindowKey("w", 13)
    try await wait("Command-W did not close the drawer") { !model.presented && controller.panel == nil }
    controller.show()
    try await wait("Drawer did not reopen after Command-W") { model.presented && model.window?.isVisible == true }
    try await press("drawer.authorizeDefaultLocation")
    try await wait("A revoked default location did not offer precise authorization") { model.window?.attachedSheet is NSOpenPanel }
    guard let recoveryPicker = model.window?.attachedSheet as? NSOpenPanel else { throw failure("Missing default location picker") }
    try require(recoveryPicker.directoryURL?.standardizedFileURL.path == authorizedRoot.path, "Default reauthorization targeted a different folder")
    recoveryPicker.cancel(nil)
    try await wait("Cancelling default authorization changed the location") { !model.interacting && model.directory == nil }
    try settings.rememberedFileAccess.rememberWriteDirectory(folder, expected: folder)
    try await wait("Restored default was not browsable") { model.directory == authorizedRoot && !model.busy }
    var noDefault = settings.committedPreferences.fileDrawer
    noDefault.defaultDirectoryPath = nil
    noDefault.remembersLastLocation = true
    try require(settings.setFileDrawer(noDefault) && (try settings.rememberedFileAccess.directoryWritePaths()).contains(authorizedRoot.path),
                "Clearing the default removed a remembered folder grant")
    model.navigate(nestedEntry.url)
    try await wait("Could not browse without a default") { model.directory == nestedEntry.url && !model.busy }
    try sendWindowKey("w", 13)
    try await wait("Drawer with no default did not close") { !model.presented }
    let fresh = FileDrawerController(settings: settings, favorites: favorites, placeHome: home, lastLocationKey: lastLocationKey)
    fresh.show()
    try await wait("A new drawer controller did not restore the saved location with its parent's authority") {
        fresh.model.directory == nestedEntry.url && fresh.model.rootURL == authorizedRoot && !fresh.model.busy
    }
    fresh.panel?.close()

    try require(settings.setFileDrawerDefaultLocation(folder), "Could not set the fallback location")
    try FileManager.default.moveItem(at: nested, to: folder.appendingPathComponent("Retained-Nested", isDirectory: true))
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: false)
    controller.show()
    try await wait("A replaced remembered folder did not fall back to the default") {
        model.directory == authorizedRoot && !model.busy
    }
    let sessionOnly = root.appendingPathComponent("SessionOnly", isDirectory: true)
    try FileManager.default.createDirectory(at: sessionOnly, withIntermediateDirectories: false)
    model.openFolder(sessionOnly)
    try await wait("Could not browse the session-only folder") {
        model.directory?.path == sessionOnly.standardizedFileURL.path && !model.busy
    }
    try sendWindowKey("w", 13)
    try await wait("Drawer did not close at the session-only folder") { !model.presented }
    controller.show()
    try await wait("The session bookmark did not restore the same authorized directory") {
        model.directory?.path == sessionOnly.standardizedFileURL.path && !model.busy
    }
    controller.panel?.close()
    fresh.show()
    try await wait("A saved position without a durable grant did not fall back to the default") {
        fresh.model.directory == authorizedRoot && !fresh.model.busy
    }
    fresh.panel?.close()
    controller.show()
    try await wait("Drawer did not return to its default") { model.directory == authorizedRoot && !model.busy }
    try await checkFileArrows()
    try await checkDimensionEditors()
    try await checkAnimationEffects()
    prefs = settings.committedPreferences.fileDrawer
    prefs.enabled = false
    try require(settings.setFileDrawer(prefs), "Disabling drawer failed")
    try await wait("Disabling drawer did not close and release its directory") {
        controller.panel == nil && !model.presented && model.directory == nil && model.previewURL == nil
    }

    func checkDrawerSettingsControls() async throws {
        let owner = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 700, height: 640),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: FileDrawerSettingsPane(openDrawer: controller.show, checkDiskRootAccess: {
            // Resolve a real saved grant inside the fixture instead of requesting disk-wide consent.
            await $0.hasSavedDrawerRootAccess(at: folder)
        }).environmentObject(settings))
        host.sizingOptions = []
        owner.contentView = host
        owner.makeKeyAndOrderFront(nil)
        defer {
            controller.panel?.close()
            owner.close()
        }

        try await wait("Open File Drawer was not disabled while the module was off") {
            guard let button = axElement("drawer.open", in: host),
                  button.responds(to: NSSelectorFromString("isAccessibilityEnabled")) else { return false }
            return owner.isKeyWindow && button.value(forKey: "accessibilityEnabled") as? Bool == false
        }
        try await press("drawer.enabled", in: host)
        try await wait("Enabling the drawer did not keep both adaptive sizing modes on") {
            let drawer = settings.committedPreferences.fileDrawer
            return drawer.enabled && drawer.fitsDisplayWidth && drawer.fitsDisplayHeight
        }
        try require(settings.committedPreferences.fileDrawer.animation == .genie, "New drawer settings did not default to Genie")
        try await wait("Drawer appearance did not offer the animation picker") { axElement("drawer.animation", in: host) != nil }
        try await wait("The missing grant did not show the authorization button") {
            axElement("drawer.authorizeDiskRoot", in: host) != nil && axElement("drawer.diskRootAuthorized", in: host) == nil
        }
        try settings.rememberedFileAccess.rememberWriteDirectory(folder, expected: folder)
        try await wait("A saved grant did not replace the authorization button with status") {
            axElement("drawer.authorizeDiskRoot", in: host) == nil && axElement("drawer.diskRootAuthorized", in: host) != nil
        }
        try require(settings.forgetDirectoryWriteAccess(path: folder.resolvingSymlinksInPath().path, legacy: false),
                    "Could not remove the fixture grant")
        try await wait("Revocation did not restore the authorization button") {
            axElement("drawer.authorizeDiskRoot", in: host) != nil && axElement("drawer.diskRootAuthorized", in: host) == nil
        }
        try await press("drawer.open", in: host)
        try await wait("Open File Drawer did not show and focus the drawer") {
            model.window?.isVisible == true && model.window?.isKeyWindow == true
        }
        guard let opened = controller.panel else { throw failure("Missing drawer opened from settings") }
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let content = opened.contentView {
            try require(!views(of: FileDrawerGenieTransition.self, in: content).isEmpty,
                        "Opening with the default setting did not start Genie")
        }
        model.pinned = true
        owner.makeKeyAndOrderFront(nil)
        try await wait("Settings could not take focus again") { owner.isKeyWindow }
        try await press("drawer.open", in: host)
        try await wait("Open File Drawer did not focus the existing drawer") {
            controller.panel === opened && opened.isKeyWindow
        }
        print("PASS drawer settings: adaptive defaults, grant status and open or focus")
    }

    func checkAnimationEffects() async throws {
        reduceMotionOverride = false
        defer { reduceMotionOverride = nil }
        func genieView() -> FileDrawerGenieTransition? {
            guard let content = controller.panel?.contentView else { return nil }
            return views(of: FileDrawerGenieTransition.self, in: content).first
        }
        @available(macOS 14.4, *)
        func checkCompositedGlass(layout: String, side: FileDrawerPreferences.Side, opening: Bool) async throws {
            let phase = opening ? "opening" : "closing"
            let label = "\(layout) \(side.rawValue) \(phase)"
            controller.show()
            guard let drawer = controller.panel else { throw failure("Missing drawer for \(label)") }
            defer { drawer.close() }
            model.pinned = true
            if !opening {
                try await wait("Drawer did not finish opening before \(label)") { genieView() == nil && !model.busy }
                model.close()
            }
            guard let genie = genieView(), genie.presentsWithTransaction else { throw failure("Missing live glass for \(label)") }
            // Keep the actual transition mounted while the window server takes the screenshot.
            // The separate lifecycle checks below exercise its normal completion and reversal.
            genie.play(opening: opening) {}
            try await wait("No intermediate frame for \(label)") { (0.42...0.62).contains(genie.progress) }
            genie.isPaused = true
            CATransaction.flush()
            let ownWindows = try await SCShareableContent.currentProcess.windows
            guard let window = ownWindows.first(where: { $0.windowID == CGWindowID(drawer.windowNumber) }) else {
                throw failure("Could not find the fixture's own drawer for \(label)")
            }
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            let width = Int(genie.drawableSize.width)
            let height = Int(genie.drawableSize.height)
            config.width = width
            config.height = height
            config.ignoreShadowsSingleWindow = true
            config.showsCursor = false
            config.shouldBeOpaque = false
            let frame = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let bitmap = NSBitmapImageRep(cgImage: frame)
            try require(frame.width == width && frame.height == height, "Unexpected backing dimensions for \(label)")
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw failure("Could not encode \(label)") }
            try png.write(to: root.appendingPathComponent("drawer-genie-\(layout)-\(phase)-\(side.rawValue).png"))

            // The glass must cover the entire warped cross-section from the body to the throat.
            let vertices = FileDrawerGenieGeometry(size: genie.bounds.size, side: side).vertices(at: genie.progress)
            let columns = FileDrawerGenieGeometry.columns
            var maxEdgeError = 0.0
            for column in [2, columns / 2, columns - 2] {
                let a = vertices[column], b = vertices[column + 1]
                let x = Int(Double((a.x + b.x) / 2) * Double(width))
                let rows = (0..<height).filter { (bitmap.colorAt(x: x, y: $0)?.alphaComponent ?? 0) > 0.4 }
                guard let first = rows.first, let last = rows.last else { throw failure("Missing glass at column \(column) in \(label)") }
                let sampleX = Float((Double(x) + 0.5) / Double(width))
                let fraction = (sampleX - a.x) / (b.x - a.x)
                let inset = Double(a.y + fraction * (b.y - a.y)) * Double(height)
                maxEdgeError = max(maxEdgeError, abs(Double(first) - inset), abs(Double(height - 1 - last) - inset))
                try require(rows.count == last - first + 1, "Gap in the composited glass at column \(column) in \(label)")
            }
            try require(maxEdgeError <= 3, "Glass outline missed the warped drawer by \(maxEdgeError) pixels in \(label)")

            // The centered resize grip is part of the Metal snapshot. Measure its visible mark
            // against the adjacent glass in this same image, including in dark appearance.
            func resizeGrip(in view: NSView) -> NSView? {
                if view.accessibilityLabel() == model.text("Resize file drawer", "调整抽屉宽度") { return view }
                return view.subviews.lazy.compactMap { resizeGrip(in: $0) }.first
            }
            guard let content = drawer.contentView, let handle = resizeGrip(in: content) else { throw failure("Missing drawer grip") }
            let sourceX = genie.convert(handle.bounds, from: handle).midX / genie.bounds.width
            let gripX = Int((Double(vertices[0].x) + sourceX * Double(vertices[columns].x - vertices[0].x)) * Double(width))
            let mid = height / 2
            let span = Int(40 * drawer.backingScaleFactor)
            func brightness(_ y: Int) throws -> CGFloat {
                guard let color = bitmap.colorAt(x: gripX, y: y)?.usingColorSpace(.sRGB) else {
                    throw failure("Missing resize grip sample in \(label)")
                }
                return color.brightnessComponent
            }
            let background = try brightness(mid - span)
            let grip = try (mid - span...mid + span).filter { abs(try brightness($0) - background) > 0.06 }
            guard let first = grip.first, let last = grip.last else { throw failure("Missing visible resize grip in \(label)") }
            let gripCenter = Double(first + last) / 2
            try require(grip.count >= 6 && grip.count == last - first + 1 && abs(gripCenter - Double(mid)) <= 2,
                        "Resize grip did not align with the glass center in \(label) (\(first)...\(last), center \(mid))")
            if layout == "adaptive" && side == .right {
                // Locate actual file icons in the composited frame. A cached location chooser has none of these rows.
                guard let list = views(of: NSCollectionView.self, in: content).first, list.numberOfItems(inSection: 0) >= 3 else {
                    throw failure("The fixture listing did not restore during \(label)")
                }
                let windowRect = genie.convert(genie.bounds, to: nil)
                for index in 0..<3 {
                    guard let item = list.item(at: IndexPath(item: index, section: 0)),
                          let icon = views(of: NSImageView.self, in: item.view).first else { throw failure("Missing fixture file icon") }
                    let rect = icon.convert(icon.bounds, to: nil)
                    let u = (rect.midX - windowRect.minX) / windowRect.width * CGFloat(columns)
                    let column = min(columns - 1, max(0, Int(u)))
                    let a = vertices[column], b = vertices[column + 1]
                    let position = a + Float(u - CGFloat(column)) * (b - a)
                    let v = (windowRect.maxY - rect.midY) / windowRect.height
                    let x = CGFloat(position.x) * CGFloat(width)
                    let y = (CGFloat(position.y) + v * CGFloat(1 - 2 * position.y)) * CGFloat(height)
                    let radius = ceil(max(rect.width, rect.height) * drawer.backingScaleFactor / 2)
                    let region = CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius)
                    guard let crop = frame.cropping(to: region.integral) else { throw failure("Missing warped file icon area") }
                    let iconPixels = NSBitmapImageRep(cgImage: crop)
                    let containsTint = (0..<iconPixels.pixelsHigh).contains { row in
                        (0..<iconPixels.pixelsWide).contains { col in
                            (iconPixels.colorAt(x: col, y: row)?.usingColorSpace(.sRGB)?.saturationComponent ?? 0) > 0.08
                        }
                    }
                    try require(containsTint, "The warped snapshot lost file icon \(index) during \(label)")
                }
            }
            print("PASS composited Genie \(label): \(width)x\(height) px, grip center \(gripCenter), maximum outline error \(maxEdgeError) px")
        }
        func checkMotionToEndpoint(_ genie: FileDrawerGenieTransition, opening: Bool) async throws {
            var previous = genie.progress
            var movedBackwards = false
            try await wait("Genie did not hand off its final frame") {
                if opening ? genie.progress > previous : genie.progress < previous { movedBackwards = true }
                previous = genie.progress
                return genie.superview == nil
            }
            try require(!movedBackwards && genie.progress == (opening ? 0 : 1),
                        "Genie reversed or handed off before rendering its endpoint at \(genie.progress)")
        }
        @available(macOS 15, *)
        func recordDrawerCycle() async throws {
            controller.show()
            guard let drawer = controller.panel, let screen = drawer.screen else { throw failure("Missing drawer to record") }
            model.pinned = true
            try await wait("Drawer did not finish opening before recording") { genieView() == nil && !model.busy }
            let own = try await SCShareableContent.currentProcess
            let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            guard let display = own.displays.first(where: { $0.displayID == screenID?.uint32Value }),
                  let app = own.applications.first(where: { $0.processID == ProcessInfo.processInfo.processIdentifier })
            else { throw failure("Missing fixture display or app to record") }
            // Both successive drawer windows belong to the fixture; exclude its other windows.
            let excluded = own.windows.filter { $0.owningApplication?.processID == app.processID && $0.windowID != CGWindowID(drawer.windowNumber) }
            let filter = SCContentFilter(display: display, including: [app], exceptingWindows: excluded)
            filter.includeMenuBar = false
            let config = SCStreamConfiguration()
            config.sourceRect = CGRect(x: drawer.frame.minX - screen.frame.minX, y: screen.frame.maxY - drawer.frame.maxY,
                                       width: drawer.frame.width, height: drawer.frame.height)
            config.width = Int(drawer.frame.width) / 2 * 2
            config.height = Int(drawer.frame.height) / 2 * 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.ignoreShadowsDisplay = true
            config.showsCursor = false
            config.capturesAudio = false
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            let movie = DrawerMovie()
            let output = SCRecordingOutputConfiguration()
            output.outputURL = root.appendingPathComponent("drawer-genie-cycle.mp4")
            try stream.addRecordingOutput(SCRecordingOutput(configuration: output, delegate: movie))
            try await stream.startCapture()
            do {
                try await wait("Drawer recording did not start") { movie.started || movie.error != nil }
                if let error = movie.error { throw error }
                try await Task.sleep(for: .milliseconds(200))
                model.close()
                guard let closing = genieView() else { throw failure("Missing recorded dismissal") }
                try await checkMotionToEndpoint(closing, opening: false)
                try await Task.sleep(for: .milliseconds(200))
                controller.show()
                model.pinned = true
                guard let opening = genieView() else { throw failure("Missing recorded opening") }
                try await checkMotionToEndpoint(opening, opening: true)
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                try? await stream.stopCapture()
                throw error
            }
            try await stream.stopCapture()
            try await wait("Drawer recording did not finish") { movie.finished || movie.error != nil }
            if let error = movie.error { throw error }
            controller.panel?.close()
        }
        func captureGenie(_ genie: FileDrawerGenieTransition, side: FileDrawerPreferences.Side, phase: String,
                          glass: NSVisualEffectView?) throws {
            let width = Int(genie.bounds.width.rounded(.up))
            let height = Int(genie.bounds.height.rounded(.up))
            let textureInfo = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: genie.colorPixelFormat,
                                                                      width: width, height: height, mipmapped: false)
            textureInfo.usage = .renderTarget
            textureInfo.storageMode = .shared
            guard let device = genie.device, let texture = device.makeTexture(descriptor: textureInfo),
                  let buffer = device.makeCommandQueue()?.makeCommandBuffer() else { throw failure("Could not allocate a Genie frame") }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            genie.renderFrame(to: pass, using: buffer)
            buffer.commit()
            buffer.waitUntilCompleted()
            try require(buffer.status == .completed, "Could not render the Genie taper")
            let rowBytes = width * 4
            var pixels = Data(count: rowBytes * height)
            pixels.withUnsafeMutableBytes { bytes in
                guard let address = bytes.baseAddress else { return }
                texture.getBytes(address, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            }
            let format: CGBitmapInfo = [.byteOrder32Little, .init(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)]
            guard let data = CGDataProvider(data: pixels as CFData), let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                      bytesPerRow: rowBytes, space: space, bitmapInfo: format, provider: data,
                                      decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
                throw failure("Could not decode the rendered Genie frame")
            }
            let bitmap = NSBitmapImageRep(cgImage: image)
            let edge = side == .left ? width / 50 : width - 1 - width / 50
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw failure("Could not encode Genie taper") }
            try png.write(to: root.appendingPathComponent("drawer-genie-\(phase)-\(side.rawValue).png"))
            let interior = (height / 2 - 5)...(height / 2 + 5)
            if let glass {
                try require(!glass.isHidden && genie.presentsWithTransaction, "Genie stopped compositing the live glass")
                guard let path = (glass.superview?.layer?.mask as? CAShapeLayer)?.path else {
                    throw failure("The \(phase) Genie frame did not mask the native glass")
                }
                let maskEdge = glass.bounds.width * (side == .left ? 0.02 : 0.98)
                try require(path.contains(CGPoint(x: maskEdge, y: glass.bounds.midY)) &&
                            !path.contains(CGPoint(x: maskEdge, y: glass.bounds.height / 8)),
                            "The \(phase) glass mask did not follow the Genie outline")
                try require(interior.contains { (bitmap.colorAt(x: edge, y: $0)?.alphaComponent ?? 1) < 0.1 },
                            "The \(phase) Genie frame covered the glass with a solid background")
                try require(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 0 },
                            "The \(phase) Genie frame lost the drawer controls")
            } else {
                try require(interior.allSatisfy { (bitmap.colorAt(x: edge, y: $0)?.alphaComponent ?? 0) > 0.98 },
                            "The \(phase) Genie frame lost its solid background")
            }
            try require((bitmap.colorAt(x: edge, y: height / 8)?.alphaComponent ?? 1) < 0.05,
                        "The \(phase) Genie frame did not taper into the \(side.rawValue) edge")
        }
        var options = settings.committedPreferences.fileDrawer
        options.animation = .genie
        controller.panel?.close()
        for side in FileDrawerPreferences.Side.allCases {
            options.side = side
            options.glass = side == .right
            try require(settings.setFileDrawer(options), "Could not save the Genie effect")
            controller.show()
            guard let drawer = controller.panel, let opening = genieView(),
                  let content = drawer.contentView, let surface = content.subviews.first?.layer,
                  let material = views(of: NSVisualEffectView.self, in: content).first(where: { $0.blendingMode == .behindWindow }) else {
                throw failure("Genie did not animate opening on the " + side.rawValue)
            }
            let glass = options.glass && !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? material : nil
            model.pinned = true
            try await wait("Genie opening did not reach the taper") { (0.43..<0.8).contains(opening.progress) }
            try captureGenie(opening, side: side, phase: "opening", glass: glass)
            try await checkMotionToEndpoint(opening, opening: true)
            try await wait("The live drawer did not finish loading") { !model.busy }
            try require(material.superview?.layer?.mask == nil, "Opening left the live drawer material masked")

            model.close()
            guard let closing = genieView() else { throw failure("Genie did not animate closing") }
            try await wait("Genie closing did not reach the taper") { (0.43..<0.8).contains(closing.progress) }
            try captureGenie(closing, side: side, phase: "closing", glass: glass)
            let progress = closing.progress
            controller.show()
            try require(controller.panel === drawer && genieView() === closing && closing.progress == progress,
                        "Reversing Genie replaced the window or restarted the deformation")
            try await checkMotionToEndpoint(closing, opening: true)
            try require(controller.panel === drawer && drawer.isVisible, "The reversed Genie transition lost the drawer")
            try require(surface.opacity == 1, "Reopening did not restore the drawer's live content")
            try require(material.superview?.layer?.mask == nil, "Reversing left the live drawer material masked")

            model.close()
            guard let dismissal = genieView() else { throw failure("Missing final Genie dismissal") }
            try await checkMotionToEndpoint(dismissal, opening: false)
            try require(controller.panel == nil && !drawer.isVisible, "Genie did not finish closing the drawer")
            try require(surface.opacity == 0 && material.superview?.layer?.mask == nil, "Finishing Genie did not clean up the closed drawer")
        }

        if #available(macOS 14.4, *), !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            var adaptive = FileDrawerPreferences()
            adaptive.enabled = true
            adaptive.defaultDirectoryPath = options.defaultDirectoryPath
            adaptive.remembersLastLocation = options.remembersLastLocation
            var tall = adaptive
            tall.fitsDisplayWidth = false
            tall.fitsDisplayHeight = false
            tall.width = tall.minimumWidth
            tall.height = tall.maximumHeight
            tall.transparency /= 2
            var wide = tall
            wide.maximumWidth = FileDrawerPreferences.supportedWidths.upperBound
            wide.width = min(screen.visibleFrame.width * 0.72, wide.maximumWidth)
            wide.height = wide.minimumHeight
            wide.transparency = adaptive.transparency
            for (layout, sizing) in [("adaptive", adaptive), ("tall", tall), ("wide", wide)] {
                for side in FileDrawerPreferences.Side.allCases {
                    var fixture = sizing
                    fixture.side = side
                    try require(settings.setFileDrawer(fixture), "Could not configure \(layout) drawer")
                    try await checkCompositedGlass(layout: layout, side: side, opening: true)
                    try await checkCompositedGlass(layout: layout, side: side, opening: false)
                }
            }
            try require(settings.setFileDrawer(tall), "Could not configure active resize")
            controller.show()
            guard let old = genieView(), let window = controller.panel else { throw failure("Missing Genie before resize") }
            model.pinned = true
            try require(settings.setFileDrawer(wide), "Could not resize an opening drawer")
            let expected = wide.panelFrame(in: screen.visibleFrame)
            try await wait("Resizing left a stale Genie frame or mask on the drawer") {
                old.superview == nil && abs(window.frame.width - expected.width) < 1 && abs(window.frame.height - expected.height) < 1 &&
                window.contentView.map {
                    views(of: NSVisualEffectView.self, in: $0).allSatisfy { $0.superview?.layer?.mask == nil }
                } == true
            }
            window.close()
            if #available(macOS 15, *) {
                try require(settings.setFileDrawer(adaptive), "Could not configure adaptive recording")
                try await recordDrawerCycle()
            }
        } else {
            print("SKIP composited Genie: own-window capture needs macOS 14.4+ with glass available")
        }

        options.animation = .scale
        try require(settings.setFileDrawer(options), "Could not save the Scale effect")
        controller.show()
        guard let drawer = controller.panel else { throw failure("Missing drawer for Scale effect") }
        model.pinned = true
        let layer = drawer.contentView?.subviews.first?.layer
        try await wait("Scale did not finish opening the drawer") { layer?.animation(forKey: "drawerVisibility") == nil }
        model.close()
        let group = layer?.animation(forKey: "drawerVisibility") as? CAAnimationGroup
        let scale = group?.animations?.compactMap { $0 as? CABasicAnimation }.first { $0.keyPath == "transform" }
        try require((scale?.toValue as? NSValue)?.caTransform3DValue.m11 == 0.7, "Scale did not shrink the drawer")
        controller.show()
        try await wait("Reversing Scale lost the drawer") {
            controller.panel === drawer && drawer.isVisible && layer?.animation(forKey: "drawerVisibility") == nil
        }

        options.animation = .genie
        try require(settings.setFileDrawer(options), "Could not restore the Genie effect")
        let stored = FileMintPreferencesStore(fileURL: root.appendingPathComponent("fixture-preferences.json")).load()
        try require(stored.fileDrawer.animation == .genie, "The saved animation did not survive readback")
        model.close()
        try require(genieView() != nil, "Missing closing transition to interrupt")
        reduceMotionOverride = true
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        try require(controller.panel == nil && !model.presented, "Reduce Motion did not finish an active dismissal")
        controller.show()
        try require(controller.panel?.isVisible == true && genieView() == nil, "Reduce Motion did not skip opening animation")
        print("PASS drawer animations: left/right Genie, interruption, Scale, persistence and Reduce Motion")
    }

    func turnOffLocationMemory() async throws {
        let owner = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 700, height: 640),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: FileDrawerSettingsPane().environmentObject(settings))
        host.sizingOptions = []
        owner.contentView = host
        owner.makeKeyAndOrderFront(nil)
        defer {
            owner.close()
            model.window?.makeKeyAndOrderFront(nil)
        }
        try await wait("Drawer settings did not expose separate browsing and root access controls") {
            owner.isKeyWindow && axElement("drawer.chooseDefaultLocation", in: host) != nil &&
                axElement("drawer.authorizeDiskRoot", in: host) != nil
        }
        try await press("drawer.remembersLastLocation", in: host)
        try await wait("The Remember Last Location switch did not persist its off state") {
            !settings.committedPreferences.fileDrawer.remembersLastLocation
        }
    }

    func checkDimensionEditors() async throws {
        guard let drawer = model.window, let screen = drawer.screen else { throw failure("Missing drawer for size settings") }
        model.pinned = true
        var setup = settings.committedPreferences.fileDrawer
        setup.fitsDisplayWidth = true
        setup.fitsDisplayHeight = true
        try require(settings.setFileDrawer(setup), "Could not enable automatic size before testing manual edits")
        let owner = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 650, height: 620),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: VStack {
            FileDrawerDimensionControls(axis: .horizontal)
            FileDrawerDimensionControls(axis: .vertical)
        }.padding().environmentObject(settings))
        host.sizingOptions = []
        owner.contentView = host
        NSApp.activate(ignoringOtherApps: true)
        owner.makeKeyAndOrderFront(nil)
        try await wait("Size settings owner did not become key") { owner.isKeyWindow }
        defer { owner.close() }

        // Exercise the production settings controls and their real AppKit field editor.
        func edit(_ id: String, _ number: Int, pressReturn: Bool = true) async throws {
            try await wait("Missing size setting " + id) { axElement(id, in: host) != nil }
            guard let node = axElement(id, in: host), node.responds(to: NSSelectorFromString("accessibilityFrame")),
                  let frame = (node.value(forKey: "accessibilityFrame") as? NSValue)?.rectValue else {
                throw failure("Missing size field frame " + id)
            }
            host.layoutSubtreeIfNeeded()
            let point = owner.convertPoint(fromScreen: NSPoint(x: frame.midX, y: frame.midY))
            let fields = views(of: NSTextField.self, in: host).filter(\.isEditable)
            let target = (node as? NSTextField) ?? fields.first {
                $0.accessibilityIdentifier() == id || $0.convert($0.bounds, to: nil).contains(point)
            }
            if let target {
                target.selectText(nil)
            } else if node.responds(to: NSSelectorFromString("setAccessibilityFocused:")) {
                node.setValue(true, forKey: "accessibilityFocused")
            } else { throw failure("No focusable control for \(id): AX=\(type(of: node)), native fields=\(fields.count), frame=\(frame)") }
            func activeEditor() -> NSTextView? {
                guard let editor = owner.firstResponder as? NSTextView else { return nil }
                if let target, target.currentEditor() !== editor { return nil }
                return editor
            }
            do { try await wait("Editor did not acquire focus") { activeEditor() != nil } }
            catch {
                let responder = owner.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
                throw failure("\(id): key=\(owner.isKeyWindow), AX=\(type(of: node)), native=\(target != nil), fields=\(fields.count), responder=\(responder), frame=\(frame)")
            }
            guard let editor = activeEditor() else { throw failure("Missing editor for " + id) }
            editor.insertText(String(number), replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
            if pressReturn {
                guard let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: 0, windowNumber: owner.windowNumber, context: nil, characters: "\r",
                    charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36) else { throw failure("Missing Return event") }
                owner.sendEvent(key)
            } else {
                owner.makeFirstResponder(nil)
            }
        }
        let oldWidth = settings.committedPreferences.fileDrawer.width
        try await edit("drawer.width", 702)
        try await wait("An out-of-range width was silently clamped or accepted") {
            let p = settings.committedPreferences.fileDrawer
            guard let apply = axElement("drawer.applyWidths", in: host),
                  apply.responds(to: NSSelectorFromString("isAccessibilityEnabled")) else { return false }
            return apply.value(forKey: "accessibilityEnabled") as? Bool == false && p.fitsDisplayWidth && p.width == oldWidth
        }
        try await edit("drawer.maximumWidth", 720)
        try await wait("Raising the limit did not apply the user's pending fixed width") {
            let p = settings.committedPreferences.fileDrawer
            return p.maximumWidth == 720 && p.width == 702 && !p.fitsDisplayWidth &&
                abs(drawer.frame.width - min(screen.visibleFrame.width - 12, 702)) < 1
        }
        try await edit("drawer.width", 572)
        try await wait("Entering a fixed width did not resize the open drawer or leave automatic mode") {
            let p = settings.committedPreferences.fileDrawer
            return !p.fitsDisplayWidth && p.width == 572 && abs(drawer.frame.width - min(screen.visibleFrame.width - 12, 572)) < 1
        }
        try await edit("drawer.minimumHeight", 590)
        try await edit("drawer.maximumHeight", 674)
        try await wait("Height limits did not bound adaptive sizing") {
            let p = settings.committedPreferences.fileDrawer
            let height = min(screen.visibleFrame.height - 12, min(674, max(590, (screen.visibleFrame.height * 0.72).rounded())))
            return p.fitsDisplayHeight && p.minimumHeight == 590 && p.maximumHeight == 674 &&
                abs(drawer.frame.height - height) < 1 && abs(drawer.frame.midY - screen.visibleFrame.midY) <= 1
        }
        try await edit("drawer.height", 631, pressReturn: false)
        try await wait("Ending height editing did not save a fixed drawer") {
            let p = settings.committedPreferences.fileDrawer
            return !p.fitsDisplayHeight && p.height == 631 && abs(drawer.frame.height - min(screen.visibleFrame.height - 12, 631)) < 1
        }
        let saved = FileMintPreferencesStore(fileURL: root.appendingPathComponent("fixture-preferences.json")).load().fileDrawer
        try require(saved.width == 572 && saved.height == 631 && saved.minimumHeight == 590 && saved.maximumHeight == 674,
                    "Size changes from the settings controls were not persisted")
        drawer.close()
        controller.show()
        try await wait("Reopened drawer ignored the sizes entered in settings") {
            guard let panel = controller.panel, panel !== drawer, let display = panel.screen else { return false }
            return abs(panel.frame.width - min(display.visibleFrame.width - 12, 572)) < 1 &&
                abs(panel.frame.height - min(display.visibleFrame.height - 12, 631)) < 1 &&
                abs(panel.frame.midY - display.visibleFrame.midY) <= 1
        }
    }

    func checkFileArrows() async throws {
        let base = root.appendingPathComponent("ArrowNavigation", isDirectory: true)
        let subfolder = base.appendingPathComponent("Subfolder", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        for index in 0..<50 {
            let name = String(format: "Item-%02d.txt", index)
            try Data().write(to: base.appendingPathComponent(name))
        }
        model.openFolder(base)
        try await wait("File arrow fixture did not load its folder") { model.entries.count == 51 && !model.busy }
        model.pinned = true
        guard let panel = model.window, let content = panel.contentView else { throw failure("Missing file arrow fixture window") }
        func arrow(_ key: UInt16) throws {
            let characters: [UInt16: String] = [123: "\u{f702}", 124: "\u{f703}", 125: "\u{f701}", 126: "\u{f700}"]
            guard let list = views(of: NSCollectionView.self, in: content).first, panel.firstResponder === list,
                  let character = characters[key],
                  let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.numericPad, .function],
                      timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: character,
                      charactersIgnoringModifiers: character, isARepeat: false, keyCode: key) else {
                throw failure("File collection did not have keyboard focus")
            }
            list.keyDown(with: event)
        }
        guard let entry = model.entries.first(where: { $0.name == "Subfolder" }) else { throw failure("Missing arrow folder") }
        for (mode, height) in [(FileDrawerViewMode.list, 42), (.icons, 100), (.compact, 29)] {
            model.setViewMode(mode)
            model.selection = []
            try await wait("File collection did not show the full arrow fixture") {
                guard let list = views(of: NSCollectionView.self, in: content).first, list.numberOfItems(inSection: 0) == 51,
                      list.selectionIndexPaths.isEmpty,
                      list.collectionViewLayout?.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.size.height == CGFloat(height)
                else { return false }
                return panel.makeFirstResponder(list)
            }
            try arrow(126)
            try require(model.selectedEntries.first?.name == "Item-49.txt", "Up from no selection did not choose the last item")
            try await wait("Arrow selection was off screen") {
                views(of: NSCollectionView.self, in: content).first?.indexPathsForVisibleItems().contains(IndexPath(item: 50, section: 0)) == true
            }
            try arrow(125)
            try require(model.selectedEntries.first?.name == "Item-49.txt", "Down wrapped past the last item")

            model.selection = []
            try arrow(125)
            try require(model.selection == [entry.url], "Down did not start at the first visible folder")
            try arrow(126)
            try require(model.selection == [entry.url], "Up wrapped past the first item")
            try arrow(125)
            try require(model.selectedEntries.first?.name == "Item-00.txt", "Down did not follow the visible sort order")
            try arrow(124)
            try require(!model.busy && model.directory?.path == entry.url.deletingLastPathComponent().path,
                        "Right on a regular file navigated away")
            try arrow(126)
            try arrow(124)
            try await wait("Right did not enter the selected folder") { !model.busy && model.directory == entry.url }
            try await wait("Empty folder did not reach the native list") {
                views(of: NSCollectionView.self, in: content).first?.numberOfItems(inSection: 0) == 0
            }
            try arrow(123)
            try await wait("Left did not return to the parent and select the departed folder") {
                !model.busy && model.entries.count == 51 && model.selection == [entry.url]
            }
        }

        // A same-name replacement is a different object, even in the same parent.
        model.navigate(entry.url)
        try await wait("Could not reenter the test subfolder") { !model.busy && model.directory == entry.url }
        try FileManager.default.moveItem(at: subfolder, to: base.appendingPathComponent("Original", isDirectory: true))
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: false)
        model.up()
        try await wait("Returning to the parent selected a replacement folder") {
            !model.busy && model.entries.count == 52 && model.selection.isEmpty
        }
    }
}
