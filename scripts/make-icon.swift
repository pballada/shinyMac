// Renders Support/AppIcon.icns: a glossy gradient squircle with white sparkles.
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

    let configuration = NSImage.SymbolConfiguration(pointSize: 430 * scale, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?.withSymbolConfiguration(configuration) {
        let size = symbol.size
        let origin = NSPoint(x: body.midX - size.width / 2, y: body.midY - size.height / 2 - 6 * scale)
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor.white.withAlphaComponent(0.55)
        glow.shadowBlurRadius = 40 * scale
        glow.set()
        symbol.draw(in: NSRect(origin: origin, size: size))
        NSGraphicsContext.restoreGraphicsState()
    }
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
