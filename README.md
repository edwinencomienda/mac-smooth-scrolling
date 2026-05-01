# MacSmoothScroll

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-6.0-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

A tiny native macOS menu-bar app that adds smooth scrolling for external mice, with adjustable speed and a reverse-direction toggle. Trackpads and Magic Mouse are left alone (macOS already smooths them).

## Why this exists

External wheel mice on macOS scroll in chunky, line-by-line steps — nothing like the buttery feel of a trackpad. Most fixes are heavy commercial apps with kernel extensions and subscriptions. **MacSmoothScroll** is a small, open-source alternative: one binary, no kext, no telemetry, no account.

## Features

- Smooth, momentum-based scrolling for external wheel mice
- Scrolling Speed slider (snaps to ticks)
- Reverse mouse scroll (trackpad direction unaffected)
- **Jump to top / bottom** — hold a recorded hotkey and scroll up/down to jump to edges; hotkey is fully customizable (default `⌥ Option`)
- Launch at login
- Lives in the menu bar (no Dock icon)
- **Settings window** — full SwiftUI preferences pane, reachable from the menu bar or by relaunching
- **Hide menu bar icon** — run invisibly; reopen settings by relaunching via Spotlight, Raycast, etc.

## Shortcuts

| Shortcut             | What it does                                          |
| -------------------- | ----------------------------------------------------- |
| `⇧` + scroll                    | Scroll horizontally (wheel Y becomes X)       |
| *jump hotkey* + scroll up       | Jump to the top of the current scroll view   |
| *jump hotkey* + scroll down     | Jump to the bottom of the current scroll view |

### Recording the jump hotkey

1. Open the settings window.
2. Click the **Jump hotkey** button under Scrolling.
3. Press and hold any combination of `⌘ ⌥ ⌃ ⇧`, then release.
4. The released combo is saved and used for the jump gesture.
5. `Esc` cancels recording. The `×` button clears the hotkey (effectively disabling the jump while the toggle is still on).

Only modifier keys are recorded — a regular keyboard key + scroll doesn't make ergonomic sense.

Detection is "contains" semantics: if your recorded hotkey is `⌥`, then both `⌥ + scroll` and `⌥⇧ + scroll` will trigger the jump. Use a richer combo (e.g. `⌥⇧`) if you want to avoid that.

Notes on the jump shortcut:

- Works with both mouse wheel and trackpad.
- Respects the **Reverse mouse scroll** setting — physical-up always means "go to top".
- Throttled to ~400ms, so a single wheel flick = a single jump (no spam when holding).
- Modifier flags are stripped from the synthesized scroll event, so apps don't misread it as `Cmd+scroll` zoom (Safari, Preview, etc.).
- Can be turned off from the menu bar (**Jump to top / bottom** toggle).

## Requirements

- macOS 13 or later
- Swift 6.0 toolchain (ships with recent Xcode / `swift --version`)
- Accessibility permission (macOS will prompt on first run)

## Project layout

```
mac-smooth-scrolling/
├── Makefile                         # build / bundle / install / sign / dmg
├── Package.swift                    # SwiftPM manifest
├── .env                             # local signing config (gitignored)
├── .env.example                     # template for .env / .env.prod
└── Sources/MacSmoothScroll/
    ├── main.swift                       # NSApp bootstrap (accessory mode)
    ├── AppDelegate.swift                # status bar item + menu UI, window mgmt, reopen handling
    ├── ScrollEngine.swift               # CGEventTap + momentum smoothing
    ├── Settings.swift                   # ObservableObject + UserDefaults-backed preferences
    ├── SettingsView.swift               # SwiftUI settings pane
    ├── SettingsWindowController.swift   # NSWindow host for the settings view
    ├── HotkeyRecorder.swift             # modifier-combo recorder used in settings
    └── Resources/
        ├── Info.plist               # bundle metadata (LSUIElement = true)
        └── MacSmoothScroll.entitlements
```

## Quick start

```bash
# Run the debug binary directly (no bundle, easiest for dev)
make run

# Build a proper .app bundle in .build/MacSmoothScroll.app
make bundle

# Open the bundled .app
make run-app

# Install to /Applications
make install

# Clean everything
make clean
```

When you first launch the app, macOS will prompt for Accessibility permission. Grant it in **System Settings → Privacy & Security → Accessibility**, then relaunch. Without it, the scroll event tap cannot run.

## Signing & distribution

Code signing and notarization are documented separately in **[SIGNING.md](SIGNING.md)**. You only need it if you're building a signed `.app` for distribution — running locally with `make run` requires no setup.

## Menu bar behavior

- **Left-click** the menu bar icon → opens the **Settings** window directly.
- **Right-click** (or Control-click) the menu bar icon → shows a small menu with **Settings…** and **Quit**.

All preferences live in the Settings window — the menu bar is just a shortcut.

## Settings window

Open it by left-clicking the menu bar icon, choosing **Settings…** from the right-click menu, or by relaunching the app (Spotlight, Raycast, `open -a MacSmoothScroll`).

The app runs as an `.accessory` (agent) app at all times — no Dock icon, and it does **not** appear in the macOS Force Quit panel (`⌘⌥Esc`). The settings window is brought to the front via `NSApp.activate(ignoringOtherApps:)` when opened.

If **Hide menu bar icon** is enabled, the menu bar icon is removed entirely. To get back into the app:

1. Launch MacSmoothScroll again (Spotlight / Raycast / `open -a MacSmoothScroll`).
2. The running instance catches the reopen event and shows the settings window.
3. Toggle **Hide menu bar icon** off if you want the icon back.

As a safety net, the app auto-opens the settings window on startup whenever the menu bar icon is hidden — **except** when the launch looks like a login auto-start (system uptime < 2 minutes). This keeps logins quiet: the app comes up silently if both launch-at-login and hide-menu-bar-icon are enabled. To reach settings after boot, just relaunch via Spotlight or Raycast.

## Preferences

Stored in `UserDefaults` under these keys:

| Key                    | Type   | Default | Range     |
| ---------------------- | ------ | ------- | --------- |
| `smoothEnabled`        | Bool   | `true`  | —         |
| `reverseMouse`         | Bool   | `false` | —         |
| `scrollSpeed`          | Double | `3.0`   | 1.0 – 6.0 |
| `jumpShortcutEnabled`  | Bool   | `true`  | —         |
| `jumpShortcutFlags`    | Int64  | `0x80000` (⌥) | CGEventFlags bitmask |
| `hideMenuBarIcon`      | Bool   | `false` | —         |

Reset with:

```bash
defaults delete com.edwinencomienda.macsmoothscroll
# or, if running unbundled via `make run`, the domain is the binary name:
defaults delete MacSmoothScroll
```

## Tuning the smoothing curve

Inside `Sources/MacSmoothScroll/ScrollEngine.swift`:

```swift
private let frameFraction: Double = 0.15
```

Fraction of the pending scroll distance consumed per frame (at ~60fps).

- `0.10` — glidier (~450ms tail)
- `0.15` — default (~300ms tail)
- `0.25` — snappier (~180ms tail)
- `0.40` — almost instant but still smooth

## Make targets

| Target     | What it does                                                   |
| ---------- | -------------------------------------------------------------- |
| `build`    | Debug `swift build` + ad-hoc codesign the binary               |
| `release`  | Release `swift build -c release`                               |
| `bundle`   | Build release → assemble `.app` → sign with `CODESIGN_IDENTITY`|
| `run`      | Run the debug binary directly                                  |
| `run-app`  | Build bundle and `open` it                                     |
| `install`  | Copy the signed bundle into `/Applications`                    |
| `sign`     | Developer ID signing + notarization (needs `.env.prod`)        |
| `dmg`      | Package the signed `.app` as a UDZO DMG                        |
| `clean`    | `swift package clean` + remove `.app` / `.zip` / `.dmg`        |

## Contributing

Contributions are welcome — bug reports, feature ideas, and pull requests.

1. **Fork** the repo and create a feature branch (`git checkout -b feat/my-change`).
2. Build locally with `make run` and verify behavior.
3. Keep changes focused; small, reviewable PRs land faster than big ones.
4. Open a PR against `main` describing **what** changed and **why**.

If you're planning a larger change (new feature, refactor), please open an issue first to discuss the approach.

### Local development

```bash
git clone https://github.com/<your-username>/mac-smooth-scrolling.git
cd mac-smooth-scrolling
make run
```

You'll need a recent Xcode (Swift 6.0) and to grant Accessibility permission on first run.

## Reporting bugs & requesting features

Use [GitHub Issues](../../issues). Helpful info to include:

- macOS version (e.g. 14.5)
- Mouse model (e.g. Logitech MX Master 3S)
- Steps to reproduce
- What you expected vs what happened
- Relevant settings (speed, reverse, jump hotkey)

## Code of Conduct

Be kind and respectful. This project follows the spirit of the [Contributor Covenant](https://www.contributor-covenant.org/). Harassment, personal attacks, or discriminatory behavior will not be tolerated.

## Security

If you discover a security issue (e.g. something exploitable in the event tap or signing flow), please **do not** open a public issue. Email the maintainer directly at `edwin@netlinkvoice.com` with details and we'll respond as soon as possible.

## License

Released under the [MIT License](LICENSE). You're free to use, modify, and distribute this software — see the `LICENSE` file for the full text.

## Acknowledgments

- Built with [Swift](https://swift.org) and AppKit.
- Inspired by the long lineage of macOS smooth-scrolling utilities — this one just aims to stay tiny, native, and free.

## Author

Made by [Edwin Encomienda](https://github.com/edwinencomienda).

If MacSmoothScroll makes your daily scrolling nicer, consider **starring the repo** ⭐ — it helps others discover the project.
