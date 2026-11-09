import AppKit
import FileMintCore

/// Copy and File Info use the same saved read-only grants, held per operation.
@MainActor
final class FileInfoReadAccess {
    private let remembered: RememberedFileAccess
    private(set) var activeScopes: [URL] = []
    private var panel: NSOpenPanel?

    init(preferencesFile: URL?) {
        remembered = RememberedFileAccess(preferencesFile: preferencesFile)
    }

    func restore(for selection: FileInfoSelection, preferences: FileMintPreferences) {
        guard OpenWithPolicy.isLocalFileURL(selection.parent), selection.parent.path.hasPrefix("/") else { return }
        activeScopes += FolderAccess.startSavedAccess(to: selection.source.deletingLastPathComponent(),
                                                       resolved: selection.parent, in: preferences)
        activeScopes += remembered.start(for: selection.resolvedSource, folder: false, mode: .read,
                                         roots: preferences.monitoredFolderURLs)
    }

    func request(for selection: FileInfoSelection, language: AppLanguage, currentRoots: () throws -> [URL]) throws -> Bool {
        let message = String(format: FileInfoText.authorizeFileOrParent.text(language),
                             selection.source.lastPathComponent, selection.parent.lastPathComponent)
        let picker = FolderAccess.authorizationPanel(for: selection.resolvedSource, selection: .item, language: language)
        picker.message = message
        // Show the parent as a selectable row. The user can enter it to choose the file.
        picker.directoryURL = selection.parent.deletingLastPathComponent()
        let delegate = FileInfoAccessPicker(selection: selection, message: message)
        picker.delegate = delegate
        panel = picker
        defer { panel = nil }
        NSApp.activate(ignoringOtherApps: true)
        guard withExtendedLifetime(delegate, { picker.runModal() }) == .OK, let chosen = picker.url else { return false }
        try remember(chosen, for: selection, in: currentRoots())
        return true
    }

    /// Only an explicit picker selection may reach this boundary.
    func remember(_ chosen: URL, for selection: FileInfoSelection, in roots: [URL]) throws {
        guard let target = Self.target(for: chosen, selection: selection) else { throw FileInfoError.invalidSelection }
        let scope = try remembered.remember(chosen, target: target.url, folder: target.folder, mode: .read, roots: roots) {
            try selection.validate(in: roots)
        }
        activeScopes.append(scope)
    }

    func cancelPicker() { panel?.cancel(nil) }

    func release() {
        activeScopes.forEach { $0.stopAccessingSecurityScopedResource() }
        activeScopes.removeAll()
    }

    fileprivate static func target(for chosen: URL, selection: FileInfoSelection) -> (url: URL, folder: Bool)? {
        guard OpenWithPolicy.isLocalFileURL(chosen) else { return nil }
        let path = chosen.standardizedFileURL.path
        if path == selection.source.path || path == selection.resolvedSource.path { return (selection.resolvedSource, false) }
        if path == selection.parent.path || path == selection.source.deletingLastPathComponent().path { return (selection.parent, true) }
        return nil
    }

}

@MainActor
private final class FileInfoAccessPicker: NSObject, NSOpenSavePanelDelegate {
    let selection: FileInfoSelection
    let message: String

    init(selection: FileInfoSelection, message: String) {
        self.selection = selection; self.message = message
    }

    func panel(_ sender: Any, validate url: URL) throws {
        guard FileInfoReadAccess.target(for: url, selection: selection) != nil else {
            throw CocoaError(.fileReadNoPermission, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
