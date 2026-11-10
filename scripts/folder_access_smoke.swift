import AppKit
import FileMintCore
import Security

/// Signed App Sandbox fixture. It accepts only its two test folders and the real
/// home from the picker. Probes touch only generated files, never other items.
@main
@MainActor
final class FolderAccessSmoke: NSObject, NSApplicationDelegate {
    private enum Failure: Error { case arguments, entitlements, unexpectedSelection, invalidFixture }
    private let home = DefaultFolders.resolvedUserHomeDirectory(fileManager: .default)
    private let seed = Data("FileMint folder access QA\n".utf8)

    static func main() {
        let app = NSApplication.shared
        let delegate = FolderAccessSmoke()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defer { NSApp.terminate(nil) }
        guard let run = Bundle.main.object(forInfoDictionaryKey: "FixtureRunID") as? String,
              run.range(of: #"^run\.[A-Za-z0-9]{8}$"#, options: .regularExpression) != nil else { return }
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3, ["off", "on", "unknown"].contains(args[1]),
              args[2].range(of: #"^[a-z0-9-]{1,50}$"#, options: .regularExpression) != nil else { return }
        let (action, fda, label) = (args[0], args[1], args[2])
        let root = home.appendingPathComponent("Library/Application Support/FileMintFolderAccessQA/" + run, isDirectory: true)
        let custom = home.appendingPathComponent("FileMint-FolderAccessQA-" + run, isDirectory: true)
        let documents = home.appendingPathComponent("Documents/FileMint-FolderAccessQA-" + run, isDirectory: true)
        let preferences = root.appendingPathComponent("preferences.json")
        let remembered = RememberedFileAccess(preferencesFile: preferences)
        var result: [String: Any] = ["action": action, "observedSwitch": fda, "pid": getpid()]
        do {
            try verifyEntitlements()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let ordinary = custom.appendingPathComponent("Included", isDirectory: true)
            let preferenceStore = FileMintPreferencesStore(fileURL: preferences)
            let scopes = [ordinary, documents]
            if !FileManager.default.fileExists(atPath: preferences.path) {
                var initial = FileMintPreferences.default
                initial.monitoredFolderURLs = scopes
                try preferenceStore.save(initial)
            }
            let before = try Data(contentsOf: preferences)
            switch action {
            case "authorize-home", "authorize-custom":
                let expected = action == "authorize-home" ? home : custom
                let picker = FolderAccess.directoryWritePanel(for: expected, language: .chinese)
                NSApp.activate(ignoringOtherApps: true)
                if picker.runModal() == .OK, let chosen = picker.url {
                    defer { chosen.stopAccessingSecurityScopedResource() }
                    guard chosen.resolvingSymlinksInPath().path == expected.resolvingSymlinksInPath().path else {
                        throw Failure.unexpectedSelection
                    }
                    try remembered.rememberWriteDirectory(chosen, expected: expected)
                } else { result["cancelled"] = true }
            case "revoke-home", "revoke-custom":
                let target = action == "revoke-home" ? home : custom
                try remembered.forgetDirectoryWrite(at: target.resolvingSymlinksInPath().standardizedFileURL.path)
                fallthrough
            case "probe":
                let roots = preferenceStore.load().monitoredFolderURLs
                result["ordinary"] = probe(ordinary, roots: roots, remembered: remembered)
                result["documents"] = probe(documents, roots: roots, remembered: remembered)
                let outside = custom.appendingPathComponent("Excluded", isDirectory: true)
                let rejected = remembered.start(for: outside, folder: true, mode: .write, roots: roots)
                result["outsideMenuScopeRejected"] = rejected.isEmpty
                rejected.forEach { $0.stopAccessingSecurityScopedResource() }
            default: throw Failure.arguments
            }
            result["savedGrantCount"] = try remembered.directoryWritePaths().count
            result["menuPreferencesUnchanged"] = try Data(contentsOf: preferences) == before
            result["signedSandbox"] = true
        } catch {
            result["error"] = error is Failure ? String(describing: error) : code(error)
        }
        do {
            let output = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .prettyPrinted])
            try output.write(to: root.appendingPathComponent(label + ".json"), options: .withoutOverwriting)
        } catch { print("Folder access QA result could not be written") }
    }

    private func verifyEntitlements() throws {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let values = info as? [String: Any],
              let entitlements = values[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
              entitlements["com.apple.security.app-sandbox"] as? Bool == true,
              entitlements["com.apple.security.files.user-selected.read-write"] as? Bool == true,
              entitlements["com.apple.security.files.bookmarks.app-scope"] as? Bool == true else { throw Failure.entitlements }
    }

    private func probe(_ directory: URL, roots: [URL], remembered: RememberedFileAccess) -> [String: Any] {
        let scopes = remembered.start(for: directory, folder: true, mode: .write, roots: roots)
        defer { scopes.forEach { $0.stopAccessingSecurityScopedResource() } }
        let reading: String
        do { reading = try Data(contentsOf: directory.appendingPathComponent("seed.txt")) == seed ? "ok" : "different" }
        catch { reading = code(error) }
        let writing: String
        do {
            let request = FileCreationRequest(destinationDirectory: directory, template: TemplateCatalog.builtInTemplates[0],
                requestedFileName: "QA-" + UUID().uuidString + ".txt", collisionStrategy: .fail,
                contentMode: .verbatim, fileData: seed)
            let created = try FileCreationService().createFile(request)
            defer { try? FileManager.default.removeItem(at: created.createdURL) }
            guard try Data(contentsOf: created.createdURL) == seed else { throw Failure.invalidFixture }
            writing = "ok"
        } catch { writing = code(error) }
        return ["grantRestored": !scopes.isEmpty, "read": reading, "write": writing]
    }

    private func code(_ error: Error) -> String {
        let value = error as NSError
        return "\(value.domain):\(value.code)"
    }
}
