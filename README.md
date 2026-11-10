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
curl -fsSL https://raw.githubusercontent.com/elchuzade/typeclip/main/install.sh | bash
```

### Option B: download manually

1. Download **TypeClip.zip** from the [latest release](https://github.com/elchuzade/typeclip/releases/latest).
2. Double-click the zip and drag **TypeClip.app** into **Applications**.
3. Open it. macOS will say it "can't be opened" because the app isn't notarized (notarization costs $99/year). To open it anyway:
   **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to TypeClip.

### Then: allow one permission

The first time you open TypeClip, it explains in plain words what it needs and why. Then macOS shows its own standard message:

> "TypeClip" would like to control this Mac and access your data.

That sounds scarier than it is. macOS uses the same wording for **every** app that needs the Accessibility permission (window managers, launchers, text expanders), and apps can't change it. For TypeClip it only means *"can press keys for you"*. TypeClip never reads your screen or files, never records what you type, and never goes online. The code is all here if you want to check.

Click **Open System Settings** and switch **TypeClip** on. TypeClip notices straight away and tells you it's ready.

You'll see a ⌨️ keyboard icon in your menu bar. That's it.

## Use

| Action                                                            | How                                                     |
| ----------------------------------------------------------------- | ------------------------------------------------------- |
| Type clipboard                                                    | **⌃⌥⌘V**, or click the menu bar icon → _Type Clipboard_ |
| Stop typing                                                       | **Esc**, or press the shortcut again                    |
| See time left                                                     | A live countdown next to the menu bar icon              |
| Change speed                                                      | Menu bar icon → _Speed_ (default: _Human-like_)         |
| Change shortcut                                                   | Menu bar icon → _Shortcut_                              |
| New lines in chat apps (Slack, Discord, WhatsApp) without sending | Menu bar icon → _Line Breaks_ → _Shift + Return_        |
| Start automatically                                               | Menu bar icon → _Open at Login_                         |

**Human-like speed** (the default) types with a natural rhythm instead of at a robotic, even pace. Each key waits a random, realistic gap (about 45–450 ms, averaging 60–100 words per minute), with slightly longer pauses after words, commas, sentences and line breaks, plus the occasional "thinking" pause. The whole timing plan is worked out before typing starts, so the countdown is exact. Pick _Very fast_, _Fast_, _Normal_ or _Slow_ for a steady pace instead.

Tips:

- Let go of the shortcut keys straight away. TypeClip waits until you do before it starts.
- Code editors may auto-indent or auto-close brackets while TypeClip types. Turn those features off temporarily if needed.
- Password fields that use macOS _Secure Input_ ignore typed events from apps. That's a macOS security feature.

## How it works

About 600 lines of Swift, with no dependencies:

- [`HotKey.swift`](Sources/HotKey.swift) registers a global shortcut with Carbon's `RegisterEventHotKey`.
- [`Typer.swift`](Sources/Typer.swift) posts a `CGEvent` key press for every character using `keyboardSetUnicodeString`, so it works with any keyboard layout, accents, emoji, and non-Latin scripts.
- [`Pacing.swift`](Sources/Pacing.swift) plans the gap after every character. The human-like model uses a log-normal key interval plus pauses at word and sentence boundaries.
- [`PermissionGuide.swift`](Sources/PermissionGuide.swift) explains the Accessibility permission before macOS asks for it, and confirms once it's on.
- [`AppDelegate.swift`](Sources/AppDelegate.swift) runs the menu bar UI, the countdown, and settings.

TypeClip doesn't connect to the internet, collect data, or store your clipboard. It only reads the clipboard when you press the shortcut.

## Build from source

You need Xcode or the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/elchuzade/typeclip.git
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
