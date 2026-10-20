import AppKit

public final class OverlayPanel: NSPanel {
    public init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Just under the Dock, which is itself under the menu bar, so both stay
        // clickable. Still above normal and floating windows.
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.dockWindow)) - 1)
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.isMovable = false
        self.isReleasedWhenClosed = false
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = true
    }

    public override var canBecomeKey: Bool {
        return !ignoresMouseEvents
    }

    public override var canBecomeMain: Bool {
        return false
    }

    public override func keyDown(with event: NSEvent) {
        // Swallow unhandled key events that bubble up from WKWebView so NSWindow
        // does not call noResponder(for: #selector(keyDown(_:))) and trigger NSBeep().
    }

    public override func noResponder(for eventSelector: Selector) {
        if eventSelector != #selector(NSResponder.keyDown(with:)) {
            super.noResponder(for: eventSelector)
        }
    }
}
