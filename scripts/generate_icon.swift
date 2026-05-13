#!/usr/bin/env swift
import AppKit
import CoreGraphics

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "MCopy/Assets.xcassets/AppIcon.appiconset"

// Render an MCopy icon at the given pixel size.
// Design: macOS-style squircle with blue→purple gradient,
// a stack of three rounded "card" shapes, and a bold "M" overlay.
func renderIcon(size: CGFloat) -> CGImage {
    let scale: CGFloat = 1.0
    let pixelSize = Int(size * scale)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { fatalError("ctx") }

    ctx.scaleBy(x: scale, y: scale)

    // ----- Squircle background with gradient -----
    let inset = size * 0.0  // full bleed; macOS asset catalog adds shadows
    let rect = CGRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
    let cornerRadius = size * 0.2237  // matches macOS Big Sur squircle ratio
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Gradient: deep indigo → vivid violet (top→bottom)
    let topColor = CGColor(red: 0.36, green: 0.42, blue: 0.95, alpha: 1.0)    // #5C6BF2
    let midColor = CGColor(red: 0.49, green: 0.36, blue: 0.93, alpha: 1.0)    // #7D5CED
    let bottomColor = CGColor(red: 0.62, green: 0.30, blue: 0.88, alpha: 1.0) // #9E4DE0
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [topColor, midColor, bottomColor] as CFArray,
        locations: [0.0, 0.5, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // Subtle top highlight for depth
    let hiColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.18)
    let hiClear = CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    let hiGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [hiColor, hiClear] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        hiGradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: size * 0.5),
        options: []
    )
    ctx.restoreGState()

    // ----- Stacked clipboard cards -----
    // Three offset rounded rectangles representing clipboard history.
    let cardW = size * 0.50
    let cardH = size * 0.58
    let cardCornerR = size * 0.07
    let centerX = size / 2
    let centerY = size / 2

    func drawCard(offsetX: CGFloat, offsetY: CGFloat, alpha: CGFloat, scale: CGFloat = 1.0) {
        let w = cardW * scale
        let h = cardH * scale
        let r = CGRect(
            x: centerX - w/2 + offsetX,
            y: centerY - h/2 + offsetY,
            width: w,
            height: h
        )
        let p = CGPath(roundedRect: r, cornerWidth: cardCornerR, cornerHeight: cardCornerR, transform: nil)
        ctx.saveGState()
        ctx.addPath(p)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: alpha))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Back card (smaller, faded)
    drawCard(offsetX: size * 0.08, offsetY: -size * 0.06, alpha: 0.28, scale: 0.92)
    // Middle card
    drawCard(offsetX: size * 0.04, offsetY: -size * 0.02, alpha: 0.55, scale: 0.96)
    // Front card (main, opaque)
    drawCard(offsetX: 0, offsetY: size * 0.02, alpha: 1.0, scale: 1.0)

    // ----- Bold "M" on the front card -----
    let frontCardRect = CGRect(
        x: centerX - cardW/2,
        y: centerY - cardH/2 + size * 0.02,
        width: cardW,
        height: cardH
    )

    let fontSize = size * 0.42
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let textColor = NSColor(red: 0.42, green: 0.32, blue: 0.92, alpha: 1.0)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraph,
        .kern: -fontSize * 0.02
    ]
    let str = NSAttributedString(string: "M", attributes: attrs)
    let strSize = str.size()
    let textRect = CGRect(
        x: frontCardRect.midX - strSize.width / 2,
        y: frontCardRect.midY - strSize.height / 2,
        width: strSize.width,
        height: strSize.height
    )

    // Use NSGraphicsContext so AttributedString drawing renders into our CGContext.
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    str.draw(in: textRect)
    NSGraphicsContext.restoreGraphicsState()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("png encode failed: \(path)")
    }
    try! data.write(to: url)
    print("wrote \(path) (\(image.width)x\(image.height))")
}

// Required sizes per Contents.json
struct IconSpec { let filename: String; let pixels: Int }
let specs: [IconSpec] = [
    IconSpec(filename: "icon_16x16.png",      pixels: 16),
    IconSpec(filename: "icon_16x16@2x.png",   pixels: 32),
    IconSpec(filename: "icon_32x32.png",      pixels: 32),
    IconSpec(filename: "icon_32x32@2x.png",   pixels: 64),
    IconSpec(filename: "icon_128x128.png",    pixels: 128),
    IconSpec(filename: "icon_128x128@2x.png", pixels: 256),
    IconSpec(filename: "icon_256x256.png",    pixels: 256),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512),
    IconSpec(filename: "icon_512x512.png",    pixels: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024),
]

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for spec in specs {
    let img = renderIcon(size: CGFloat(spec.pixels))
    writePNG(img, to: "\(outputDir)/\(spec.filename)")
}

// Update Contents.json to reference the filenames
let contentsJSON = """
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16",   "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16",   "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32",   "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32",   "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try! contentsJSON.write(toFile: "\(outputDir)/Contents.json", atomically: true, encoding: .utf8)
print("wrote \(outputDir)/Contents.json")
