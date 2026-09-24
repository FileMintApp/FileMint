import AppKit
import FileMintCore
import SwiftUI

@main
struct FileMintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = PreferencesModel.shared
    @StateObject private var updater = UpdateModel.shared

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { model.preferences.showMenuBar },
            set: { visible in Task { @MainActor in model.setShowMenuBar(visible) } }
        )) {
            FileMintMenu().environmentObject(model).environmentObject(updater)
        } label: {
            Label("FileMint", image: "MenuBarIcon")
        }
        .commands { FileMintCommands(model: model, updater: updater) }
    }
}

private struct FileMintCommands: Commands {
    @ObservedObject var model: PreferencesModel
    @ObservedObject var updater: UpdateModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(model.text(.customNewFile)) { model.newFile() }.keyboardShortcut("n")
            Button(model.text(.pasteImageFile)) { model.pasteImageFile() }
            Button(FavoriteText.searchAll.text(model.preferences.language)) {
                FavoriteQuickPanelController.shared.show()
            }.keyboardShortcut("k")
            Button(model.text(.importSettings)) { model.importSettings() }
        }
        CommandGroup(replacing: .appSettings) {
            Button(model.text(.openFileMint)) { SettingsWindowController.shared.show() }.keyboardShortcut(",")
        }
        CommandGroup(replacing: .appInfo) {
            Button(model.text(.aboutFileMint)) { showAbout() }
            Button(model.text(.checkForUpdates)) {
                showAbout()
                updater.checkForUpdates()
            }.disabled(updater.isBusy)
        }
    }

    private func showAbout() {
        SettingsWindowController.shared.show(pane: .about)
    }
}

private struct FileMintMenu: View {
    @EnvironmentObject private var model: PreferencesModel
    @EnvironmentObject private var updater: UpdateModel
    @ObservedObject private var favorites = FavoriteLocationsModel.shared

    var body: some View {
        Button(model.text(.customNewFile)) { model.newFile() }.keyboardShortcut("n")
        Button(model.text(.pasteImageFile)) { model.pasteImageFile() }
        Menu(FavoriteText.title.text(model.preferences.language)) {
            ForEach(favorites.quickItems) { item in
                Button(item.name) {
                    do { try favorites.locate(item.id) }
                    catch {
                        favorites.message = FavoriteText.locateFailed.text(model.preferences.language)
                        FavoriteQuickPanelController.shared.show()
                    }
                }
            }
            if !favorites.quickItems.isEmpty { Divider() }
            Button(FavoriteText.searchAll.text(model.preferences.language)) {
                FavoriteQuickPanelController.shared.show()
            }
        }
        Button(model.text(.toggleFinderHiddenItems)) { model.toggleFinderHiddenItems() }
        Button(model.text(.openFileMint)) {
            SettingsWindowController.shared.show()
        }.keyboardShortcut(",")
        if let update = updater.update {
            Button("\(model.text(.availableVersion)) \(update.version.description)…") {
                SettingsWindowController.shared.show(pane: .about)
            }
        }
        Button(model.text(.checkForUpdates)) {
            SettingsWindowController.shared.show(pane: .about)
            updater.checkForUpdates()
        }.disabled(updater.isBusy)
        Divider()
        Button(model.text(.quitFileMint)) { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
