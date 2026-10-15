import Darwin
import FileMintCore
import Foundation

/// A headless subprocess with directory/content reads and all fixture writes denied.
/// This deliberately cannot use the container-local access of the GUI smoke app.
@main
@MainActor
struct BatchRenameCaptureSmoke {
    struct Failure: Error { let message: String }
    static var assertions = 0

    static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
        assertions += 1
    }

    static func expectDenied(_ body: () throws -> Void) throws {
        do { try body() }
        catch let error as NSError where error.domain == NSPOSIXErrorDomain && [EPERM, EACCES].contains(Int32(error.code)) {
            assertions += 1
            return
        }
        throw Failure(message: "Expected a sandbox permission denial")
    }

    static func deniedOpen(_ url: URL, directory: Bool) throws {
        let fd = open(url.path, O_RDONLY | O_CLOEXEC | (directory ? O_DIRECTORY : 0))
        if fd >= 0 {
            close(fd)
            throw Failure(message: "Fixture data is readable; sandbox regression is inactive")
        }
        try check([EPERM, EACCES].contains(errno), "Open failed for a reason other than sandbox access")
    }

    static func run() throws {
        guard CommandLine.arguments.count == 3 else { throw Failure(message: "Expected fixture and control directories") }
        let parent = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let control = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try deniedOpen(parent, directory: true)
        try deniedOpen(parent.appendingPathComponent("IMG_2.JPG"), directory: false)

        let names = ["IMG_10.JPG", "IMG_2.JPG", "Photos"]
        let selection = try BatchRenameSelection.capture(selection: names.map { parent.appendingPathComponent($0) })
        try check(selection.items.map(\.source.lastPathComponent) == names, "Captured selection order or names changed")
        try check(selection.parent.path == parent.resolvingSymlinksInPath().standardizedFileURL.path,
                  "Captured parent changed")
        try check(selection.items.count == 3 && selection.itemIdentities.count == 3, "Selection was truncated")
        for (item, identity) in zip(selection.items, selection.itemIdentities) {
            var observed = stat()
            try check(lstat(item.source.path, &observed) == 0, "Selected-item metadata is unavailable")
            try check(identity.inode == observed.st_ino && identity.device == UInt64(bitPattern: Int64(observed.st_dev)),
                      "Capture did not preserve the filesystem identity")
        }

        let tickets = FileOperationTicketStore(directory: control.appendingPathComponent("tickets"))
        let request = FileOperationRequest.batchRename(selection: selection)
        let url = try tickets.enqueue(request)
        try check(try tickets.consume(url) == request, "Ticket did not retain the complete immutable snapshot")
        // Capturing metadata is not an authorization grant to prepare or mutate.
        try expectDenied {
            _ = try BatchRenameService(store: BatchRenameStore(directory: control.appendingPathComponent("state")))
                .prepare(selection: selection, parentBookmark: Data([1]), observationRoots: [parent])
        }
        do {
            _ = try BatchRenameSelection.capture(selection: [parent.appendingPathComponent("IMG_2.JPG"),
                                                             parent.appendingPathComponent("link.JPG")])
            throw Failure(message: "A symlink neighbor was accepted")
        } catch BatchRenameError.unsupportedItem { assertions += 1 }
        do {
            _ = try BatchRenameSelection.capture(selection: [parent.appendingPathComponent("IMG_2.JPG"),
                                                             parent.appendingPathComponent("hardlink.JPG")])
            throw Failure(message: "Duplicate filesystem identities were accepted")
        } catch BatchRenameError.invalidSelection { assertions += 1 }
        print("PASS batch rename metadata-only sandbox capture: \(assertions) assertions")
    }

    static func main() {
        do { try run() }
        catch {
            let message = (error as? Failure)?.message ?? "\((error as NSError).domain) / \((error as NSError).code)"
            FileHandle.standardError.write(Data("FAIL batch rename sandbox capture: \(message)\n".utf8))
            exit(1)
        }
    }
}
