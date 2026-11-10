import AppKit
import Carbon
import FileMintCore

@MainActor
enum FinderHiddenFilesChecks {
    static func run(root: URL) async throws {
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw TemplateWorkflowSmoke.CheckFailure(message: message) }
        }
        let tahoe = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
        let goldenGate = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        let englishLegacy = FinderHiddenFilesService.permissionMessage(language: .english, systemVersion: tahoe)
        let englishCurrent = FinderHiddenFilesService.permissionMessage(language: .english, systemVersion: goldenGate)
        let chineseLegacy = FinderHiddenFilesService.permissionMessage(language: .chinese, systemVersion: tahoe)
        let chineseCurrent = FinderHiddenFilesService.permissionMessage(language: .chinese, systemVersion: goldenGate)
        try require(englishLegacy.contains("Privacy & Security → Accessibility") &&
                    englishCurrent.contains("Privacy & Security → Device Control and Data Access") &&
                    chineseLegacy.contains("隐私与安全性 → 辅助功能") &&
                    chineseCurrent.contains("隐私与安全 → 设备控制和数据访问"),
                    "Permission guidance must match the system version in both languages")
        try require([englishLegacy, englishCurrent].allSatisfy { $0.contains("quit and reopen FileMint") } &&
                    [chineseLegacy, chineseCurrent].allSatisfy { $0.contains("退出并重新打开 FileMint") },
                    "Permission guidance must explain how to refresh the grant")

        guard let events = FinderHiddenFilesService.shortcutEvents() else {
            throw TemplateWorkflowSmoke.CheckFailure(message: "Could not construct the Finder shortcut")
        }
        try require(events.map(\.type) == [.flagsChanged, .flagsChanged, .keyDown, .keyUp, .flagsChanged, .flagsChanged],
                    "Expected complete modifier and period key transitions")
        try require(events.map { Int($0.getIntegerValueField(.keyboardEventKeycode)) } ==
                    [kVK_Command, kVK_Shift, kVK_ANSI_Period, kVK_ANSI_Period, kVK_Shift, kVK_Command],
                    "The key sequence was not Command-Shift-Period")
        let modifiers: CGEventFlags = [.maskCommand, .maskShift]
        try require(events.map(\.flags) == [.maskCommand, modifiers, modifiers, modifiers, .maskCommand, []],
                    "The shortcut did not release both modifiers")

        // Use a path with no on-disk entry. This is menu scope, not an I/O target.
        let menuFolder = root.appendingPathComponent("menu-folder", isDirectory: true)
        let preferencesFile = root.appendingPathComponent("settings.json")
        let preferencesStore = FileMintPreferencesStore(fileURL: preferencesFile)
        let ticketDirectory = root.appendingPathComponent("tickets", isDirectory: true)
        let tickets = FileOperationTicketStore(directory: ticketDirectory)
        let now = Date()
        var preferences = FileMintPreferences.default
        preferences.language = .chinese
        preferences.monitoredFolderURLs = [menuFolder]
        preferences.fileTools.isEnabled = true
        preferences.fileTools.fileVisibility = true
        try preferencesStore.save(preferences)
        let originalPreferences = try Data(contentsOf: preferencesFile)
        var dispatched: [AppLanguage] = []
        let coordinator = FileOperationCoordinator(tickets: tickets, preferencesFile: preferencesFile,
            ticketClock: { now }, hiddenFilesToggle: { dispatched.append($0) })

        func waitForDispatch() async throws {
            for _ in 0..<100 where coordinator.isBusy { try await Task.sleep(for: .milliseconds(20)) }
            try require(!coordinator.isBusy, "The toggle did not release operation ownership")
        }

        let request = FileOperationRequest.toggleHiddenFiles(directory: menuFolder)
        let url = try tickets.enqueue(request, now: now)
        coordinator.enqueue(url)
        try await waitForDispatch()
        coordinator.enqueue(url)
        try await waitForDispatch()
        try require(dispatched == [.chinese], "A Finder request must reach dispatch only once")
        try require(try Data(contentsOf: preferencesFile) == originalPreferences, "The toggle rewrote saved preferences")

        let expired = try tickets.enqueue(request, now: now.addingTimeInterval(-61))
        coordinator.enqueue(expired)
        try await waitForDispatch()
        let outside = try tickets.enqueue(.toggleHiddenFiles(directory: root), now: now)
        coordinator.enqueue(outside)
        try await waitForDispatch()
        let revoked = try tickets.enqueue(request, now: now)
        coordinator.enqueue(revoked)
        preferences.fileTools.fileVisibility = false
        try preferencesStore.save(preferences)
        try await waitForDispatch()
        preferences.fileTools.fileVisibility = true
        try preferencesStore.save(preferences)

        guard let release = coordinator.reserveExternalPresentation() else {
            throw TemplateWorkflowSmoke.CheckFailure(message: "Could not reserve the coordinator")
        }
        let busy = try tickets.enqueue(request, now: now)
        coordinator.enqueue(busy)
        let id = URLComponents(url: busy, resolvingAgainstBaseURL: false)?.queryItems?.first?.value ?? ""
        let pending = ticketDirectory.appendingPathComponent("\(id).json")
        for _ in 0..<100 where FileManager.default.fileExists(atPath: pending.path) {
            try await Task.sleep(for: .milliseconds(20))
        }
        let consumedWhileBusy = !FileManager.default.fileExists(atPath: pending.path)
        release()
        try await waitForDispatch()
        try require(consumedWhileBusy && dispatched == [.chinese], "Expired, out-of-scope, revoked or busy requests dispatched")
        print("PASS Finder hidden files: permission guidance, native shortcut events, single-use dispatch, scope, revocation, busy and expiry")
    }
}
