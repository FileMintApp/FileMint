import AppKit
import FileMintCore
import SwiftUI

@main
struct FileMintApp: App {
    @StateObject private var model = PreferencesModel()

    var body: some Scene {
        Window("FileMint", id: "main") {
            ContentView().environmentObject(model)
                .onOpenURL { model.handle(url: $0) }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(model.text(.customNewFile)) { model.newFile() }.keyboardShortcut("n")
                Button(model.preferences.language == .english ? "Import Settings…" : "导入设置…") { model.importSettings() }
            }
        }
        MenuBarExtra {
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
