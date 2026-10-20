# ExcaliCursor

**ExcaliCursor** is a lightweight, system-wide macOS menu bar utility that brings Excalidraw's iconic sketch-style vectors directly onto your screen overlay. Built using native AppKit windows and the Rough.js rendering engine, it lets you sketch over code editors, browser windows, or live video calls without interrupting your workflow.

**Instant Trigger & On-Demand Overlay:** Activated only when you need it. Press a customizable hotkey or double-tap <kbd>⌥</kbd> to toggle the drawing canvas on or off while your foreground app keeps focus.

<p>
  <a href="#activate"><strong>Activate</strong></a>
  &nbsp;·&nbsp;
  <a href="#features"><strong>Features</strong></a>
  &nbsp;·&nbsp;
  <a href="#shortcuts"><strong>Shortcuts</strong></a>
  &nbsp;·&nbsp;
  <a href="#build"><strong>Build &amp; Run</strong></a>
</p>

## Activate

<p>
  Default hotkey
  <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>D</kbd>.
  Presets in Settings:
  <kbd>⌘</kbd> <kbd>D</kbd>
  and
  <kbd>⌥</kbd> <kbd>D</kbd>.
  Or double-tap <kbd>⌥</kbd>.
</p>

<details>
  <summary>Double-tap <kbd>⌥</kbd> and Accessibility</summary>
  <p>The keyboard shortcut is registered with Carbon and works without extra permission. Double-tap <kbd>⌥</kbd> needs ExcaliCursor allowed under <strong>System Settings → Privacy &amp; Security → Accessibility</strong>. Settings shows <strong>Open Accessibility Settings</strong> when that monitor is unavailable.</p>
</details>

<details>
  <summary>What the menu bar item shows</summary>
  <ul>
    <li>Shortcut and double-tap: <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>D</kbd> / 2×<kbd>⌥</kbd></li>
    <li>Shortcut only: the keys you saved</li>
    <li>Double-tap only: 2×<kbd>⌥</kbd></li>
  </ul>
</details>

## Features

<p id="features">Click a row to open it.</p>

<details open>
  <summary><strong>On-Demand Hotkey Toggle</strong></summary>
  <p>Stays out of the way until a global hotkey fires, for example <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>D</kbd>, <kbd>⌘</kbd> <kbd>D</kbd>, or a double-tap of <kbd>⌥</kbd>.</p>
</details>

<details>
  <summary><strong>Zero Input Interruption</strong></summary>
  <p>When drawing mode is off, the overlay ignores mouse events, so clicks, scrolls, and keystrokes go to the app underneath. Annotations stay on screen unless you choose to hide or clear them.</p>
</details>

<details>
  <summary><strong>Screen-Side Adaptive Dock</strong></summary>
  <p>Drag the toolbar by its 6-dot grip. Near the left or right edge it becomes a vertical dock. Near the top or bottom it becomes a horizontal dock. Double-click the grip to snap back to top-center.</p>
</details>

<details>
  <summary><strong>Laser Pointer</strong> <kbd>K</kbd></summary>
  <p>Neon crimson trail with midpoint spline smoothing and a radial cursor glow for screen shares, code walkthroughs, and presentations.</p>
</details>

<details>
  <summary><strong>Stroke, Sloppiness, and Theme</strong></summary>
  <p>Stroke color, width (Thin, Bold, Extra), Rough.js sloppiness (Architect, Artist, Cartoon), hachure fill, and a dark or light toolbar.</p>
</details>

<details>
  <summary><strong>Copy PNG and Launch at Login</strong></summary>
  <p>Press <kbd>⌘</kbd> <kbd>C</kbd> to put a transparent PNG of the canvas on the macOS clipboard. Launch at Login uses <code>SMAppService</code>. If registration fails, the toggle reverts and Settings shows the error.</p>
</details>

## Toolbar shortcuts

<p id="shortcuts">These keys work while drawing mode is active. Click a key to read the action.</p>

<details>
  <summary><kbd>Q</kbd> Lock tool</summary>
  <p>Keep the selected tool active after a stroke.</p>
</details>

<details>
  <summary><kbd>H</kbd> Hand</summary>
  <p>Pan the canvas.</p>
</details>

<details>
  <summary><kbd>V</kbd> or <kbd>1</kbd> Selection</summary>
  <p>Select, move, restyle, or delete shapes.</p>
</details>

<details>
  <summary><kbd>R</kbd> or <kbd>2</kbd> Rectangle</summary>
  <p>Sketch a rectangle.</p>
</details>

<details>
  <summary><kbd>D</kbd> or <kbd>3</kbd> Diamond</summary>
  <p>Sketch a diamond.</p>
</details>

<details>
  <summary><kbd>O</kbd> or <kbd>4</kbd> Ellipse</summary>
  <p>Sketch an ellipse.</p>
</details>

<details>
  <summary><kbd>A</kbd> or <kbd>5</kbd> Arrow</summary>
  <p>Sketch an arrow.</p>
</details>

<details>
  <summary><kbd>L</kbd> or <kbd>6</kbd> Line</summary>
  <p>Sketch a line.</p>
</details>

<details>
  <summary><kbd>P</kbd> or <kbd>7</kbd> Draw</summary>
  <p>Freehand pen.</p>
</details>

<details>
  <summary><kbd>T</kbd> or <kbd>8</kbd> Text</summary>
  <p>Place a text annotation.</p>
</details>

<details>
  <summary><kbd>E</kbd> or <kbd>0</kbd> Eraser</summary>
  <p>Erase a shape under the pointer.</p>
</details>

<details>
  <summary><kbd>K</kbd> Laser pointer</summary>
  <p>Glowing fading red spline trail.</p>
</details>

<details>
  <summary><kbd>⇧</kbd> <kbd>X</kbd> Draw to shape</summary>
  <p>Recognizes rectangles, diamonds, ellipses, and lines.</p>
</details>

<details>
  <summary><kbd>B</kbd> Bucket fill</summary>
  <p>Fills a shape with Rough.js hachure.</p>
</details>

<details>
  <summary><kbd>C</kbd> or <kbd>Delete</kbd> Clear</summary>
  <p>Clears every drawing on the canvas. <kbd>Delete</kbd> removes the current selection when one exists.</p>
</details>

<details>
  <summary><kbd>⌘</kbd> <kbd>Z</kbd> Undo</summary>
  <p>Undo the last stroke.</p>
</details>

<details>
  <summary><kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>Z</kbd> Redo</summary>
  <p>Redo a stroke.</p>
</details>

<details>
  <summary><kbd>⌘</kbd> <kbd>C</kbd> Copy PNG</summary>
  <p>Copy the canvas to the clipboard as a PNG.</p>
</details>

<details>
  <summary><kbd>Esc</kbd> Exit</summary>
  <p>Leave drawing mode and return to click-through. Closes an open popover, or clears the selection, before exiting.</p>
</details>

## Build & Run

<p id="build">macOS 13.0 (Ventura) or later, and Swift 5.9+ or the Xcode Command Line Tools.</p>

<details>
  <summary>Build the <code>.app</code></summary>
  <pre><code>make app</code></pre>
</details>

<details>
  <summary>Launch ExcaliCursor</summary>
  <pre><code>make run</code></pre>
  <p>The sketch icon appears in the menu bar.</p>
</details>

<details>
  <summary>Build <code>ExcaliCursor.dmg</code></summary>
  <pre><code>make dmg</code></pre>
  <p>Writes <code>build/ExcaliCursor.dmg</code> with a shortcut to <code>/Applications</code>.</p>
</details>
