import AppKit
import Combine
import FileMintCore

@MainActor
final class GlobalShortcutController: ObservableObject {
    @Published private(set) var configuration = GlobalShortcutPreferences()
    @Published private(set) var isRegistered = false
    @Published private(set) var isRecording = false
    @Published private(set) var failure: GlobalShortcutFailure?
    private var service: GlobalShortcutService?
    private var started = false
    var onTrigger: () -> Void = {}

    func start(_ configuration: GlobalShortcutPreferences) {
        started = true
        reloadSavedConfiguration(configuration, retry: true)
    }

    /// A loaded snapshot is already authoritative on disk. Never leave an old
    /// combination active when a different saved combination cannot be restored.
    func reloadSavedConfiguration(_ next: GlobalShortcutPreferences, retry: Bool = false) {
        guard next != configuration || retry else { return }
        configuration = next
        guard started, !isRecording else { return }
        do {
            if let key = next.effectiveCombination {
                try GlobalShortcutKeyboard.validate(key)
                try registrar().replace(with: key) { _ in }
            } else { try service?.replace(with: nil) { _ in } }
            failure = nil
        } catch {
            try? service?.replace(with: nil) { _ in }
            failure = error as? GlobalShortcutFailure
        }
        isRegistered = service?.isRegistered == true
    }

    func commit(_ next: GlobalShortcutPreferences, persist: () throws -> Void) throws {
        guard next != configuration else { try persist(); return }
        do {
            if let key = next.combination,
               next.combination != configuration.combination || (next.isEnabled && !configuration.isEnabled) {
                try GlobalShortcutKeyboard.validate(key)
            }
            if started {
                if next.effectiveCombination != nil || service != nil {
                    try registrar().replace(with: next.effectiveCombination) { _ in try persist() }
                } else { try persist() }
            } else { try persist() }
            configuration = next
            failure = nil
        } catch {
            failure = error as? GlobalShortcutFailure
            throw error
        }
        isRegistered = service?.isRegistered == true
    }

    func beginRecording() {
        guard !isRecording else { return }
        service?.suspend(); isRecording = true; isRegistered = false; failure = nil
    }

    func endRecording() {
        guard isRecording else { return }
        isRecording = false
        // Release the paused registration's old desired value before restoring
        // the latest saved configuration (an external edit may have arrived).
        try? service?.replace(with: nil) { _ in }
        try? service?.resume()
        reloadSavedConfiguration(configuration, retry: true)
    }

    func retry() { reloadSavedConfiguration(configuration, retry: true) }

    func shutdown() {
        service?.shutdown(); service = nil
        started = false; isRecording = false; isRegistered = false
    }

    private func registrar() throws -> GlobalShortcutService {
        if let service { return service }
        let instance = try GlobalShortcutService()
        instance.onRelease = { [weak self] in self?.onTrigger() }
        service = instance
        return instance
    }
}
