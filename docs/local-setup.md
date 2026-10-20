---
title: Local setup
description: Prerequisites and the build, launch, and install commands defined in the repo.
audience: engineer
status: current
---

After reading this page you can build `build/ExcaliCursor.app`, launch it, and see the menu-bar icon.

## Prerequisites

| Requirement | Version in the repo | Where stated |
| --- | --- | --- |
| macOS | 13.0 | `Package.swift` (`.macOS(.v13)`), `Info.plist` (`LSMinimumSystemVersion`), `README.md` |
| Swift tools | 5.9 | `Package.swift` (`swift-tools-version: 5.9`). `README.md` also says Swift 5.9+ or the Xcode Command Line Tools |
| Node | Unknown | `bin/excalicursor.js` uses `#!/usr/bin/env node`. `package.json` has no `engines` field |
| `make`, `swift`, `hdiutil`, `codesign`, `open` | Unknown | Invoked by `Makefile` |

`Package.swift` has no package dependencies. There is no migrate step and no seed step. Checked `Makefile` and `Package.swift`.

`OverlayWebView` sets `isInspectable = true` when the OS is macOS 13.3 or newer. The minimum system version remains 13.0.

## Build and run

From the repo root:

```bash
make app
```

```bash
make run
```

```bash
make dmg
```

```bash
make install
```

```bash
make clean
```

`make` with no target runs `all`, which depends on `app`. `npm run build`, `npm run dmg`, and `npm run install-app` call `make app`, `make dmg`, and `make install` (`package.json`).

The Node CLI, after `npm` exposes `bin/excalicursor.js`:

```bash
excalicursor
```

```bash
excalicursor install
```

```bash
excalicursor dmg
```

```bash
excalicursor stop
```

`excalicursor.js --postinstall` builds the app when `build/ExcaliCursor.app` is missing and exits 0. The `catch` around that build ignores the error. `package.json` `postinstall` runs that flag.

`scripts/generate_icons.swift` is not a `make` target. Running it is not wired. The script’s own output path is `build/AppIcon.iconset`.

There is no test target in `Package.swift` and no test script in the root `package.json`.

## Healthy process

`README.md` says `make run` leaves the sketch icon in the menu bar. `AppDelegate.updateStatusIcon` sets the button tooltip to `ExcaliCursor — Idle` or `ExcaliCursor — Drawing Active`. The default CLI path prints `Launched` plus the app path it opened (`/Applications/ExcaliCursor.app` if that bundle exists, otherwise `build/ExcaliCursor.app`).

No health URL exists. Checked `Sources/` for `os_log`, `Logger`, `NSLog`, and `print`.

## Failures named in the repo

- Double-tap Option needs Accessibility. `README.md` and the alert in `HotkeyManager.promptForAccessibilityIfNeeded` say keyboard shortcuts keep working without it. Settings shows **Open Accessibility Settings** when `needsAccessibilityForDoubleTap` is true.
- A hotkey Carbon rejects sets `hotkeyRegistrationError` to the combo’s display string plus ` is already in use`, then restores `lastGoodCombo` when one exists (`HotkeyManager.registerCarbonHotKey`).
- Login-item `register()` / `unregister()` failure puts `error.localizedDescription` on the settings view and sets the toggle from `SMAppService.mainApp.status` (`SettingsPopoverViewController.swift`). `README.md` says the same.
- `excalicursor install` prints `Could not copy to /Applications automatically; using` the bundled app path when the copy throws.
- `excalicursor stop` prints `ExcaliCursor is not running.` when `killall` fails.
- `Makefile` `app` runs `codesign --force --deep --sign -` and ignores a non-zero status (`|| true`).

> **Boundary:** `make install` runs `rm -rf "/Applications/ExcaliCursor.app"` before `cp`. A failed copy leaves that path empty. The Makefile does not restore the previous bundle.
