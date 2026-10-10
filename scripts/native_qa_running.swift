import AppKit
import Foundation

// Read only the QA identities explicitly requested by the publisher. No app is
// launched, activated, quit or granted access by this guard.
let requested = Set(CommandLine.arguments.dropFirst())
let running = NSWorkspace.shared.runningApplications.compactMap { application -> String? in
    guard let identifier = application.bundleIdentifier, requested.contains(identifier) else { return nil }
    return identifier
}
let data = try JSONSerialization.data(withJSONObject: running.sorted())
print(String(decoding: data, as: UTF8.self))
