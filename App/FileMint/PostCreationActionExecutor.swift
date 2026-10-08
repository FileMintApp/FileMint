import AppKit
import FileMintCore

@MainActor
final class PostCreationActionExecutor {
    enum Failure: Error {
        case savedItemChanged, applicationUnavailable, handoffFailed, defaultHandoffFailed

        var textKey: TemplateWorkflowText {
            switch self {
            case .savedItemChanged: .savedUnavailable
            case .applicationUnavailable: .openingApplicationUnavailable
            case .handoffFailed: .applicationOpenFailed
            case .defaultHandoffFailed: .defaultApplicationOpenFailed
            }
        }
    }
    private(set) var activeCount = 0
    private var accepted = Set<UUID>()
    let gate: () -> CreationOpeningGate
    let nativeOpen: ([URL], URL) async throws -> Void
    let nativeOpenDefault: (URL) async throws -> Void
    let reveal: ([URL]) -> Void
    init(gate: @escaping () -> CreationOpeningGate,
         nativeOpen: @escaping ([URL], URL) async throws -> Void = { try await OpenWithApplicationAccess.open($0, with: $1) },
         nativeOpenDefault: @escaping (URL) async throws -> Void = { try await OpenWithApplicationAccess.openWithDefaultApplication($0) },
         reveal: @escaping ([URL]) -> Void = { NSWorkspace.shared.activateFileViewerSelecting($0) }) {
        self.gate = gate; self.nativeOpen = nativeOpen; self.nativeOpenDefault = nativeOpenDefault; self.reveal = reveal
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
                let textKey = (error as? Failure)?.textKey ?? .openingApplicationUnavailable
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
        if action.kind == .openWithDefaultApp {
            // Resolve the association inside LaunchServices at each dispatch,
            // including retries, instead of selecting or filtering an editor.
            do { try await nativeOpenDefault(result.createdURL) } catch { throw Failure.defaultHandoffFailed }
            return
        }
        guard let application, application.id == action.localApplicationID,
              application.hint == action.application else { throw Failure.applicationUnavailable }
        let appURL: URL
        do { appURL = try await Task.detached { try OpenWithApplicationAccess.resolve(application.openWithApplication) }.value }
        catch { throw Failure.applicationUnavailable }
        let granted = appURL.startAccessingSecurityScopedResource()
        defer { if granted { appURL.stopAccessingSecurityScopedResource() } }
        do {
            try await Task.detached {
                try OpenWithApplicationAccess.validate(application.openWithApplication, at: appURL)
            }.value
        } catch { throw Failure.applicationUnavailable }
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
