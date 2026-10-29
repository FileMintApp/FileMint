import Darwin
import FileMintCore
import Foundation

@main struct FileVisibilityCaptureSmoke {
    static func main() throws {
        precondition(CommandLine.arguments.count == 3)
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let mode = CommandLine.arguments[2]
        let file = root.appendingPathComponent("file.txt"), folder = root.appendingPathComponent("folder")
        if mode == "capture" {
            for (url, flags) in [(file, Int32(0)), (folder, O_DIRECTORY)] {
                let fd = open(url.path, O_RDONLY | O_CLOEXEC | flags)
                precondition(fd < 0 && [EPERM, EACCES].contains(errno), "Content/directory reads must be denied")
            }
        }
        let captured = try FileVisibilityService.capture([file, folder])
        precondition(FileVisibilityService.menuActions(for: [file, folder]) == [.hide])
        if mode != "allow" {
            do {
                try FileVisibilityService.perform(captured, action: .hide)
                fatalError("Denied metadata writes reported success")
            } catch let error as NSError {
                precondition(error.domain == NSPOSIXErrorDomain && [Int(EPERM), Int(EACCES)].contains(error.code))
            }
            precondition(FileVisibilityService.menuActions(for: [file, folder]) == [.hide])
        } else {
            let hidden = try FileVisibilityService.perform(captured, action: .hide)
            precondition(hidden == 2)
            precondition(FileVisibilityService.menuActions(for: [file, folder]) == [.unhide])
            let unhidden = try FileVisibilityService.perform(captured, action: .unhide)
            precondition(unhidden == 2)
            precondition(FileVisibilityService.menuActions(for: [file, folder]) == [.hide])
        }
        print("PASS file visibility \(mode): metadata capture, event-only attributes and denied-access preservation")
    }
}
