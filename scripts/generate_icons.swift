import AppKit

func renderAppIcon(size: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let s = CGFloat(size)
    let pad = s * 0.085
    let cardRect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let cornerRadius = s * 0.225

    // Soft outer drop shadow
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -s * 0.025),
        blur: s * 0.06,
        color: NSColor(calibratedWhite: 0, alpha: 0.35).cgColor
    )
    let bgPath = NSBezierPath(roundedRect: cardRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(calibratedRed: 0.41, green: 0.39, blue: 0.86, alpha: 1.0).setFill()
    bgPath.fill()
    cg.restoreGState()

    // Clip to squircle
    bgPath.addClip()

    // Excalidraw indigo/violet gradient background (#6965db -> #4338ca)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        NSColor(calibratedRed: 0.48, green: 0.45, blue: 0.96, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.33, green: 0.29, blue: 0.78, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.20, green: 0.18, blue: 0.52, alpha: 1.0).cgColor
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0.0, 0.55, 1.0]) {
        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
            options: []
        )
    }

    // Subtle canvas grid lines inside the squircle
    NSColor(calibratedWhite: 1.0, alpha: 0.08).setStroke()
    let gridStep = s * 0.14
    for offset in stride(from: cardRect.minX + gridStep, to: cardRect.maxX, by: gridStep) {
        let vLine = NSBezierPath()
        vLine.lineWidth = max(1.0, s * 0.004)
        vLine.move(to: CGPoint(x: offset, y: cardRect.minY))
        vLine.line(to: CGPoint(x: offset, y: cardRect.maxY))
        vLine.stroke()

        let hLine = NSBezierPath()
        hLine.lineWidth = max(1.0, s * 0.004)
        hLine.move(to: CGPoint(x: cardRect.minX, y: offset))
        hLine.line(to: CGPoint(x: cardRect.maxX, y: offset))
        hLine.stroke()
    }

    // Inner glass border highlight
    let borderPath = NSBezierPath(roundedRect: cardRect.insetBy(dx: s * 0.008, dy: s * 0.008), xRadius: cornerRadius, yRadius: cornerRadius)
    borderPath.lineWidth = max(1.5, s * 0.012)
    NSColor(calibratedWhite: 1.0, alpha: 0.24).setStroke()
    borderPath.stroke()

    // Sketchy Excalidraw S-curve laser/ink trail across the canvas
    let curve = NSBezierPath()
    curve.move(to: CGPoint(x: s * 0.22, y: s * 0.26))
    curve.curve(
        to: CGPoint(x: s * 0.54, y: s * 0.44),
        controlPoint1: CGPoint(x: s * 0.24, y: s * 0.52),
        controlPoint2: CGPoint(x: s * 0.40, y: s * 0.20)
    )
    curve.curve(
        to: CGPoint(x: s * 0.77, y: s * 0.72),
        controlPoint1: CGPoint(x: s * 0.65, y: s * 0.62),
        controlPoint2: CGPoint(x: s * 0.64, y: s * 0.74)
    )
    curve.lineCapStyle = .round
    curve.lineJoinStyle = .round

    // Outer neon crimson/amber glow on the curve
    cg.saveGState()
    cg.setShadow(
        offset: .zero,
        blur: s * 0.045,
        color: NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.35, alpha: 0.85).cgColor
    )
    NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.42, alpha: 0.95).setStroke()
    curve.lineWidth = s * 0.055
    curve.stroke()
    cg.restoreGState()

    // Bright warm-white core of the sketch stroke
    NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.88, alpha: 1.0).setStroke()
    curve.lineWidth = s * 0.026
    curve.stroke()

    // Sketchy diamond annotation node in top-left
    cg.saveGState()
    let diamondCenter = CGPoint(x: s * 0.31, y: s * 0.69)
    let dR = s * 0.085
    let diamond = NSBezierPath()
    diamond.move(to: CGPoint(x: diamondCenter.x, y: diamondCenter.y + dR))
    diamond.line(to: CGPoint(x: diamondCenter.x + dR, y: diamondCenter.y))
    diamond.line(to: CGPoint(x: diamondCenter.x, y: diamondCenter.y - dR))
    diamond.line(to: CGPoint(x: diamondCenter.x - dR, y: diamondCenter.y))
    diamond.close()
    diamond.lineJoinStyle = .round
    NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.40, alpha: 0.22).setFill()
    diamond.fill()
    NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.40, alpha: 0.95).setStroke()
    diamond.lineWidth = s * 0.022
    diamond.stroke()
    cg.restoreGState()

    // Draw bold macOS-style Cursor / Pen Nib hybrid in the center-right
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -s * 0.02),
        blur: s * 0.045,
        color: NSColor(calibratedWhite: 0, alpha: 0.45).cgColor
    )

    // Pen body tilted at -45 deg pointing to (0.54, 0.44)
    cg.translateBy(x: s * 0.58, y: s * 0.46)
    cg.rotate(by: -CGFloat.pi / 4.0)

    let barrelW = s * 0.14
    let barrelH = s * 0.34
    let barrelRect = CGRect(x: -barrelW / 2, y: s * 0.05, width: barrelW, height: barrelH)
    let barrelPath = NSBezierPath(roundedRect: barrelRect, xRadius: barrelW * 0.28, yRadius: barrelW * 0.28)
    NSColor.white.setFill()
    barrelPath.fill()

    // Coral/Red cap band at top of pen
    let capRect = CGRect(x: -barrelW / 2, y: s * 0.29, width: barrelW, height: s * 0.10)
    let capPath = NSBezierPath(roundedRect: capRect, xRadius: barrelW * 0.28, yRadius: barrelW * 0.28)
    NSColor(calibratedRed: 0.98, green: 0.32, blue: 0.32, alpha: 1.0).setFill()
    capPath.fill()

    // Nib cone pointing down to (0, -s * 0.07)
    let nibPath = NSBezierPath()
    nibPath.move(to: CGPoint(x: -barrelW * 0.44, y: s * 0.04))
    nibPath.line(to: CGPoint(x: barrelW * 0.44, y: s * 0.04))
    nibPath.line(to: CGPoint(x: 0, y: -s * 0.085))
    nibPath.close()
    nibPath.lineJoinStyle = .round
    NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.38, alpha: 1.0).setFill()
    nibPath.fill()

    // Dark ink tip
    let tipPath = NSBezierPath()
    tipPath.move(to: CGPoint(x: -barrelW * 0.18, y: -s * 0.035))
    tipPath.line(to: CGPoint(x: barrelW * 0.18, y: -s * 0.035))
    tipPath.line(to: CGPoint(x: 0, y: -s * 0.085))
    tipPath.close()
    NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.18, alpha: 1.0).setFill()
    tipPath.fill()

    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let iconsetDir = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in specs {
    if let data = renderAppIcon(size: px) {
        try data.write(to: iconsetDir.appendingPathComponent(name))
    }
}
print("Generated iconset at \(iconsetDir.path)")
