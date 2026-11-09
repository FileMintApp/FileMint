import Darwin
import FileMintCore
import Foundation

@main struct FileInfoCaptureSmoke {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "file-only") else {
            fatalError("Expected isolated fixture directory and optional file-only scenario")
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        if arguments.count == 3 {
            try checkFileOnlyAccess(in: root)
            return
        }
        for (url, flags) in [(root, O_DIRECTORY), (root.appendingPathComponent("file.txt"), Int32(0))] {
            let fd = open(url.path, O_RDONLY | O_CLOEXEC | flags)
            guard fd < 0 && [EPERM, EACCES].contains(errno) else {
                if fd >= 0 { close(fd) }
                fatalError("Sandbox regression must deny all content/directory reads")
            }
        }
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.fileTools.isEnabled = true; preferences.fileTools.fileInfo = true
        preferences.fileTools.copyContents = true
        precondition(FileToolsPolicy.availableTools(selection: [root.appendingPathComponent("file.txt")],
            isItemMenu: true, preferences: preferences).contains(.fileInfo))
        for name in ["folder", "link", "missing"] {
            precondition(!FileToolsPolicy.availableTools(selection: [root.appendingPathComponent(name, isDirectory: false)],
                isItemMenu: true, preferences: preferences).contains(.fileInfo))
        }
        let file = try FileInfoSelection.capture([root.appendingPathComponent("file.txt")])
        precondition(FileContentCopyPolicy.supportsMenuSelection([file.source]))
        do {
            _ = try FileContentRead.read(file)
            fatalError("Denied content must not produce clipboard data")
        } catch FileInfoError.accessDenied {}
        let metadata = try FileDigestService.inspect(file)
        precondition(metadata.kind == .file && metadata.logicalSize == 3)
        let folder = try FileDigestService.inspect(FileInfoSelection.capture([root.appendingPathComponent("folder")]))
        precondition(folder.kind == .directory && folder.logicalSize == nil)
        let link = try FileDigestService.inspect(FileInfoSelection.capture([root.appendingPathComponent("link")]))
        precondition(link.kind == .unsupported)
        do {
            _ = try FileDigestService.calculate(file, choice: .all)
            fatalError("Denied content must not produce a digest")
        } catch FileInfoError.accessDenied {}
        print("PASS file information metadata-only menu/capture; unsupported menu items hidden; content reads denied; no digest on permission failure")
    }

    private static func checkFileOnlyAccess(in root: URL) throws {
        let directory = open(root.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directory < 0 && [EPERM, EACCES].contains(errno) else {
            if directory >= 0 { close(directory) }
            fatalError("File-only scenario must deny directory reads")
        }
        let file = try FileInfoSelection.capture([root.appendingPathComponent("file.txt")])
        try file.validate(in: [root])
        let contents = try FileContentRead.read(file)
        precondition(contents.data == Data("abc".utf8))
        let digest = try FileDigestService.calculate(file, choice: .sha256)
        precondition(digest.clipboardText == "SHA-256: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let other = try FileInfoSelection.capture([root.appendingPathComponent("folder/keep")])
        do {
            _ = try FileContentRead.read(other)
            fatalError("File-only access must not allow an ungranted file read")
        } catch FileInfoError.accessDenied {}
        print("PASS file-only sandbox access: exact copy and checksum without directory reads; ungranted content denied")
    }
}
