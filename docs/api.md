---
title: API
description: CLI commands and the messages passed between Swift and the canvas page.
audience: integrator
status: current
---

After reading this page you can launch or stop the app from the CLI and you can see every message the canvas page sends to Swift.

There is no HTTP route. Checked `Sources/` and `bin/excalicursor.js`. Auth on every entry below is none: the CLI is a local process, and the bridge is a `WKScriptMessageHandler` inside that process.

> **Boundary:** `copyImage` with no comma in the data URL, or with base64 that is not a decodable `NSImage`, returns without writing the pasteboard and without an error message (`OverlayWebView.writeDataURLToPasteboard`).

## CLI

Implemented in `bin/excalicursor.js`. The default subcommand is `start`, which falls through to the launch path.

| Command | Auth | Request | Response | Where it is implemented |
| --- | --- | --- | --- | --- |
| `excalicursor` | None | No arguments | Prints `Launched` and the opened path. Spawns `open` on `/Applications/ExcaliCursor.app` if it exists, otherwise builds if needed and opens `build/ExcaliCursor.app` | `bin/excalicursor.js` |
| `excalicursor install` | None | Subcommand `install` | Copies the bundle to `/Applications/ExcaliCursor.app`, prints `Installed ExcaliCursor to` that path, then `open`s it. On copy failure, prints `Could not copy to /Applications automatically; using` the build path and opens that | `installToApplications` |
| `excalicursor dmg` | None | Subcommand `dmg` | Runs `make dmg` in the repo root | `bin/excalicursor.js` |
| `excalicursor stop` | None | `stop` or `kill` | `killall ExcaliCursor`. Prints `Stopped ExcaliCursor.` or `ExcaliCursor is not running.` | `bin/excalicursor.js` |
| `excalicursor --help` | None | `--help`, `-h`, or `help` | Prints the usage text and exits 0 | `bin/excalicursor.js` |
| `excalicursor --postinstall` | None | Flag | Builds when the app bundle is missing. Build errors are ignored. Exits 0 | `bin/excalicursor.js` |

## Swift to the page

`OverlayWebView` evaluates these scripts. Each call is skipped by the page when `window.excaliCursor` is missing. Tool names are inserted inside single quotes with no escaping (`selectTool`).

| Call | Auth | Request | Response | Where it is implemented |
| --- | --- | --- | --- | --- |
| `window.excaliCursor.setActive(active, hideDrawingsWhenInactive)` | None | Two booleans | Toggles `inactive` and `hide-when-inactive` on `document.body` | `canvas.js` `setActive` |
| `window.excaliCursor.selectTool(tool)` | None | Tool id string | Sets `state.currentTool` | `canvas.js` `selectTool` |
| `window.excaliCursor.undo()` | None | None | Pops one element onto `redoStack` | `canvas.js` `undo` |
| `window.excaliCursor.redo()` | None | None | Pushes one redo element back | `canvas.js` `redo` |
| `window.excaliCursor.copyCanvasToClipboard()` | None | None | Posts `copyImage` | `canvas.js` `copyCanvasToClipboard` |
| `window.excaliCursor.clearCanvas()` | None | None | Empties `state.elements` | `canvas.js` `clearCanvas` |

Tool ids used by `AppDelegate` and the toolbar: `select`, `rectangle`, `diamond`, `ellipse`, `arrow`, `line`, `pen`, `text`, `eraser`, `laser`, `draw-to-shape`, `bucket`, `hand`, `lasso`.

## Page to Swift

Handler name: `excaliCursorBridge` (`OverlayWebView.messageHandlerName`). The body must be a dictionary with a string `action`. Any other body returns immediately. An unknown `action` hits `default: break`.

| Message | Auth | Request | Response | Where it is implemented |
| --- | --- | --- | --- | --- |
| `deactivate` | None | `{"action":"deactivate"}` | `OverlayWindowController.setOverlayActive(false)` | `OverlayWebView.userContentController` |
| `copyImage` | None | `{"action":"copyImage","dataURL":"<png data URL>"}` | Decodes the base64 after the first comma and writes an `NSImage` to `NSPasteboard.general` | `writeDataURLToPasteboard` |

Real request from the exit control in `canvas.js`:

```javascript
postToNative({ action: "deactivate" });
```

`postToNative` delivers that object only when `window.webkit.messageHandlers.excaliCursorBridge` exists. Drawing-mode keys (tool letters, Escape, Command-Z, Command-Shift-Z, Command-Y, Command-C, Delete) are handled in the same file’s `keydown` listener. They are not bridge messages. `README.md` lists those keys. Command-Y is implemented in `canvas.js` and is not listed in `README.md`.

`Q` toggles `state.isToolLocked`. `README.md` and `site/index.html` say that lock keeps the selected tool after a stroke. `canvas.js` reads `isToolLocked` only inside `commitActiveTextInput`: after text is committed, the tool becomes `select` unless the lock is on. Other tools stay selected either way. The running page is `canvas.js`.
