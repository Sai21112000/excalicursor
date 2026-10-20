import AppKit
import WebKit

public protocol OverlayWebViewDelegate: AnyObject {
    func overlayWebViewRequestedDeactivate(_ webView: OverlayWebView)
}

public final class OverlayWebView: WKWebView, WKScriptMessageHandler {
    public weak var overlayDelegate: OverlayWebViewDelegate?

    private static let messageHandlerName = "excaliCursorBridge"

    public init(frame: CGRect) {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        config.userContentController = userContentController

        super.init(frame: frame, configuration: config)

        userContentController.add(WeakScriptMessageHandler(target: self), name: Self.messageHandlerName)

        // Make WKWebView background completely transparent on macOS
        self.setValue(false, forKey: "drawsBackground")
        self.allowsMagnification = false
        if #available(macOS 13.3, *) {
            self.isInspectable = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    public func loadCanvasHTML() {
        if let htmlURL = Self.resolveResourceURL(named: "canvas", withExtension: "html") {
            let dirURL = htmlURL.deletingLastPathComponent()
            loadFileURL(htmlURL, allowingReadAccessTo: dirURL)
        }
    }

    private static func resolveResourceURL(named name: String, withExtension ext: String) -> URL? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        #endif
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        let fallbackPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/ExcaliCursor/Resources/\(name).\(ext)")
        if FileManager.default.fileExists(atPath: fallbackPath.path) {
            return fallbackPath
        }
        return nil
    }

    // MARK: - Swift to JS Commands

    public func setActive(_ active: Bool, hideDrawingsWhenInactive: Bool) {
        let js = "window.excaliCursor && window.excaliCursor.setActive(\(active), \(hideDrawingsWhenInactive));"
        evaluateJavaScript(js, completionHandler: nil)
    }

    public func selectTool(_ tool: String) {
        let js = "window.excaliCursor && window.excaliCursor.selectTool('\(tool)');"
        evaluateJavaScript(js, completionHandler: nil)
    }

    public func undo() {
        let js = "window.excaliCursor && window.excaliCursor.undo();"
        evaluateJavaScript(js, completionHandler: nil)
    }

    public func redo() {
        let js = "window.excaliCursor && window.excaliCursor.redo();"
        evaluateJavaScript(js, completionHandler: nil)
    }

    public func copyCanvasToClipboard() {
        let js = "window.excaliCursor && window.excaliCursor.copyCanvasToClipboard();"
        evaluateJavaScript(js, completionHandler: nil)
    }

    public func clearCanvas() {
        let js = "window.excaliCursor && window.excaliCursor.clearCanvas();"
        evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            return
        }

        switch action {
        case "deactivate":
            overlayDelegate?.overlayWebViewRequestedDeactivate(self)
        case "copyImage":
            if let dataURL = body["dataURL"] as? String {
                Self.writeDataURLToPasteboard(dataURL)
            }
        default:
            break
        }
    }

    private static func writeDataURLToPasteboard(_ dataURL: String) {
        guard let commaIndex = dataURL.firstIndex(of: ",") else { return }
        let base64Part = String(dataURL[dataURL.index(after: commaIndex)...])
        guard let pngData = Data(base64Encoded: base64Part),
              let image = NSImage(data: pngData) else {
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
