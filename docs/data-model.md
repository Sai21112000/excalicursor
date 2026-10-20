---
title: Data model
description: In-memory strokes, dock preferences, and the UserDefaults the app writes.
audience: engineer
status: current
---

After reading this page you can name each stored shape, which file writes it, and why there is no migration command.

There is no database, schema file, or migration directory. Checked `Package.swift`, `Makefile`, and `Sources/`. Nothing applies migrations.

Each display has its own `canvas.js` `state`. `state.elements` is the only stroke store. `state.redoStack` holds elements removed by undo, erase, Delete, or clear.

> **Boundary:** `state.elements` is not encoded to disk. Relaunch starts from an empty array.

## Drawing element

`pushElement`, text commit, and `recognizeShapeFromPoints` create objects with these fields (`canvas.js`).

| Field | Used by | Meaning |
| --- | --- | --- |
| `type` | All | `pen`, `line`, `arrow`, `rectangle`, `diamond`, `ellipse`, `text`. `draw-to-shape` exists only while the pointer is down; pointer-up replaces it with `line`, `ellipse`, `diamond`, `rectangle`, or `pen`. |
| `seed` | Rough.js options | Integer from `randomSeed`. Arrow heads use `seed + 1` and `seed + 2`. |
| `strokeColor` | All drawn types | CSS color. New strokes copy `state.strokeColor` (initial `#e03131`). |
| `strokeWidth` | Rough.js stroke | Initial `3.2`. Toolbar values are `1.8`, `3.2`, `5.2`. |
| `roughness` | Rough.js | Initial `1.2`. Toolbar values are `0.35`, `1.2`, `2.3`. |
| `fillColor` | Closed shapes when set | Set when `state.fillEnabled` is true at creation, or by the bucket tool and the fill toggle. Fill style passed to Rough.js is `hachure`. |
| `points` | `pen` | World-space `[x, y]` pairs. |
| `x1`, `y1`, `x2`, `y2` | Line, arrow, rectangle, diamond, ellipse | Opposite corners or endpoints in world space (screen minus `panX` / `panY`). |
| `text`, `fontSize` | `text` | String and size. Commit always sets `fontSize` to `22`. |

Text is filled with `fillText` in Comic Sans MS, Chalkboard SE, Marker Felt, cursive, then sans-serif. It does not go through Rough.js.

There is no primary key. Selection stores indexes into `state.elements`. Hit tests use `isPointNearElement`. Lasso selection keeps elements whose bounds center sits inside the lasso’s axis-aligned bounds (`finishPointerInteraction`).

## Who writes what

| Entity | Writer | Reader |
| --- | --- | --- |
| `state.elements`, `state.redoStack` | `canvas.js` (`pushElement`, `eraseAtPoint`, `undo`, `redo`, `clearCanvas`, Delete/Backspace, bucket, swatches, width, roughness, fill toggle) | `renderScene` in the same page |
| Laser trails | `canvas.js` pointer handlers | `renderLaserTrails`. Cleared by `clearCanvas`. Not pushed as elements |
| Dock prefs | `saveDockPrefs` | `loadDockPrefs` |
| `ExcaliCursor.*` defaults | `HotkeyManager` | `HotkeyManager.init` and the settings bindings |
| Login item | `SMAppService.mainApp.register` / `unregister` | `SMAppService.mainApp.status` |
| Pasteboard image | `OverlayWebView.writeDataURLToPasteboard` | macOS pasteboard. The app does not read it back |

`AppDelegate` and `OverlayWindowController` do not append elements. They call `window.excaliCursor` methods, which call the functions above in every page (copy uses one page). See [Architecture](architecture.md) and [Configuration](configuration.md).

## Migrations

No migration files and no migrate command. Checked `Package.swift` and `Makefile`.
