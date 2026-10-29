import AppKit
import Carbon
import FileMintCore

enum GlobalShortcutFailure: Error, Equatable {
    case invalid, systemReserved, menuConflict(String), registration(OSStatus), systemQuery(OSStatus), handler(OSStatus)

    func message(_ language: AppLanguage) -> String {
        let chinese = language.resolved() == .chinese
        switch self {
        case .invalid: return chinese ? "请使用包含 Control 或 Command 的组合键。" : "Use a key combination containing Control or Command."
        case .systemReserved: return chinese ? "该组合已用于系统快捷键，请换一个组合。" : "This combination is used by a system shortcut. Choose another."
        case .menuConflict(let title): return chinese ? "该组合已用于菜单“\(title)”。" : "This combination is used by “\(title)” in the app menu."
        case .registration: return chinese ? "无法启用该组合，可能已被其他应用占用。" : "Could not enable this combination; another app may be using it."
        case .systemQuery, .handler: return chinese ? "无法准备快捷键，请重试。" : "Could not prepare the shortcut. Try again."
        }
    }
}

@MainActor
enum GlobalShortcutKeyboard {
    static func capture(_ event: NSEvent) -> GlobalShortcut {
        var flags: UInt32 = 0
        for (flag, mask) in [(NSEvent.ModifierFlags.command, GlobalShortcut.command), (.control, GlobalShortcut.control),
                             (.option, GlobalShortcut.option), (.shift, GlobalShortcut.shift)] {
            if event.modifierFlags.contains(flag) { flags |= mask }
        }
        return .init(keyCode: UInt32(event.keyCode), modifiers: flags)
    }

    static func title(_ shortcut: GlobalShortcut) -> String {
        var title = ""
        for (mask, symbol) in [(GlobalShortcut.control, "⌃"), (GlobalShortcut.option, "⌥"),
                               (GlobalShortcut.shift, "⇧"), (GlobalShortcut.command, "⌘")] {
            if shortcut.modifiers & mask != 0 { title += symbol }
        }
        return title + keyName(shortcut.keyCode)
    }

    static func keyName(_ code: UInt32) -> String {
        let special: [UInt32: String] = [36:"↩", 48:"⇥", 49:"Space", 51:"⌫", 53:"⎋", 65:".", 67:"*", 69:"+",
            71:"Clear", 75:"/", 76:"⌤", 78:"−", 81:"=", 96:"F5", 97:"F6", 98:"F7", 99:"F3", 100:"F8",
            101:"F9", 103:"F11", 105:"F13", 106:"F16", 107:"F14", 109:"F10", 111:"F12", 113:"F15",
            114:"Help", 115:"↖", 116:"⇞", 117:"⌦", 118:"F4", 119:"↘", 120:"F2", 121:"⇟", 122:"F1",
            123:"←", 124:"→", 125:"↓", 126:"↑", 64:"F17", 79:"F18", 80:"F19", 90:"F20"]
        if let value = special[code] { return value }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "[\(code)]"
        }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return "[\(code)]" }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var dead: UInt32 = 0, count = 0
        var chars = [UniChar](repeating: 0, count: 8)
        let result = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, chars.count, &count, &chars)
        guard result == noErr, count > 0 else { return "[\(code)]" }
        return String(utf16CodeUnits: chars, count: count).uppercased()
    }

    static func validate(_ shortcut: GlobalShortcut, menu: NSMenu? = NSApp?.mainMenu) throws {
        guard shortcut.isValid else { throw GlobalShortcutFailure.invalid }
        var values: Unmanaged<CFArray>?
        let code = CopySymbolicHotKeys(&values)
        guard code == noErr, let entries = values?.takeRetainedValue() as? [[String: Any]] else {
            throw GlobalShortcutFailure.systemQuery(code)
        }
        if entries.contains(where: {
            ($0[kHISymbolicHotKeyEnabled] as? NSNumber)?.boolValue == true &&
            ($0[kHISymbolicHotKeyCode] as? NSNumber)?.uint32Value == shortcut.keyCode &&
            ($0[kHISymbolicHotKeyModifiers] as? NSNumber)?.uint32Value == shortcut.modifiers
        }) { throw GlobalShortcutFailure.systemReserved }
        if let menu, let title = conflict(shortcut, in: menu) { throw GlobalShortcutFailure.menuConflict(title) }
    }

    private static func conflict(_ shortcut: GlobalShortcut, in menu: NSMenu) -> String? {
        let key = keyName(shortcut.keyCode).lowercased()
        for item in menu.items {
            if let submenu = item.submenu, let match = conflict(shortcut, in: submenu) { return match }
            var flags: UInt32 = 0
            for (flag, mask) in [(NSEvent.ModifierFlags.command, GlobalShortcut.command), (.control, GlobalShortcut.control),
                                 (.option, GlobalShortcut.option), (.shift, GlobalShortcut.shift)] {
                if item.keyEquivalentModifierMask.contains(flag) { flags |= mask }
            }
            if !item.keyEquivalent.isEmpty, item.keyEquivalent.lowercased() == key, flags == shortcut.modifiers {
                return item.title
            }
        }
        return nil
    }
}

/// Owns only this app's explicitly registered combination, never a global event
/// monitor. All operations and Carbon delivery are serialized on the main thread.
@MainActor
final class GlobalShortcutService {
    private struct Registration { let id: UInt32; let reference: EventHotKeyRef }
    private let signature: OSType = 0x464D4851
    private var sequence: UInt32 = 0
    private var registration: Registration?
    private var handler: EventHandlerRef?
    private var armedID: UInt32?
    private(set) var binding: GlobalShortcut?
    private(set) var suspended = false
    var isRegistered: Bool { registration != nil }
    var onRelease: () -> Void = {}

    init() throws {
        var events = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, event, pointer in
            guard Thread.isMainThread, let event, let pointer else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                Unmanaged<GlobalShortcutService>.fromOpaque(pointer).takeUnretainedValue().receive(event)
            }
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw GlobalShortcutFailure.handler(status) }
    }

    func replace(with candidate: GlobalShortcut?, persist: (GlobalShortcut?) throws -> Void) throws {
        if let candidate, !candidate.isValid { throw GlobalShortcutFailure.invalid }
        if candidate == binding, candidate == nil || isRegistered || suspended {
            try persist(candidate)
            return
        }
        let prepared = try candidate.flatMap { suspended ? nil : try register($0) }
        do { try persist(candidate) }
        catch {
            if let prepared { UnregisterEventHotKey(prepared.reference) }
            throw error
        }
        let previous = registration
        registration = prepared; binding = candidate; armedID = nil
        if let previous { UnregisterEventHotKey(previous.reference) }
    }

    func suspend() {
        suspended = true; armedID = nil
        if let registration { UnregisterEventHotKey(registration.reference) }
        registration = nil
    }

    func resume() throws {
        suspended = false
        guard registration == nil, let binding else { return }
        registration = try register(binding)
    }

    func shutdown() {
        suspend()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    private func register(_ binding: GlobalShortcut) throws -> Registration {
        sequence += 1
        var reference: EventHotKeyRef?
        let code = RegisterEventHotKey(binding.keyCode, binding.modifiers,
            EventHotKeyID(signature: signature, id: sequence), GetEventDispatcherTarget(),
            OptionBits(kEventHotKeyExclusive), &reference)
        guard code == noErr, let reference else { throw GlobalShortcutFailure.registration(code) }
        return .init(id: sequence, reference: reference)
    }

    private func receive(_ event: EventRef) -> OSStatus {
        var identifier = EventHotKeyID()
        guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
              identifier.signature == signature, identifier.id == registration?.id else {
            return OSStatus(eventNotHandledErr)
        }
        if GetEventKind(event) == UInt32(kEventHotKeyPressed) { armedID = identifier.id }
        else if GetEventKind(event) == UInt32(kEventHotKeyReleased), armedID == identifier.id {
            armedID = nil; onRelease()
        }
        return noErr
    }
}
