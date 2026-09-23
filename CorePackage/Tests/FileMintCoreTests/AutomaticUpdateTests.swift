import FileMintCore
import Foundation
import Testing

@Suite("Low-frequency automatic updates")
struct AutomaticUpdateTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("new and old preferences enable automatic checks without changing existing choices")
    func defaultsAndMigration() throws {
        #expect(FileMintPreferences.default.automaticallyChecksForUpdates)
        #expect(FileMintPreferences.default.lastUpdateCheckAttempt == nil)
        let old = Data(#"{"language":"zh-Hans","showMenuBar":false,"launchAtLogin":false}"#.utf8)
        let migrated = try FileMintPreferencesStore.decode(old)
        #expect(migrated.automaticallyChecksForUpdates)
        #expect(migrated.lastUpdateCheckAttempt == nil)
        #expect(migrated.language == .chinese)
        #expect(!migrated.showMenuBar && !migrated.launchAtLogin)
    }

    @Test("saved off and attempt time survive a real preferences-store reload")
    func persistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("preferences.json")
        var saved = FileMintPreferences.default
        saved.automaticallyChecksForUpdates = false
        saved.lastUpdateCheckAttempt = now
        saved.language = .english
        try FileMintPreferencesStore(fileURL: url).save(saved)
        let reloaded = FileMintPreferencesStore(fileURL: url).load()
        #expect(reloaded == saved)
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: reloaded.automaticallyChecksForUpdates,
            lastAttempt: reloaded.lastUpdateCheckAttempt, now: now) == nil)
        // Re-enabling retains the cooldown, including failed/cancelled attempts.
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: true,
            lastAttempt: reloaded.lastUpdateCheckAttempt, now: now) == now.addingTimeInterval(604_800))
    }

    @Test("first launch and overdue checks are eligible, disabled checks never are")
    func eligibility() {
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: true, lastAttempt: nil, now: now) == now)
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: false, lastAttempt: nil, now: now) == nil)
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: false,
            lastAttempt: now.addingTimeInterval(-1_000_000), now: now) == nil)
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: true,
            lastAttempt: now.addingTimeInterval(-1_000_000), now: now) == now)
    }

    @Test("requests stay at least seven days apart across restarts and the exact boundary")
    func weeklyBoundary() {
        let next = now.addingTimeInterval(604_800)
        for elapsed: TimeInterval in [0, 60, 86_400, 604_799, 604_800] {
            #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: true, lastAttempt: now,
                now: now.addingTimeInterval(elapsed)) == next)
        }
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: true, lastAttempt: now,
            now: next.addingTimeInterval(1)) == next.addingTimeInterval(1))
    }

    @Test("clock rollback waits one interval without postponing forever on each launch")
    func clockRollback() {
        let future = now.addingTimeInterval(10_000_000)
        let corrected = AutomaticUpdatePolicy.normalizedAttempt(future, now: now)
        #expect(corrected == now)
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: true, lastAttempt: future,
            now: now) == now.addingTimeInterval(604_800))
        let nextLaunch = now.addingTimeInterval(86_400)
        #expect(AutomaticUpdatePolicy.normalizedAttempt(corrected, now: nextLaunch) == now)
        #expect(AutomaticUpdatePolicy.nextCheckDate(enabled: true, lastAttempt: corrected,
            now: nextLaunch) == now.addingTimeInterval(604_800))
    }

    @Test("both languages explain frequency, manual installation and extension consent",
          arguments: [AppLanguage.english, .chinese])
    func guidance(language: AppLanguage) {
        let hint = FileMintStrings.text(.automaticUpdateHint, language: language)
        let finder = FileMintStrings.text(.finderSetup, language: language)
        let modernPath = FileMintStrings.text(.finderSettingsPathModern, language: language)
        let legacyPath = FileMintStrings.text(.finderSettingsPathLegacy, language: language)
        #expect(hint.contains("7"))
        if language == .chinese {
            #expect(hint.contains("下载和安装由你决定"))
            #expect(finder.contains("需要你") && finder.contains("状态会自动刷新"))
            #expect(modernPath.contains("登录项与扩展") && modernPath.contains("Finder"))
            #expect(legacyPath.contains("隐私与安全性") && legacyPath.contains("扩展"))
        } else {
            #expect(hint.contains("Download and install when you choose"))
            #expect(finder.contains("requires you") && finder.contains("refresh its status"))
            #expect(modernPath.contains("Login Items & Extensions") && modernPath.contains("Finder"))
            #expect(legacyPath.contains("Privacy & Security") && legacyPath.contains("Extensions"))
        }
    }
}
