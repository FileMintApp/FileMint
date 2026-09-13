import AppKit
import Darwin
import FileMintCore
import UniformTypeIdentifiers

/// Interactive regression: the actual client must run in an App Sandbox.
@MainActor
final class UpdateSandboxSmoke: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var output: NSTextView!
    private var update: AppUpdate?
    private let client = UpdateClient()
    private var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 330),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "FileMint sandbox update regression"
        let actions: [(String, Selector)] = [
            ("Check release", #selector(checkRelease)),
            ("Reject unapproved save", #selector(rejectUnapprovedSave)),
            ("Save with system dialog", #selector(saveApprovedInstaller))
        ]
        for (index, action) in actions.enumerated() {
            let button = NSButton(title: action.0, target: self, action: action.1)
            button.frame = NSRect(x: 14 + index * 218, y: 282, width: 212, height: 32)
            window.contentView?.addSubview(button)
        }
        output = NSTextView(frame: NSRect(x: 18, y: 16, width: 644, height: 250))
        output.isEditable = false
        output.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        output.string = "Use Check release, test rejection, then save with the system dialog.\nNo installer is opened automatically.\n"
        window.contentView?.addSubview(output)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func checkRelease() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                update = try await client.check(currentVersion: "0.0.0")
                output.string += "Release: \(update?.version.description ?? "none")\n"
            } catch { output.string += "FAIL check: \(error)\n" }
        }
    }

    @objc private func rejectUnapprovedSave() {
        guard !busy, let update else { return }
        busy = true
        Task {
            defer { busy = false }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                _ = try await client.download(update, to: directory.appendingPathComponent(update.fileName),
                                              progress: { _ in }, verifying: {})
                output.string += "FAIL: unapproved installer was accepted\n"
            } catch UpdateClientError.installerAuthorizationFailed {
                output.string += "PASS: sandbox no-user-consent installer rejected\n"
            } catch { output.string += "FAIL unexpected rejection: \(error)\n" }
        }
    }

    @objc private func saveApprovedInstaller() {
        guard !busy, let update else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.diskImage]
        panel.nameFieldStringValue = update.fileName
        guard panel.runModal() == .OK, let destination = panel.url else {
            output.string += "PASS: save-panel cancellation started no download\n"
            return
        }
        busy = true
        let accessing = destination.startAccessingSecurityScopedResource()
        Task {
            defer {
                if accessing { destination.stopAccessingSecurityScopedResource() }
                busy = false
            }
            do {
                let installer = try await client.download(update, to: destination, progress: { _ in }, verifying: {})
                try await client.validateInstaller(installer)
                let url = installer.url
                var bytes = [UInt8](repeating: 0, count: 4096)
                let count = getxattr(url.path, "com.apple.quarantine", &bytes, bytes.count, 0, 0)
                let attribute = count > 0 ? String(decoding: bytes.prefix(count), as: UTF8.self) : nil
                guard InstallerQuarantinePolicy.allowsGatekeeperAssessment(attribute) else {
                    throw UpdateClientError.installerAuthorizationFailed
                }
                output.string += "PASS: verified \(update.fileName), quarantine \(attribute?.components(separatedBy: ";").first ?? "missing")\n"
            } catch { output.string += "FAIL approved save: \(error)\n" }
        }
    }
}

@main
struct SandboxSmokeMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = UpdateSandboxSmoke()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
