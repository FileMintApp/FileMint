import Darwin
import FileMintCore
import Foundation

@main struct FileInfoCaptureSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Expected isolated fixture directory") }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
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
}
