import AppKit
import FileMintCore
import Foundation

@MainActor
final class PreferencesModel: ObservableObject {
    @Published var preferences: FileMintPreferences
    @Published var lastError: String?

    private let store = FileMintPreferencesStore()

    init() {
        var loadedPreferences = store.load()
        loadedPreferences.templates = TemplateCatalog.sortedTemplates(from: loadedPreferences.templates)
        self.preferences = loadedPreferences
    }

    var enabledTemplates: [FileTemplate] {
        TemplateCatalog.enabledTemplates(from: preferences.templates)
    }

    var permissionGuideSteps: [PermissionGuideStep] {
        PermissionGuide.steps(language: preferences.language)
    }

    func text(_ key: FileMintTextKey) -> String {
        FileMintStrings.text(key, language: preferences.language)
    }

    func templateDisplayName(for template: FileTemplate) -> String {
        FileMintStrings.templateDisplayName(for: template, language: preferences.language)
    }

    func templateGroupName(for template: FileTemplate) -> String {
        FileMintStrings.templateGroupName(for: template, language: preferences.language)
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

    func moveTemplates(fromOffsets source: IndexSet, toOffset destination: Int) {
        preferences.templates = TemplateCatalog.reorderedTemplates(
            preferences.templates,
            moving: source,
            to: destination
        )
        save()
    }

    func moveTemplate(id: String, by offset: Int) {
        let orderedTemplates = TemplateCatalog.sortedTemplates(from: preferences.templates)
        guard let sourceIndex = orderedTemplates.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = sourceIndex + offset
        guard orderedTemplates.indices.contains(destinationIndex) else {
            return
        }

        let destinationOffset = offset > 0 ? destinationIndex + 1 : destinationIndex
        moveTemplates(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationOffset)
    }

    func canMoveTemplate(id: String, by offset: Int) -> Bool {
        let orderedTemplates = TemplateCatalog.sortedTemplates(from: preferences.templates)
        guard let sourceIndex = orderedTemplates.firstIndex(where: { $0.id == id }) else {
            return false
        }

        return orderedTemplates.indices.contains(sourceIndex + offset)
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
