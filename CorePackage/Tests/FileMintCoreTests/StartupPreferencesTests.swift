import FileMintCore
import Foundation
import Testing

@Suite("Startup preferences and localization")
struct StartupPreferencesTests {
    @Test("New File location defaults to submenu and survives an explicit main-menu choice")
    func newFileMenuPlacement() throws {
        #expect(FileMintPreferences.default.newFileMenuPlacement == .submenu)
        for field in ["", ",\"newFileMenuPlacement\":\"unknown\"",
                      ",\"newFileMenuPlacement\":null", ",\"newFileMenuPlacement\":false"] {
            let data = Data("{\"language\":\"zh-Hans\",\"showMenuBar\":false\(field)}".utf8)
            let restored = try FileMintPreferencesStore.decode(data)
            #expect(restored.newFileMenuPlacement == .submenu)
            #expect(restored.language == .chinese && !restored.showMenuBar)
        }
        var value = FileMintPreferences.default
        value.newFileMenuPlacement = .main
        value.templates[0].isEnabled = false
        let saved = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(value))
        #expect(saved.newFileMenuPlacement == .main)
        #expect(saved.templates == value.templates)
    }

    @Test("appearance defaults and malformed values follow the system without resetting preferences")
    func appearanceMigration() throws {
        #expect(FileMintPreferences.default.appearance == .system)
        for value in [nil, "\"sepia\"", "null", "false", "42", "[]", "{}"] as [String?] {
            let field = value.map { ",\"appearance\":\($0)" } ?? ""
            let data = Data("{\"language\":\"en\",\"showMenuBar\":false,\"launchAtLogin\":false,\"revealAfterCreation\":false\(field)}".utf8)
            let preferences = try FileMintPreferencesStore.decode(data)
            #expect(preferences.appearance == .system)
            #expect(preferences.language == .english)
            #expect(!preferences.showMenuBar && !preferences.launchAtLogin && !preferences.revealAfterCreation)
        }
    }

    @Test("all appearance choices survive store reload and settings import", arguments: AppAppearance.allCases)
    func appearancePersistence(appearance: AppAppearance) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("preferences.json")
        let store = FileMintPreferencesStore(fileURL: file)
        var preferences = FileMintPreferences.default
        preferences.appearance = appearance
        preferences.language = .chinese
        preferences.showMenuBar = false
        preferences.monitoredFolderBookmarks = ["/fixture": Data([1, 2, 3])]
        preferences.templates[0].isEnabled = false
        try store.save(preferences)
        #expect(FileMintPreferencesStore(fileURL: file).load() == preferences)
        #expect(try FileMintPreferencesStore.decode(Data(contentsOf: file)) == preferences)
    }

    @Test("home menus follow different usernames and relocated home directories")
    func dynamicHomeScope() {
        for path in ["/Users/alex", "/Volumes/People/改名用户"] {
            let home = URL(fileURLWithPath: path, isDirectory: true)
            let defaults = DefaultFolders.urls(homeDirectory: home)
            #expect(defaults.first == home)
            #expect(FileMenuDestination.directory(target: home, isContainer: true,
                targetIsDirectory: false, monitoredFolders: defaults) == home)
            #expect(FileMenuDestination.directory(target: home.appendingPathComponent("note.txt"), isContainer: false,
                targetIsDirectory: false, monitoredFolders: defaults) == home)
            let legacy = Array(defaults.dropFirst())
            #expect(DefaultFolders.migratingHomeScope(legacy, homeDirectory: home) == defaults)
            #expect(DefaultFolders.migratingHomeScope([legacy[0]], homeDirectory: home) == [legacy[0]])
        }
    }

    @Test("old default folders gain home once while saved removals and restricted scopes survive")
    func homeScopeMigration() throws {
        let home = DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = Array(DefaultFolders.urls(homeDirectory: home).dropFirst())
        preferences.monitoredFolderBookmarks[preferences.monitoredFolderURLs[0].path] = Data([1, 2, 3])
        preferences.language = .chinese
        preferences.showMenuBar = false
        var old = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        old.removeValue(forKey: "folderScopeVersion")
        var migrated = try JSONDecoder().decode(FileMintPreferences.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(migrated.monitoredFolderURLs.first == home)
        #expect(migrated.monitoredFolderBookmarks == preferences.monitoredFolderBookmarks)
        #expect(migrated.language == .chinese && !migrated.showMenuBar)
        migrated.monitoredFolderURLs.removeAll { $0 == home }
        let removed = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(migrated))
        #expect(removed.monitoredFolderURLs == preferences.monitoredFolderURLs)
        old["monitoredFolderURLs"] = [preferences.monitoredFolderURLs[0].absoluteString]
        let restricted = try JSONDecoder().decode(FileMintPreferences.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(restricted.monitoredFolderURLs == [preferences.monitoredFolderURLs[0]])
    }

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

    @Test("settings navigation and moved behavior explanations are bilingual")
    func settingsNavigationCopy() {
        for key in [FileMintTextKey.settingsLabel, .creationSettings, .templatesAndTypes,
                    .finderAndFolders, .generalSettingsHint, .creationSettingsHint,
                    .finderFoldersHint, .interfaceLanguage, .startupAndAccess,
                    .appearance, .theme, .lightAppearance, .darkAppearance,
                    .viewUpdateSettings, .quickCreation, .newFileMenuPosition, .newFileMenuPositionHint,
                    .quickCollisionHint,
                    .afterCreationHint, .manageTemplates, .finderExtension, .menuFolders, .enabledTypes] {
            let english = FileMintStrings.text(key, language: .english)
            let chinese = FileMintStrings.text(key, language: .chinese)
            #expect(english != key.rawValue && chinese != key.rawValue)
            #expect(!english.isEmpty && !chinese.isEmpty && english != chinese)
        }
        #expect(FileMintStrings.text(.quickCollisionHint, language: .english).contains("asks before replacing"))
        #expect(FileMintStrings.text(.quickCollisionHint, language: .chinese).contains("替换已有文件前询问"))
    }

    @Test("permission guidance explains granted, off and unreadable status in both languages",
          arguments: [AppLanguage.english, .chinese])
    func permissionGuidance(language: AppLanguage) {
        let status = FileMintStrings.text(.fullDiskAccessStatus, language: language)
        let explanation = FileMintStrings.text(.fullDiskAccessStatusHint, language: language)
        let enabled = FileMintStrings.text(.fullDiskAccessEnabledHint, language: language)
        let disabled = FileMintStrings.text(.fullDiskAccessHint, language: language)
        let folder = FileMintStrings.text(.folderAccessSaved, language: language)
        let reminder = FileMintStrings.text(.folderAccessReminder, language: language)

        if language == .chinese {
            #expect(status.contains("以系统设置开关为准"))
            #expect(explanation.contains("无法自动读取") && explanation.contains("不代表你尚未授权"))
            #expect(enabled.contains("开关已开启：已授予权限") && enabled.contains("重新打开"))
            #expect(enabled.contains("无需重复"))
            #expect(disabled.contains("开关关闭或没有 FileMint"))
            #expect(folder.contains("文件夹") && folder.contains("已保存"))
            #expect(reminder.contains("即使已开启完全磁盘访问"))
        } else {
            #expect(status.contains("system switch"))
            #expect(explanation.contains("cannot read") && explanation.contains("does not mean access is denied"))
            #expect(enabled.contains("Switch on: permission is granted") && enabled.contains("reopen"))
            #expect(enabled.contains("no need to add it again"))
            #expect(disabled.contains("Switch off or FileMint missing"))
            #expect(folder.contains("Folder") && folder.contains("saved"))
            #expect(reminder.contains("Even with Full Disk Access"))
        }
        #expect(folder != FileMintStrings.text(.ready, language: language))
    }
}
