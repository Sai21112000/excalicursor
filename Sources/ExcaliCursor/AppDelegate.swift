import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayController: OverlayWindowController!
    private let hotkeyManager = HotkeyManager.shared
    private let settingsPopover = NSPopover()

    private var toggleMenuItem: NSMenuItem!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: icnsURL) {
            NSApp.applicationIconImage = appIcon
        }

        overlayController = OverlayWindowController(hotkeyManager: hotkeyManager)

        setupStatusItem()
        setupSettingsPopover()
        bindCallbacks()
        updateStatusIcon(isActive: overlayController.isActive)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()

        toggleMenuItem = NSMenuItem(
            title: "Toggle Drawing Overlay",
            action: #selector(handleToggleOverlay),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        let laserQuickItem = NSMenuItem(
            title: "Activate Laser Pointer",
            action: #selector(handleActivateLaser),
            keyEquivalent: "k"
        )
        laserQuickItem.keyEquivalentModifierMask = []
        laserQuickItem.target = self
        menu.addItem(laserQuickItem)

        menu.addItem(.separator())

        let toolsHeader = NSMenuItem(title: "Excalidraw Tools", action: nil, keyEquivalent: "")
        toolsHeader.isEnabled = false
        menu.addItem(toolsHeader)

        let tools: [(String, String, String)] = [
            ("Selection", "select", "v"),
            ("Rectangle", "rectangle", "r"),
            ("Diamond", "diamond", "d"),
            ("Ellipse", "ellipse", "o"),
            ("Arrow", "arrow", "a"),
            ("Line", "line", "l"),
            ("Draw (Freehand Pen)", "pen", "p"),
            ("Text", "text", "t"),
            ("Eraser", "eraser", "e"),
            ("Laser Pointer", "laser", "k"),
            ("Draw to Shape", "draw-to-shape", "X"),
            ("Bucket Fill", "bucket", "b"),
            ("Hand (Pan)", "hand", "h")
        ]

        for (label, toolID, key) in tools {
            let item = NSMenuItem(title: label, action: #selector(handleSelectTool(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = key == "X" ? [.shift] : []
            item.representedObject = toolID
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let undoItem = NSMenuItem(title: "Undo Stroke", action: #selector(handleUndo), keyEquivalent: "z")
        undoItem.target = self
        menu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo Stroke", action: #selector(handleRedo), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.target = self
        menu.addItem(redoItem)

        let copyItem = NSMenuItem(title: "Copy Canvas PNG", action: #selector(handleCopyCanvas), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)

        let clearItem = NSMenuItem(
            title: "Clear Canvas",
            action: #selector(handleClearCanvas),
            keyEquivalent: "\u{8}"
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Hotkey & Overlay Settings...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit ExcaliCursor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupSettingsPopover() {
        settingsPopover.behavior = .transient
        settingsPopover.animates = true
        settingsPopover.contentViewController = SettingsPopoverViewController(
            hotkeyManager: hotkeyManager,
            onToggleOverlay: { [weak self] in
                self?.overlayController.toggleOverlay()
            },
            onActivateLaser: { [weak self] in
                self?.overlayController.selectTool("laser")
            },
            onClearCanvas: { [weak self] in
                self?.overlayController.clearAllCanvases()
            }
        )
    }

    private func bindCallbacks() {
        hotkeyManager.onToggleRequested = { [weak self] in
            self?.overlayController.toggleOverlay()
        }

        hotkeyManager.onPreferenceChanged = { [weak self] in
            self?.overlayController.syncOverlayState()
        }

        hotkeyManager.onActivationChanged = { [weak self] in
            guard let self else { return }
            self.updateStatusIcon(isActive: self.overlayController.isActive)
        }

        overlayController.onActiveStateChanged = { [weak self] isActive in
            self?.updateStatusIcon(isActive: isActive)
        }
    }

    private func updateStatusIcon(isActive: Bool) {
        if let button = statusItem.button {
            button.image = Self.makeMenuBarIcon(isActive: isActive)
            button.imagePosition = .imageOnly
            button.toolTip = isActive ? "ExcaliCursor — Drawing Active" : "ExcaliCursor — Idle"
        }

        let hint = activationHint()
        toggleMenuItem?.title = isActive
            ? "Deactivate Drawing Mode (\(hint))"
            : "Activate Drawing Mode (\(hint))"
    }

    private func activationHint() -> String {
        switch hotkeyManager.triggerMode {
        case .both:
            return "\(hotkeyManager.keyCombo.displayString) / 2×⌥"
        case .shortcutOnly:
            return hotkeyManager.keyCombo.displayString
        case .doubleTapOptionOnly:
            return "2×⌥"
        }
    }

    private static func makeMenuBarIcon(isActive: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            // Outer rounded canvas frame
            let frameRect = NSRect(x: 1.5, y: 1.5, width: 15, height: 15)
            let framePath = NSBezierPath(roundedRect: frameRect, xRadius: 4.0, yRadius: 4.0)

            if isActive {
                // Active state: Excalidraw indigo badge with glowing sketch curve & nib
                NSColor(calibratedRed: 0.41, green: 0.39, blue: 0.86, alpha: 1.0).setFill()
                framePath.fill()
            } else {
                // Template idle state: crisp monochrome outline + pen + sketch curve
                NSColor.labelColor.withAlphaComponent(0.85).setStroke()
                framePath.lineWidth = 1.35
                framePath.stroke()
            }

            let fgColor = isActive ? NSColor.white : NSColor.labelColor

            // Sketch S-curve inside the menu bar icon
            let curve = NSBezierPath()
            curve.move(to: NSPoint(x: 4.2, y: 5.0))
            curve.curve(
                to: NSPoint(x: 10.2, y: 8.5),
                controlPoint1: NSPoint(x: 4.5, y: 9.8),
                controlPoint2: NSPoint(x: 7.5, y: 4.2)
            )
            curve.lineCapStyle = .round
            curve.lineWidth = 1.65
            fgColor.setStroke()
            curve.stroke()

            // Tilted pen nib at top-right pointing down-left toward the curve
            let pen = NSBezierPath()
            pen.move(to: NSPoint(x: 9.8, y: 9.2))
            pen.line(to: NSPoint(x: 11.4, y: 13.8))
            pen.line(to: NSPoint(x: 14.0, y: 11.2))
            pen.close()
            pen.lineJoinStyle = .round
            if isActive {
                NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.40, alpha: 1.0).setFill()
            } else {
                fgColor.setFill()
            }
            pen.fill()

            // Active laser dot accent in top-left corner when drawing mode is active
            if isActive {
                let dotRect = NSRect(x: 4.2, y: 11.2, width: 3.2, height: 3.2)
                let dotPath = NSBezierPath(ovalIn: dotRect)
                NSColor(calibratedRed: 1.0, green: 0.36, blue: 0.36, alpha: 1.0).setFill()
                dotPath.fill()
            }

            return true
        }
        image.isTemplate = !isActive
        image.accessibilityDescription = isActive ? "ExcaliCursor (Drawing Active)" : "ExcaliCursor (Idle)"
        return image
    }

    // MARK: - Menu Actions

    @objc private func handleToggleOverlay() {
        overlayController.toggleOverlay()
    }

    @objc private func handleActivateLaser() {
        overlayController.selectTool("laser")
    }

    @objc private func handleSelectTool(_ sender: NSMenuItem) {
        guard let tool = sender.representedObject as? String else { return }
        overlayController.selectTool(tool)
    }

    @objc private func handleUndo() {
        overlayController.undo()
    }

    @objc private func handleRedo() {
        overlayController.redo()
    }

    @objc private func handleCopyCanvas() {
        overlayController.copyActiveCanvasToClipboard()
    }

    @objc private func handleClearCanvas() {
        overlayController.clearAllCanvases()
    }

    @objc private func handleOpenSettings() {
        guard let button = statusItem.button else { return }
        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            settingsPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            settingsPopover.contentViewController?.view.window?.makeKey()
        }
    }
}
