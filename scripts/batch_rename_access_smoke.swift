import Darwin
import FileMintCore
import Foundation

/// Exercises real permission failures against disposable grant stores only.
@main
@MainActor
struct BatchRenameAccessSmoke {
    struct Failure: Error { let message: String }
    static var assertions = 0

    static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw Failure(message: message) }
        assertions += 1
    }

    static func run() throws {
        guard CommandLine.arguments.count == 3 else { throw Failure(message: "Expected mode and fixture root") }
        let mode = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let parent = root.appendingPathComponent("items", isDirectory: true).standardizedFileURL
        let items = ["a.txt", "b.txt"].map { parent.appendingPathComponent($0) }
        if mode == "setup" {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            for item in items { try Data("original".utf8).write(to: item, options: .withoutOverwriting) }
        }
        let selection = try BatchRenameSelection.capture(selection: items)
        if mode == "setup" {
            for directory in ["final", "failure"] {
                let store = BatchRenameAccessStore(file: root.appendingPathComponent(directory + "/existing.json"))
                try store.remember(parent: parent, identity: selection.parentIdentity, bookmark: Data([1]))
            }
            return
        }
        guard ["final", "failure"].contains(mode) else { throw Failure(message: "Invalid mode") }
        let directory = root.appendingPathComponent(mode, isDirectory: true)
        // Prove the child policy is active, even if setting the same mode.
        let denied = chmod(directory.appendingPathComponent("existing.json").path, 0o600)
        try check(denied != 0 && [EPERM, EACCES].contains(errno), "Mode changes were not denied by the sandbox")
        for existing in [true, false] {
            let file = directory.appendingPathComponent(existing ? "existing.json" : "new.json")
            let store = BatchRenameAccessStore(file: file)
            let before = existing ? try Data(contentsOf: file) : nil
            if !existing { try check(!FileManager.default.fileExists(atPath: file.path), "New cache unexpectedly exists") }
            var failed = false
            do { try store.remember(parent: parent, identity: selection.parentIdentity, bookmark: Data([2])) }
            catch BatchRenameAccessStoreError.unavailable { failed = true }
            if mode == "final" {
                // Denying chmod on the published pathname must be harmless:
                // all permission changes belong to unpublished temporary files.
                try check(!failed, "Save tried to repair permissions after publication")
                try check(try store.load()[parent.path]?.bookmark == Data([2]), "Saved grant cannot be restored")
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                try check(attributes[.posixPermissions] as? Int == 0o600, "Published grant is not private")
            } else {
                try check(failed, "Expected a temporary-file permission failure")
                if let before {
                    try check(try Data(contentsOf: file) == before, "Failed update replaced the previous grant bytes")
                    try check(try store.load()[parent.path]?.bookmark == Data([1]), "Previous grant became unreadable")
                } else {
                    try check(!FileManager.default.fileExists(atPath: file.path), "Failed first save published a cache")
                    try check(try store.load().isEmpty, "Failed first save blocks the next request")
                }
            }
        }
        let expected = mode == "final" ? ["existing.json", "new.json"] : ["existing.json"]
        try check(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)) == Set(expected),
                  "Caught save failure leaked a temporary cache")
        for item in items { try check(try Data(contentsOf: item) == Data("original".utf8), "Synthetic source changed") }
        print("PASS batch rename grant publication \(mode): \(assertions) assertions")
    }

    static func main() {
        do { try run() }
        catch {
            let message = (error as? Failure)?.message ?? "\((error as NSError).domain) / \((error as NSError).code)"
            FileHandle.standardError.write(Data("FAIL batch rename grant publication: \(message)\n".utf8))
            exit(1)
        }
    }
}
