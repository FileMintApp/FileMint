import FileMintCore
import Foundation
import Testing

@Suite("Startup preferences and localization")
struct StartupPreferencesTests {
    @Test("startup and menu bar default on while explicit off survives persistence")
    func defaultsAndSavedChoices() throws {
        let defaults = FileMintPreferences.default
        #expect(defaults.launchAtLogin)
        #expect(defaults.showMenuBar)
        #expect(!defaults.hasAttemptedLoginItemSetup)
        var saved = defaults
        saved.launchAtLogin = false
        saved.showMenuBar = false
        saved.hasAttemptedLoginItemSetup = true
        saved.language = .english
        let copy = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(saved))
        #expect(!copy.launchAtLogin && !copy.showMenuBar)
        #expect(copy.hasAttemptedLoginItemSetup)
        #expect(copy.language == .english)
    }

    @Test("older settings gain new switches without losing explicit language")
    func migration() throws {
        let data = Data("{\"language\":\"zh-Hans\",\"revealAfterCreation\":false}".utf8)
        let preferences = try JSONDecoder().decode(FileMintPreferences.self, from: data)
        #expect(preferences.launchAtLogin && preferences.showMenuBar)
        #expect(preferences.language == .chinese)
        #expect(!preferences.revealAfterCreation)
    }

    @Test("default login registration runs only once from an installed app")
    func initialRegistration() {
        #expect(LoginItemPolicy.shouldRegisterInitially(wantsEnabled: true, attempted: false, status: .notRegistered, installed: true))
        #expect(!LoginItemPolicy.shouldRegisterInitially(wantsEnabled: true, attempted: true, status: .notRegistered, installed: true))
        #expect(!LoginItemPolicy.shouldRegisterInitially(wantsEnabled: false, attempted: false, status: .notRegistered, installed: true))
        #expect(!LoginItemPolicy.shouldRegisterInitially(wantsEnabled: true, attempted: false, status: .enabled, installed: true))
        #expect(!LoginItemPolicy.shouldRegisterInitially(wantsEnabled: true, attempted: false, status: .requiresApproval, installed: true))
        #expect(!LoginItemPolicy.shouldRegisterInitially(wantsEnabled: true, attempted: false, status: .notRegistered, installed: false))
    }

    @Test("development and disk-image copies never become automatic login items")
    func installLocations() {
        let home = URL(fileURLWithPath: "/Users/example")
        #expect(LoginItemPolicy.isInstalled(URL(fileURLWithPath: "/Applications/FileMint.app"), userHome: home))
        #expect(LoginItemPolicy.isInstalled(URL(fileURLWithPath: "/Users/example/Applications/FileMint.app"), userHome: home))
        #expect(!LoginItemPolicy.isInstalled(URL(fileURLWithPath: "/Volumes/FileMint/FileMint.app"), userHome: home))
        #expect(!LoginItemPolicy.isInstalled(URL(fileURLWithPath: "/tmp/build/FileMint.app"), userHome: home))
    }

    @Test("system language resolves menu function labels and explicit choices win")
    func localizedMenu() {
        #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]) == .chinese)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["en-GB", "zh-Hans"]) == .english)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == .english)
        #expect(AppLanguage.english.resolved(preferredLanguages: ["zh-Hant-TW"]) == .english)
        #expect(FileMintStrings.text(.newFile, language: .chinese) == "新建文件")
        #expect(FileMintStrings.text(.newFile, language: .english) == "New File")
        for key in [FileMintTextKey.launchAtLogin, .showMenuBar, .fullDiskAccess, .fullDiskAccessHint] {
            #expect(FileMintStrings.text(key, language: .chinese) != FileMintStrings.text(key, language: .english))
        }
    }
}
