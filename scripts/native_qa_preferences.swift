import FileMintCore
import SwiftUI

/// Fixture-only settings. Native smoke apps never load the owner's store.
@MainActor
final class PreferencesModel: ObservableObject {
    static let shared = PreferencesModel()
    @Published var preferences = FileMintPreferences.default

    func save() {}

    func preferenceBinding<Value>(_ keyPath: WritableKeyPath<FileMintPreferences, Value>) -> Binding<Value> {
        Binding(get: { self.preferences[keyPath: keyPath] },
                set: { self.preferences[keyPath: keyPath] = $0 })
    }

    func text(_ key: FileMintTextKey) -> String {
        FileMintStrings.text(key, language: preferences.language)
    }

    func menuIconBinding(for slot: MenuIconSlot) -> Binding<MenuIconCustomization?> {
        Binding(get: { self.preferences.menuIcons[slot.rawValue] },
                set: { self.preferences.menuIcons[slot.rawValue] = $0 })
    }
}
