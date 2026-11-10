import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let repoURL = URL(string: "https://github.com/elchuzade/typeclip")!

    private var statusItem: NSStatusItem!
    private let typer = Typer()
    private var hotKey: HotKey?
    private var escMonitor: Any?
    private var countdownTimer: Timer?
    private let permissionGuide = PermissionGuide()
    private let defaults = UserDefaults.standard

    // MARK: Settings

    private var pacing: Pacing {
        get { Pacing(rawValue: defaults.string(forKey: "pacing") ?? "") ?? .human }
        set { defaults.set(newValue.rawValue, forKey: "pacing") }
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        // Monospaced digits so the countdown doesn't wobble as numbers change.
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        setIcon(typing: false)

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        registerHotKey()

        // Explain, then ask for, Accessibility permission (needed to type into other apps).
        permissionGuide.start(shortcut: hotKeyCombo.label)
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

        let characters = Typer.characters(of: text)
        let delays = pacing.delays(for: characters)
        let total = delays.reduce(0, +)

        if total > 120 {
            if !confirm("Type \(characters.count) characters?",
                        "This will take about \(Self.format(total)). Press Esc at any time to stop.") { return }
        }

        setIcon(typing: true)
        showCountdown(total)
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.stopTyping() } // Esc
        }
        // Tick often so the shown second changes right on time.
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.showCountdown(self.typer.remainingTime)
        }
        RunLoop.main.add(timer, forMode: .common) // keep ticking while the menu is open
        countdownTimer = timer
        typer.type(characters, delays: delays, lineBreaks: lineBreakMode) { [weak self] in
            self?.typingFinished()
        }
    }

    @objc private func stopTyping() { typer.stop() }

    private func typingFinished() {
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        statusItem.button?.title = ""
        setIcon(typing: false)
    }

    /// Shows the time left next to the menu bar icon, e.g. "42s" or "1:05".
    private func showCountdown(_ seconds: TimeInterval) {
        statusItem.button?.title = " " + Self.format(seconds)
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return s < 60 ? "\(s)s" : String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !AXIsProcessTrusted() {
            menu.addItem(item("⚠︎ Allow TypeClip to Type…", #selector(showPermissionAlert)))
            menu.addItem(.separator())
        }

        if typer.isRunning {
            menu.addItem(item("Stop Typing (Esc), \(Self.format(typer.remainingTime)) left", #selector(stopTyping)))
        } else {
            let typeItem = item("Type Clipboard   \(hotKeyCombo.label)", #selector(startTyping))
            menu.addItem(typeItem)
        }
        menu.addItem(.separator())

        menu.addItem(submenu("Speed", Pacing.allCases.enumerated().map { i, p in
            let it = item(p.label, #selector(selectSpeed(_:)))
            it.tag = i
            it.state = p == pacing ? .on : .off
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

    @objc private func selectSpeed(_ sender: NSMenuItem) { pacing = Pacing.allCases[sender.tag] }

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

    // MARK: Alerts

    @objc private func showPermissionAlert() {
        permissionGuide.start(shortcut: hotKeyCombo.label)
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
