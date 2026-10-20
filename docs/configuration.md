---
title: Configuration
description: UserDefaults keys and canvas localStorage that the running app reads.
audience: engineer
status: current
---

After reading this page you can name every preference the ExcaliCursor process stores, where it is read, and the default used when the key is missing.

The app reads no environment variables. Checked `Sources/` for `ProcessInfo.processInfo.environment`, `getenv`, and `process.env`. The repo does not define separate local and production values. Checked `Makefile`, `package.json`, and `Info.plist`.

`super-video-maker-skill-main/.env.example` lists `HEYGEN_API_KEY`, `HEYGEN_AVATAR_ID`, `HEYGEN_VOICE_ID`, `REPLICATE_API_TOKEN`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `AWS_S3_BUCKET`, and `SOUNDTRACKS_S3_BASE_URL`. Those names are not read by `Sources/`.

Launch at login is `SMAppService.mainApp`, not a `UserDefaults` key (`SettingsPopoverViewController.swift`).

> **Boundary:** A Carbon registration failure does not keep the rejected combo. `registerCarbonHotKey` writes `lastGoodCombo` back to `ExcaliCursor.keyCode` and `ExcaliCursor.carbonModifiers`.

## ExcaliCursor process

Keys live in `HotkeyManager.DefaultsKey` and `UserDefaults.standard`. None are required to launch. Missing keys use the defaults in `HotkeyManager.init`.

| Variable | Required | Where it is read | Purpose | Example |
| --- | --- | --- | --- | --- |
| `ExcaliCursor.triggerMode` | No | `HotkeyManager.init`, `triggerMode.didSet` | Which activators run: `both`, `shortcutOnly`, or `doubleTapOptionOnly` | `both` |
| `ExcaliCursor.keyCode` | No | `HotkeyManager.init`, `keyCombo.didSet`, `registerCarbonHotKey` | Carbon virtual key code for the global shortcut | Unset. Default combo is `KeyCombo.cmdShiftD` |
| `ExcaliCursor.carbonModifiers` | No | Same as `keyCode` | Carbon modifier mask (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`) | Unset. Default is command + shift |
| `ExcaliCursor.doubleTapInterval` | No | `HotkeyManager.init`, `doubleTapInterval.didSet`, `handleFlagsChanged` | Maximum seconds between Option releases. Values `<= 0` are replaced with `0.32`. The slider writes `0.18` through `0.50` in steps of `0.02` | `0.32` |
| `ExcaliCursor.clearOnDeactivate` | No | `HotkeyManager.init`, `clearOnDeactivate.didSet`, `OverlayWindowController.setOverlayActive` | Clears every canvas when drawing mode turns off | `false` (`UserDefaults.bool` when the key is absent) |
| `ExcaliCursor.hideDrawingsWhenInactive` | No | `HotkeyManager.init`, `hideDrawingsWhenInactive.didSet`, `OverlayWindowController.syncOverlayState` | Asks each page to hide strokes while inactive. The settings toggle “Keep drawings visible when deactivated” stores the inverse | `false` |
| `ExcaliCursor.didPromptAccessibility` | No | `promptForAccessibilityIfNeeded` | After the first Accessibility alert, further automatic alerts are skipped | `false` |

Settings can assign three presets: `KeyCombo.cmdShiftD`, `KeyCombo.cmdD`, and `KeyCombo.optionD`. Recording a shortcut requires a non-zero modifier mask (`SettingsPopoverView.startRecordingShortcut`). Escape cancels recording.

## Canvas page

Written by `saveDockPrefs` and read by `loadDockPrefs` in `Sources/ExcaliCursor/Resources/canvas.js`. Stroke color, width, roughness, fill, and tool are fields on `state` and are not written to `localStorage`.

| Variable | Required | Where it is read | Purpose | Example |
| --- | --- | --- | --- | --- |
| `ExcaliCursor.dockPrefs.v1` | No | `loadDockPrefs` on page load | JSON object written by `saveDockPrefs`: `isCustom`, `left`, `top`, `isVertical`, `dockClasses`, `darkMode` | `darkMode` boolean, initial `false` until the theme control runs |

`dockClasses` keeps only `vertical`, `dock-left`, `dock-right`, `dock-bottom`, and `custom-pos`.
