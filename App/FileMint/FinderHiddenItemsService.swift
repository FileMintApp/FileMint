import AppKit
import ApplicationServices
import CoreGraphics

enum FinderHiddenItemsResult {
    case needsAuthorization
    case sent
    case finderUnavailable
}

/// A user-click-only adapter for Finder's own Command-Shift-Period command.
/// It never reads or writes Finder defaults and never observes global input.
@MainActor
enum FinderHiddenItemsService {
    static var isAuthorized: Bool { AXIsProcessTrusted() }

    static func toggle() async -> FinderHiddenItemsResult {
        guard AXIsProcessTrusted() else {
            let prompt = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(prompt)
            return .needsAuthorization
        }
        guard let finder = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.finder" && !$0.isTerminated
        }), finder.activate(options: [.activateIgnoringOtherApps]) else {
            return .finderUnavailable
        }
        // Activation is asynchronous. The event is addressed to Finder's PID,
        // and is only posted once Finder has become the frontmost application.
        for _ in 0..<20 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == finder.processIdentifier { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard AXIsProcessTrusted(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == finder.processIdentifier,
              let down = CGEvent(keyboardEventSource: nil, virtualKey: 47, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 47, keyDown: false) else {
            return .finderUnavailable
        }
        down.flags = [.maskCommand, .maskShift]
        up.flags = [.maskCommand, .maskShift]
        down.postToPid(finder.processIdentifier)
        up.postToPid(finder.processIdentifier)
        return .sent
    }
}
