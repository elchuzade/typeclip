import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let repoURL = URL(string: "https://github.com/YOUR_USERNAME/typeclip")!

    private var statusItem: NSStatusItem!
    private let typer = Typer()
    private var hotKey: HotKey?
    private var escMonitor: Any?
    private let defaults = UserDefaults.standard

    // MARK: Settings

    private struct Speed { let label: String; let delay: TimeInterval }
    private let speeds: [Speed] = [
        Speed(label: "Very fast", delay: 0.004),
        Speed(label: "Fast", delay: 0.012),
        Speed(label: "Normal", delay: 0.03),
        Speed(label: "Slow", delay: 0.07),
    ]

    private var speedIndex: Int {
        get { defaults.object(forKey: "speedIndex") as? Int ?? 1 }
        set { defaults.set(newValue, forKey: "speedIndex") }
    }

    private var hotKeyCombo: HotKey.Combo {
        get {
            let id = defaults.string(forKey: "hotKey")
            return HotKey.presets.first { $0.id == id } ?? HotKey.presets[0]
        }
        set { defaults.set(newValue.id, forKey: "hotKey") }
    }

    private var lineBreakMode: Typer.LineBreakMode {
        get { Typer.LineBreakMode(rawValue: defaults.string(forKey: "lineBreaks") ?? "") ?? .enter }
        set { defaults.set(newValue.rawValue, forKey: "lineBreaks") }
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(typing: false)

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        registerHotKey()

        // Ask for Accessibility permission on first launch (needed to type into other apps).
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    private func registerHotKey() {
        hotKey = nil
        hotKey = HotKey(hotKeyCombo) { [weak self] in self?.hotKeyPressed() }
    }

    private func setIcon(typing: Bool) {
        let name = typing ? "keyboard.fill" : "keyboard"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "TypeClip")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    // MARK: Typing

    private func hotKeyPressed() {
        if typer.isRunning { stopTyping(); return } // pressing the shortcut again stops it
        startTyping()
    }

    @objc private func startTyping() {
        guard AXIsProcessTrusted() else { showPermissionAlert(); return }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            NSSound.beep(); return
        }

        let delay = speeds[speedIndex].delay
        if text.count > 2000 {
            let seconds = Int(Double(text.count) * delay)
            if !confirm("Type \(text.count) characters?",
                        "This will take about \(seconds) seconds. Press Esc at any time to stop.") { return }
        }

        setIcon(typing: true)
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.stopTyping() } // Esc
        }
        typer.type(text, delay: delay, lineBreaks: lineBreakMode) { [weak self] in
            self?.typingFinished()
        }
    }

    @objc private func stopTyping() { typer.stop() }

    private func typingFinished() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
        setIcon(typing: false)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !AXIsProcessTrusted() {
            menu.addItem(item("⚠︎ Grant Accessibility Permission…", #selector(openAccessibilitySettings)))
            menu.addItem(.separator())
        }

        if typer.isRunning {
            menu.addItem(item("Stop Typing (Esc)", #selector(stopTyping)))
        } else {
            let typeItem = item("Type Clipboard   \(hotKeyCombo.label)", #selector(startTyping))
            menu.addItem(typeItem)
        }
        menu.addItem(.separator())

        menu.addItem(submenu("Speed", speeds.enumerated().map { i, speed in
            let it = item(speed.label, #selector(selectSpeed(_:)))
            it.tag = i
            it.state = i == speedIndex ? .on : .off
            return it
        }))

        menu.addItem(submenu("Shortcut", HotKey.presets.enumerated().map { i, combo in
            let it = item(combo.label, #selector(selectHotKey(_:)))
            it.tag = i
            it.state = combo == hotKeyCombo ? .on : .off
            return it
        }))

        let enter = item("Return", #selector(selectLineBreaks(_:)))
        enter.representedObject = Typer.LineBreakMode.enter.rawValue
        enter.state = lineBreakMode == .enter ? .on : .off
        let shiftEnter = item("Shift + Return (chat apps)", #selector(selectLineBreaks(_:)))
        shiftEnter.representedObject = Typer.LineBreakMode.shiftEnter.rawValue
        shiftEnter.state = lineBreakMode == .shiftEnter ? .on : .off
        menu.addItem(submenu("Line Breaks", [enter, shiftEnter]))

        let login = item("Open at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("About TypeClip", #selector(openRepo)))
        menu.addItem(item("Quit", #selector(NSApplication.terminate(_:)), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = action == #selector(NSApplication.terminate(_:)) ? NSApp : self
        return it
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        items.forEach(sub.addItem)
        parent.submenu = sub
        return parent
    }

    @objc private func selectSpeed(_ sender: NSMenuItem) { speedIndex = sender.tag }

    @objc private func selectHotKey(_ sender: NSMenuItem) {
        hotKeyCombo = HotKey.presets[sender.tag]
        registerHotKey()
    }

    @objc private func selectLineBreaks(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = Typer.LineBreakMode(rawValue: raw) {
            lineBreakMode = mode
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            _ = confirm("Couldn't change login setting", error.localizedDescription, okOnly: true)
        }
    }

    @objc private func openRepo() { NSWorkspace.shared.open(Self.repoURL) }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Alerts

    private func showPermissionAlert() {
        let ok = confirm("TypeClip needs Accessibility permission",
                         "macOS only lets apps type into other apps if you allow it.\n\nOpen System Settings → Privacy & Security → Accessibility and switch TypeClip on.",
                         okTitle: "Open Settings")
        if ok { openAccessibilitySettings() }
    }

    @discardableResult
    private func confirm(_ title: String, _ message: String,
                         okTitle: String = "OK", okOnly: Bool = false) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: okTitle)
        if !okOnly { alert.addButton(withTitle: "Cancel") }
        let result = alert.runModal() == .alertFirstButtonReturn
        NSApp.hide(nil) // give focus back to the app the user was typing in
        return result
    }
}
