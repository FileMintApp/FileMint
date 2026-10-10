import AppKit
import CryptoKit
import FileMintCore
import Security
import Sparkle

@main
@MainActor
final class AccessMigrationSmoke: NSObject, NSApplicationDelegate, SPUUpdaterDelegate, SPUUserDriver {
    private var window: NSWindow!
    private var evidence: NSTextView!
    private var status: NSTextField!
    private var nasPath: NSTextField!
    private var declaredFDA: NSPopUpButton!
    private var updater: SPUUpdater?
    private var busy = false
    private var events: [[String: Any]] = []
    private let folderAccess = FolderAccess()
    private var sandboxed: Bool { Bundle.main.object(forInfoDictionaryKey: "FixtureSandboxed") as? Bool == true }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
    private var store: FileMintPreferencesStore { FileMintPreferencesStore(fileURL: AccessQA.preferences) }
    private var control: URL { AccessQA.root.appendingPathComponent("control") }

    static func main() {
        let app = NSApplication.shared
        let delegate = AccessMigrationSmoke()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        makeWindow()
        do {
            guard Bundle.main.bundleIdentifier == AccessQA.identifier else { throw failure(1) }
            try FileManager.default.createDirectory(at: AccessQA.root, withIntermediateDirectories: true)
            let eventFile = AccessQA.root.appendingPathComponent("events.jsonl")
            if let data = try? String(contentsOf: eventFile, encoding: .utf8) {
                events = data.split(separator: "\n").compactMap {
                    (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any]
                }
            }
            if let last = events.last(where: { $0["event"] as? String == "user-declared-fda" }),
               let value = last["state"] as? Int { declaredFDA.selectItem(at: value) }
            try verifyOwnEntitlement()
            if sandboxed, !FileManager.default.fileExists(atPath: AccessQA.preferences.path) { try seedOldData() }
            record("launch", ["sandbox": sandboxed, "os": ProcessInfo.processInfo.operatingSystemVersionString])
            try checkMigration()
            DistributedNotificationCenter.default().post(name: NSNotification.Name(AccessQA.identifier + ".changed"), object: nil)
            if sandboxed {
                let value = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: self)
                updater = value
                try value.start()
            }
            status.stringValue = "Build \(build) · \(sandboxed ? "沙箱旧原型" : "非沙箱新原型") · 已校验隔离数据"
            if CommandLine.arguments.contains("--control") { runTargets([("control", control)]) }
            if CommandLine.arguments.contains("--local") { localProbes() }
            if CommandLine.arguments.contains("--update") { startUpdate() }
        } catch { fail(error) }
    }

    private func makeWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 690),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "FileMint Access QA — 独立权限迁移原型"
        window.isReleasedWhenClosed = false
        status = NSTextField(wrappingLabelWithString: "Initializing…")
        status.font = .systemFont(ofSize: 17, weight: .semibold)
        let help = NSTextField(wrappingLabelWithString:
            "仅测试独立 QA 身份。请在系统设置中给 FileMint Access QA 开启完全磁盘访问，退出并重新打开。下方状态由你手动记录，不代表应用检测到了系统开关。旧原型若弹出文件夹授权，请取消，以免给新版测试额外授权。")
        declaredFDA = NSPopUpButton()
        declaredFDA.addItems(withTitles: ["FDA 状态：未确认", "用户确认：已开启 FDA", "用户确认：已关闭 FDA"])
        declaredFDA.target = self
        declaredFDA.action = #selector(fdaChanged)
        let settings = NSButton(title: "打开完全磁盘访问设置", target: self, action: #selector(openPrivacySettings))
        let privacy = NSStackView(views: [declaredFDA, settings])
        let probes = NSStackView(views: [
            NSButton(title: "测试本机目录", target: self, action: #selector(localProbes)),
            NSButton(title: "检查旧数据", target: self, action: #selector(checkData)),
            NSButton(title: "执行隔离升级", target: self, action: #selector(startUpdate)),
            NSButton(title: "退出 QA", target: self, action: #selector(quit))])
        nasPath = NSTextField(string: "")
        nasPath.placeholderString = "可选：已挂载的 NAS 测试目录绝对路径（不提供账号密码）"
        let nas = NSStackView(views: [nasPath, NSButton(title: "测试 NAS", target: self, action: #selector(nasProbe))])
        nasPath.widthAnchor.constraint(greaterThanOrEqualToConstant: 530).isActive = true
        evidence = NSTextView()
        evidence.isEditable = false
        evidence.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let scroll = NSScrollView()
        scroll.documentView = evidence
        scroll.hasVerticalScroller = true
        evidence.autoresizingMask = [.width]
        let stack = NSStackView(views: [status, help, privacy, probes, nas, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -24),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 340)
        ])
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func verifyOwnEntitlement() throws {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let values = info as? [String: Any] else { throw failure(2) }
        let entitlements = values[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]
        guard (entitlements["com.apple.security.app-sandbox"] as? Bool == true) == sandboxed else { throw failure(3) }
    }

    private func seedOldData() throws {
        try FileManager.default.createDirectory(at: control, withIntermediateDirectories: true)
        let seed = control.appendingPathComponent("saved.txt")
        try Data("Preserved QA file — 中文\n".utf8).write(to: seed, options: .withoutOverwriting)
        let keys: Set<URLResourceKey> = [.fileResourceIdentifierKey, .volumeUUIDStringKey, .creationDateKey]
        let bookmark = try control.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                                               includingResourceValuesForKeys: keys, relativeTo: nil)
        var preferences = FileMintPreferences.default
        preferences.templates.append(AccessQA.template)
        preferences.language = .chinese
        preferences.launchAtLogin = false
        preferences.showMenuBar = false
        preferences.automaticallyChecksForUpdates = false
        preferences.newFileMenuPlacement = .main
        preferences.favoriteLocations.showListInFinder = false
        preferences.monitoredFolderURLs = [control, AccessQA.home.appendingPathComponent("Desktop"), AccessQA.home.appendingPathComponent("Documents")]
        preferences.monitoredFolderBookmarks = [control.path: bookmark]
        try store.save(preferences)
        let access = OpenWithFolderAccessStore(file: AccessQA.root.appendingPathComponent("open-with-access.json"))
        try access.save([control.path: bookmark])
        let data = try seed.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: keys, relativeTo: nil)
        var metadata = stat()
        guard lstat(seed.path, &metadata) == 0 else { throw failure(4) }
        let favorite = FavoriteLocation(url: seed, bookmark: data, device: UInt64(metadata.st_dev), inode: UInt64(metadata.st_ino),
            createdAt: try seed.resourceValues(forKeys: [.creationDateKey]).creationDate, kind: .file,
            name: "QA 保留收藏", group: "迁移测试", isPinned: true)
        try FavoriteLocationsStore(file: AccessQA.root.appendingPathComponent("favorites.json")).save(FavoriteLocationsCatalog(items: [favorite]))
        var hashes: [String: String] = [:]
        for name in ["preferences.json", "open-with-access.json", "favorites.json", "control/saved.txt"] {
            hashes[name] = try digest(AccessQA.root.appendingPathComponent(name))
        }
        try JSONSerialization.data(withJSONObject: hashes, options: [.sortedKeys]).write(to: AccessQA.root.appendingPathComponent("baseline.json"), options: .withoutOverwriting)
        record("seeded-old-data")
    }

    private func checkMigration() throws {
        let hashes = try JSONSerialization.jsonObject(with: Data(contentsOf: AccessQA.root.appendingPathComponent("baseline.json"))) as! [String: String]
        for name in ["preferences.json", "open-with-access.json", "favorites.json", "control/saved.txt"] {
            guard try hashes[name] == digest(AccessQA.root.appendingPathComponent(name)) else { throw failure(10) }
        }
        let loaded = store.loadWithStatus()
        let preferences = loaded.preferences
        guard !loaded.requiresRecovery, preferences.templates.contains(AccessQA.template),
              !preferences.launchAtLogin, !preferences.showMenuBar, !preferences.automaticallyChecksForUpdates,
              preferences.newFileMenuPlacement == .main, !preferences.favoriteLocations.showListInFinder else { throw failure(11) }
        folderAccess.restore(preferences)
        var stale = false
        let bookmark = preferences.monitoredFolderBookmarks[control.path]!
        let restored = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                               relativeTo: nil, bookmarkDataIsStale: &stale)
        let started = restored.startAccessingSecurityScopedResource()
        defer { if started { restored.stopAccessingSecurityScopedResource() } }
        guard restored.standardizedFileURL == control.standardizedFileURL,
              try digest(restored.appendingPathComponent("saved.txt")) == hashes["control/saved.txt"] else { throw failure(12) }
        let catalog = try FavoriteLocationsStore(file: AccessQA.root.appendingPathComponent("favorites.json")).load()
        guard catalog.items.count == 1, let favorite = catalog.items.first, favorite.isPinned else { throw failure(13) }
        let favoriteURL = try URL(resolvingBookmarkData: favorite.bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                  relativeTo: nil, bookmarkDataIsStale: &stale)
        let favoriteStarted = favoriteURL.startAccessingSecurityScopedResource()
        defer { if favoriteStarted { favoriteURL.stopAccessingSecurityScopedResource() } }
        var identity = stat()
        guard lstat(favoriteURL.path, &identity) == 0, UInt64(identity.st_ino) == favorite.inode,
              UInt64(identity.st_dev) == favorite.device else { throw failure(14) }
        record("migration-check", ["result": "pass", "preferencesAndTemplate": true, "bytesUnchanged": true,
            "folderBookmark": true, "favoriteIdentity": true, "securityScopeStarted": started])
    }

    @objc private func checkData() { do { try checkMigration() } catch { fail(error) } }
    @objc private func fdaChanged() { record("user-declared-fda", ["state": declaredFDA.indexOfSelectedItem]) }
    @objc private func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }
    @objc private func quit() { if !busy { NSApp.terminate(nil) } }
    @objc private func localProbes() {
        runTargets([("control", control), ("desktop", AccessQA.home.appendingPathComponent("Desktop")),
                    ("documents", AccessQA.home.appendingPathComponent("Documents"))])
    }
    @objc private func nasProbe() {
        let path = nasPath.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.hasPrefix("/"), !path.contains("\n") else { status.stringValue = "请输入已挂载的 NAS 测试目录绝对路径。"; return }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .volumeIsLocalKey])
            guard values.isDirectory == true, values.volumeIsLocal == false else {
                record("nas", ["result": "not-run", "reason": "not a mounted network directory"]); return
            }
            runTargets([("nas", url)])
        } catch { record("nas", errorFields(error)) }
    }

    private func runTargets(_ targets: [(String, URL)]) {
        guard !busy, updater?.sessionInProgress != true else { return }
        busy = true
        Task {
            defer { busy = false; status.stringValue = "本轮测试结束；结果见下方。FDA 状态仅为用户声明。" }
            for (label, directory) in targets { await probe(label, directory) }
            // A controlled non-TCC denial must remain a real write failure.
            let readonly = control.appendingPathComponent("readonly-" + UUID().uuidString)
            do {
                try FileManager.default.createDirectory(at: readonly, withIntermediateDirectories: false)
                try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: readonly.path)
                await probe("readonly-control", readonly)
                try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: readonly.path)
                try FileManager.default.removeItem(at: readonly)
            } catch { record("readonly-setup", errorFields(error)) }
        }
    }

    private func probe(_ label: String, _ directory: URL) async {
        let phase = declaredFDA.indexOfSelectedItem
        record("probe-start", ["target": label, "declaredFDA": phase])
        var pickerCount = 0
        do {
            // Exercise the actual app's access helper. Record native panels at
            // their injection seam; never infer FDA from its boolean result.
            let access = try OpenWithFolderAccess(
                store: OpenWithFolderAccessStore(file: AccessQA.root.appendingPathComponent("probe-grants.json")),
                chooseDirectory: { [weak self] url, language in
                    pickerCount += 1
                    self?.record("folder-picker-shown", ["target": label])
                    return OpenWithFolderAccess.chooseDirectory(url, language: language)
                })
            defer { access.release() }
            let allowed = try access.authorize(directory, folders: [directory], language: .chinese)
            record("folder-access", ["target": label, "allowed": allowed, "folderPickers": pickerCount])
            // A cancelled helper dialog must not skip the independent write probe.
            let result = await Task.detached(priority: .userInitiated) { () -> [String: String] in
                let owned = directory.appendingPathComponent("FileMintAccessQA-" + UUID().uuidString, isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: false,
                                                            attributes: [.posixPermissions: 0o700])
                    defer { try? FileManager.default.removeItem(at: owned) }
                    let service = FileCreationService(documentTemplates: DocumentTemplateStore(directory: owned.appendingPathComponent("templates")))
                    let request = FileCreationRequest(destinationDirectory: owned, template: AccessQA.template)
                    let first = try service.createFile(request)
                    let second = try service.createFile(request)
                    guard second.usedCollisionFallback, try Data(contentsOf: first.createdURL) == Data(AccessQA.template.content.utf8) else {
                        return ["result": "fail", "reason": "content or collision mismatch"]
                    }
                    let moved = owned.appendingPathComponent("moved.txt")
                    try FileManager.default.moveItem(at: first.createdURL, to: moved)
                    guard try Data(contentsOf: moved) == Data(AccessQA.template.content.utf8) else { return ["result": "fail"] }
                    try FileManager.default.removeItem(at: owned)
                    return ["result": "pass", "createReadMoveDelete": "pass", "collision": "pass"]
                } catch {
                    let ns = error as NSError
                    let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError
                    return ["result": "denied-or-failed", "domain": ns.domain, "code": String(ns.code),
                            "underlying": underlying.map { "\($0.domain):\($0.code)" } ?? ""]
                }
            }.value
            var fields: [String: Any] = result
            fields["target"] = label
            fields["folderPickers"] = pickerCount
            fields["declaredFDA"] = phase
            record("file-probe", fields)
        } catch {
            var fields = errorFields(error)
            fields["target"] = label
            fields["folderPickers"] = pickerCount
            record("probe-error", fields)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !busy else { return }
        for url in urls where url.scheme == AccessQA.scheme {
            do {
                guard let translated = AccessQA.translated(url, to: "filemint"),
                      let ticket = try AccessQA.tickets.consume(translated, preferences: store.load()) else { continue }
                runTargets([("finder", ticket.directory)])
            } catch { fail(error) }
        }
    }

    @objc private func startUpdate() {
        guard sandboxed, !busy, let updater, !updater.sessionInProgress else { return }
        record("update-requested")
        updater.checkForUpdates()
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error { fail(error) }
    }
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { record("update-checking") }
    func showUpdateFound(with item: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard item.versionString == "28" else { reply(.dismiss); return }
        record("update-found", ["version": item.versionString]); reply(.install)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) { fail(error); acknowledgement() }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) { fail(error); acknowledgement() }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { record("update-download") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { record("update-extract") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        record("update-ready"); reply(busy ? .dismiss : .install)
    }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        record("update-installing", ["terminated": applicationTerminated])
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func dismissUpdateInstallation() { record("update-dismissed") }
    func showUpdateInFocus() { window.makeKeyAndOrderFront(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !busy }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { busy ? .terminateCancel : .terminateNow }

    private func failure(_ code: Int) -> NSError { NSError(domain: "AccessQA", code: code) }
    private func digest(_ url: URL) throws -> String { SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined() }
    private func errorFields(_ error: Error) -> [String: Any] {
        let value = error as NSError
        return ["result": "fail", "domain": value.domain, "code": value.code]
    }
    private func fail(_ error: Error) {
        let value = error as NSError
        status.stringValue = "FAIL: \(value.domain) \(value.code)"
        record("error", errorFields(error))
    }
    private func record(_ event: String, _ fields: [String: Any] = [:]) {
        var value = fields
        value["event"] = event
        value["build"] = build
        value["pid"] = ProcessInfo.processInfo.processIdentifier
        value["time"] = ISO8601DateFormatter().string(from: Date())
        events.append(value)
        do {
            var data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            data.append(0x0A)
            let url = AccessQA.root.appendingPathComponent("events.jsonl")
            if !FileManager.default.fileExists(atPath: url.path) { try Data().write(to: url, options: .withoutOverwriting) }
            let file = try FileHandle(forWritingTo: url)
            defer { try? file.close() }
            try file.seekToEnd()
            try file.write(contentsOf: data)
            evidence.string = events.suffix(70).compactMap {
                (try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys])).flatMap { String(data: $0, encoding: .utf8) }
            }.joined(separator: "\n")
            evidence.scrollToEndOfDocument(nil)
        } catch { status.stringValue = "FAIL: QA evidence could not be saved" }
    }
}
