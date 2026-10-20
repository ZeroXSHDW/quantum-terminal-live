import AppKit
import CoreGraphics
import CoreText
import Foundation

/// Renders the Quantum Terminal app icon natively at every size required by an
/// `.iconset`. Drawn in a 1024 × 1024 design space and rasterised per size, so
/// the 16 pt variant stays crisp instead of being a downscaled 1024 master.
enum AppIconArt {
    private enum C {
        static let black = CGColor(red: 0.002, green: 0.006, blue: 0.004, alpha: 1)
        static let deep = CGColor(red: 0.006, green: 0.040, blue: 0.022, alpha: 1)
        static let steel = CGColor(red: 0.020, green: 0.085, blue: 0.052, alpha: 1)
        static let steelHi = CGColor(red: 0.085, green: 0.230, blue: 0.145, alpha: 1)
        static let edge = CGColor(red: 0.190, green: 0.640, blue: 0.380, alpha: 1)
        static let green = CGColor(red: 0.240, green: 1.000, blue: 0.440, alpha: 1)
        static let ice = CGColor(red: 0.850, green: 1.000, blue: 0.910, alpha: 1)
        static let amber = CGColor(red: 0.850, green: 1.000, blue: 0.320, alpha: 1)
        static let red = CGColor(red: 1.000, green: 0.160, blue: 0.360, alpha: 1)
    }

    private static func a(_ c: CGColor, _ alpha: CGFloat) -> CGColor {
        c.copy(alpha: alpha) ?? c
    }

    static func render(pixelSize: Int) -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: pixelSize, height: pixelSize,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            fatalError("Unable to create icon context")
        }
        let u = CGFloat(pixelSize) / 1024.0
        ctx.scaleBy(x: u, y: u)
        ctx.setAllowsAntialiasing(true)
        ctx.interpolationQuality = .high
        draw(ctx, pixelSize: pixelSize)
        guard let image = ctx.makeImage() else { fatalError("Unable to render icon") }
        return image
    }

    private static func draw(_ ctx: CGContext, pixelSize: Int) {
        let detail = pixelSize >= 64
        let box = CGRect(x: 44, y: 44, width: 936, height: 936)
        let plate = CGPath(roundedRect: box, cornerWidth: 208, cornerHeight: 208, transform: nil)
        let center = CGPoint(x: 512, y: 512)

        // Drop shadow beneath the plate.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 34,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
        ctx.addPath(plate)
        ctx.setFillColor(C.black)
        ctx.fillPath()
        ctx.restoreGState()

        // Plate body.
        ctx.saveGState()
        ctx.addPath(plate)
        ctx.clip()

        let body = [C.deep, C.black] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: body,
                              locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: 980),
                                   end: CGPoint(x: 512, y: 44), options: [])
        }

        // Central vault glow.
        let glow = [a(C.edge, 0.34), a(C.deep, 0.30), a(C.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glow,
                              locations: [0.0, 0.48, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 20,
                                   endCenter: center, endRadius: 540, options: [])
        }

        // Hex lattice etched into the plate.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.setStrokeColor(a(C.edge, 0.045))
        ctx.setLineWidth(2.2)
        let step: CGFloat = 74
        for row in -6...8 {
            for col in -8...8 {
                var points: [CGPoint] = []
                let cx = CGFloat(col) * step * 1.5 + (row % 2 == 0 ? 0 : step * 0.75)
                let cy = CGFloat(row) * step * 1.35
                for i in 0..<6 {
                    let ang = Double(i) * Double.pi / 3.0 + Double.pi / 6.0
                    points.append(CGPoint(x: cx + CGFloat(cos(ang)) * step,
                                          y: cy + CGFloat(sin(ang)) * step))
                }
                let path = CGMutablePath()
                path.addLines(between: points)
                path.closeSubpath()
                ctx.addPath(path)
            }
        }
        ctx.strokePath()

        // Scanlines.
        var y: CGFloat = 60
        while y < 980 {
            ctx.setFillColor(a(C.black, 0.16))
            ctx.fill(CGRect(x: 44, y: y, width: 936, height: 1.2))
            y += 4.5
        }
        ctx.restoreGState()
        ctx.restoreGState()

        // Plate rim.
        ctx.addPath(plate)
        ctx.setStrokeColor(a(C.edge, 0.55))
        ctx.setLineWidth(5)
        ctx.strokePath()
        ctx.addPath(CGPath(roundedRect: box.insetBy(dx: 16, dy: 16),
                           cornerWidth: 194, cornerHeight: 194, transform: nil))
        ctx.setStrokeColor(a(C.ice, 0.10))
        ctx.setLineWidth(2)
        ctx.strokePath()

        // HUD corner brackets.
        ctx.saveGState()
        ctx.setStrokeColor(a(C.green, 0.55))
        ctx.setLineWidth(6)
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: 96, y: 928), 1, -1),
            (CGPoint(x: 928, y: 928), -1, -1),
            (CGPoint(x: 96, y: 96), 1, 1),
            (CGPoint(x: 928, y: 96), -1, 1)
        ]
        for (p, dx, dy) in corners {
            ctx.move(to: CGPoint(x: p.x, y: p.y + dy * 52))
            ctx.addLine(to: p)
            ctx.addLine(to: CGPoint(x: p.x + dx * 52, y: p.y))
        }
        ctx.strokePath()
        ctx.restoreGState()

        drawVault(ctx, center: center, detail: detail)

        // Small alert lamp at the 2 o'clock bearing.
        let lampAngle = Double.pi * 0.32
        let lamp = CGPoint(x: center.x + CGFloat(cos(lampAngle)) * 404,
                           y: center.y + CGFloat(sin(lampAngle)) * 404)
        ctx.setFillColor(a(C.red, 0.85))
        ctx.fillEllipse(in: CGRect(x: lamp.x - 9, y: lamp.y - 9, width: 18, height: 18))
        ctx.setFillColor(a(C.red, 0.16))
        ctx.fillEllipse(in: CGRect(x: lamp.x - 26, y: lamp.y - 26, width: 52, height: 52))
    }

    private static func drawVault(_ ctx: CGContext, center: CGPoint, detail: Bool) {
        let outerR: CGFloat = 352

        // Outer bloom.
        let bloom = [a(C.green, 0.20), a(C.edge, 0.06), a(C.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bloom,
                              locations: [0.0, 0.45, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: outerR * 0.6,
                                   endCenter: center, endRadius: outerR * 1.42, options: [])
        }

        // Machined housing band.
        let band = CGMutablePath()
        band.addEllipse(in: CGRect(x: center.x - outerR, y: center.y - outerR,
                                   width: outerR * 2, height: outerR * 2))
        band.addEllipse(in: CGRect(x: center.x - outerR * 0.885, y: center.y - outerR * 0.885,
                                   width: outerR * 1.77, height: outerR * 1.77))
        ctx.addPath(band)
        ctx.saveGState()
        ctx.clip(using: .evenOdd)
        let metal = [a(C.steelHi, 0.98), a(C.steel, 0.98), a(C.black, 1.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: metal,
                              locations: [0.0, 0.52, 1.0]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: center.x - outerR, y: center.y + outerR),
                                   end: CGPoint(x: center.x + outerR, y: center.y - outerR),
                                   options: [])
        }
        ctx.restoreGState()
        ctx.addPath(band)
        ctx.setStrokeColor(a(C.edge, 0.78))
        ctx.setLineWidth(4)
        ctx.strokePath()

        // Housing bolts.
        if detail {
            for i in 0..<28 {
                let ang = Double(i) / 28.0 * Double.pi * 2.0
                let p = CGPoint(x: center.x + CGFloat(cos(ang)) * outerR * 0.945,
                                y: center.y + CGFloat(sin(ang)) * outerR * 0.945)
                ctx.setFillColor(a(C.black, 0.9))
                ctx.fillEllipse(in: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16))
                ctx.setFillColor(a(C.ice, 0.32))
                ctx.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
            }
        }

        // Outer tick ring.
        if detail {
            for i in 0..<72 {
                let ang = Double(i) / 72.0 * Double.pi * 2.0
                let major = i % 6 == 0
                let r0 = outerR * 1.02
                let r1 = outerR * (major ? 1.085 : 1.058)
                ctx.setStrokeColor(a(major ? C.green : C.edge, major ? 0.62 : 0.24))
                ctx.setLineWidth(major ? 5 : 2.6)
                ctx.move(to: CGPoint(x: center.x + CGFloat(cos(ang)) * r0,
                                     y: center.y + CGFloat(sin(ang)) * r0))
                ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(ang)) * r1,
                                        y: center.y + CGFloat(sin(ang)) * r1))
                ctx.strokePath()
            }
        }

        // Iris blades.
        let blades = 10
        let innerR = outerR * 0.40
        let bladeR = outerR * 0.885
        let step = Double.pi * 2.0 / Double(blades)
        let gap = 0.055
        let skew = 0.170

        for i in 0..<blades {
            let a0 = Double(i) * step + gap * 0.5
            let a1 = Double(i + 1) * step - gap * 0.5
            let blade = CGMutablePath()
            blade.addArc(center: center, radius: bladeR,
                         startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
            blade.addLine(to: CGPoint(x: center.x + CGFloat(cos(a1 - skew)) * innerR,
                                      y: center.y + CGFloat(sin(a1 - skew)) * innerR))
            blade.addArc(center: center, radius: innerR,
                         startAngle: CGFloat(a1 - skew), endAngle: CGFloat(a0 - skew),
                         clockwise: true)
            blade.closeSubpath()

            ctx.saveGState()
            ctx.addPath(blade)
            ctx.clip()
            let colors = [C.edge, C.steelHi, C.steel, C.black] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0.0, 0.12, 0.42, 1.0]) {
                ctx.drawLinearGradient(
                    g,
                    start: CGPoint(x: center.x + CGFloat(cos(a0)) * bladeR,
                                   y: center.y + CGFloat(sin(a0)) * bladeR),
                    end: CGPoint(x: center.x + CGFloat(cos(a1)) * bladeR,
                                 y: center.y + CGFloat(sin(a1)) * bladeR),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            ctx.restoreGState()

            ctx.addPath(blade)
            ctx.setStrokeColor(a(C.edge, i % 2 == 0 ? 0.80 : 0.50))
            ctx.setLineWidth(4.5)
            ctx.strokePath()

            ctx.addPath(blade)
            ctx.setStrokeColor(a(C.green, 0.18))
            ctx.setLineWidth(1.6)
            ctx.strokePath()

            // Bright leading edge.
            ctx.setStrokeColor(a(C.ice, i % 2 == 0 ? 0.38 : 0.20))
            ctx.setLineWidth(3)
            ctx.addArc(center: center, radius: bladeR,
                       startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
            ctx.strokePath()
        }

        // Cross ring.
        let ringR = outerR * 0.60
        let ring = CGMutablePath()
        ring.addEllipse(in: CGRect(x: center.x - ringR, y: center.y - ringR,
                                   width: ringR * 2, height: ringR * 2))
        ring.addEllipse(in: CGRect(x: center.x - ringR * 0.925, y: center.y - ringR * 0.925,
                                   width: ringR * 1.85, height: ringR * 1.85))
        ctx.addPath(ring)
        ctx.setFillColor(a(C.steel, 0.96))
        ctx.fillPath(using: .evenOdd)
        ctx.addPath(ring)
        ctx.setStrokeColor(a(C.edge, 0.62))
        ctx.setLineWidth(3.4)
        ctx.strokePath()

        // Inner collar.
        let collarR = innerR * 1.10
        let collar = CGMutablePath()
        collar.addEllipse(in: CGRect(x: center.x - collarR, y: center.y - collarR,
                                     width: collarR * 2, height: collarR * 2))
        collar.addEllipse(in: CGRect(x: center.x - collarR * 0.92, y: center.y - collarR * 0.92,
                                     width: collarR * 1.84, height: collarR * 1.84))
        ctx.addPath(collar)
        ctx.setFillColor(a(C.steel, 0.98))
        ctx.fillPath(using: .evenOdd)
        ctx.addPath(collar)
        ctx.setStrokeColor(a(C.edge, 0.70))
        ctx.setLineWidth(3.2)
        ctx.strokePath()

        // Aperture.
        let aperture = CGMutablePath()
        aperture.addEllipse(in: CGRect(x: center.x - innerR, y: center.y - innerR,
                                       width: innerR * 2, height: innerR * 2))
        ctx.addPath(aperture)
        ctx.setFillColor(a(C.black, 0.98))
        ctx.fillPath()

        // Hex core plate.
        let hexR: CGFloat = 132
        let hex = CGMutablePath()
        for i in 0..<6 {
            let ang = Double(i) * Double.pi / 3.0 + Double.pi / 6.0
            let p = CGPoint(x: center.x + CGFloat(cos(ang)) * hexR,
                            y: center.y + CGFloat(sin(ang)) * hexR)
            if i == 0 { hex.move(to: p) } else { hex.addLine(to: p) }
        }
        hex.closeSubpath()
        ctx.addPath(hex)
        ctx.setFillColor(a(C.black, 0.96))
        ctx.fillPath()
        for (width, alpha) in [(20.0, 0.06), (9.0, 0.16), (3.6, 0.85)] {
            ctx.addPath(hex)
            ctx.setStrokeColor(a(C.green, alpha))
            ctx.setLineWidth(CGFloat(width))
            ctx.strokePath()
        }

        // Hex aura.
        let aura = [a(C.green, 0.30), a(C.edge, 0.08), a(C.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: aura,
                              locations: [0.0, 0.55, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: hexR * 0.6,
                                   endCenter: center, endRadius: hexR * 2.2, options: [])
        }

        drawPadlock(ctx, center: center)
    }

    private static func drawPadlock(_ ctx: CGContext, center: CGPoint) {
        let bodyW: CGFloat = 96
        let bodyH: CGFloat = 78
        let body = CGRect(x: center.x - bodyW * 0.5,
                          y: center.y - bodyH * 0.66,
                          width: bodyW, height: bodyH)
        let corner: CGFloat = 14

        // Shackle.
        let shackleR: CGFloat = 32
        ctx.setStrokeColor(a(C.ice, 0.95))
        ctx.setLineWidth(15)
        ctx.addArc(center: CGPoint(x: center.x, y: body.maxY + 2),
                   radius: shackleR,
                   startAngle: CGFloat(Double.pi * 0.0),
                   endAngle: CGFloat(Double.pi * 1.0),
                   clockwise: false)
        ctx.strokePath()

        // Glow behind the body.
        let glow = [a(C.green, 0.45), a(C.green, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glow,
                              locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 10,
                                   endCenter: center, endRadius: 130, options: [])
        }

        // Body.
        let bodyPath = CGPath(roundedRect: body, cornerWidth: corner,
                              cornerHeight: corner, transform: nil)
        ctx.addPath(bodyPath)
        ctx.setFillColor(a(C.black, 0.95))
        ctx.fillPath()
        ctx.addPath(bodyPath)
        ctx.setStrokeColor(a(C.ice, 0.92))
        ctx.setLineWidth(6)
        ctx.strokePath()

        // Keyhole.
        let keyR: CGFloat = 13
        let keyCenter = CGPoint(x: center.x, y: body.midY + 8)
        ctx.setFillColor(a(C.ice, 0.96))
        ctx.fillEllipse(in: CGRect(x: keyCenter.x - keyR, y: keyCenter.y - keyR,
                                   width: keyR * 2, height: keyR * 2))
        let slot = CGMutablePath()
        slot.move(to: CGPoint(x: keyCenter.x - keyR * 0.55, y: keyCenter.y - keyR * 0.1))
        slot.addLine(to: CGPoint(x: keyCenter.x + keyR * 0.55, y: keyCenter.y - keyR * 0.1))
        slot.addLine(to: CGPoint(x: keyCenter.x + keyR * 1.15, y: body.minY + 14))
        slot.addLine(to: CGPoint(x: keyCenter.x - keyR * 1.15, y: body.minY + 14))
        slot.closeSubpath()
        ctx.addPath(slot)
        ctx.fillPath()

        // Pulse ring.
        ctx.setStrokeColor(a(C.green, 0.30))
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: CGRect(x: center.x - 168, y: center.y - 168,
                                     width: 336, height: 336))
    }
}

// MARK: - CLI

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: IconMaker <output-iconset-directory>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outputDirectory,
                                         withIntermediateDirectories: true)

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (pixelSize, name) in variants {
    let image = AppIconArt.render(pixelSize: pixelSize)
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("unable to encode \(name)\n", stderr)
        exit(3)
    }
    try data.write(to: outputDirectory.appendingPathComponent(name))
}
print("wrote \(variants.count) icon variants to \(outputDirectory.path)")
