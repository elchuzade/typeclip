import Cocoa

/// macOS's own Accessibility prompt ("would like to control this Mac and access your data")
/// can't be reworded by apps. So before it appears, TypeClip explains in plain words
/// what the permission is for, then confirms once it has been switched on.
final class PermissionGuide {
    private var pollTimer: Timer?

    /// Shows the explanation, then hands over to macOS. `shortcut` is e.g. "⌃⌥⌘V".
    func start(shortcut: String) {
        guard !AXIsProcessTrusted() else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = Self.icon
        alert.messageText = "One quick permission"
        alert.informativeText = """
        TypeClip types text for you, so macOS asks you to allow it to press keys. \
        Keyboard and window tools need the same permission.

        What TypeClip does:
        • Types your clipboard, only when you press \(shortcut)

        What it never does:
        • Read your screen or files
        • Record or store anything you type
        • Connect to the internet

        It's open source, so anyone can check the code on GitHub.

        Next, macOS will show its standard security message. Click \
        "Open System Settings", then switch TypeClip on.
        """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "View Source Code")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            requestFromSystem()
            waitForPermission(shortcut: shortcut)
        case .alertThirdButtonReturn:
            NSWorkspace.shared.open(AppDelegate.repoURL)
        default:
            break
        }
    }

    /// First time: triggers macOS's own prompt, which also adds TypeClip to the
    /// Accessibility list. After that macOS may not show the prompt again, so we
    /// open the right page of System Settings directly.
    private func requestFromSystem() {
        let key = "askedForAccessibility"
        if UserDefaults.standard.bool(forKey: key) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            UserDefaults.standard.set(true, forKey: key)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    /// Checks every second (for up to 10 minutes) and says thanks once it's switched on.
    private func waitForPermission(shortcut: String) {
        pollTimer?.invalidate()
        let deadline = Date().addingTimeInterval(600)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.showReady(shortcut: shortcut)
            } else if Date() > deadline {
                timer.invalidate()
            }
        }
    }

    private func showReady(shortcut: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = Self.icon
        alert.messageText = "You're all set"
        alert.informativeText = """
        Copy any text, click where you want it, and press \(shortcut).

        A countdown appears next to the ⌨ icon in your menu bar. Press Esc to stop at any time.
        """
        alert.addButton(withTitle: "Got It")
        alert.runModal()
        NSApp.hide(nil)
    }

    private static var icon: NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "TypeClip")?
            .withSymbolConfiguration(config)
    }
}
