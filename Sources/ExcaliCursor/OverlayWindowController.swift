import AppKit

public final class OverlayWindowController: NSObject, OverlayWebViewDelegate {
    private struct ScreenOverlay {
        let screenID: CGDirectDisplayID
        let panel: OverlayPanel
        let webView: OverlayWebView
    }

    public private(set) var isActive: Bool = false {
        didSet {
            onActiveStateChanged?(isActive)
        }
    }

    public var onActiveStateChanged: ((Bool) -> Void)?

    private var overlays: [ScreenOverlay] = []
    private let hotkeyManager: HotkeyManager

    public init(hotkeyManager: HotkeyManager = .shared) {
        self.hotkeyManager = hotkeyManager
        super.init()

        rebuildScreenOverlays()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func toggleOverlay() {
        setOverlayActive(!isActive)
    }

    public func setOverlayActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active

        if !active && hotkeyManager.clearOnDeactivate {
            clearAllCanvases()
        }

        syncOverlayState()
    }

    public func syncOverlayState() {
        let hideWhenInactive = hotkeyManager.hideDrawingsWhenInactive
        let mouseLocation = NSEvent.mouseLocation

        for entry in overlays {
            entry.panel.ignoresMouseEvents = !isActive
            entry.webView.setActive(isActive, hideDrawingsWhenInactive: hideWhenInactive)

            if isActive {
                entry.panel.orderFrontRegardless()
                if entry.panel.frame.contains(mouseLocation) {
                    entry.panel.makeKey()
                    entry.panel.makeFirstResponder(entry.webView)
                }
            } else {
                entry.panel.resignKey()
            }
        }
    }

    public func selectTool(_ tool: String) {
        if !isActive {
            setOverlayActive(true)
        }
        for entry in overlays {
            entry.webView.selectTool(tool)
        }
    }

    public func undo() {
        for entry in overlays {
            entry.webView.undo()
        }
    }

    public func redo() {
        for entry in overlays {
            entry.webView.redo()
        }
    }

    public func copyActiveCanvasToClipboard() {
        let mouseLocation = NSEvent.mouseLocation
        if let activeEntry = overlays.first(where: { $0.panel.frame.contains(mouseLocation) }) ?? overlays.first {
            activeEntry.webView.copyCanvasToClipboard()
        }
    }

    public func clearAllCanvases() {
        for entry in overlays {
            entry.webView.clearCanvas()
        }
    }

    // MARK: - Multi-Display Management

    @objc private func handleScreenParametersChanged() {
        let currentScreens = NSScreen.screens
        let currentIDs = Set(currentScreens.compactMap { Self.displayID(for: $0) })

        overlays.removeAll { entry in
            if !currentIDs.contains(entry.screenID) {
                entry.panel.close()
                return true
            }
            return false
        }

        for screen in currentScreens {
            guard let id = Self.displayID(for: screen) else { continue }
            if let existing = overlays.first(where: { $0.screenID == id }) {
                existing.panel.setFrame(screen.frame, display: true)
                existing.webView.frame = CGRect(origin: .zero, size: screen.frame.size)
            } else {
                let entry = createOverlay(for: screen, id: id)
                overlays.append(entry)
            }
        }

        syncOverlayState()
    }

    private func rebuildScreenOverlays() {
        for entry in overlays {
            entry.panel.close()
        }
        overlays.removeAll()

        for screen in NSScreen.screens {
            guard let id = Self.displayID(for: screen) else { continue }
            let entry = createOverlay(for: screen, id: id)
            overlays.append(entry)
        }
    }

    private func createOverlay(for screen: NSScreen, id: CGDirectDisplayID) -> ScreenOverlay {
        let panel = OverlayPanel(screen: screen)
        let webView = OverlayWebView(frame: CGRect(origin: .zero, size: screen.frame.size))
        webView.autoresizingMask = [.width, .height]
        webView.overlayDelegate = self
        panel.contentView = webView
        webView.loadCanvasHTML()
        panel.orderFrontRegardless()
        return ScreenOverlay(screenID: id, panel: panel, webView: webView)
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        return screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    // MARK: - OverlayWebViewDelegate

    public func overlayWebViewRequestedDeactivate(_ webView: OverlayWebView) {
        setOverlayActive(false)
    }
}
