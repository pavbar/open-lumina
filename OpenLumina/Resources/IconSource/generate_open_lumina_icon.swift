import AppKit
import Foundation

struct IconSlot {
    let filename: String
    let pixelSize: CGFloat
}

let slots: [IconSlot] = [
    .init(filename: "icon_16x16.png", pixelSize: 16),
    .init(filename: "icon_16x16@2x.png", pixelSize: 32),
    .init(filename: "icon_32x32.png", pixelSize: 32),
    .init(filename: "icon_32x32@2x.png", pixelSize: 64),
    .init(filename: "icon_128x128.png", pixelSize: 128),
    .init(filename: "icon_128x128@2x.png", pixelSize: 256),
    .init(filename: "icon_256x256.png", pixelSize: 256),
    .init(filename: "icon_256x256@2x.png", pixelSize: 512),
    .init(filename: "icon_512x512.png", pixelSize: 512),
    .init(filename: "icon_512x512@2x.png", pixelSize: 1024),
]

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconSetURL = repoRoot
    .appendingPathComponent("OpenLumina", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("Assets.xcassets", isDirectory: true)
    .appendingPathComponent("AppIcon.appiconset", isDirectory: true)

try fileManager.createDirectory(at: iconSetURL, withIntermediateDirectories: true)

for slot in slots {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(slot.pixelSize),
        pixelsHigh: Int(slot.pixelSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "OpenLuminaIconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate bitmap for \(slot.filename)"])
    }

    bitmap.size = NSSize(width: slot.pixelSize, height: slot.pixelSize)
    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "OpenLuminaIconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing graphics context"])
    }
    NSGraphicsContext.current = graphicsContext

    drawIcon(in: graphicsContext.cgContext, size: CGSize(width: slot.pixelSize, height: slot.pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "OpenLuminaIconGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode \(slot.filename)"])
    }

    try pngData.write(to: iconSetURL.appendingPathComponent(slot.filename), options: .atomic)
}

func drawIcon(in context: CGContext, size: CGSize) {
    let rect = CGRect(origin: .zero, size: size)
    let scale = min(size.width, size.height) / 1024.0
    let inset = 22.0 * scale
    let cornerRadius = 230.0 * scale

    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let backgroundPath = NSBezierPath(
        roundedRect: rect.insetBy(dx: inset, dy: inset),
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )
    context.saveGState()
    backgroundPath.addClip()

    let backgroundGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.20, alpha: 1.0),
        NSColor(calibratedRed: 0.08, green: 0.23, blue: 0.36, alpha: 1.0),
        NSColor(calibratedRed: 0.03, green: 0.10, blue: 0.17, alpha: 1.0)
    ])!
    backgroundGradient.draw(in: backgroundPath, angle: -55)

    let glowGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.52, green: 0.89, blue: 0.99, alpha: 0.55),
        NSColor(calibratedRed: 0.52, green: 0.89, blue: 0.99, alpha: 0.0)
    ])!
    let glowRect = CGRect(x: 190 * scale, y: 530 * scale, width: 640 * scale, height: 410 * scale)
    glowGradient.draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: NSPoint(x: 0, y: 0))

    let plateRect = CGRect(x: 238 * scale, y: 210 * scale, width: 548 * scale, height: 548 * scale)
    let platePath = NSBezierPath(roundedRect: plateRect, xRadius: 120 * scale, yRadius: 120 * scale)
    NSColor(calibratedWhite: 0.96, alpha: 0.96).setFill()
    platePath.fill()

    NSColor(calibratedRed: 0.45, green: 0.84, blue: 0.96, alpha: 0.22).setFill()
    NSBezierPath(
        roundedRect: plateRect.insetBy(dx: 26 * scale, dy: 26 * scale),
        xRadius: 94 * scale,
        yRadius: 94 * scale
    ).fill()

    let xrayRect = CGRect(x: 320 * scale, y: 292 * scale, width: 384 * scale, height: 384 * scale)
    let xrayPath = NSBezierPath(ovalIn: xrayRect)
    let xrayGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.83, green: 0.97, blue: 1.0, alpha: 1.0),
        NSColor(calibratedRed: 0.53, green: 0.82, blue: 0.92, alpha: 1.0),
        NSColor(calibratedRed: 0.13, green: 0.28, blue: 0.36, alpha: 1.0)
    ])!
    xrayGradient.draw(in: xrayPath, relativeCenterPosition: NSPoint(x: 0, y: 0.15))

    let beamColor = NSColor(calibratedWhite: 1.0, alpha: 0.56)
    context.setLineCap(.round)
    context.setStrokeColor(beamColor.cgColor)
    context.setLineWidth(64 * scale)
    context.move(to: CGPoint(x: 390 * scale, y: 378 * scale))
    context.addLine(to: CGPoint(x: 634 * scale, y: 622 * scale))
    context.strokePath()

    context.setLineWidth(36 * scale)
    context.move(to: CGPoint(x: 634 * scale, y: 378 * scale))
    context.addLine(to: CGPoint(x: 390 * scale, y: 622 * scale))
    context.strokePath()

    let apertureRect = CGRect(x: 670 * scale, y: 632 * scale, width: 88 * scale, height: 88 * scale)
    NSColor(calibratedRed: 0.91, green: 0.98, blue: 1.0, alpha: 0.96).setFill()
    NSBezierPath(ovalIn: apertureRect).fill()

    let plateBorder = NSBezierPath(roundedRect: plateRect.insetBy(dx: 1 * scale, dy: 1 * scale), xRadius: 120 * scale, yRadius: 120 * scale)
    NSColor(calibratedWhite: 0.0, alpha: 0.12).setStroke()
    plateBorder.lineWidth = 8 * scale
    plateBorder.stroke()

    context.restoreGState()
}
