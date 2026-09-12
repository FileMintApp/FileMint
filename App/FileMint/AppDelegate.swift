import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await PreferencesModel.shared.prepareLoginItemIfNeeded() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { PreferencesModel.shared.handle(url: url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
