import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let iconAssetsURL = root
    .appendingPathComponent("Phobo/PhoboIcon.icon/Assets")
private let appIconURL = root
    .appendingPathComponent("Phobo/Assets.xcassets/AppIcon.appiconset")

private struct RGBA {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
}

private func color(_ rgba: RGBA) -> CGColor {
    CGColor(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
}

private func context(size: CGSize, opaque: Bool = false) -> CGContext {
    let space = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create CGContext")
    }
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    if opaque {
        ctx.setFillColor(color(RGBA(r: 0.86, g: 0.95, b: 0.91, a: 1)))
        ctx.fill(CGRect(origin: .zero, size: size))
    }
    return ctx
}

private func savePNG(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        )
    else {
        fatalError("Could not create image destination at \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(url.path)")
    }
}

private func fillLinearGradient(
    _ ctx: CGContext,
    rect: CGRect,
    colors: [RGBA],
    start: CGPoint,
    end: CGPoint
) {
    let cgColors = colors.map { color($0) } as CFArray
    let locations = colors.indices.map { CGFloat($0) / CGFloat(colors.count - 1) }
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
        colors: cgColors,
        locations: locations
    )!
    ctx.saveGState()
    ctx.addRect(rect)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    ctx.restoreGState()
}

private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
}

private func drawBackground(into ctx: CGContext, size: CGSize, dark: Bool, tinted: Bool) {
    let rect = CGRect(origin: .zero, size: size)
    if dark {
        fillLinearGradient(
            ctx,
            rect: rect,
            colors: [
                RGBA(r: 0.04, g: 0.09, b: 0.13, a: 1),
                RGBA(r: 0.02, g: 0.19, b: 0.29, a: 1),
                RGBA(r: 0.05, g: 0.38, b: 0.48, a: 1)
            ],
            start: CGPoint(x: 260, y: 1024),
            end: CGPoint(x: 760, y: 0)
        )
    } else if tinted {
        fillLinearGradient(
            ctx,
            rect: rect,
            colors: [
                RGBA(r: 0.95, g: 0.98, b: 1.00, a: 1),
                RGBA(r: 0.73, g: 0.89, b: 1.00, a: 1),
                RGBA(r: 0.25, g: 0.57, b: 0.95, a: 1)
            ],
            start: CGPoint(x: 350, y: 1024),
            end: CGPoint(x: 820, y: 0)
        )
    } else {
        fillLinearGradient(
            ctx,
            rect: rect,
            colors: [
                RGBA(r: 0.89, g: 0.97, b: 0.93, a: 1),
                RGBA(r: 0.47, g: 0.87, b: 0.86, a: 1),
                RGBA(r: 0.00, g: 0.52, b: 1.00, a: 1)
            ],
            start: CGPoint(x: 420, y: 1024),
            end: CGPoint(x: 740, y: 0)
        )
    }

    ctx.setFillColor(color(RGBA(r: 1, g: 1, b: 1, a: dark ? 0.10 : 0.20)))
    ctx.fillEllipse(in: CGRect(x: 96, y: 650, width: 420, height: 300))
    ctx.setFillColor(color(RGBA(r: 0.0, g: 0.22, b: 0.34, a: dark ? 0.24 : 0.12)))
    ctx.fillEllipse(in: CGRect(x: 590, y: 88, width: 350, height: 300))
}

private func drawFrameLayer(size: CGSize) -> CGImage {
    let ctx = context(size: size)

    ctx.saveGState()
    ctx.translateBy(x: size.width / 2, y: size.height / 2)
    ctx.rotate(by: -.pi / 28)
    ctx.translateBy(x: -size.width / 2, y: -size.height / 2)

    let card = CGRect(x: 98, y: 104, width: 504, height: 510)
    ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 52, color: color(RGBA(r: 0, g: 0.18, b: 0.28, a: 0.22)))
    ctx.setFillColor(color(RGBA(r: 1, g: 1, b: 1, a: 0.44)))
    ctx.addPath(roundedRect(card, radius: 76))
    ctx.fillPath()

    ctx.setShadow(offset: .zero, blur: 0)
    ctx.setStrokeColor(color(RGBA(r: 1, g: 1, b: 1, a: 0.78)))
    ctx.setLineWidth(18)
    ctx.addPath(roundedRect(card.insetBy(dx: 14, dy: 14), radius: 64))
    ctx.strokePath()

    let photo = card.insetBy(dx: 76, dy: 104)
    ctx.addPath(roundedRect(photo, radius: 44))
    ctx.clip()
    fillLinearGradient(
        ctx,
        rect: photo,
        colors: [
            RGBA(r: 0.10, g: 0.35, b: 0.93, a: 0.58),
            RGBA(r: 0.57, g: 0.95, b: 0.79, a: 0.55)
        ],
        start: CGPoint(x: photo.minX, y: photo.maxY),
        end: CGPoint(x: photo.maxX, y: photo.minY)
    )
    ctx.setFillColor(color(RGBA(r: 1, g: 1, b: 1, a: 0.26)))
    ctx.fillEllipse(in: CGRect(x: photo.minX + 44, y: photo.maxY - 108, width: 74, height: 74))
    ctx.setFillColor(color(RGBA(r: 0.04, g: 0.26, b: 0.40, a: 0.25)))
    let mountain = CGMutablePath()
    mountain.move(to: CGPoint(x: photo.minX, y: photo.minY + 54))
    mountain.addLine(to: CGPoint(x: photo.minX + 140, y: photo.minY + 180))
    mountain.addLine(to: CGPoint(x: photo.minX + 224, y: photo.minY + 102))
    mountain.addLine(to: CGPoint(x: photo.maxX, y: photo.minY + 222))
    mountain.addLine(to: CGPoint(x: photo.maxX, y: photo.minY))
    mountain.addLine(to: CGPoint(x: photo.minX, y: photo.minY))
    mountain.closeSubpath()
    ctx.addPath(mountain)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.setFillColor(color(RGBA(r: 1, g: 1, b: 1, a: 0.30)))
    ctx.fill(CGRect(x: 152, y: 544, width: 250, height: 18))

    guard let image = ctx.makeImage() else { fatalError("Could not render frame layer") }
    return image
}

private func drawGlyphLayer(size: CGSize) -> CGImage {
    let ctx = context(size: size)

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: color(RGBA(r: 0, g: 0.15, b: 0.27, a: 0.28)))
    ctx.setStrokeColor(color(RGBA(r: 0.98, g: 1.00, b: 1.00, a: 0.92)))
    ctx.setLineWidth(78)

    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: 174, y: 112))
    stem.addLine(to: CGPoint(x: 174, y: 456))
    ctx.addPath(stem)
    ctx.strokePath()

    let bowl = CGMutablePath()
    bowl.move(to: CGPoint(x: 174, y: 456))
    bowl.addCurve(
        to: CGPoint(x: 356, y: 300),
        control1: CGPoint(x: 370, y: 474),
        control2: CGPoint(x: 420, y: 314)
    )
    bowl.addCurve(
        to: CGPoint(x: 174, y: 286),
        control1: CGPoint(x: 280, y: 286),
        control2: CGPoint(x: 224, y: 286)
    )
    ctx.addPath(bowl)
    ctx.strokePath()

    ctx.setShadow(offset: .zero, blur: 0)
    ctx.setLineWidth(20)
    ctx.setStrokeColor(color(RGBA(r: 0.35, g: 0.92, b: 0.95, a: 0.82)))
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 310, y: 150))
    check.addLine(to: CGPoint(x: 374, y: 92))
    check.addLine(to: CGPoint(x: 462, y: 214))
    ctx.addPath(check)
    ctx.strokePath()

    ctx.setFillColor(color(RGBA(r: 1, g: 1, b: 1, a: 0.55)))
    ctx.fillEllipse(in: CGRect(x: 354, y: 356, width: 42, height: 42))

    guard let image = ctx.makeImage() else { fatalError("Could not render glyph layer") }
    return image
}

private func drawComposedIcon(dark: Bool = false, tinted: Bool = false) -> CGImage {
    let canvas = CGSize(width: 1024, height: 1024)
    let ctx = context(size: canvas, opaque: true)
    drawBackground(into: ctx, size: canvas, dark: dark, tinted: tinted)

    let frame = drawFrameLayer(size: CGSize(width: 700, height: 700))
    let glyph = drawGlyphLayer(size: CGSize(width: 520, height: 560))

    ctx.draw(frame, in: CGRect(x: 162, y: 140, width: 700, height: 700))
    ctx.draw(glyph, in: CGRect(x: 284, y: 224, width: 520, height: 560))

    guard let image = ctx.makeImage() else { fatalError("Could not render composed icon") }
    return image
}

private func writeContentsJSON() {
    let contents = """
    {
      "images" : [
        {
          "filename" : "PhoboIcon-Light.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "dark"
            }
          ],
          "filename" : "PhoboIcon-Dark.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "tinted"
            }
          ],
          "filename" : "PhoboIcon-Tinted.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """ + "\n"
    try! contents.write(to: appIconURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

savePNG(drawFrameLayer(size: CGSize(width: 700, height: 700)), to: iconAssetsURL.appendingPathComponent("MidRec.png"))
savePNG(drawGlyphLayer(size: CGSize(width: 520, height: 560)), to: iconAssetsURL.appendingPathComponent("P.png"))
savePNG(drawComposedIcon(), to: appIconURL.appendingPathComponent("PhoboIcon-Light.png"))
savePNG(drawComposedIcon(dark: true), to: appIconURL.appendingPathComponent("PhoboIcon-Dark.png"))
savePNG(drawComposedIcon(tinted: true), to: appIconURL.appendingPathComponent("PhoboIcon-Tinted.png"))
writeContentsJSON()

print("Generated Phobo icon assets in \(root.path)")
