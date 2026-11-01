// Renders Support/AppIcon.icns: a glossy gradient squircle with a shiny white iMac and sparkles.
//   swift scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func drawIcon(in rect: NSRect) {
    let scale = rect.width / 1024
    // Apple's icon grid: an 824 pt body centred on the 1024 canvas.
    let body = rect.insetBy(dx: 100 * scale, dy: 100 * scale)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * scale, yRadius: 185 * scale)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -14 * scale)
    shadow.set()
    NSGradient(colors: [color(0xFF7AD9), color(0xB04BFF), color(0x4B2BD6)])!.draw(in: shape, angle: -65)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    // Cool glow in the lower right and a soft specular sheen at the top.
    NSGradient(colors: [color(0x7FDBFF).withAlphaComponent(0.5), .clear])!
        .draw(fromCenter: NSPoint(x: body.maxX - 120 * scale, y: body.minY + 110 * scale), radius: 0,
              toCenter: NSPoint(x: body.maxX - 120 * scale, y: body.minY + 110 * scale), radius: 520 * scale, options: [])
    let sheen = NSBezierPath(ovalIn: NSRect(x: body.minX - 60 * scale, y: body.midY + 90 * scale,
                                            width: body.width + 120 * scale, height: body.height * 0.75))
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.32), NSColor.white.withAlphaComponent(0)])!.draw(in: sheen, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    drawMac(in: body, scale: scale)
}

/// A glossy white iMac with a glowing screen and sparkles: the "shiny Mac".
func drawMac(in body: NSRect, scale: CGFloat) {
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: body.minX + x * scale, y: body.minY + y * scale, width: w * scale, height: h * scale)
    }
    let white = NSGradient(colors: [color(0xFFFFFF), color(0xE9E4F5)])!

    // Stand: a tapered neck and a flat foot.
    NSGraphicsContext.saveGraphicsState()
    let lift = NSShadow()
    lift.shadowColor = NSColor.black.withAlphaComponent(0.3)
    lift.shadowBlurRadius = 24 * scale
    lift.shadowOffset = NSSize(width: 0, height: -10 * scale)
    lift.set()
    let neck = NSBezierPath()
    neck.move(to: NSPoint(x: body.minX + 342 * scale, y: body.minY + 176 * scale))
    neck.line(to: NSPoint(x: body.minX + 482 * scale, y: body.minY + 176 * scale))
    neck.line(to: NSPoint(x: body.minX + 506 * scale, y: body.minY + 96 * scale))
    neck.line(to: NSPoint(x: body.minX + 318 * scale, y: body.minY + 96 * scale))
    neck.close()
    NSGradient(colors: [color(0xD9D2EA), color(0xB9AED6)])!.draw(in: neck, angle: -90)
    let foot = NSBezierPath(roundedRect: rect(262, 78, 300, 30), xRadius: 15 * scale, yRadius: 15 * scale)
    white.draw(in: foot, angle: -90)

    // Body with a chin.
    let frame = rect(102, 166, 620, 470)
    let shell = NSBezierPath(roundedRect: frame, xRadius: 46 * scale, yRadius: 46 * scale)
    white.draw(in: shell, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Screen.
    let screenRect = rect(128, 250, 568, 360)
    let screen = NSBezierPath(roundedRect: screenRect, xRadius: 22 * scale, yRadius: 22 * scale)
    NSGradient(colors: [color(0x2A1366), color(0x6A2BD9), color(0xFF6FC8)])!.draw(in: screen, angle: 60)
    NSGraphicsContext.saveGraphicsState()
    screen.addClip()
    // Diagonal reflection across the glass.
    let streak = NSBezierPath()
    streak.move(to: NSPoint(x: screenRect.minX + 300 * scale, y: screenRect.maxY))
    streak.line(to: NSPoint(x: screenRect.minX + 470 * scale, y: screenRect.maxY))
    streak.line(to: NSPoint(x: screenRect.minX + 230 * scale, y: screenRect.minY))
    streak.line(to: NSPoint(x: screenRect.minX + 60 * scale, y: screenRect.minY))
    streak.close()
    NSColor.white.withAlphaComponent(0.13).setFill()
    streak.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Sparkles: a big one on the screen, a small one popping off the corner.
    sparkle(center: NSPoint(x: screenRect.midX, y: screenRect.midY), radius: 128 * scale, glow: 40 * scale)
    sparkle(center: NSPoint(x: screenRect.minX + 120 * scale, y: screenRect.maxY - 92 * scale), radius: 44 * scale, glow: 16 * scale)
    sparkle(center: NSPoint(x: frame.maxX - 6 * scale, y: frame.maxY + 4 * scale), radius: 70 * scale, glow: 26 * scale)

    // Chin logo dot.
    NSColor(white: 0.78, alpha: 1).setFill()
    NSBezierPath(ovalIn: rect(400, 194, 24, 24)).fill()
}

/// Four-pointed star with concave sides and a soft white glow.
func sparkle(center: NSPoint, radius: CGFloat, glow: CGFloat) {
    let path = NSBezierPath()
    let pinch = radius * 0.16
    let points = (0..<4).map { index -> NSPoint in
        let angle = CGFloat(index) * .pi / 2 + .pi / 2
        return NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
    path.move(to: points[0])
    for index in 1...4 {
        let point = points[index % 4]
        let mid = CGFloat(index) * .pi / 2 + .pi / 4 - .pi / 2 + .pi / 2
        let control = NSPoint(x: center.x + cos(mid) * pinch, y: center.y + sin(mid) * pinch)
        path.curve(to: point, controlPoint1: control, controlPoint2: control)
    }
    path.close()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.white.withAlphaComponent(0.8)
    shadow.shadowBlurRadius = glow
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: iconset.appending(path: "icon_\(points)x\(points).png"))
    try png(pixels: points * 2).write(to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
}
try png(pixels: 1024).write(to: root.appending(path: "Support/AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(filePath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appending(path: "Support/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Support/AppIcon.icns" : "iconutil failed")
