import AppKit
import FileMintCore
import Foundation

@MainActor
final class PreferencesModel: ObservableObject {
    @Published var preferences: FileMintPreferences
    @Published var lastError: String?

    private let store = FileMintPreferencesStore()

    init() {
        self.preferences = store.load()
    }

    var enabledTemplates: [FileTemplate] {
        TemplateCatalog.enabledTemplates(from: preferences.templates)
    }

    func save() {
        do {
            try store.save(preferences)
            DistributedNotificationCenter.default().post(
                name: Notification.Name(FileMintAppGroup.preferencesDidChangeNotification),
                object: nil
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resetTemplates() {
        preferences.templates = TemplateCatalog.builtInTemplates
        save()
    }

    func addMonitoredFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true

        guard panel.runModal() == .OK else {
            return
        }

        let existing = Set(preferences.monitoredFolderURLs)
        let additions = panel.urls.filter { !existing.contains($0) }
        preferences.monitoredFolderURLs.append(contentsOf: additions)
        save()
    }

    func removeMonitoredFolders(at offsets: IndexSet) {
        preferences.monitoredFolderURLs.remove(atOffsets: offsets)
        save()
    }

    func openExtensionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }
}
