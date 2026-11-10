# TypeClip ⌨️

**Type out your clipboard instead of pasting it.** A tiny, free macOS menu bar app.

Copy any text, press **⌃⌥⌘V** (Control + Option + Command + V), and TypeClip types it into the focused app character by character, as if you were typing it yourself.

## Why?

Sometimes pasting doesn't work, or doesn't work the way you want:

- **Fields that block paste**: some banking sites, forms, and "confirm your email" boxes.
- **Remote desktops, VMs, and VNC/KVM consoles**: these often have no shared clipboard.
- **Web apps that handle pasted text differently** from typed text (formatting, autocomplete, mentions).
- **Live demos and screen recordings** where you want text to appear as if typed.
- **Pasted text keeps hidden formatting.** TypeClip only ever sends plain characters.

## Install

### Option A: one command (easiest)

Open **Terminal** (press ⌘ Space, type "Terminal", press Return), paste this, and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/typeclip/main/install.sh | bash
```

### Option B: download manually

1. Download **TypeClip.zip** from the [latest release](https://github.com/YOUR_USERNAME/typeclip/releases/latest).
2. Double-click the zip and drag **TypeClip.app** into **Applications**.
3. Open it. macOS will say it "can't be opened" because the app isn't notarized (notarization costs $99/year). To open it anyway:
   **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to TypeClip.

### Then: allow Accessibility

macOS only lets an app type into other apps if you allow it. When asked, open
**System Settings → Privacy & Security → Accessibility** and switch **TypeClip** on.

You'll see a ⌨️ keyboard icon in your menu bar. That's it.

## Use

| Action | How |
| --- | --- |
| Type clipboard | **⌃⌥⌘V**, or click the menu bar icon → *Type Clipboard* |
| Stop typing | **Esc**, or press the shortcut again |
| Change speed | Menu bar icon → *Speed* |
| Change shortcut | Menu bar icon → *Shortcut* |
| New lines in chat apps (Slack, Discord, WhatsApp) without sending | Menu bar icon → *Line Breaks* → *Shift + Return* |
| Start automatically | Menu bar icon → *Open at Login* |

Tips:
- Let go of the shortcut keys straight away. TypeClip waits until you do before it starts.
- Code editors may auto-indent or auto-close brackets while TypeClip types. Turn those features off temporarily if needed.
- Password fields that use macOS *Secure Input* ignore typed events from apps. That's a macOS security feature.

## How it works

About 300 lines of Swift, with no dependencies:

- [`HotKey.swift`](Sources/HotKey.swift) registers a global shortcut with Carbon's `RegisterEventHotKey`.
- [`Typer.swift`](Sources/Typer.swift) posts a `CGEvent` key press for every character using `keyboardSetUnicodeString`, so it works with any keyboard layout, accents, emoji, and non-Latin scripts.
- [`AppDelegate.swift`](Sources/AppDelegate.swift) runs the menu bar UI and settings.

TypeClip doesn't connect to the internet, collect data, or store your clipboard. It only reads the clipboard when you press the shortcut.

## Build from source

You need Xcode or the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/YOUR_USERNAME/typeclip.git
cd typeclip
./build.sh
open build/TypeClip.app
```

To publish a release, push a tag (`git tag v1.0.0 && git push --tags`). GitHub Actions builds `TypeClip.zip` and attaches it to the release.

> Each local rebuild has a new ad-hoc signature, so macOS may ask for Accessibility permission again. Remove the old TypeClip entry from the list and add the new one.

## Requirements

macOS 13 Ventura or later, on Apple Silicon or Intel.

## License

MIT. Use it, fork it, ship it. If it helped you, a ⭐ is appreciated.
