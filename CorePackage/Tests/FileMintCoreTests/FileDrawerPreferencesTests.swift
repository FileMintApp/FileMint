import CoreGraphics
import FileMintCore
import Foundation
import Testing

@Suite("File drawer settings")
struct FileDrawerPreferencesTests {
    @Test("remember last location defaults on and the legacy display path survives migration")
    func openingPreferencesMigration() throws {
        let old = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"enabled":true}"#.utf8))
        #expect(old.remembersLastLocation && FileDrawerPreferences().remembersLastLocation)
        #expect(old.defaultDirectoryPath == nil)
        let legacy = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"rootDirectoryPath":"/Volumes/Example"}"#.utf8))
        #expect(legacy.remembersLastLocation && legacy.defaultDirectoryPath == "/Volumes/Example")
        var fixed = legacy
        fixed.remembersLastLocation = false
        let saved = try JSONEncoder().encode(fixed)
        #expect(try JSONDecoder().decode(FileDrawerPreferences.self, from: saved) == fixed)
        let invalid = try JSONDecoder().decode(FileDrawerPreferences.self,
            from: Data(#"{"rootDirectoryPath":"relative","remembersLastLocation":"false","enabled":true}"#.utf8))
        #expect(invalid.enabled && invalid.defaultDirectoryPath == nil && invalid.remembersLastLocation)
        let disk = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"rootDirectoryPath":"/","hasOfferedRootAccess":true}"#.utf8))
        #expect(disk.defaultDirectoryPath == "/")
    }
    @Test("new and legacy settings keep the optional drawer and automatic preview off")
    func defaultsAndMigration() throws {
        let legacy = try JSONDecoder().decode(FileMintPreferences.self, from: Data(#"{"showMenuBar":false}"#.utf8))
        #expect(!legacy.showMenuBar)
        for settings in [FileMintPreferences.default.fileDrawer, legacy.fileDrawer] {
            #expect(!settings.enabled && !settings.autoPreview)
            #expect(settings.showsShortcutHints)
            #expect(settings.viewMode == .list && settings.sort == .name && settings.sortAscending)
            #expect(settings.side == .right && settings.glass)
            #expect(settings.minimumWidth == 320 && settings.maximumWidth == 640 && settings.width == 520)
            #expect(settings.fitsDisplayHeight && settings.height == 640)
            #expect(settings.minimumHeight == 480 && settings.maximumHeight == 1_100)
            #expect(settings.transparency == 0.3)
        }
    }

    @Test("migration adds the drawer shortcut without claiming a key for a disabled drawer")
    func shortcutMigration() throws {
        let previous = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"enabled":true}"#.utf8))
        #expect(previous.shortcut.isEnabled && previous.effectiveShortcut.effectiveCombination == .suggestedDrawer)
        #expect(FileDrawerPreferences().effectiveShortcut.effectiveCombination == nil)
        #expect(GlobalShortcut.suggestedDrawer == GlobalShortcut(keyCode: 2, modifiers: GlobalShortcut.control | GlobalShortcut.option))
        var saved = previous
        saved.shortcut = .init(isEnabled: false, combination: GlobalShortcut(keyCode: 27, modifiers: GlobalShortcut.command))
        let reloaded = try JSONDecoder().decode(FileDrawerPreferences.self, from: JSONEncoder().encode(saved))
        #expect(reloaded.enabled && reloaded.shortcut == saved.shortcut && reloaded.effectiveShortcut.effectiveCombination == nil)
        let malformed = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"enabled":true,"shortcut":"bad"}"#.utf8))
        #expect(malformed.enabled && malformed.effectiveShortcut.effectiveCombination == nil)
    }

    @Test("a corrupt group and malformed individual fields decode independently")
    func corruptValues() throws {
        let corrupt = Data(#"{"showMenuBar":false,"fileDrawer":"broken"}"#.utf8)
        let prefs = try JSONDecoder().decode(FileMintPreferences.self, from: corrupt)
        #expect(!prefs.showMenuBar && prefs.fileDrawer == FileDrawerPreferences())
        let mixed = Data(#"{"enabled":true,"autoPreview":42,"side":"top","glass":false,"minimumWidth":400,"maximumWidth":"bad","width":900,"transparency":4}"#.utf8)
        let settings = try JSONDecoder().decode(FileDrawerPreferences.self, from: mixed)
        #expect(settings.enabled && !settings.autoPreview && !settings.glass && settings.side == .right)
        #expect(settings.showsShortcutHints)
        let invalidView = try JSONDecoder().decode(FileDrawerPreferences.self, from:
            Data(#"{"viewMode":"bad","sort":"date","sortAscending":"bad","showsShortcutHints":null}"#.utf8))
        #expect(invalidView.viewMode == .list && invalidView.sort == .date && !invalidView.sortAscending)
        #expect(invalidView.showsShortcutHints)
        #expect(settings.minimumWidth == 400 && settings.maximumWidth == 640 && settings.width == 640)
        #expect(settings.transparency == 0.3)
        let reversed = Data(#"{"minimumWidth":900,"maximumWidth":800,"side":"left"}"#.utf8)
        let invalidPair = try JSONDecoder().decode(FileDrawerPreferences.self, from: reversed)
        #expect(invalidPair.minimumWidth == 320 && invalidPair.maximumWidth == 640 && invalidPair.side == .left)
    }

    @Test("configured values round trip and a smaller display only limits the visible width")
    func persistedPreferences() throws {
        var prefs = FileMintPreferences.default
        prefs.fileDrawer.enabled = true
        prefs.fileDrawer.autoPreview = true
        prefs.fileDrawer.showsShortcutHints = false
        prefs.fileDrawer.sort = .kind
        prefs.fileDrawer.sortAscending = false
        prefs.fileDrawer.viewMode = .compact
        prefs.fileDrawer.glass = false
        prefs.fileDrawer.transparency = 0.55
        prefs.fileDrawer.side = .left
        prefs.fileDrawer.minimumWidth = 400
        prefs.fileDrawer.maximumWidth = 800
        prefs.fileDrawer.width = 700
        let restored = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(prefs))
        #expect(restored.fileDrawer == prefs.fileDrawer)
        #expect(restored.fileDrawer.effectiveWidth(availableWidth: 200) == 200)
        #expect(restored.fileDrawer.effectiveWidth(availableWidth: 1500) == 700)
        prefs.fileDrawer.width = 50
        #expect(prefs.fileDrawer.effectiveWidth(availableWidth: 1000) == 400)
        prefs.fileDrawer.width = 900
        #expect(prefs.fileDrawer.effectiveWidth(availableWidth: 1000) == 800)
    }

    @Test("drawer centers on its target display and remembers explicit widths across display changes")
    func adaptiveFrame() throws {
        var prefs = FileDrawerPreferences()
        let laptop = CGRect(x: 0, y: 35, width: 1_440, height: 850)
        let external = CGRect(x: -2_560, y: -200, width: 2_560, height: 1_380)
        let narrow = CGRect(x: 1_440, y: 300, width: 290, height: 400)
        let regular = prefs.panelFrame(in: laptop)
        #expect(regular.width == 520 && regular.height == 612)
        #expect(regular.maxX == laptop.maxX - 6 && regular.midY == laptop.midY)
        prefs.side = .left
        let large = prefs.panelFrame(in: external)
        #expect(large.width == 640 && large.height > regular.height && large.height < external.height)
        #expect(large.minX == external.minX + 6 && abs(large.midY - external.midY) <= 0.5)
        let legacyCustom = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"width":580}"#.utf8))
        #expect(!legacyCustom.fitsDisplayWidth)
        #expect(legacyCustom.panelFrame(in: external).width == 580)
        #expect(legacyCustom.panelFrame(in: narrow).size == CGSize(width: 278, height: 388))
        #expect(legacyCustom.panelFrame(in: laptop).width == 580)
        let restored = try JSONDecoder().decode(FileDrawerPreferences.self, from: JSONEncoder().encode(legacyCustom))
        #expect(restored == legacyCustom)
    }

    @Test("fixed height survives switching modes and display bounds independently of width")
    func heightMode() throws {
        let screen = CGRect(x: -1_500, y: -407, width: 1_200, height: 900)
        let small = CGRect(x: 340, y: 72, width: 720, height: 500)
        var prefs = FileDrawerPreferences()
        prefs.height = 711
        prefs.fitsDisplayHeight = false
        let fixed = prefs.panelFrame(in: screen)
        #expect(fixed.height == 711 && fixed.midY == screen.midY)
        let clamped = prefs.panelFrame(in: small)
        #expect(clamped.height == 488 && clamped.midY == small.midY && prefs.height == 711)
        prefs.fitsDisplayHeight = true
        let automatic = prefs.panelFrame(in: screen)
        #expect(automatic.height == 648 && automatic.midY == screen.midY && automatic.width == fixed.width)
        let saved = try JSONDecoder().decode(FileDrawerPreferences.self, from: JSONEncoder().encode(prefs))
        #expect(saved.fitsDisplayWidth && saved.fitsDisplayHeight && saved.height == 711)
        prefs.fitsDisplayHeight = false
        #expect(prefs.panelFrame(in: screen) == fixed)
        let invalid = try JSONDecoder().decode(FileDrawerPreferences.self, from:
            Data(#"{"fitsDisplayHeight":false,"height":-100,"width":580}"#.utf8))
        #expect(!invalid.fitsDisplayHeight && invalid.height == 640 && invalid.width == 580)
        let old = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"fitsDisplayWidth":false}"#.utf8))
        #expect(old.fitsDisplayHeight && old.height == 640 && !old.fitsDisplayWidth)
    }

    @Test("custom height limits bound both sizing modes, preserving legacy tall windows")
    func heightRange() throws {
        let screen = CGRect(x: -700, y: -240, width: 1_100, height: 1_000)
        var p = FileDrawerPreferences()
        p.minimumHeight = 570
        p.maximumHeight = 680
        #expect(p.panelFrame(in: screen).height == 680)
        p.minimumHeight = 800
        p.maximumHeight = 940
        #expect(p.panelFrame(in: screen).height == 800)
        p.fitsDisplayHeight = false
        p.height = 880
        #expect(p.panelFrame(in: screen).height == 880)
        let short = CGRect(x: 700, y: 50, width: 900, height: 640)
        #expect(p.panelFrame(in: short).height == 628 && p.panelFrame(in: short).midY == short.midY)
        #expect(try JSONDecoder().decode(FileDrawerPreferences.self, from: JSONEncoder().encode(p)) == p)
        let legacy = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"fitsDisplayHeight":false,"height":2000,"width":605}"#.utf8))
        #expect(legacy.minimumHeight == 480 && legacy.maximumHeight == 2_000 && legacy.height == 2_000)
        #expect(legacy.panelFrame(in: CGRect(x: 0, y: 0, width: 1200, height: 2200)).height == 2_000)
        let reversed = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"minimumHeight":970,"maximumHeight":600,"width":605}"#.utf8))
        #expect(reversed.minimumHeight == 480 && reversed.maximumHeight == 1_100 && reversed.width == 605)
        let partial = try JSONDecoder().decode(FileDrawerPreferences.self, from: Data(#"{"minimumHeight":"invalid","maximumHeight":700,"height":810}"#.utf8))
        #expect(partial.minimumHeight == 480 && partial.maximumHeight == 700 && partial.height == 700)
    }
}
