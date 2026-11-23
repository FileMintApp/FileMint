import AppKit

let bundleID = CommandLine.arguments[1]
let installedPath = CommandLine.arguments[2]

func stop(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
guard running.allSatisfy({ $0.bundleURL?.standardizedFileURL.path == installedPath }) else {
    stop("Quit the other running copy of FileMint before installing Debug.")
}

for app in running where !app.isTerminated {
    if !app.terminate() && !app.isTerminated {
        stop("FileMint did not accept the normal quit request.")
    }
}

let deadline = Date().addingTimeInterval(15)
while running.contains(where: { !$0.isTerminated }) && Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
}
if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
    stop("FileMint is still running. Finish any active work, then quit before installing Debug.")
}
