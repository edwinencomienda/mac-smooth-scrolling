# MacSmoothScroll

A tiny native macOS menu-bar app that adds smooth scrolling for external mice, with adjustable speed and a reverse-direction toggle. Trackpads and Magic Mouse are left alone (macOS already smooths them).

## Features

- Smooth, momentum-based scrolling for external wheel mice
- Scrolling Speed slider (snaps to ticks)
- Reverse mouse scroll (trackpad direction unaffected)
- **Jump to top / bottom** — hold `⌘⇧` and scroll up/down to jump to edges
- Launch at login
- Lives in the menu bar (no Dock icon)
- **Settings window** — full SwiftUI preferences pane, reachable from the menu bar or by relaunching
- **Hide menu bar icon** — run invisibly; reopen settings by relaunching via Spotlight, Raycast, etc.

## Shortcuts

| Shortcut             | What it does                                          |
| -------------------- | ----------------------------------------------------- |
| `⇧` + scroll         | Scroll horizontally (wheel Y becomes X)              |
| `⌘⇧` + scroll up     | Jump to the top of the current scroll view           |
| `⌘⇧` + scroll down   | Jump to the bottom of the current scroll view        |

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

## Signing configuration

Signing identities are loaded from `.env` (dev) and `.env.prod` (distribution). See `.env.example` for the full template.

### Development signing (`.env`)

Used by `make bundle` and `make install`. A stable self-signed identity lets macOS remember the Accessibility permission across rebuilds (ad-hoc signatures change every build and force you to re-grant).

```env
# Any name works — this is the Common Name of a self-signed cert in your Keychain.
# Defaults to "MacSmoothScroll Dev" if unset.
# Use "-" for ad-hoc (permission will reset every rebuild).
CODESIGN_IDENTITY=Your Name Local Dev
```

To create a reusable self-signed cert:

1. Open **Keychain Access → Certificate Assistant → Create a Certificate…**
2. Name: your chosen `CODESIGN_IDENTITY` value
3. Identity Type: Self Signed Root
4. Certificate Type: Code Signing
5. Save it in the **login** keychain

### Production signing & notarization (`.env.prod`)

Used by `make sign` to produce a Developer ID–signed, notarized bundle ready for public distribution.

```env
SIGN_IDENTITY=Developer ID Application: Your Name (TEAMID)
APPLE_API_KEY=/absolute/path/to/AuthKey_XXXXXXXXXX.p8
APPLE_API_KEY_ID=XXXXXXXXXX
APPLE_API_ISSUER=00000000-0000-0000-0000-000000000000
APPLE_TEAM_ID=TEAMID
```

Values come from your Apple Developer account:

- `SIGN_IDENTITY` — the full string from `security find-identity -v -p codesigning`
- `APPLE_API_KEY*` — an App Store Connect API key (Users and Access → Integrations → App Store Connect API)
- `APPLE_TEAM_ID` — from developer.apple.com → Membership

Then:

```bash
make sign   # build, sign with Developer ID, notarize, staple
make dmg    # package the signed .app into a distributable DMG
```

## Menu bar behavior

- **Left-click** the menu bar icon → opens the **Settings** window directly.
- **Right-click** (or Control-click) the menu bar icon → shows a small menu with **Settings…** and **Quit**.

All preferences live in the Settings window — the menu bar is just a shortcut.

## Settings window

Open it by left-clicking the menu bar icon, choosing **Settings…** from the right-click menu, or by relaunching the app (Spotlight, Raycast, `open -a MacSmoothScroll`).

While the settings window is open, the app temporarily switches its activation policy from `.accessory` to `.regular`, so the window can take focus and the Dock shows the app. On close, it switches back — no lingering Dock icon.

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
