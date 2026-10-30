// Renders the app icon into the asset catalog: AppIcon (Release) and AppIconDev (Debug, with
// a DEV band). The drawing lives here so the icon can be changed and re-rendered instead of
// edited as pixels.
//
//   swift scripts/render-app-icon.swift
//
// Stacked boards: three cards fanned on deep indigo, the front one a task with a kind pill and
// two text lines. Drawn on the macOS grid: 1024 px canvas, 824 px rounded body, 100 px margin.
// Every size macOS asks for is rendered from the vector drawing.
import AppKit
import CoreGraphics

let canvas: CGFloat = 1024
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let radius: CGFloat = 186
let catalog = URL(fileURLWithPath: "App/Sources/Assets.xcassets")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func fillGradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(
        gradient,
        start: from,
        end: to,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

/// A rect given in the design's y-down space (as in the SVG), flipped into CoreGraphics' y-up.
func designRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
    CGRect(x: x, y: canvas - y - height, width: width, height: height)
}

func fillRounded(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, _ fill: CGColor) {
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(fill)
    ctx.fillPath()
}

/// A board card with a soft shadow below it, so the stack reads as layered paper.
func drawCard(_ ctx: CGContext, _ rect: CGRect, _ fill: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x0B0A26, 0.45))
    fillRounded(ctx, rect, radius: 44, fill)
    ctx.restoreGState()
}

func drawIcon(dev: Bool) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: Int(canvas),
        height: Int(canvas),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let squircle = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x000000, 0.28))
    ctx.addPath(squircle)
    ctx.setFillColor(color(0x000000))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    fillGradient(ctx, [color(0x2A2670), color(0x1E1B4B)], from: CGPoint(x: 0, y: 924), to: CGPoint(x: 0, y: 100))

    drawCard(ctx, designRect(x: 380, y: 230, width: 400, height: 290), color(0x6366F1))
    drawCard(ctx, designRect(x: 312, y: 360, width: 400, height: 290), color(0xA5B4FC))
    drawCard(ctx, designRect(x: 244, y: 490, width: 400, height: 290), color(0xFFFFFF))

    // The front card is a task: kind pill, then a title line and a fainter detail line.
    fillRounded(ctx, designRect(x: 292, y: 540, width: 120, height: 40), radius: 20, color(0x14B8A6))
    fillRounded(ctx, designRect(x: 292, y: 616, width: 290, height: 30), radius: 15, color(0x1E1B4B, 0.85))
    fillRounded(ctx, designRect(x: 292, y: 674, width: 210, height: 30), radius: 15, color(0x1E1B4B, 0.3))

    if dev {
        // Amber band across the bottom: readable as "not the real app" even at 16 px.
        let band = designRect(x: 100, y: 762, width: 824, height: 162)
        ctx.setFillColor(color(0xF59E0B))
        ctx.fill(band)
        ctx.setFillColor(color(0xFFFFFF, 0.25))
        ctx.fill(CGRect(x: band.minX, y: band.maxY - 4, width: band.width, height: 4))
        let font = NSFont.systemFont(ofSize: 104, weight: .bold)
        let text = NSAttributedString(
            string: "DEV",
            attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(0x1F1300))!, .kern: 14]
        )
        let line = CTLineCreateWithAttributedString(text)
        let bounds = CTLineGetImageBounds(line, ctx)
        ctx.textPosition = CGPoint(
            x: band.midX - bounds.width / 2 - bounds.minX,
            y: band.midY - bounds.height / 2 - bounds.minY
        )
        CTLineDraw(line, ctx)
    }

    fillGradient(
        ctx,
        [color(0xFFFFFF, 0.08), color(0xFFFFFF, 0)],
        from: CGPoint(x: 0, y: 924),
        to: CGPoint(x: 0, y: 600)
    )
    ctx.restoreGState()

    ctx.addPath(squircle)
    ctx.setStrokeColor(color(0x000000, 0.12))
    ctx.setLineWidth(2)
    ctx.strokePath()
    return ctx.makeImage()!
}

func resized(_ image: CGImage, to pixels: Int) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
}

/// The ten images macOS asks for: 16 to 512 pt at 1x and 2x.
func writeIconSet(named name: String, dev: Bool) throws {
    let folder = catalog.appendingPathComponent("\(name).appiconset")
    try? FileManager.default.removeItem(at: folder)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let master = drawIcon(dev: dev)
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let file = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
            writePNG(resized(master, to: points * scale), to: folder.appendingPathComponent(file))
            images.append([
                "filename": file, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)",
            ])
        }
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: folder.appendingPathComponent("Contents.json"))
}

guard FileManager.default.fileExists(atPath: catalog.path) else {
    fatalError("run from the repository root: \(catalog.path) not found")
}
try writeIconSet(named: "AppIcon", dev: false)
try writeIconSet(named: "AppIconDev", dev: true)
print("rendered AppIcon and AppIconDev")
