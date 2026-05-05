#!/usr/bin/env swift
// Generates AppIcon.icns in Resources/ using AppKit drawing.
import AppKit

func makeIconImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    defer { img.unlockFocus() }

    let ctx = NSGraphicsContext.current!.cgContext
    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let r = size * 0.18 // corner radius

    // Background: deep dark navy
    ctx.setFillColor(CGColor(red: 0.09, green: 0.09, blue: 0.13, alpha: 1))
    let bg = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(bg)
    ctx.fillPath()

    // Subtle inner gradient overlay (lighter at top)
    let colors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.07),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.00),
    ]
    if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: colors as CFArray,
                              locations: [0, 1]) {
        ctx.saveGState()
        ctx.addPath(bg)
        ctx.clip()
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
        ctx.restoreGState()
    }

    // Green play triangle, centred slightly left
    let triSize  = size * 0.38
    let cx       = size * 0.50
    let cy       = size * 0.50

    let tri = CGMutablePath()
    tri.move(to:    CGPoint(x: cx - triSize * 0.30, y: cy + triSize * 0.50))
    tri.addLine(to: CGPoint(x: cx + triSize * 0.60, y: cy))
    tri.addLine(to: CGPoint(x: cx - triSize * 0.30, y: cy - triSize * 0.50))
    tri.closeSubpath()
    ctx.addPath(tri)
    ctx.setFillColor(CGColor(red: 0.18, green: 0.84, blue: 0.48, alpha: 1))
    ctx.fillPath()

    return img
}

func pngData(from image: NSImage, size: Int) -> Data {
    let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return bmp.representation(using: .png, properties: [:])!
}

let repoRoot = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = repoRoot.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let specs: [(name: String, points: Int, scale: Int)] = [
    ("icon_16x16",      16,  1),
    ("icon_16x16@2x",   16,  2),
    ("icon_32x32",      32,  1),
    ("icon_32x32@2x",   32,  2),
    ("icon_128x128",   128,  1),
    ("icon_128x128@2x",128,  2),
    ("icon_256x256",   256,  1),
    ("icon_256x256@2x",256,  2),
    ("icon_512x512",   512,  1),
    ("icon_512x512@2x",512,  2),
]

for spec in specs {
    let px = spec.points * spec.scale
    let img = makeIconImage(size: CGFloat(px))
    let data = pngData(from: img, size: px)
    let file = iconsetURL.appendingPathComponent("\(spec.name).png")
    try! data.write(to: file)
    print("wrote \(file.lastPathComponent)")
}

print("done — run: iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns")
