import Carbon
import Cocoa

/// A system-wide keyboard shortcut using Carbon's RegisterEventHotKey.
/// Works in every app and does not need any extra permission.
final class HotKey {
    struct Combo: Equatable {
        let keyCode: UInt32
        let modifiers: UInt32 // Carbon modifier mask (cmdKey, optionKey, ...)
        let label: String
        let id: String
    }

    static let presets: [Combo] = [
        Combo(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey | cmdKey), label: "⌃⌥⌘V", id: "ctrl-opt-cmd-v"),
        Combo(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey), label: "⌃⌥V", id: "ctrl-opt-v"),
        Combo(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | shiftKey), label: "⌃⇧V", id: "ctrl-shift-v"),
        Combo(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | optionKey | cmdKey), label: "⌃⌥⌘T", id: "ctrl-opt-cmd-t"),
    ]

    private var ref: EventHotKeyRef?
    private static var handler: (() -> Void)?
    private static var eventHandlerInstalled = false

    init(_ combo: Combo, handler: @escaping () -> Void) {
        HotKey.handler = handler
        HotKey.installEventHandlerOnce()

        let hotKeyID = EventHotKeyID(signature: OSType(0x5459_434C), id: 1) // 'TYCL'
        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
    }

    private static func installEventHandlerOnce() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.handler?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
