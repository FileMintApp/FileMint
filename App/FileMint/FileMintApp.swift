import AppKit
import FileMintCore
import SwiftUI

@main
struct FileMintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = PreferencesModel.shared

    var body: some Scene {
        Window("FileMint", id: "main") {
            ContentView().environmentObject(model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(model.text(.customNewFile)) { model.newFile() }.keyboardShortcut("n")
                Button(model.text(.importSettings)) { model.importSettings() }
            }
        }
        MenuBarExtra(isInserted: Binding(
            get: { model.preferences.showMenuBar },
            set: { visible in Task { @MainActor in model.setShowMenuBar(visible) } }
        )) {
            FileMintMenu().environmentObject(model)
        } label: {
            Label("FileMint", image: "MenuBarIcon")
        }
    }
}

private struct FileMintMenu: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        Button(model.text(.customNewFile)) { model.newFile() }.keyboardShortcut("n")
        Button(model.text(.openFileMint)) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }.keyboardShortcut(",")
        Divider()
        Button(model.text(.quitFileMint)) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
