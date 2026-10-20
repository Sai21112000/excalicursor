---
title: Decisions
description: Behaviors the Swift and canvas code enforce, and what each one rules out.
audience: engineer
status: current
---

After reading this page you can see which constraints are in code, so a change that breaks them is a behavior change.

No ADR directory exists. Checked the repo root and `Sources/`. Each entry below is a rule the running code applies. The running entry point is `main.swift` plus the page loaded by `OverlayWebView`.

> **Boundary:** Double-tap Option is not delivered for other frontmost apps until Accessibility allows the global event monitor. The Carbon shortcut does not use that monitor (`HotkeyManager.swift`).

## Accessory menu-bar app

`main.swift` calls `setActivationPolicy(.accessory)`. `Info.plist` sets `LSUIElement` to true. The process does not show a Dock icon and does not use a normal document window.

This rules out a Dock app and a document-based window as the shell.

## Overlay under the Dock

`OverlayPanel` sets its level to `CGWindowLevelForKey(.dockWindow) - 1`. The comment in that initializer says this stays under the Dock, which is under the menu bar, so both stay clickable, and still above normal and floating windows. Collection behavior includes `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary`, and `ignoresCycle`. `canBecomeMain` returns false. The style mask includes `nonactivatingPanel`.

This rules out covering the menu bar or Dock, and rules out the overlay becoming the main window.

`canBecomeKey` is true only when `ignoresMouseEvents` is false. `syncOverlayState` makes the panel under the pointer key while drawing mode is on.

## Click-through when idle

`OverlayPanel` starts with `ignoresMouseEvents = true`. `setOverlayActive` sets it from `isActive`. The page adds class `inactive`, which sets `pointer-events: none` on the canvas and hides the dock (`canvas.html`).

This rules out capturing clicks, scrolls, and keystrokes for the app underneath while drawing mode is off.

## Swallowed key events

`OverlayPanel.keyDown` is empty. `noResponder` skips `keyDown` so `NSWindow` does not beep. The comment in `keyDown` states that reason.

This rules out the system beep for keys the web view does not handle.

## Carbon shortcut, event-monitor double-tap

`registerCarbonHotKey` uses `RegisterEventHotKey` with signature `0x45584343` (`EXCC`) and id `1`. `README.md` says this shortcut works without Accessibility.

Double-tap installs global and local `flagsChanged` and `keyDown` monitors. A nil global flags monitor sets `needsAccessibilityForDoubleTap` and may show one alert, gated by `ExcaliCursor.didPromptAccessibility`. A second tap counts when the gap is greater than `0.04` seconds and at most `doubleTapInterval`, and no other key or modifier was held (`handleFlagsChanged`).

This rules out a global shortcut that depends on Accessibility, and rules out counting Option chords or Option plus another key as a double-tap.

## Rejected hotkeys revert

If `tryRegister` does not return `noErr`, the error string is the combo display string plus ` is already in use`. When `lastGoodCombo` exists and differs, that combo is registered and written to `UserDefaults`.

This rules out leaving a combo installed in defaults that Carbon refused.

Recorded shortcuts with no modifier call `NSSound.beep` and are not saved (`SettingsPopoverView.startRecordingShortcut`). This rules out a bare key as the global hotkey.

## One panel per display

`rebuildScreenOverlays` and `handleScreenParametersChanged` own the panel list. Strokes stay inside each web view.

This rules out one canvas bitmap stretched across every display, and rules out automatic copy of strokes onto a newly attached display.

## Strokes are not persisted

`canvas.js` keeps elements in `state`. `localStorage` stores dock prefs only (`ExcaliCursor.dockPrefs.v1`).

This rules out restoring strokes after quit. Preferences in `UserDefaults` do persist. See [Data model](data-model.md).

## Login item through SMAppService

The settings toggle calls `SMAppService.mainApp.register()` or `unregister()` and then reads `.status`. On throw, the toggle matches `.enabled` and the view shows `error.localizedDescription`.

This rules out a login item stored only as a boolean in `UserDefaults`.

## Ad-hoc signature

`Makefile` signs with `codesign --force --deep --sign -` and ignores failure. No `.entitlements` file is in the repo. Checked the repo root and `Sources/`.

This rules out a build that fails closed when signing fails, and rules out an entitlements file as part of the current build.

## Text lock versus the README

`README.md` and `site/index.html` say `Q` keeps the selected tool active after a stroke. `canvas.js` uses `isToolLocked` only so a committed text element does not switch the tool to `select`.

The page that runs is `canvas.js`. This rules out treating the README sentence as the behavior for rectangle, pen, and the other tools.
