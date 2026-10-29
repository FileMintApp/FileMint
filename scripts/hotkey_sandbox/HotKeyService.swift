import AppKit
import Carbon
import FileMintCore

// The signed fixture exercises the same registration backend as the app.
typealias HotKeyService = GlobalShortcutService
typealias HotKeyBinding = GlobalShortcut

extension GlobalShortcut {
    static let primary = Self(keyCode: UInt32(kVK_ANSI_K), modifiers: control | option)
    static let alternate = Self(keyCode: UInt32(kVK_ANSI_K), modifiers: control | option | shift)
    @MainActor var title: String { GlobalShortcutKeyboard.title(self) }
    @MainActor static func capture(_ event: NSEvent) -> Self { GlobalShortcutKeyboard.capture(event) }
}

enum HotKeyFailure: Error, CustomStringConvertible {
    case simulatedSaveFailure, check(String)
    var description: String {
        switch self {
        case .simulatedSaveFailure: "Simulated save failure"
        case .check(let label): "Check failed: \(label)"
        }
    }
}

func qaEmit(_ event: String, _ values: [String: Any] = [:]) {
    var object = values
    object["event"] = event
    object["time"] = ISO8601DateFormatter().string(from: Date())
    if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) {
        FileHandle.standardOutput.write(data + Data([10]))
    }
}
