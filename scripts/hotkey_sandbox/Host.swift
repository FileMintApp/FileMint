import AppKit
import Carbon
import FileMintCore

@main
enum HostMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = HostDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class PeerSession {
    init(primary: Bool = false) throws {
        // The host and peer need independent sandbox initialization. The external
        // QA driver launches both, as siblings, and passes readiness over stdin.
        qaEmit("peer-start", ["primary": primary])
        guard readLine() == "READY exclusive" else {
            throw HotKeyFailure.check("separate-process contender readiness")
        }
    }

    static var applicationURL: URL {
        Bundle.main.resourceURL!.appendingPathComponent("FileMintHotKeyPeer.app")
    }

    func stop() {
        qaEmit("peer-stop")
        guard readLine() == "STOPPED" else {
            FileHandle.standardOutput.write(Data("FAIL hotkey sandbox: contender did not stop\n".utf8))
            exit(1)
        }
    }
}

@MainActor
final class HostDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSSearchFieldDelegate {
    private var service: HotKeyService!
    private var control: NSWindow?
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var recorder: Any?
    private let status = NSTextField(wrappingLabelWithString: "")
    private let search = NSSearchField()
    private let feedback = NSTextField(labelWithString: "↑↓ / Return / Escape；组合输入期间不执行")
    private var persistenceURL: URL!
    private var releaseCount = 0
    private var submitCount = 0
    private var selection = 0
    private var modalCount = 0
    private var recording = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let run = Bundle.main.object(forInfoDictionaryKey: "FixtureRunID") as? String ?? "missing"
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("HotKeyQA/\(run)/\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            persistenceURL = directory.appendingPathComponent("binding.json")
            service = try HotKeyService()
            service.onRelease = { [weak self] in self?.receivedHotKey() }
            qaEmit("environment", ["os": ProcessInfo.processInfo.operatingSystemVersionString,
                "screens": NSScreen.screens.count, "runID": run,
                "bundleID": Bundle.main.bundleIdentifier ?? "missing"])
            if CommandLine.arguments.contains("--verify-automation") {
                try verifyAutomation()
                service.shutdown()
                NSApp.terminate(nil)
                return
            }
            installMenu()
            showStatusItem()
            showControl()
        } catch {
            qaEmit("failure", ["reason": String(describing: error)])
            FileHandle.standardOutput.write(Data("FAIL hotkey sandbox: \(error)\n".utf8))
            service?.shutdown()
            exit(1)
        }
    }

    private func persist(_ binding: HotKeyBinding?) throws {
        try JSONEncoder().encode(binding).write(to: persistenceURL, options: .atomic)
    }

    private func installMenu() {
        let main = NSMenu()
        let item = NSMenuItem()
        let menu = NSMenu()
        menu.addItem(withTitle: "显示测试控制台", action: #selector(showControl), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "退出原型", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu; main.addItem(item)
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Copy", #selector(NSText.copy(_:)), "c"),
                                       ("Paste", #selector(NSText.paste(_:)), "v"),
                                       ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        editItem.submenu = edit; main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func showStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "HK QA"
        let menu = NSMenu()
        menu.addItem(withTitle: "显示测试控制台", action: #selector(showControl), keyEquivalent: "").target = self
        menu.addItem(withTitle: "打开搜索原型", action: #selector(showSearch), keyEquivalent: "").target = self
        menu.addItem(withTitle: "退出原型", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu; statusItem = item
    }

    @objc private func showControl() {
        if control == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 485),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "FileMint 全局热键 P0 — 签名沙盒原型"
            window.isReleasedWhenClosed = false; window.delegate = self
            let stack = NSStackView()
            stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false
            let heading = NSTextField(wrappingLabelWithString: "仅操作测试窗口与独立偏好。先启用组合键，再到独立测试应用按键。")
            stack.addArrangedSubview(heading)
            status.setAccessibilityIdentifier("hotkey.status")
            stack.addArrangedSubview(status)
            let actions: [(String, Selector)] = [
                ("打开搜索原型", #selector(showSearch)), ("打开独立测试应用", #selector(openPeer)),
                ("启用 ⌃⌥K", #selector(enable)), ("清除绑定", #selector(clear)),
                ("开始录制", #selector(startRecording)), ("取消录制", #selector(cancelRecording)),
                ("模拟保存失败", #selector(failSave)), ("打开模态对话框", #selector(showModal)),
                ("显示菜单栏图标", #selector(restoreStatus)), ("隐藏菜单栏图标", #selector(hideStatus)),
                ("关闭控制台", #selector(closeControl)), ("退出原型", #selector(quit))]
            for start in stride(from: 0, to: actions.count, by: 2) {
                let row = NSStackView()
                row.spacing = 12
                for (title, action) in actions[start..<min(start + 2, actions.count)] {
                    let button = NSButton(title: title, target: self, action: action)
                    button.setAccessibilityIdentifier("hotkey.\(NSStringFromSelector(action))")
                    row.addArrangedSubview(button)
                }
                stack.addArrangedSubview(row)
            }
            let note = NSTextField(wrappingLabelWithString: "录制仅处理本应用收到的按键；Escape 取消。\n测试面板不会执行文件动作，不读取剪贴板或 Finder 选择。")
            note.textColor = .secondaryLabelColor
            stack.addArrangedSubview(note)
            window.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
                stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
                stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)])
            window.center(); control = window
        }
        NSApp.setActivationPolicy(.regular)
        control?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        refresh()
    }

    private func refresh(_ message: String = "") {
        status.stringValue = "绑定：\(service.binding?.title ?? "未绑定")；生效：\(service.isRegistered ? "是" : "否")；录制：\(recording ? "是" : "否")\n释放回调：\(releaseCount)；搜索执行：\(submitCount)；模态聚焦：\(modalCount)\n\(message)"
    }

    @objc private func enable() { change(.primary) }
    @objc private func clear() { change(nil) }
    private func change(_ binding: HotKeyBinding?) {
        guard !recording else { refresh("先结束录制。"); return }
        do { try service.replace(with: binding, persist: persist); refresh("已保存。"); qaEmit("binding", ["registered": service.isRegistered]) }
        catch { refresh(String(describing: error)); qaEmit("binding-failed", ["reason": String(describing: error)]) }
    }

    @objc private func failSave() {
        do {
            try service.replace(with: service.binding == .alternate ? .primary : .alternate) { _ in
                throw HotKeyFailure.simulatedSaveFailure
            }
        } catch { refresh(String(describing: error)); qaEmit("save-rejected", ["registered": service.isRegistered]) }
    }

    @objc private func startRecording() {
        guard !recording else { return }
        service.suspend(); recording = true
        recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self, self.recording else { return false }
                if event.keyCode == UInt16(kVK_Escape) { self.cancelRecording(); return true }
                do {
                    try self.service.resume()
                    try self.service.replace(with: HotKeyBinding.capture(event), persist: self.persist)
                    self.finishRecording()
                } catch { self.service.suspend(); self.refresh(String(describing: error)) }
                return true
            }
            return consumed ? nil : event
        }
        refresh("请按新的组合键；Escape 取消。"); qaEmit("recording-start")
    }

    @objc private func cancelRecording() { if recording { finishRecording() } }
    private func finishRecording() {
        if let recorder { NSEvent.removeMonitor(recorder) }
        recorder = nil; recording = false
        do { try service.resume(); refresh("录制结束。"); qaEmit("recording-end", ["registered": service.isRegistered]) }
        catch { refresh(String(describing: error)); qaEmit("resume-failed", ["reason": String(describing: error)]) }
    }

    private func receivedHotKey() {
        releaseCount += 1
        qaEmit("system-hotkey-release", ["count": releaseCount, "wasActive": NSApp.isActive,
            "controlVisible": control?.isVisible == true, "statusVisible": statusItem != nil])
        showSearch()
        refresh()
    }

    @objc private func showSearch() {
        if let modal = NSApp.modalWindow ?? control?.attachedSheet ?? panel?.attachedSheet {
            modalCount += 1
            NSApp.activate(ignoringOtherApps: true); modal.makeKeyAndOrderFront(nil)
            qaEmit("modal-priority", ["count": modalCount]); refresh()
            return
        }
        if panel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 550, height: 230),
                styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "FileMint 快捷搜索 — P0"
            window.isReleasedWhenClosed = false; window.delegate = self
            window.hidesOnDeactivate = false
            window.level = .floating
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            search.frame = NSRect(x: 20, y: 170, width: 510, height: 30)
            search.placeholderString = "输入法测试；回车只增加计数"
            search.delegate = self
            search.target = self; search.action = #selector(submitSearch)
            search.sendsWholeSearchString = true
            search.maximumRecents = 0
            search.setAccessibilityIdentifier("hotkey.search")
            feedback.frame = NSRect(x: 20, y: 110, width: 510, height: 40)
            let controls = NSStackView(frame: NSRect(x: 20, y: 25, width: 510, height: 38))
            for (title, action) in [("控制台", #selector(showControl)), ("打开测试应用", #selector(openPeer)),
                                    ("模态测试", #selector(showModal)), ("关闭", #selector(closeSearch))] {
                controls.addArrangedSubview(NSButton(title: title, target: self, action: action))
            }
            window.contentView!.addSubview(search); window.contentView!.addSubview(feedback)
            window.contentView!.addSubview(controls)
            window.center(); panel = window
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(search)
        qaEmit("panel-presented", ["windowNumber": panel!.windowNumber,
            "dockRegular": NSApp.activationPolicy() == .regular])
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Let the input method consume Return/Escape/arrows while composing.
        guard !textView.hasMarkedText() else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            submitSearch()
        case #selector(NSResponder.cancelOperation(_:)):
            closeSearch()
        case #selector(NSResponder.moveDown(_:)): selection = min(2, selection + 1)
        case #selector(NSResponder.moveUp(_:)): selection = max(0, selection - 1)
        default: return false
        }
        feedback.stringValue = "搜索执行：\(submitCount)；模拟选择：\(selection + 1) / 3"
        return true
    }

    @objc private func submitSearch() {
        guard (search.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
        submitCount += 1
        feedback.stringValue = "搜索执行：\(submitCount)；模拟选择：\(selection + 1) / 3"
        qaEmit("search-submit", ["count": submitCount]); refresh()
    }

    func controlTextDidChange(_ notification: Notification) {
        let marked = (search.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
        qaEmit("composition-state", ["marked": marked])
    }

    @objc private func showModal() {
        let alert = NSAlert()
        alert.messageText = "P0 模态窗口测试"
        alert.informativeText = "切到测试应用按热键，应聚焦此对话框。"
        alert.addButton(withTitle: "结束模态测试")
        qaEmit("modal-open")
        alert.runModal()
        qaEmit("modal-close")
    }
    @objc private func openPeer() {
        NSWorkspace.shared.openApplication(at: PeerSession.applicationURL, configuration: .init()) { _, error in
            if let error { qaEmit("peer-open-failed", ["code": (error as NSError).code]) }
        }
    }
    @objc private func hideStatus() {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil; qaEmit("status-hidden")
    }
    @objc private func restoreStatus() { showStatusItem() }
    @objc private func closeControl() { control?.close() }
    @objc private func closeSearch() { panel?.close() }
    @objc private func quit() { NSApp.terminate(nil) }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === control {
            cancelRecording(); NSApp.setActivationPolicy(.accessory); qaEmit("control-closed")
        }
        if window === panel { qaEmit("panel-closed") }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showControl(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) {
        if let recorder { NSEvent.removeMonitor(recorder) }
        service?.shutdown(); qaEmit("shutdown")
    }

    private func verifyAutomation() throws {
        func require(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
            guard try condition() else { throw HotKeyFailure.check(label) }
            qaEmit("check-passed", ["check": label])
        }
        try service.replace(with: .primary, persist: persist)
        try require(service.isRegistered, "exclusive-primary-registered")
        let saved = try Data(contentsOf: persistenceURL)
        let contender = try PeerSession()
        do {
            defer { contender.stop() }
            do {
                try service.replace(with: .alternate, persist: persist)
                throw HotKeyFailure.check("conflict was accepted")
            } catch GlobalShortcutFailure.registration(let code) {
                qaEmit("expected-conflict", ["status": code])
            }
            try require(service.binding == .primary && service.isRegistered, "conflict-preserves-old-registration")
            try require(try Data(contentsOf: persistenceURL) == saved, "conflict-preserves-saved-bytes")
        }
        do {
            try service.replace(with: .alternate) { _ in throw HotKeyFailure.simulatedSaveFailure }
            throw HotKeyFailure.check("save failure was accepted")
        } catch HotKeyFailure.simulatedSaveFailure {}
        try require(service.binding == .primary && service.isRegistered, "save-failure-preserves-old-registration")
        try require(try Data(contentsOf: persistenceURL) == saved, "save-failure-preserves-saved-bytes")
        let releasedCandidate = try PeerSession()
        releasedCandidate.stop()
        qaEmit("check-passed", ["check": "failed-candidate-released-to-other-process"])
        service.suspend()
        try require(!service.isRegistered && service.binding == .primary, "recording-suspends-without-forgetting")
        let suspendedContender = try PeerSession(primary: true)
        do {
            defer { suspendedContender.stop() }
            do {
                try service.resume()
                throw HotKeyFailure.check("resume conflict was accepted")
            } catch GlobalShortcutFailure.registration {}
            try require(!service.isRegistered && service.binding == .primary, "resume-conflict-visible-and-config-retained")
        }
        try service.resume()
        try require(service.isRegistered, "explicit-retry-after-contender-exit")
        try service.replace(with: nil, persist: persist)
        try require(!service.isRegistered && service.binding == nil, "clear-unregisters")
        let removed = try PeerSession(primary: true)
        removed.stop()
        qaEmit("check-passed", ["check": "cleared-binding-released-to-other-process"])
        let decoded = try JSONDecoder().decode(HotKeyBinding?.self, from: saved)
        try service.replace(with: decoded) { _ in }
        try require(service.isRegistered && service.binding == .primary, "saved-keycode-restores")
        try service.replace(with: nil, persist: persist)
        try verifyController()
        FileHandle.standardOutput.write(Data("PASS hotkey sandbox: exclusive registration, independent process conflict, atomic save rollback, suspension, retry and removal\n".utf8))
    }

    private func verifyController() throws {
        func require(_ condition: Bool, _ label: String) throws {
            guard condition else { throw HotKeyFailure.check(label) }
            qaEmit("check-passed", ["check": label])
        }
        let controller = GlobalShortcutController()
        defer { controller.shutdown() }
        controller.start(.init())
        let defaultContender = try PeerSession(primary: true)
        var enabledWasSaved = false
        do {
            defer { defaultContender.stop() }
            do {
                try controller.commit(.init(isEnabled: true, combination: .suggested)) { enabledWasSaved = true }
                throw HotKeyFailure.check("conflicting suggested key enabled")
            } catch GlobalShortcutFailure.registration {}
            try require(!controller.isRegistered && !controller.configuration.isEnabled && !enabledWasSaved,
                        "suggested-key-conflict-keeps-feature-disabled")
        }
        var saved = GlobalShortcutPreferences(isEnabled: false, combination: .primary)
        controller.start(saved)
        try require(!controller.isRegistered, "disabled-combination-does-not-register")
        var enabled = saved; enabled.isEnabled = true
        try controller.commit(enabled) { saved = enabled }
        try require(controller.isRegistered && saved.isEnabled, "controller-enable-registers")
        controller.beginRecording()
        try require(!controller.isRegistered && saved.isEnabled, "recorder-pauses-without-changing-saved-switch")
        controller.endRecording()
        try require(controller.isRegistered, "recorder-cancel-restores-committed-key")
        let contender = try PeerSession()
        let imported = GlobalShortcutPreferences(isEnabled: true, combination: .alternate)
        do {
            defer { contender.stop() }
            do {
                try controller.commit(imported) { saved = imported }
                throw HotKeyFailure.check("controller conflict accepted")
            } catch GlobalShortcutFailure.registration {}
            try require(controller.isRegistered && saved == enabled, "local-conflict-keeps-old-config-and-registration")
            // Imported/external preferences have already been committed to disk.
            saved = imported; controller.reloadSavedConfiguration(imported)
            try require(!controller.isRegistered && controller.configuration == imported && controller.failure != nil,
                        "loaded-conflict-releases-obsolete-key-and-reports-inactive")
        }
        let oldKeyReleased = try PeerSession(primary: true)
        oldKeyReleased.stop()
        controller.retry()
        try require(controller.isRegistered && controller.failure == nil, "loaded-config-explicit-retry")
        var disabled = saved; disabled.isEnabled = false
        do {
            try controller.commit(disabled) { throw HotKeyFailure.simulatedSaveFailure }
            throw HotKeyFailure.check("controller save failure accepted")
        } catch HotKeyFailure.simulatedSaveFailure {}
        try require(controller.isRegistered && controller.configuration == imported, "failed-disable-keeps-active-key")
        try controller.commit(disabled) { saved = disabled }
        try require(!controller.isRegistered && saved.combination == .alternate, "disable-preserves-combination")
    }
}
