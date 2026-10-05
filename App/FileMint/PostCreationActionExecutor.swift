import AppKit
import FileMintCore

@MainActor
final class PostCreationActionExecutor {
    enum Failure: Error { case savedItemChanged, editorRequired, applicationUnavailable, handoffFailed }
    private(set) var activeCount = 0
    private var accepted = Set<UUID>()
    let gate: () -> CreationOpeningGate
    let nativeOpen: ([URL], URL) async throws -> Void
    let reveal: ([URL]) -> Void
    let defaultHandler: (URL) -> URL?
    let editingPolicy: (String, Bool) -> Bool
    let verifyEditor: @Sendable (String, URL) throws -> Void
    init(gate: @escaping () -> CreationOpeningGate,
         nativeOpen: @escaping ([URL], URL) async throws -> Void = { try await OpenWithApplicationAccess.open($0, with: $1) },
         reveal: @escaping ([URL]) -> Void = { NSWorkspace.shared.activateFileViewerSelecting($0) },
         defaultHandler: @escaping (URL) -> URL? = { NSWorkspace.shared.urlForApplication(toOpen: $0) },
         editingPolicy: @escaping (String, Bool) -> Bool = { CreationEditingPolicy.permits(bundleIdentifier: $0, isDocument: $1) },
         verifyEditor: @escaping @Sendable (String, URL) throws -> Void = { try CreationEditorIdentity.validate(identifier: $0, at: $1) }) {
        self.gate = gate; self.nativeOpen = nativeOpen; self.reveal = reveal
        self.defaultHandler = defaultHandler; self.editingPolicy = editingPolicy; self.verifyEditor = verifyEditor
    }

    @discardableResult
    func complete(_ result: FileCreationResult, followUp: CreationFollowUp, language: AppLanguage, presentFailures: Bool = true) async -> Bool {
        guard accepted.insert(followUp.id).inserted else { return false }
        activeCount += 1
        defer {
            activeCount -= 1
        }
        var action = followUp.action
        var application = followUp.application
        while true {
            do {
                try await execute(result, action: action, application: application, followUp: followUp)
                return true
            } catch {
                if !presentFailures { return false }
                let textKey: TemplateWorkflowText = switch error {
                case Failure.savedItemChanged: .savedUnavailable
                case Failure.editorRequired: .unsupportedEditor
                default: .unresolvedApp
                }
                let alert = NSAlert()
                alert.messageText = TemplateWorkflowText.savedOpenFailed.text(language)
                alert.informativeText = textKey.text(language)
                alert.addButton(withTitle: FileMintStrings.text(.cancel, language: language))
                if textKey != .savedUnavailable {
                    alert.addButton(withTitle: TemplateWorkflowText.reveal.text(language))
                    alert.addButton(withTitle: TemplateWorkflowText.retryOpen.text(language))
                    alert.addButton(withTitle: TemplateWorkflowText.chooseApp.text(language))
                }
                NSApp.activate(ignoringOtherApps: true)
                switch alert.runModal() {
                case .alertSecondButtonReturn: action = .init(.revealInFinder)
                case .alertThirdButtonReturn: break
                case NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertFirstButtonReturn.rawValue + 3):
                    let picker = NSOpenPanel()
                    picker.canChooseDirectories = false; picker.allowsMultipleSelection = false
                    picker.allowedContentTypes = [.applicationBundle]
                    picker.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
                    guard picker.runModal() == .OK, let url = picker.url else { return false }
                    do {
                        let captured = try await Task.detached { try OpenWithApplicationAccess.capture(url) }.value
                        let app = CreationApplication(id: captured.id,
                            hint: .init(bundleIdentifier: captured.bundleIdentifier, displayName: captured.name),
                            url: captured.url, bookmark: captured.bookmark)
                        application = app
                        action = .init(.openWithApplication, application: app.hint, localApplicationID: app.id)
                    } catch { continue }
                default: return false
                }
            }
        }
    }

    /// Public to isolated native fixtures; no writer is accessible from a retry.
    func execute(_ result: FileCreationResult, action requested: TemplateCreationAction,
                 application: CreationApplication?, followUp: CreationFollowUp) async throws {
        let action = gate().permits(followUp.permission) ? requested : followUp.fallback
        guard action.kind != .none else { return }
        guard let identity = result.identity else { throw Failure.savedItemChanged }
        do { try identity.validate(result.createdURL) } catch { throw Failure.savedItemChanged }
        if action.kind == .revealInFinder { reveal([result.createdURL]); return }
        let appURL: URL
        let selected: OpenWithApplication?
        if action.kind == .openWithApplication {
            guard let application, application.id == action.localApplicationID,
                  application.hint == action.application else { throw Failure.applicationUnavailable }
            selected = application.openWithApplication
            do { appURL = try await Task.detached { try OpenWithApplicationAccess.resolve(application.openWithApplication) }.value }
            catch { throw Failure.applicationUnavailable }
        } else {
            selected = nil
            guard let handler = defaultHandler(result.createdURL) else { throw Failure.applicationUnavailable }
            appURL = handler
        }
        let granted = appURL.startAccessingSecurityScopedResource()
        defer { if granted { appURL.stopAccessingSecurityScopedResource() } }
        let identifier: String
        do {
            identifier = try await Task.detached {
                if let selected { try OpenWithApplicationAccess.validate(selected, at: appURL) }
                return try OpenWithApplicationAccess.validatedIdentifier(at: appURL)
            }.value
        } catch { throw Failure.applicationUnavailable }
        guard editingPolicy(identifier, result.contentKind != .text) else { throw Failure.editorRequired }
        let validator = verifyEditor
        try await Task.detached { try validator(identifier, appURL) }.value
        do { try identity.validate(result.createdURL) } catch { throw Failure.savedItemChanged }
        // This recheck is after all asynchronous app validation and immediately
        // before invoking LaunchServices. Turning off/on invalidates this request.
        guard gate().permits(followUp.permission) else {
            if followUp.fallback.kind == .revealInFinder { reveal([result.createdURL]) }
            return
        }
        do { try await nativeOpen([result.createdURL], appURL) } catch { throw Failure.handoffFailed }
    }
}
