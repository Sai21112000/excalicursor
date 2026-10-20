---
title: Operations
description: How the repo builds the app bundle and disk image, and what it logs.
audience: operator
status: partial
---

After reading this page you can build the bundle, write the disk image, copy it to `/Applications`, and quit the running process.

The repo builds a local `.app` and a `.dmg`. It does not define a remote deploy, a CI workflow, or a rollback command. Checked the repo root for `.github/`, `Dockerfile`, and workflow YAML. None are present. Status is partial because logs and rollback are not defined.

## Build and install

Commands from `Makefile` and `package.json`:

```bash
make app
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

```bash
npm run build
```

```bash
npm run dmg
```

```bash
npm run install-app
```

`make app` runs `swift build -c release`, copies `.build/release/ExcaliCursor` to `build/ExcaliCursor.app/Contents/MacOS/ExcaliCursor`, copies `Info.plist`, copies `ExcaliCursor_ExcaliCursor.bundle` when that directory exists, copies `Sources/ExcaliCursor/Resources/*`, and ad-hoc signs with `codesign --force --deep --sign -`. A codesign failure does not fail the target.

`make dmg` depends on `app`. It stages the bundle plus a symlink to `/Applications`, then runs the `hdiutil` line from `Makefile` (`APP_NAME` is `ExcaliCursor`, `DMG_STAGING` is `build/dmg-staging`, `DMG_PATH` is `build/ExcaliCursor.dmg`):

```bash
hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING)" -ov -format UDZO "$(DMG_PATH)"
```

The staging directory is removed afterward. `README.md` says the image is `build/ExcaliCursor.dmg`.

`make install` deletes `/Applications/ExcaliCursor.app` and copies `build/ExcaliCursor.app` there. `excalicursor stop` and `excalicursor kill` run `killall ExcaliCursor` (`bin/excalicursor.js`).

## Background work

No cron, queue, or scheduled job is registered. Checked `Sources/` and `Makefile`.

These run inside the process while it is open:

| Work | Trigger | If it fails |
| --- | --- | --- |
| Carbon hotkey | `RegisterEventHotKey` during `reconfigureHotkeys` | Sets `hotkeyRegistrationError` and restores `lastGoodCombo` when one exists (`HotkeyManager.swift`) |
| Option double-tap monitors | `triggerMode` is `both` or `doubleTapOptionOnly` | If the global flags monitor is nil, `needsAccessibilityForDoubleTap` becomes true and one alert may open Accessibility settings |
| Screen list | `NSApplication.didChangeScreenParametersNotification` | Panels for missing display ids are closed. New screens get a new page with an empty `state.elements` |
| Laser fade | `requestAnimationFrame` while trail points remain | The loop stops when `renderLaserTrails` reports no active points (`canvas.js` `ensureLaserLoop`) |

## Logs and health

`Sources/` does not call `print`, `NSLog`, `os_log`, or `Logger`. Checked those names.

| Output | Where |
| --- | --- |
| `Built build/ExcaliCursor.app` | `Makefile` `app` |
| `Built build/ExcaliCursor.dmg` | `Makefile` `dmg` |
| `Installed to /Applications/ExcaliCursor.app` | `Makefile` `install` |
| `Launched <path>`, install and stop lines | `bin/excalicursor.js` |
| `Generated iconset at <path>` | `scripts/generate_icons.swift`, only if that script is run |
| Menu-bar tooltip `ExcaliCursor — Idle` or `ExcaliCursor — Drawing Active` | `AppDelegate.updateStatusIcon` |

`README.md` treats the menu-bar sketch icon after `make run` as the running app. `WKWebView.isInspectable` is set on macOS 13.3 and later (`OverlayWebView.swift`). No other health check is implemented.

## Rollback

Unknown. No rollback script or command is defined. Checked `Makefile`, `package.json`, and `bin/excalicursor.js`.

> **Boundary:** `make install` deletes `/Applications/ExcaliCursor.app` and then copies the new bundle. The repo does not keep the previous app.
