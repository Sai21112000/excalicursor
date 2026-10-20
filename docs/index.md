---
title: ExcaliCursor
description: Menu-bar overlay that draws sketch strokes on top of the macOS screen.
audience: engineer
status: current
---

After reading this page you can name the process that runs, the directories that belong to it, and which documents cover setup, configuration, data, and the native bridge.

ExcaliCursor is a macOS menu-bar app (`LSUIElement`, bundle id `com.excalicursor.app` in `Info.plist`). It opens one transparent panel per display and draws on a `WKWebView` loaded from `canvas.html`. The person using it sketches over whatever window is already on screen. Version `1.0.0` is set in `Info.plist` (`CFBundleShortVersionString`) and in `package.json`.

The running entry point is `Sources/ExcaliCursor/main.swift`. It starts `NSApplication`, sets the activation policy to `.accessory`, and hands control to `AppDelegate`.

The app does these things:

- Registers a Carbon global hotkey, and optionally watches for a double-tap of Option (`HotkeyManager.swift`).
- Ignores mouse events while drawing mode is off (`OverlayPanel.swift`, `OverlayWindowController.swift`).
- Draws strokes with the bundled Rough.js canvas in `Sources/ExcaliCursor/Resources/rough.min.js`.
- Copies a PNG of one screen’s canvas to the general pasteboard.
- Registers or unregisters a login item with `SMAppService.mainApp`.

It keeps strokes in memory inside each page. Quit drops them. It does not open an HTTP server. `Package.swift`, `Makefile`, and `Sources/` do not start `super-video-maker-skill-main/`.

> **Boundary:** Strokes live only in the page’s `state.elements`. Quitting the app drops them.

## Documents

- [Architecture](architecture.md) — process, modules, and where state lives.
- [Local setup](local-setup.md) — prerequisites and the `make` / CLI commands in the repo.
- [Configuration](configuration.md) — `UserDefaults` keys and canvas `localStorage`.
- [Data model](data-model.md) — drawing elements, dock prefs, and who writes them.
- [API](api.md) — CLI commands and the `excaliCursorBridge` messages.
- [Operations](operations.md) — app bundle, disk image, and install.
- [Decisions](decisions.md) — behavior the code enforces.

## Repository layout

| Path | Responsibility |
| --- | --- |
| `Sources/` | Swift executable and the canvas page (`canvas.html`, `canvas.js`, `rough.min.js`, `AppIcon.icns`). |
| `bin/` | Node launcher `excalicursor.js`. |
| `scripts/` | `generate_icons.swift` writes `build/AppIcon.iconset`. `Makefile` does not call it. |
| `site/` | Static page (`index.html`, `styles.css`, `favicon.svg`). No build script. |
| `build/` | Output of `make`: `ExcaliCursor.app`, `ExcaliCursor.dmg`, and `AppIcon.iconset`. |
| `.build/` | Swift Package Manager products. |
| `super-video-maker-skill-main/` | Separate skill tree with its own `README.md`. Not referenced by `Package.swift`, `Makefile`, or `Sources/`. |
| `node_modules/` | Present. `package.json` declares no dependencies. `pnpm-lock.yaml` has an empty importer. |
| `.cursor/` | Contains `debug-19f9c9.log`. The app does not read it. |

Root manifests the app uses: `Package.swift`, `Makefile`, `Info.plist`, `package.json`, `README.md`. `excalicursor-1.0.0.tgz` contains the paths listed in `package.json` `files`, including `build/ExcaliCursor.app`. No script in `package.json` or `Makefile` produces that tarball. `package.json` sets `"license": "MIT"`. No `LICENSE` file is in the repo root.
