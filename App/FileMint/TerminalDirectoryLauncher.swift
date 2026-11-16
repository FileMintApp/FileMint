import AppKit
import FileMintCore

@MainActor
enum TerminalDirectoryLauncher {
    static func open(_ directory: URL, with application: OpenWithApplication,
                     applicationURL: URL, mode: TerminalOpenMode) async throws {
        guard mode != .applicationDefault else {
            try await OpenWithApplicationAccess.open([directory], with: applicationURL)
            return
        }
        guard let adapter = TerminalAdapter(bundleIdentifier: application.bundleIdentifier),
              adapter.supports(mode) else {
            throw OpenWithError.unsupportedTerminal
        }
        switch adapter {
        case .otty:
            // Otty opens a supplied folder as a terminal tab in the running app.
            try await OpenWithApplicationAccess.open([directory], with: applicationURL)
        case .warp:
            let url = try warpURL(for: directory, mode: mode)
            try await OpenWithApplicationAccess.open([url], with: applicationURL)
        case .terminal, .iterm2, .ghostty:
            // NSPerformService addresses a registered service by name, not by
            // bundle URL. Refuse a saved copy different from the registered app.
            guard let registered = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier),
                  registered.resolvingSymlinksInPath().standardizedFileURL ==
                    applicationURL.resolvingSymlinksInPath().standardizedFileURL else {
                throw OpenWithError.serviceUnavailable
            }
            let serviceName: String
            switch (adapter, mode) {
            case (.terminal, .newTab): serviceName = "New Terminal Tab at Folder"
            case (.terminal, .newWindow): serviceName = "New Terminal at Folder"
            case (.iterm2, .newTab): serviceName = "New iTerm2 Tab Here"
            case (.iterm2, .newWindow): serviceName = "New iTerm2 Window Here"
            case (.ghostty, .newTab): serviceName = "New Ghostty Tab Here"
            case (.ghostty, .newWindow): serviceName = "New Ghostty Window Here"
            default: throw OpenWithError.unsupportedTerminal
            }
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            board.clearContents()
            let legacyFileNames = NSPasteboard.PasteboardType("NSFilenamesPboardType")
            guard board.setPropertyList([directory.path], forType: legacyFileNames),
                  board.setString(directory.path, forType: .string),
                  NSPerformService(serviceName, board) else {
                throw OpenWithError.serviceUnavailable
            }
        }
    }

    static func warpURL(for directory: URL, mode: TerminalOpenMode) throws -> URL {
        guard mode == .newTab || mode == .newWindow else { throw OpenWithError.unsupportedTerminal }
        var parts = URLComponents()
        parts.scheme = "warp"
        parts.host = "action"
        parts.path = mode == .newTab ? "/new_tab" : "/new_window"
        parts.queryItems = [URLQueryItem(name: "path", value: directory.path)]
        guard let url = parts.url else { throw OpenWithError.openFailed }
        return url
    }
}
