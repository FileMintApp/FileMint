import FileMintCore
import AppKit
import SwiftUI

@main
struct FileMintApp: App {
    @StateObject private var model = PreferencesModel()

    var body: some Scene {
        WindowGroup("FileMint", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 500)
        }
        .windowStyle(.titleBar)

        Settings {
            ContentView()
                .environmentObject(model)
                .frame(width: 760, height: 500)
        }

        MenuBarExtra {
            FileMintMenuBarMenu()
                .environmentObject(model)
        } label: {
            Label("FileMint", image: "MenuBarIcon")
        }
    }
}

private struct FileMintMenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: PreferencesModel

    var body: some View {
        Button(model.text(.openFileMint)) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button(model.text(.openExtensionSettings)) {
            model.openExtensionSettings()
        }

        Divider()

        Button(model.text(.quitFileMint)) {
            NSApp.terminate(nil)
        }
    }
}
