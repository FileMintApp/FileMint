import AppKit
import Carbon

@main
enum PeerMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = PeerDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class PeerDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var hotkey: HotKeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--contender") {
            NSApp.setActivationPolicy(.accessory)
            do {
                let service = try HotKeyService()
                let binding: HotKeyBinding = CommandLine.arguments.contains("--primary") ? .primary : .alternate
                try service.replace(with: binding) { _ in }
                hotkey = service
                FileHandle.standardOutput.write(Data("READY exclusive\n".utf8))
                Task.detached {
                    _ = FileHandle.standardInput.readDataToEndOfFile()
                    await MainActor.run { NSApp.terminate(nil) }
                }
                // A broken parent cannot leave a permanent shortcut reservation.
                Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { _ in
                    MainActor.assumeIsolated { NSApp.terminate(nil) }
                }
            } catch {
                FileHandle.standardOutput.write(Data("FAIL contender \(error)\n".utf8))
                exit(1)
            }
            return
        }
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Peer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit; menu.addItem(editItem)
        NSApp.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 630, height: 390),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "FileMint HotKey Peer — 独立前台测试窗口"
        window.collectionBehavior = [.fullScreenPrimary]
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 20, width: 590, height: 350))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds)
        text.isRichText = false
        text.font = .systemFont(ofSize: 20)
        text.string = "此窗口属于独立进程。\n\n在原型中启用 ⌃⌥K，回到这里按组合键。\n可用绿色窗口按钮进入全屏，验证跨 Space 呼出。\n文本仅留在内存，不保存。"
        text.setAccessibilityIdentifier("hotkey.peerText")
        scroll.documentView = text
        window.contentView?.addSubview(scroll)
        self.window = window
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) { hotkey?.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
