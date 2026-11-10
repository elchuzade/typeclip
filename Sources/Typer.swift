import Cocoa

/// Types a string into whatever app is focused, one character at a time,
/// by posting synthetic keyboard events (the same way a real keyboard would).
final class Typer {
    enum LineBreakMode: String, CaseIterable {
        case enter        // plain Return
        case shiftEnter   // Shift+Return (new line in chat apps without sending)
    }

    private let lock = NSLock()
    private var cancelled = false
    private var running = false

    var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }

    /// Starts typing `text` on a background thread.
    /// - Parameters:
    ///   - delay: seconds between characters
    ///   - onFinish: called on the main thread when done or cancelled
    func type(_ text: String,
              delay: TimeInterval,
              lineBreaks: LineBreakMode,
              onFinish: @escaping () -> Void) {
        lock.lock()
        if running { lock.unlock(); return }
        running = true
        cancelled = false
        lock.unlock()

        Thread.detachNewThread { [weak self] in
            guard let self else { return }
            Self.waitForModifierRelease()

            let source = CGEventSource(stateID: .hidSystemState)
            // Normalise Windows-style line endings so we don't press Return twice.
            let normalised = text.replacingOccurrences(of: "\r\n", with: "\n")

            for character in normalised {
                if self.isCancelled { break }
                Self.post(character, source: source, lineBreaks: lineBreaks)
                Thread.sleep(forTimeInterval: delay)
            }

            self.lock.lock(); self.running = false; self.lock.unlock()
            DispatchQueue.main.async(execute: onFinish)
        }
    }

    func stop() {
        lock.lock(); cancelled = true; lock.unlock()
    }

    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    // MARK: - Low level

    private static let kReturn: CGKeyCode = 36
    private static let kTab: CGKeyCode = 48

    private static func post(_ character: Character, source: CGEventSource?, lineBreaks: LineBreakMode) {
        switch character {
        case "\n", "\r":
            pressKey(kReturn, flags: lineBreaks == .shiftEnter ? .maskShift : [], source: source)
        case "\t":
            pressKey(kTab, flags: [], source: source)
        default:
            typeUnicode(String(character), source: source)
        }
    }

    private static func pressKey(_ key: CGKeyCode, flags: CGEventFlags, source: CGEventSource?) {
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    /// Sends a character as a Unicode string, so it works for any keyboard layout,
    /// accents, emoji, Cyrillic, Arabic, CJK, etc.
    private static func typeUnicode(_ string: String, source: CGEventSource?) {
        let utf16 = Array(string.utf16)
        // CGEvent accepts at most 20 UTF-16 units per event; split huge grapheme clusters.
        for chunkStart in stride(from: 0, to: utf16.count, by: 20) {
            let chunk = Array(utf16[chunkStart..<min(chunkStart + 20, utf16.count)])
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown) else { continue }
                event.flags = [] // never inherit ⌘/⌥/⌃ from the user's fingers
                var c = chunk
                event.keyboardSetUnicodeString(stringLength: c.count, unicodeString: &c)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    /// The hotkey is pressed with ⌘/⌥/⌃ held down. If we start typing while they
    /// are still physically held, apps would see shortcuts instead of letters.
    /// Wait (up to 2s) until the user lets go.
    private static func waitForModifierRelease() {
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection(modifiers).isEmpty { break }
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.05)
    }
}
