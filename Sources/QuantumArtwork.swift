import CoreGraphics
import CoreText
import Foundation

/// Procedural 8K master artwork for Quantum Terminal Live.
///
/// The static environment is generated once (and shipped as a PNG) so the live
/// layer only has to composite the animated vault overlay. Everything is
/// resolution-independent: call `generateBase(width:height:)` at any size.
enum QuantumArtwork {
    // MARK: - Palette

    private enum P {
        static let black = CGColor(red: 0.002, green: 0.004, blue: 0.003, alpha: 1)
        static let navy = CGColor(red: 0.004, green: 0.018, blue: 0.010, alpha: 1)
        static let deep = CGColor(red: 0.012, green: 0.045, blue: 0.025, alpha: 1)
        static let steel = CGColor(red: 0.015, green: 0.045, blue: 0.032, alpha: 1)
        static let steelHi = CGColor(red: 0.060, green: 0.135, blue: 0.100, alpha: 1)
        static let edge = CGColor(red: 0.000, green: 0.550, blue: 0.300, alpha: 1)
        static let cyan = CGColor(red: 0.000, green: 1.000, blue: 0.250, alpha: 1)
        static let ice = CGColor(red: 0.800, green: 1.000, blue: 0.880, alpha: 1)
        static let violet = CGColor(red: 0.320, green: 1.000, blue: 0.520, alpha: 1)
        static let red = CGColor(red: 1.000, green: 0.140, blue: 0.380, alpha: 1)
        static let amber = CGColor(red: 0.750, green: 1.000, blue: 0.280, alpha: 1)
    }

    private static func a(_ c: CGColor, _ alpha: CGFloat) -> CGColor {
        c.copy(alpha: alpha) ?? c
    }

    // MARK: - Deterministic random

    private struct RNG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 11) & 0xFFFFFFFF) / Double(0xFFFFFFFF)
        }
        mutating func range(_ lo: Double, _ hi: Double) -> Double {
            lo + (hi - lo) * next()
        }
    }

    // MARK: - Entry point

    static func generateBase(width: Int, height: Int) -> CGImage {
        let w = CGFloat(width)
        let h = CGFloat(height)
        let s = min(w, h)
        let center = CGPoint(x: w * 0.5, y: h * 0.555)
        let irisR = s * 0.285
        let horizon = h * 0.585

        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            fatalError("Unable to create artwork context")
        }
        ctx.setAllowsAntialiasing(true)
        ctx.interpolationQuality = .high

        drawSky(ctx, w: w, h: h, s: s, center: center, horizon: horizon)
        drawStars(ctx, w: w, h: h, s: s)
        drawCeilingGrid(ctx, w: w, h: h, s: s, horizon: horizon)
        drawDataColumns(ctx, w: w, h: h, s: s, horizon: horizon)
        drawBackdrop(ctx, w: w, h: h, s: s, center: center)
        drawFloor(ctx, w: w, h: h, s: s, horizon: horizon, center: center)
        drawFloorCircuits(ctx, w: w, h: h, s: s, horizon: horizon, center: center)
        drawAisleDataWalls(ctx, w: w, h: h, s: s, horizon: horizon)
        drawPylons(ctx, w: w, h: h, s: s)
        drawPlatform(ctx, w: w, h: h, s: s, center: center)
        drawIris(ctx, w: w, h: h, s: s, center: center, radius: irisR)
        drawVaultEtching(ctx, w: w, h: h, s: s, center: center, radius: irisR)
        drawAtmosphere(ctx, w: w, h: h, s: s, center: center, horizon: horizon)
        drawVignette(ctx, w: w, h: h, s: s, center: center)

        guard let image = ctx.makeImage() else {
            fatalError("Unable to render artwork")
        }
        return image
    }

    // MARK: - Backdrop lattice

    private static func drawBackdrop(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                     center: CGPoint) {
        ctx.saveGState()
        ctx.setBlendMode(.screen)

        // Concentric containment hexagons.
        for j in 0..<4 {
            let r = s * (0.385 + CGFloat(j) * 0.048)
            let hex = CGMutablePath()
            for i in 0..<6 {
                let ang = Double(i) * Double.pi / 3.0 + Double.pi / 6.0
                let p = CGPoint(x: center.x + CGFloat(cos(ang)) * r,
                                y: center.y + CGFloat(sin(ang)) * r)
                if i == 0 { hex.move(to: p) } else { hex.addLine(to: p) }
            }
            hex.closeSubpath()
            ctx.addPath(hex)
            ctx.setStrokeColor(a(j % 2 == 0 ? P.edge : P.violet, 0.034 - CGFloat(j) * 0.004))
            ctx.setLineWidth(max(1, s * 0.0008))
            ctx.strokePath()
        }

        // Bearing ticks on the first hexagon.
        for i in 0..<48 {
            let ang = Double(i) / 48.0 * Double.pi * 2
            let r0 = s * 0.385
            let r1 = r0 + s * (i % 6 == 0 ? 0.012 : 0.006)
            ctx.setStrokeColor(a(P.edge, i % 6 == 0 ? 0.10 : 0.04))
            ctx.setLineWidth(max(1, s * 0.0006))
            ctx.move(to: CGPoint(x: center.x + CGFloat(cos(ang)) * r0,
                                 y: center.y + CGFloat(sin(ang)) * r0))
            ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(ang)) * r1,
                                    y: center.y + CGFloat(sin(ang)) * r1))
            ctx.strokePath()
        }

        // Vertical depth beams behind the vault.
        for fx in [CGFloat(0.315), CGFloat(0.685)] {
            let x = w * fx
            let colors = [a(P.cyan, 0.0), a(P.cyan, 0.030), a(P.cyan, 0.0)] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0.0, 0.5, 1.0]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: x - w * 0.03, y: h * 0.62),
                                       end: CGPoint(x: x + w * 0.03, y: h * 0.62),
                                       options: [])
            }
        }
        ctx.restoreGState()
    }

    // MARK: - Sky

    private static func drawSky(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                center: CGPoint, horizon: CGFloat) {
        let bg = [P.black, P.navy, P.deep, P.black] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bg,
                              locations: [0.0, 0.42, 0.62, 1.0]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: w * 0.5, y: h),
                                   end: CGPoint(x: w * 0.5, y: 0), options: [])
        }

        // Deep halo behind the vault.
        let halo = [a(P.violet, 0.18), a(P.deep, 0.38), a(P.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: halo,
                              locations: [0.0, 0.45, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: s * 0.78, options: [])
        }

        // Horizon haze.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        let haze = [a(P.deep, 0.0), a(P.deep, 0.55), a(P.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: haze,
                              locations: [0.0, 0.5, 1.0]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: w * 0.5, y: horizon + h * 0.10),
                                   end: CGPoint(x: w * 0.5, y: horizon - h * 0.05),
                                   options: [])
        }
        ctx.restoreGState()

        // Faint vertical light shafts from above.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        for i in -3...3 {
            let x = w * 0.5 + CGFloat(i) * w * 0.085
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x - w * 0.012, y: h))
            path.addLine(to: CGPoint(x: x + w * 0.012, y: h))
            path.addLine(to: CGPoint(x: x + w * 0.060, y: horizon))
            path.addLine(to: CGPoint(x: x - w * 0.060, y: horizon))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setFillColor(a(P.cyan, 0.008 + 0.004 * CGFloat(3 - abs(i))))
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    // MARK: - Stars / dust

    private static func drawStars(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat) {
        var rng = RNG(state: 0x51A7_2026_0BAD_F00D)
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        for _ in 0..<520 {
            let x = CGFloat(rng.next()) * w
            let y = h * CGFloat(rng.range(0.52, 1.0))
            let r = s * CGFloat(rng.range(0.0004, 0.0016))
            let alpha = CGFloat(rng.range(0.015, 0.16))
            ctx.setFillColor(a(rng.next() > 0.82 ? P.ice : P.edge, alpha))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        // A few atmospheric motes in the lower half.
        for _ in 0..<220 {
            let x = CGFloat(rng.next()) * w
            let y = h * CGFloat(rng.range(0.05, 0.60))
            let r = s * CGFloat(rng.range(0.0004, 0.0012))
            ctx.setFillColor(a(P.cyan, CGFloat(rng.range(0.008, 0.045))))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        ctx.restoreGState()
    }

    // MARK: - Ceiling depth grid

    private static func drawCeilingGrid(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                        horizon: CGFloat) {
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.clip(to: CGRect(x: 0, y: horizon, width: w, height: h - horizon))

        // Perspective fan of ceiling seams converging on the horizon vanishing point.
        for i in -18...18 {
            let baseX = w * 0.5 + CGFloat(i) * w * 0.0042
            let topX = w * 0.5 + CGFloat(i) * w * 0.070
            let major = i % 6 == 0
            ctx.setStrokeColor(a(major ? P.edge : P.cyan, major ? 0.030 : 0.013))
            ctx.setLineWidth(max(1, s * (major ? 0.0008 : 0.0004)))
            ctx.move(to: CGPoint(x: baseX, y: horizon))
            ctx.addLine(to: CGPoint(x: topX, y: h))
            ctx.strokePath()
        }

        // Ceiling cross rails get sparser and fainter with distance.
        for i in 0..<7 {
            let t = CGFloat(i) / 6.0
            let y = horizon + pow(t, 2.4) * (h - horizon)
            let alpha = 0.010 + 0.016 * t
            ctx.setStrokeColor(a(P.edge, alpha))
            ctx.setLineWidth(max(1, s * 0.0005))
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: w, y: y))
            ctx.strokePath()
        }

        // Suspended light rails.
        for fx in [CGFloat(0.315), CGFloat(0.685)] {
            let x = w * fx
            let colors = [a(P.cyan, 0.0), a(P.cyan, 0.05), a(P.cyan, 0.0)] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0.0, 0.5, 1.0]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: x - s * 0.010, y: h * 0.90),
                                       end: CGPoint(x: x + s * 0.010, y: h * 0.90),
                                       options: [])
            }
        }
        ctx.restoreGState()
    }

    // MARK: - Background data columns

    private static func drawDataColumns(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                        horizon: CGFloat) {
        let glyphs = Array("0123456789ABCDEF#/").map(String.init)
        let fontSize = s * 0.0082
        var rng = RNG(state: 0x0D47_A1CE_71C0_2222)

        ctx.saveGState()
        ctx.setBlendMode(.screen)

        let columns: [CGFloat] = [0.010, 0.027, 0.046, 0.066, 0.088,
                                  0.912, 0.934, 0.954, 0.973, 0.990]
        for (index, fx) in columns.enumerated() {
            let x = w * fx
            let top = h * CGFloat(rng.range(0.905, 0.955))
            let bottom = max(horizon + h * 0.03, h * CGFloat(rng.range(0.66, 0.74)))
            let lineAlpha = CGFloat(rng.range(0.025, 0.055))

            ctx.setStrokeColor(a(P.edge, lineAlpha))
            ctx.setLineWidth(max(1, s * 0.00045))
            ctx.move(to: CGPoint(x: x - fontSize * 0.55, y: bottom))
            ctx.addLine(to: CGPoint(x: x - fontSize * 0.55, y: top))
            ctx.strokePath()

            var y = top
            while y > bottom {
                var row = ""
                for _ in 0..<4 {
                    row += glyphs[Int(rng.next() * Double(glyphs.count)) % glyphs.count]
                }
                let bright = rng.next() > 0.90
                let alpha = CGFloat(rng.range(0.018, 0.055)) * (bright ? 2.2 : 1.0)
                let color = bright ? P.ice : (index % 3 == 0 ? P.cyan : P.edge)
                drawText(ctx, row, at: CGPoint(x: x, y: y), size: fontSize,
                         color: a(color, alpha), kern: fontSize * 0.08)
                y -= s * 0.0175
            }

            // A few lit status squares along the column.
            for _ in 0..<4 {
                let y = bottom + CGFloat(rng.next()) * (top - bottom)
                let d = s * 0.0016
                ctx.setFillColor(a(rng.next() > 0.75 ? P.amber : P.cyan, CGFloat(rng.range(0.10, 0.30))))
                ctx.fill(CGRect(x: x + fontSize * 0.55, y: y, width: d, height: d))
            }
        }
        ctx.restoreGState()
    }

    // MARK: - Aisle data walls

    /// Dense glyph curtains standing in the service aisles between the near and
    /// far pylons. They read as glowing server telemetry at a distance and give
    /// the lower half of the frame the density of a real operations floor.
    private static func drawAisleDataWalls(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                           horizon: CGFloat) {
        let glyphs = Array("0123456789ABCDEF").map(String.init)
        let fontSize = s * 0.0074
        let rowStep = s * 0.0165
        let walls: [(CGFloat, UInt64)] = [
            (0.132, 0x51DE_0001),
            (0.824, 0x51DE_0002)
        ]

        ctx.saveGState()
        ctx.setBlendMode(.screen)

        for (wallIndex, wall) in walls.enumerated() {
            let left = w * wall.0
            let width = w * 0.042
            let top = h * 0.690
            let bottom = h * 0.188
            var rng = RNG(state: wall.1)

            // Dark backing so the glyphs sit in a recess, not on top of the floor.
            ctx.setBlendMode(.normal)
            ctx.setFillColor(a(P.black, 0.50))
            ctx.fill(CGRect(x: left, y: bottom, width: width, height: top - bottom))
            ctx.setBlendMode(.screen)

            // Chassis rails.
            let railAlpha: CGFloat = wallIndex == 0 ? 0.17 : 0.13
            ctx.setStrokeColor(a(P.edge, railAlpha))
            ctx.setLineWidth(max(1, s * 0.0007))
            ctx.move(to: CGPoint(x: left, y: bottom))
            ctx.addLine(to: CGPoint(x: left, y: top))
            ctx.move(to: CGPoint(x: left + width, y: bottom))
            ctx.addLine(to: CGPoint(x: left + width, y: top))
            ctx.strokePath()

            for i in 0..<4 {
                let y = bottom + (top - bottom) * CGFloat(i) / 3.0
                ctx.setStrokeColor(a(P.edge, railAlpha * 0.7))
                ctx.setLineWidth(max(1, s * 0.0005))
                ctx.move(to: CGPoint(x: left, y: y))
                ctx.addLine(to: CGPoint(x: left + width, y: y))
                ctx.strokePath()
            }

            // Recessed channel.
            ctx.setFillColor(a(P.deep, 0.30))
            ctx.fill(CGRect(x: left + width * 0.08, y: bottom + rowStep * 0.4,
                            width: width * 0.84, height: top - bottom - rowStep * 0.8))

            // Two columns of rolling hex telemetry.
            for col in 0..<2 {
                let x = left + width * (col == 0 ? 0.24 : 0.60)
                var y = top - rowStep * 0.8
                while y > bottom + rowStep * 0.3 {
                    var row = ""
                    for _ in 0..<4 {
                        row += glyphs[Int(rng.next() * Double(glyphs.count)) % glyphs.count]
                    }
                    let hot = rng.next() > 0.93
                    let alpha = CGFloat(rng.range(0.045, 0.115)) * (hot ? 2.6 : 1.0)
                    let color = hot ? P.ice : (rng.next() > 0.88 ? P.amber : P.cyan)
                    drawText(ctx, row, at: CGPoint(x: x, y: y), size: fontSize,
                             color: a(color, alpha), kern: fontSize * 0.06)
                    y -= rowStep
                }
            }

            // Sink the base of the curtain into the deck shadow.
            let fade = [a(P.black, 0.88), a(P.black, 0.0)] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fade,
                                  locations: [0.0, 1.0]) {
                ctx.saveGState()
                ctx.setBlendMode(.normal)
                ctx.clip(to: CGRect(x: left, y: bottom, width: width, height: h * 0.060))
                ctx.drawLinearGradient(g, start: CGPoint(x: left, y: bottom),
                                       end: CGPoint(x: left, y: bottom + h * 0.060), options: [])
                ctx.restoreGState()
            }
            ctx.setBlendMode(.screen)

            // Status rail and a single red lamp at the top of each wall.
            let railX = left + width * 0.5
            ctx.setStrokeColor(a(P.cyan, 0.12))
            ctx.setLineWidth(max(1, s * 0.0008))
            ctx.move(to: CGPoint(x: railX, y: bottom + rowStep))
            ctx.addLine(to: CGPoint(x: railX, y: top - rowStep * 1.4))
            ctx.strokePath()

            for i in 0..<6 {
                let y = bottom + rowStep * (1.0 + CGFloat(i) * 2.4)
                let bright = i == 2 || i == 5
                ctx.setFillColor(a(bright ? P.amber : P.cyan, bright ? 0.55 : 0.18))
                let d = s * 0.0014
                ctx.fill(CGRect(x: railX - d, y: y, width: d * 2, height: d * 2))
            }

            let lamp = s * 0.0026
            let lampX = left + width * 0.5
            let lampY = top - rowStep * 0.35
            ctx.setFillColor(a(P.red, 0.10))
            ctx.fillEllipse(in: CGRect(x: lampX - lamp * 3.0, y: lampY - lamp * 3.0,
                                       width: lamp * 6.0, height: lamp * 6.0))
            ctx.setFillColor(a(P.red, 0.82))
            ctx.fillEllipse(in: CGRect(x: lampX - lamp, y: lampY - lamp,
                                       width: lamp * 2, height: lamp * 2))

            // A small header block: three lit segments and a hazard notch.
            for i in 0..<3 {
                ctx.setFillColor(a(i == 1 ? P.amber : P.cyan, 0.22))
                ctx.fill(CGRect(x: left + width * 0.18 + CGFloat(i) * width * 0.18,
                                y: top + s * 0.004,
                                width: width * 0.11, height: s * 0.0022))
            }
        }

        // Horizon light rail: a hard neon line where the deck meets the void.
        let rail = [a(P.cyan, 0.0), a(P.cyan, 0.16), a(P.cyan, 0.22), a(P.cyan, 0.16),
                    a(P.cyan, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: rail,
                              locations: [0.0, 0.30, 0.5, 0.70, 1.0]) {
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: horizon - h * 0.008, width: w, height: h * 0.016))
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: horizon),
                                   end: CGPoint(x: w, y: horizon), options: [])
            ctx.restoreGState()
        }
        ctx.setStrokeColor(a(P.ice, 0.16))
        ctx.setLineWidth(max(1, s * 0.0007))
        ctx.move(to: CGPoint(x: w * 0.16, y: horizon))
        ctx.addLine(to: CGPoint(x: w * 0.84, y: horizon))
        ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - Text helper

    private static func drawText(_ ctx: CGContext, _ text: String, at point: CGPoint,
                                 size: CGFloat, color: CGColor, kern: CGFloat) {
        let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): kern
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attrs))
        ctx.textPosition = point
        CTLineDraw(line, ctx)
    }

    private static func drawRingText(_ ctx: CGContext, _ text: String, center: CGPoint,
                                     angle: Double, radius: CGFloat, size: CGFloat,
                                     color: CGColor, kern: CGFloat) {
        let font = CTFontCreateWithName("Menlo" as CFString, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): kern
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attrs))
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        ctx.saveGState()
        ctx.translateBy(x: center.x + CGFloat(cos(angle)) * radius,
                        y: center.y + CGFloat(sin(angle)) * radius)
        // Radial labels: flip the left half so every legend stays readable.
        let flip = cos(angle) < 0 ? Double.pi : 0.0
        ctx.rotate(by: CGFloat(angle + flip))
        ctx.textPosition = CGPoint(x: -width * 0.5, y: -size * 0.36)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // MARK: - Floor

    private static func drawFloor(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                  horizon: CGFloat, center: CGPoint) {
        let floorColors = [a(P.deep, 0.85), a(P.navy, 0.90), a(P.black, 1.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: floorColors,
                              locations: [0.0, 0.35, 1.0]) {
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: horizon))
            ctx.drawLinearGradient(g, start: CGPoint(x: w * 0.5, y: horizon),
                                   end: CGPoint(x: w * 0.5, y: 0), options: [])
            ctx.restoreGState()
        }

        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.setLineWidth(max(1, s * 0.0006))

        // Converging rails.
        for i in -32...32 {
            let bx = w * 0.5 + CGFloat(i) * w * 0.030
            let major = i % 8 == 0
            ctx.setStrokeColor(a(major ? P.edge : P.cyan, major ? 0.050 : 0.020))
            ctx.setLineWidth(max(1, s * (major ? 0.0010 : 0.0005)))
            ctx.move(to: CGPoint(x: w * 0.5, y: horizon))
            ctx.addLine(to: CGPoint(x: bx, y: 0))
            ctx.strokePath()
        }

        // Depth lines.
        let rows = 30
        for i in 1...rows {
            let p = Double(i) / Double(rows)
            let y = horizon * CGFloat(1.0 - pow(p, 2.15))
            let major = i % 5 == 0
            ctx.setStrokeColor(a(major ? P.edge : P.cyan, major ? 0.042 : 0.016))
            ctx.setLineWidth(max(1, s * (major ? 0.0009 : 0.0005)))
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: w, y: y))
            ctx.strokePath()
        }

        // Light pool under the platform.
        let pool = [a(P.cyan, 0.16), a(P.deep, 0.08), a(P.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: pool,
                              locations: [0.0, 0.42, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: center.x, y: h * 0.16),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: center.x, y: h * 0.16),
                                   endRadius: s * 0.42, options: [])
        }
        ctx.restoreGState()
    }

    // MARK: - Floor circuitry

    private static func drawFloorCircuits(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                          horizon: CGFloat, center: CGPoint) {
        let cx = center.x
        var rng = RNG(state: 0xC1C0_1715_2026)

        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: horizon))

        // Inlaid containment hexagons on the deck.
        for (index, config) in [(CGFloat(0.335), CGFloat(0.060)), (CGFloat(0.455), CGFloat(0.028))].enumerated() {
            let r = w * config.0
            let cy = h * 0.070
            let path = CGMutablePath()
            for i in 0..<6 {
                let ang = Double(i) * Double.pi / 3.0 + Double.pi / 6.0
                    + (index == 0 ? 0.0 : 0.18)
                let p = CGPoint(x: cx + CGFloat(cos(ang)) * r,
                                y: cy + CGFloat(sin(ang)) * r * 0.28)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setStrokeColor(a(index == 0 ? P.cyan : P.edge, config.1))
            ctx.setLineWidth(max(1, s * 0.0008))
            ctx.strokePath()

            // Alignment ticks at the vertices.
            for i in 0..<6 {
                let ang = Double(i) * Double.pi / 3.0 + Double.pi / 6.0
                    + (index == 0 ? 0.0 : 0.18)
                let p = CGPoint(x: cx + CGFloat(cos(ang)) * r,
                                y: cy + CGFloat(sin(ang)) * r * 0.28)
                ctx.setStrokeColor(a(P.cyan, config.1 * 1.6))
                ctx.setLineWidth(max(1, s * 0.0006))
                ctx.move(to: CGPoint(x: p.x - s * 0.006, y: p.y))
                ctx.addLine(to: CGPoint(x: p.x + s * 0.006, y: p.y))
                ctx.strokePath()
            }
        }

        // Printed circuit traces running from the plinth to the frame edges.
        let traceCount = 16
        for i in 0..<traceCount {
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            var x = cx + side * w * CGFloat(rng.range(0.235, 0.315))
            var y = h * CGFloat(rng.range(0.045, 0.135))
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: y))

            var nodes: [CGPoint] = []
            for _ in 0..<3 {
                let dx = side * w * CGFloat(rng.range(0.035, 0.090))
                let dy = h * CGFloat(rng.range(-0.020, 0.040))
                let chamfer = min(abs(dx), abs(dy)) * 0.55
                path.addLine(to: CGPoint(x: x + dx - side * chamfer, y: y))
                path.addLine(to: CGPoint(x: x + dx, y: y + (dy > 0 ? chamfer : -chamfer)))
                path.addLine(to: CGPoint(x: x + dx, y: y + dy))
                x += dx
                y += dy
                nodes.append(CGPoint(x: x, y: y))
                if x < 0 || x > w { break }
            }

            ctx.addPath(path)
            ctx.setStrokeColor(a(i % 5 == 0 ? P.amber : P.cyan, CGFloat(rng.range(0.035, 0.075))))
            ctx.setLineWidth(max(1, s * (i % 5 == 0 ? 0.0009 : 0.0006)))
            ctx.strokePath()

            // Solder pads and a few lit vias.
            for (index, node) in nodes.enumerated() {
                let pad = s * 0.0032
                ctx.setStrokeColor(a(P.edge, 0.10))
                ctx.setLineWidth(max(1, s * 0.0005))
                ctx.addRect(CGRect(x: node.x - pad, y: node.y - pad * 0.55,
                                   width: pad * 2, height: pad * 1.1))
                ctx.strokePath()
                if (i + index) % 4 == 0 {
                    ctx.setFillColor(a(i % 5 == 0 ? P.amber : P.ice, 0.20))
                    ctx.fillEllipse(in: CGRect(x: node.x - pad * 0.35, y: node.y - pad * 0.35,
                                               width: pad * 0.7, height: pad * 0.7))
                }
            }
        }

        // Aisle light strip feeding the plinth.
        let aisle = [a(P.cyan, 0.0), a(P.cyan, 0.055), a(P.cyan, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: aisle,
                              locations: [0.0, 0.55, 1.0]) {
            ctx.drawLinearGradient(g,
                                   start: CGPoint(x: cx, y: 0),
                                   end: CGPoint(x: cx, y: h * 0.17),
                                   options: [])
        }

        ctx.restoreGState()
    }

    // MARK: - Pylons

    private static func drawPylons(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat) {
        // Back pylons first, then the near pair.
        drawPylon(ctx, w: w, h: h, s: s,
                  points: [CGPoint(x: w * 0.185, y: h * 0.16),
                           CGPoint(x: w * 0.250, y: h * 0.28),
                           CGPoint(x: w * 0.250, y: h * 0.58),
                           CGPoint(x: w * 0.185, y: h * 0.44)],
                  lightX: 0.244, alpha: 0.26, leds: 8)
        drawPylon(ctx, w: w, h: h, s: s,
                  points: [CGPoint(x: w * 0.815, y: h * 0.44),
                           CGPoint(x: w * 0.750, y: h * 0.58),
                           CGPoint(x: w * 0.750, y: h * 0.28),
                           CGPoint(x: w * 0.815, y: h * 0.16)],
                  lightX: 0.756, alpha: 0.26, leds: 8)

        drawPylon(ctx, w: w, h: h, s: s,
                  points: [CGPoint(x: w * 0.022, y: h * 0.145),
                           CGPoint(x: w * 0.120, y: h * 0.170),
                           CGPoint(x: w * 0.120, y: h * 0.705),
                           CGPoint(x: w * 0.058, y: h * 0.685)],
                  lightX: 0.112, alpha: 0.46, leds: 16)
        drawPylon(ctx, w: w, h: h, s: s,
                  points: [CGPoint(x: w * 0.978, y: h * 0.145),
                           CGPoint(x: w * 0.880, y: h * 0.170),
                           CGPoint(x: w * 0.880, y: h * 0.705),
                           CGPoint(x: w * 0.942, y: h * 0.685)],
                  lightX: 0.888, alpha: 0.46, leds: 16)

        _ = s
    }

    private static func drawPylon(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                  points: [CGPoint], lightX: CGFloat,
                                  alpha: CGFloat, leds: Int) {
        guard points.count == 4 else { return }
        let bl = points[0], br = points[1], tr = points[2], tl = points[3]

        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }

        let face = CGMutablePath()
        face.move(to: bl)
        face.addLine(to: br)
        face.addLine(to: tr)
        face.addLine(to: tl)
        face.closeSubpath()

        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()

        // Face lighting: bright on the aisle side, falling off outward.
        let innerX = br.x
        let outerX = bl.x
        let steelColors = [a(P.steel, 0.98), a(P.black, 0.98), a(P.black, 1.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: steelColors,
                              locations: [0.0, 0.42, 1.0]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: innerX, y: h * 0.52),
                                   end: CGPoint(x: outerX, y: h * 0.46), options: [])
        }

        // Rack seams.
        for i in 1..<14 {
            let t = CGFloat(i) / 14.0
            let l = lerp(bl, tl, t)
            let r = lerp(br, tr, t)
            let major = i % 4 == 0
            ctx.setStrokeColor(a(P.edge, major ? 0.12 : 0.055))
            ctx.setLineWidth(max(1, s * (major ? 0.0009 : 0.0005)))
            ctx.move(to: l)
            ctx.addLine(to: r)
            ctx.strokePath()
        }

        // LED matrices down the aisle side.
        for col in 0..<3 {
            let f = 0.58 + CGFloat(col) * 0.15
            for row in 0..<18 {
                let t = (CGFloat(row) + 0.5) / 18.0
                let l = lerp(bl, tl, t)
                let r = lerp(br, tr, t)
                let p = lerp(l, r, f)
                let dot = s * (col == 2 ? 0.0014 : 0.0010)
                let lit = (row + col * 3) % 9 != 4
                let ledColor: CGColor = col == 1 ? P.violet : (lit ? P.cyan : P.amber)
                ctx.setFillColor(a(ledColor, lit ? 0.34 : 0.22))
                ctx.fillEllipse(in: CGRect(x: p.x - dot, y: p.y - dot,
                                           width: dot * 2, height: dot * 2))
            }
        }

        // Holographic readout panel.
        let panel = CGMutablePath()
        let p0 = lerp(lerp(bl, tl, 0.34), lerp(br, tr, 0.34), 0.42)
        let p1 = lerp(lerp(bl, tl, 0.34), lerp(br, tr, 0.34), 0.90)
        let p2 = lerp(lerp(bl, tl, 0.62), lerp(br, tr, 0.62), 0.90)
        let p3 = lerp(lerp(bl, tl, 0.62), lerp(br, tr, 0.62), 0.42)
        panel.move(to: p0); panel.addLine(to: p1)
        panel.addLine(to: p2); panel.addLine(to: p3); panel.closeSubpath()
        ctx.addPath(panel)
        ctx.setFillColor(a(P.violet, 0.040))
        ctx.fillPath()
        ctx.addPath(panel)
        ctx.setStrokeColor(a(P.violet, 0.18))
        ctx.setLineWidth(max(1, s * 0.0007))
        ctx.strokePath()
        for i in 0..<4 {
            let t = 0.10 + CGFloat(i) * 0.22
            let a0 = lerp(p0, p3, t)
            let a1 = lerp(p1, p2, t)
            ctx.setStrokeColor(a(P.cyan, 0.055))
            ctx.setLineWidth(max(1, s * 0.0005))
            ctx.move(to: a0); ctx.addLine(to: a1); ctx.strokePath()
        }
        for i in 0..<5 {
            let t = 0.16 + CGFloat(i) * 0.15
            let x = lerp(p0, p1, t).x
            let baseY = p0.y + (p3.y - p0.y) * 0.55
            let barH = (p3.y - p0.y) * CGFloat(0.10 + 0.07 * CGFloat((i * 3) % 4))
            ctx.setFillColor(a(P.cyan, 0.10))
            ctx.fill(CGRect(x: x, y: baseY, width: s * 0.0015, height: barH))
        }

        // Base hazard band with diagonal warning stripes.
        let bandBottom = min(bl.y, br.y)
        let bandHeight = h * 0.022
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: bandBottom, width: w, height: bandHeight))
        var stripeX = 0.0
        var stripeIndex = 0
        while stripeX < Double(w) {
            if stripeIndex % 2 == 0 {
                let stripe = CGMutablePath()
                let x0 = CGFloat(stripeX)
                stripe.move(to: CGPoint(x: x0, y: bandBottom))
                stripe.addLine(to: CGPoint(x: x0 + s * 0.006, y: bandBottom))
                stripe.addLine(to: CGPoint(x: x0 + s * 0.006 + bandHeight, y: bandBottom + bandHeight))
                stripe.addLine(to: CGPoint(x: x0 + bandHeight, y: bandBottom + bandHeight))
                stripe.closeSubpath()
                ctx.addPath(stripe)
                ctx.setFillColor(a(P.amber, 0.11))
                ctx.fillPath()
            }
            stripeX += Double(s * 0.0135)
            stripeIndex += 1
        }
        ctx.restoreGState()

        ctx.restoreGState()

        // Top cap block.
        let capH = s * 0.012
        let cap = CGMutablePath()
        cap.move(to: tl)
        cap.addLine(to: tr)
        cap.addLine(to: CGPoint(x: tr.x, y: tr.y + capH))
        cap.addLine(to: CGPoint(x: tl.x, y: tl.y + capH))
        cap.closeSubpath()
        ctx.addPath(cap)
        ctx.setFillColor(a(P.black, 0.94))
        ctx.fillPath()
        ctx.addPath(cap)
        ctx.setStrokeColor(a(P.edge, 0.40))
        ctx.setLineWidth(max(1, s * 0.0011))
        ctx.strokePath()
        ctx.setStrokeColor(a(P.cyan, 0.30))
        ctx.setLineWidth(max(1, s * 0.0008))
        ctx.move(to: CGPoint(x: tl.x, y: tl.y + capH * 0.82))
        ctx.addLine(to: CGPoint(x: tr.x, y: tr.y + capH * 0.82))
        ctx.strokePath()

        // Vapour vents along the cap.
        for i in 1...5 {
            let t = CGFloat(i) / 6.0
            let x = tl.x + (tr.x - tl.x) * t
            let y = tl.y + (tr.y - tl.y) * t + capH * 0.35
            ctx.setFillColor(a(P.cyan, 0.22))
            ctx.fill(CGRect(x: x - s * 0.002, y: y, width: s * 0.004, height: s * 0.0016))
        }

        // Top cap.
        ctx.setStrokeColor(a(P.steelHi, 0.75))
        ctx.setLineWidth(max(1, s * 0.0060))
        ctx.move(to: tl)
        ctx.addLine(to: tr)
        ctx.strokePath()
        ctx.setStrokeColor(a(P.ice, 0.35))
        ctx.setLineWidth(max(1, s * 0.0012))
        ctx.move(to: CGPoint(x: tl.x, y: tl.y + s * 0.004))
        ctx.addLine(to: CGPoint(x: tr.x, y: tr.y + s * 0.004))
        ctx.strokePath()

        // Emergency strobe lens on the cap shoulder.
        let lampCenter = CGPoint(x: (tl.x + tr.x) * 0.5, y: (tl.y + tr.y) * 0.5 + capH * 0.46)
        let lampR = s * 0.0030
        ctx.setFillColor(a(P.red, 0.10))
        ctx.fillEllipse(in: CGRect(x: lampCenter.x - lampR * 3.2, y: lampCenter.y - lampR * 3.2,
                                   width: lampR * 6.4, height: lampR * 6.4))
        ctx.setFillColor(a(P.red, 0.78))
        ctx.fillEllipse(in: CGRect(x: lampCenter.x - lampR, y: lampCenter.y - lampR * 0.62,
                                   width: lampR * 2, height: lampR * 1.24))
        ctx.setFillColor(a(P.ice, 0.55))
        ctx.fillEllipse(in: CGRect(x: lampCenter.x - lampR * 0.32,
                                   y: lampCenter.y - lampR * 0.20,
                                   width: lampR * 0.64, height: lampR * 0.64))
        ctx.setStrokeColor(a(P.red, 0.32))
        ctx.setLineWidth(max(1, s * 0.0006))
        ctx.addEllipse(in: CGRect(x: lampCenter.x - lampR * 2.2, y: lampCenter.y - lampR * 1.0,
                                  width: lampR * 4.4, height: lampR * 2.0))
        ctx.strokePath()

        // Bevel.
        let bevel = CGMutablePath()
        bevel.move(to: bl)
        bevel.addLine(to: br)
        bevel.addLine(to: tr)
        bevel.addLine(to: tl)
        bevel.closeSubpath()
        ctx.addPath(bevel)
        ctx.setStrokeColor(a(P.edge, 0.30))
        ctx.setLineWidth(max(1, s * 0.0011))
        ctx.strokePath()

        // Inner edge accent.
        ctx.setStrokeColor(a(P.cyan, 0.26))
        ctx.setLineWidth(max(1, s * 0.0016))
        ctx.move(to: br)
        ctx.addLine(to: tr)
        ctx.strokePath()

        // Cable sweeping into the floor.
        let basePoint = bl.y < br.y ? bl : br
        for (index, spread) in [CGFloat(0.000), CGFloat(0.010), CGFloat(0.019)].enumerated() {
            let cable = CGMutablePath()
            let start = CGPoint(x: basePoint.x + spread * w * (basePoint == bl ? 1 : -1),
                                y: basePoint.y)
            cable.move(to: start)
            cable.addQuadCurve(to: CGPoint(x: basePoint.x + w * (0.014 - spread * 0.35), y: 0),
                               control: CGPoint(x: basePoint.x - w * (0.004 + spread * 0.20),
                                                y: h * 0.02))
            ctx.addPath(cable)
            ctx.setStrokeColor(a(index == 0 ? P.cyan : P.edge, index == 0 ? 0.07 : 0.035))
            ctx.setLineWidth(max(1, s * (index == 0 ? 0.0010 : 0.0006)))
            ctx.strokePath()
        }

        // Vertical light channel.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        let stripX = w * lightX
        let stripTop = max(tr.y, tl.y) - h * 0.025
        let stripBottom = min(bl.y, br.y) + h * 0.025
        for (width, a0) in [(0.010, 0.035), (0.0035, 0.12), (0.0014, 0.60)] {
            ctx.setStrokeColor(a(P.cyan, alpha * CGFloat(a0)))
            ctx.setLineWidth(max(1, w * CGFloat(width)))
            ctx.move(to: CGPoint(x: stripX, y: stripBottom))
            ctx.addLine(to: CGPoint(x: stripX, y: stripTop))
            ctx.strokePath()
        }

        var rng = RNG(state: UInt64(lightX * 100000) | 1)
        for i in 0..<leds {
            let t = (CGFloat(i) + 0.5) / CGFloat(leds)
            let y = stripTop - (stripTop - stripBottom) * t
            let r = s * 0.0016
            ctx.setFillColor(a(i % 7 == 3 ? P.amber : P.cyan, 0.60))
            ctx.fillEllipse(in: CGRect(x: stripX - r, y: y - r, width: r * 2, height: r * 2))
            ctx.setFillColor(a(P.ice, 0.12))
            ctx.fillEllipse(in: CGRect(x: stripX - r * 2.6, y: y - r * 2.6,
                                       width: r * 5.2, height: r * 5.2))
            _ = rng.next()
        }
        ctx.restoreGState()
    }

    // MARK: - Platform

    private static func drawPlatform(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                     center: CGPoint) {
        let cx = center.x
        let baseY = h * 0.145
        let rxBase = w * 0.225
        let ryBase = h * 0.064

        // Shadow.
        ctx.setFillColor(a(P.black, 0.55))
        ctx.fillEllipse(in: CGRect(x: cx - rxBase * 1.08, y: baseY - ryBase * 1.45,
                                   width: rxBase * 2.16, height: ryBase * 2.9))

        // Three stacked tiers.
        for tier in 0..<3 {
            let inset = CGFloat(tier) * w * 0.017
            let y = baseY + CGFloat(tier) * h * 0.022
            let rx = rxBase - inset
            let ry = ryBase - CGFloat(tier) * h * 0.006
            let rect = CGRect(x: cx - rx, y: y - ry, width: rx * 2, height: ry * 2)

            // Side wall.
            let side = CGMutablePath()
            side.move(to: CGPoint(x: cx - rx, y: y))
            side.addLine(to: CGPoint(x: cx + rx, y: y))
            side.addLine(to: CGPoint(x: cx + rx, y: y - h * 0.020))
            side.addLine(to: CGPoint(x: cx - rx, y: y - h * 0.020))
            side.closeSubpath()
            ctx.addPath(side)
            ctx.setFillColor(a(P.black, 0.85))
            ctx.fillPath()

            ctx.addEllipse(in: rect)
            ctx.setFillColor(a(P.steel, 0.85))
            ctx.fillPath()
            if tier == 2 {
                ctx.saveGState()
                ctx.addEllipse(in: rect)
                ctx.clip()
                let top = [a(P.deep, 0.55), a(P.navy, 0.30), a(P.black, 0.85)] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: top,
                                      locations: [0.0, 0.60, 1.0]) {
                    ctx.drawRadialGradient(g, startCenter: CGPoint(x: cx, y: y),
                                           startRadius: 0, endCenter: CGPoint(x: cx, y: y),
                                           endRadius: rx, options: [])
                }
                ctx.restoreGState()
            }

            ctx.addEllipse(in: rect)
            ctx.setStrokeColor(a(P.edge, 0.34))
            ctx.setLineWidth(max(1, s * 0.0012))
            ctx.strokePath()
            if tier == 2 {
                ctx.addEllipse(in: rect.insetBy(dx: s * 0.002, dy: s * 0.002))
                ctx.setStrokeColor(a(P.cyan, 0.22))
                ctx.setLineWidth(max(1, s * 0.0016))
                ctx.strokePath()
            }

            // Concentric inlays.
            for ring in 1...4 {
                let f = CGFloat(ring) / 5.0
                let rrect = CGRect(x: cx - rx * f, y: y - ry * f,
                                   width: rx * 2 * f, height: ry * 2 * f)
                ctx.addEllipse(in: rrect)
                ctx.setStrokeColor(a(ring == 2 ? P.violet : P.cyan, ring == 1 ? 0.16 : 0.09))
                ctx.setLineWidth(max(1, s * 0.0007))
                ctx.strokePath()
            }

            // Radial spokes.
            for i in 0..<24 {
                let ang = Double(i) / 24.0 * Double.pi * 2
                ctx.setStrokeColor(a(P.cyan, 0.055))
                ctx.setLineWidth(max(1, s * 0.0005))
                ctx.move(to: CGPoint(x: cx + CGFloat(cos(ang)) * rx * 0.34,
                                     y: y + CGFloat(sin(ang)) * ry * 0.34))
                ctx.addLine(to: CGPoint(x: cx + CGFloat(cos(ang)) * rx * 0.96,
                                        y: y + CGFloat(sin(ang)) * ry * 0.96))
                ctx.strokePath()
            }
        }

        // Platform side ribs and a lit front rim.
        ctx.saveGState()
        let rimRect = CGRect(x: cx - rxBase, y: baseY + h * 0.044 - ryBase,
                             width: rxBase * 2, height: ryBase * 2)
        ctx.addEllipse(in: rimRect)
        ctx.setStrokeColor(a(P.cyan, 0.28))
        ctx.setLineWidth(max(1, s * 0.0018))
        ctx.strokePath()

        for i in 0..<28 {
            let ang = Double(i) / 28.0 * Double.pi * 2
            let px = cx + CGFloat(cos(ang)) * rxBase * 0.995
            let py = baseY + h * 0.044 + CGFloat(sin(ang)) * ryBase * 0.995
            ctx.setStrokeColor(a(P.edge, 0.13))
            ctx.setLineWidth(max(1, s * 0.0007))
            ctx.move(to: CGPoint(x: px, y: py))
            ctx.addLine(to: CGPoint(x: px, y: py - h * 0.022))
            ctx.strokePath()
        }

        // Vent ribs along the front face of the plinth.
        for i in 0..<72 {
            let ang = Double(i) / 72.0 * Double.pi * 2.0
            guard sin(ang) < -0.02 else { continue }
            let px = cx + CGFloat(cos(ang)) * rxBase * 0.99
            let py = baseY + CGFloat(sin(ang)) * ryBase * 0.99
            let accent = i % 9 == 0
            ctx.setStrokeColor(a(accent ? P.amber : P.edge, accent ? 0.20 : 0.09))
            ctx.setLineWidth(max(1, s * (accent ? 0.0012 : 0.0006)))
            ctx.move(to: CGPoint(x: px, y: py))
            ctx.addLine(to: CGPoint(x: px, y: py - h * 0.018))
            ctx.strokePath()
        }

        // Amber hazard ticks around the leading edge of the plinth.
        let rimCy = baseY + h * 0.044
        for i in 0..<30 {
            let ang = Double.pi * (1.02 + 0.96 * Double(i) / 29.0)
            let px = cx + CGFloat(cos(ang)) * rxBase * 0.982
            let py = rimCy + CGFloat(sin(ang)) * ryBase * 0.982
            let hot = i % 5 == 0
            ctx.setStrokeColor(a(hot ? P.amber : P.edge, hot ? 0.42 : 0.10))
            ctx.setLineWidth(max(1, s * (hot ? 0.0016 : 0.0007)))
            ctx.move(to: CGPoint(x: px, y: py))
            ctx.addLine(to: CGPoint(x: px + CGFloat(cos(ang)) * s * (hot ? 0.009 : 0.005),
                                    y: py + CGFloat(sin(ang)) * s * (hot ? 0.009 : 0.005)))
            ctx.strokePath()
        }

        // Wet-floor reflection streaks.
        ctx.setBlendMode(.screen)
        for i in -6...6 {
            let x = cx + CGFloat(i) * w * 0.020
            ctx.setStrokeColor(a(P.cyan, 0.018))
            ctx.setLineWidth(max(1, w * 0.0022))
            ctx.move(to: CGPoint(x: x, y: h * 0.13))
            ctx.addLine(to: CGPoint(x: x * 1.008, y: 0))
            ctx.strokePath()
        }
        ctx.restoreGState()

        // Light column rising from the platform to the vault.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        let column = [a(P.cyan, 0.14), a(P.deep, 0.06), a(P.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: column,
                              locations: [0.0, 0.5, 1.0]) {
            ctx.saveGState()
            let rect = CGRect(x: cx - w * 0.055, y: h * 0.16, width: w * 0.11, height: h * 0.34)
            ctx.clip(to: rect)
            ctx.drawLinearGradient(g, start: CGPoint(x: cx, y: h * 0.50),
                                   end: CGPoint(x: cx, y: h * 0.15), options: [])
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    // MARK: - Iris / vault

    private static func drawIris(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                 center: CGPoint, radius R: CGFloat) {
        // Distant containment rings.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        for (r, segs, alpha) in [(1.38, 18, 0.075), (1.55, 30, 0.045)] {
            let rr = R * CGFloat(r)
            let step = Double.pi * 2 / Double(segs)
            for i in 0..<segs {
                let a0 = Double(i) * step + 0.03
                let a1 = a0 + step * 0.62
                ctx.setStrokeColor(a(P.edge, CGFloat(alpha)))
                ctx.setLineWidth(max(1, R * 0.003))
                ctx.addArc(center: center, radius: rr,
                           startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
                ctx.strokePath()
            }
        }
        ctx.restoreGState()

        // Halo.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        let halo = [a(P.violet, 0.24), a(P.deep, 0.34), a(P.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: halo,
                              locations: [0.0, 0.55, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: R * 0.35,
                                   endCenter: center, endRadius: R * 1.65, options: [])
        }
        ctx.restoreGState()

        // Outer machined housing.
        let housing = CGMutablePath()
        housing.addEllipse(in: CGRect(x: center.x - R * 1.10, y: center.y - R * 1.10,
                                      width: R * 2.20, height: R * 2.20))
        housing.addEllipse(in: CGRect(x: center.x - R * 0.985, y: center.y - R * 0.985,
                                      width: R * 1.97, height: R * 1.97))
        ctx.saveGState()
        ctx.addPath(housing)
        ctx.clip(using: .evenOdd)
        let metal = [a(P.steelHi, 0.95), a(P.steel, 0.95), a(P.black, 1.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: metal,
                              locations: [0.0, 0.55, 1.0]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: center.x - R, y: center.y + R),
                                   end: CGPoint(x: center.x + R, y: center.y - R), options: [])
        }
        ctx.restoreGState()

        // Housing bevels.
        for (r, alpha, width) in [(1.095, 0.40, 0.004), (1.00, 0.30, 0.003),
                                  (0.985, 0.20, 0.002)] {
            ctx.addEllipse(in: CGRect(x: center.x - R * CGFloat(r),
                                      y: center.y - R * CGFloat(r),
                                      width: R * 2 * CGFloat(r), height: R * 2 * CGFloat(r)))
            ctx.setStrokeColor(a(P.edge, CGFloat(alpha)))
            ctx.setLineWidth(max(1, R * CGFloat(width)))
            ctx.strokePath()
        }

        // Specular arcs on the housing.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        ctx.setStrokeColor(a(P.ice, 0.34))
        ctx.setLineWidth(max(1, R * 0.006))
        ctx.addArc(center: center, radius: R * 1.072,
                   startAngle: CGFloat(Double.pi * 0.62), endAngle: CGFloat(Double.pi * 1.24),
                   clockwise: false)
        ctx.strokePath()
        ctx.setStrokeColor(a(P.violet, 0.34))
        ctx.setLineWidth(max(1, R * 0.004))
        ctx.addArc(center: center, radius: R * 1.040,
                   startAngle: CGFloat(Double.pi * 1.30), endAngle: CGFloat(Double.pi * 1.90),
                   clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()

        // Housing bolts.
        for i in 0..<32 {
            let ang = Double(i) / 32.0 * Double.pi * 2
            let r = R * 1.045
            let p = CGPoint(x: center.x + CGFloat(cos(ang)) * r,
                            y: center.y + CGFloat(sin(ang)) * r)
            let br = R * 0.012
            ctx.setFillColor(a(P.black, 0.8))
            ctx.fillEllipse(in: CGRect(x: p.x - br, y: p.y - br, width: br * 2, height: br * 2))
            ctx.setFillColor(a(P.steelHi, 0.55))
            ctx.fillEllipse(in: CGRect(x: p.x - br * 0.55, y: p.y - br * 0.55,
                                       width: br * 1.1, height: br * 1.1))
        }

        // Iris blades.
        let blades = 10
        let innerR = R * 0.335
        let outerR = R * 0.945
        let step = Double.pi * 2 / Double(blades)
        let gap = 0.050
        let skew = 0.165

        for i in 0..<blades {
            let a0 = Double(i) * step + gap * 0.5
            let a1 = Double(i + 1) * step - gap * 0.5

            let blade = CGMutablePath()
            blade.addArc(center: center, radius: outerR,
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
            let even = i % 2 == 0
            // Cross-blade bevel: bright leading edge, dark trailing edge.
            let colors = [P.edge, P.steelHi, P.steel, P.black] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0.0, 0.18, 0.55, 1.0]) {
                ctx.drawLinearGradient(
                    g,
                    start: CGPoint(x: center.x + CGFloat(cos(a0)) * outerR,
                                   y: center.y + CGFloat(sin(a0)) * outerR),
                    end: CGPoint(x: center.x + CGFloat(cos(a1)) * outerR,
                                 y: center.y + CGFloat(sin(a1)) * outerR),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            // Radial darkening toward the hub.
            let radial = [a(P.black, 0.0), a(P.black, 0.55)] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: radial,
                                  locations: [0.0, 1.0]) {
                ctx.drawRadialGradient(g, startCenter: center, startRadius: innerR * 0.98,
                                       endCenter: center, endRadius: outerR, options: [])
            }

            // Machined bevel lines across the plate.
            for k in 1...2 {
                let ang = a0 + (a1 - a0) * Double(k) / 3.0
                ctx.setStrokeColor(a(P.edge, even ? 0.10 : 0.06))
                ctx.setLineWidth(max(1, R * 0.0016))
                ctx.move(to: CGPoint(x: center.x + CGFloat(cos(ang - skew * 0.5)) * innerR,
                                     y: center.y + CGFloat(sin(ang - skew * 0.5)) * innerR))
                ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(ang)) * outerR,
                                        y: center.y + CGFloat(sin(ang)) * outerR))
                ctx.strokePath()
            }
            ctx.restoreGState()

            ctx.addPath(blade)
            ctx.setStrokeColor(a(P.edge, even ? 0.52 : 0.28))
            ctx.setLineWidth(max(1, R * 0.0042))
            ctx.strokePath()

            // Outer bevel highlight.
            ctx.setStrokeColor(a(P.ice, even ? 0.20 : 0.10))
            ctx.setLineWidth(max(1, R * 0.0028))
            ctx.addArc(center: center, radius: outerR,
                       startAngle: CGFloat(a0), endAngle: CGFloat(a1), clockwise: false)
            ctx.strokePath()

            // Leading edge glow.
            ctx.setStrokeColor(a(P.cyan, even ? 0.26 : 0.13))
            ctx.setLineWidth(max(1, R * 0.0026))
            ctx.move(to: CGPoint(x: center.x + CGFloat(cos(a1)) * outerR,
                                 y: center.y + CGFloat(sin(a1)) * outerR))
            ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(a1 - skew)) * innerR,
                                    y: center.y + CGFloat(sin(a1 - skew)) * innerR))
            ctx.strokePath()
        }

        // Glowing gaps between blades.
        ctx.saveGState()
        ctx.setBlendMode(.screen)
        for i in 0..<blades {
            let ang = Double(i) * step
            ctx.setStrokeColor(a(P.cyan, 0.10))
            ctx.setLineWidth(max(1, R * 0.012))
            ctx.move(to: CGPoint(x: center.x + CGFloat(cos(ang)) * innerR,
                                 y: center.y + CGFloat(sin(ang)) * innerR))
            ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(ang)) * outerR,
                                    y: center.y + CGFloat(sin(ang)) * outerR))
            ctx.strokePath()
        }
        ctx.restoreGState()

        // Radial locking bars, turning the iris into a vault door.
        for i in 0..<4 {
            let ang = Double(i) * Double.pi * 0.5 + Double.pi * 0.25
            let ca = CGFloat(cos(ang)), sa = CGFloat(sin(ang))
            let px = -sa, py = ca
            let r0 = R * 0.375
            let r1 = R * 0.935
            let w0 = R * 0.030
            let w1 = R * 0.040
            func point(_ r: CGFloat, _ w: CGFloat, _ sign: CGFloat) -> CGPoint {
                CGPoint(x: center.x + ca * r + px * w * sign,
                        y: center.y + sa * r + py * w * sign)
            }
            let bar = CGMutablePath()
            bar.move(to: point(r0, w0, 1))
            bar.addLine(to: point(r1, w1, 1))
            bar.addLine(to: point(r1, w1, -1))
            bar.addLine(to: point(r0, w0, -1))
            bar.closeSubpath()

            ctx.saveGState()
            ctx.addPath(bar)
            ctx.clip()
            let colors = [a(P.steelHi, 0.95), a(P.steel, 0.95), a(P.black, 1.0)] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0.0, 0.45, 1.0]) {
                ctx.drawLinearGradient(g, start: point(r0, w0, 1), end: point(r1, w1, -1),
                                       options: [])
            }
            ctx.restoreGState()
            ctx.addPath(bar)
            ctx.setStrokeColor(a(P.edge, 0.45))
            ctx.setLineWidth(max(1, R * 0.0035))
            ctx.strokePath()

            // Energy seam down the bar.
            ctx.setStrokeColor(a(P.cyan, 0.22))
            ctx.setLineWidth(max(1, R * 0.0030))
            ctx.move(to: point(r0 + R * 0.05, 0, 0))
            ctx.addLine(to: point(r1 - R * 0.03, 0, 0))
            ctx.strokePath()

            // Bolts.
            for k in 0..<4 {
                let t = (CGFloat(k) + 0.5) / 4.0
                let r = r0 + (r1 - r0) * t
                let p = point(r, 0, 0)
                let br = R * 0.008
                ctx.setFillColor(a(P.ice, 0.30))
                ctx.fillEllipse(in: CGRect(x: p.x - br, y: p.y - br, width: br * 2, height: br * 2))
            }
        }

        // Machined cross-rings over the blades.
        for (rf, width, boltCount) in [(0.575, 0.022, 20), (0.800, 0.017, 24)] {
            let rr = R * CGFloat(rf)
            let ring = CGMutablePath()
            ring.addEllipse(in: CGRect(x: center.x - rr, y: center.y - rr,
                                       width: rr * 2, height: rr * 2))
            ring.addEllipse(in: CGRect(x: center.x - rr * (1.0 - CGFloat(width)),
                                       y: center.y - rr * (1.0 - CGFloat(width)),
                                       width: rr * 2 * (1.0 - CGFloat(width)),
                                       height: rr * 2 * (1.0 - CGFloat(width))))
            ctx.addPath(ring)
            ctx.setFillColor(a(P.steel, 0.92))
            ctx.fillPath(using: .evenOdd)
            ctx.addPath(ring)
            ctx.setStrokeColor(a(P.edge, 0.34))
            ctx.setLineWidth(max(1, R * 0.0025))
            ctx.strokePath()
            ctx.addPath(ring)
            ctx.setStrokeColor(a(P.violet, 0.25))
            ctx.setLineWidth(max(1, R * 0.0010))
            ctx.strokePath()

            for k in 0..<boltCount {
                let ang = Double(k) / Double(boltCount) * Double.pi * 2
                let p = CGPoint(x: center.x + CGFloat(cos(ang)) * rr,
                                y: center.y + CGFloat(sin(ang)) * rr)
                let br = R * 0.007
                ctx.setFillColor(a(P.black, 0.8))
                ctx.fillEllipse(in: CGRect(x: p.x - br, y: p.y - br, width: br * 2, height: br * 2))
                ctx.setFillColor(a(P.steelHi, 0.55))
                ctx.fillEllipse(in: CGRect(x: p.x - br * 0.55, y: p.y - br * 0.55,
                                           width: br * 1.1, height: br * 1.1))
            }
        }

        // Inner collar.
        let collar = CGMutablePath()
        collar.addEllipse(in: CGRect(x: center.x - innerR * 1.07, y: center.y - innerR * 1.07,
                                     width: innerR * 2.14, height: innerR * 2.14))
        collar.addEllipse(in: CGRect(x: center.x - innerR * 0.99, y: center.y - innerR * 0.99,
                                     width: innerR * 1.98, height: innerR * 1.98))
        ctx.addPath(collar)
        ctx.setFillColor(a(P.steel, 0.95))
        ctx.fillPath(using: .evenOdd)
        ctx.addPath(collar)
        ctx.setStrokeColor(a(P.edge, 0.40))
        ctx.setLineWidth(max(1, R * 0.0025))
        ctx.strokePath()

        for i in 0..<18 {
            let ang = Double(i) / 18.0 * Double.pi * 2
            let r = innerR * 1.03
            let p = CGPoint(x: center.x + CGFloat(cos(ang)) * r,
                            y: center.y + CGFloat(sin(ang)) * r)
            let br = R * 0.008
            ctx.setFillColor(a(P.steelHi, 0.6))
            ctx.fillEllipse(in: CGRect(x: p.x - br, y: p.y - br, width: br * 2, height: br * 2))
        }

        // Aperture.
        let ap = [P.black, a(P.deep, 0.85), P.black] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: ap,
                              locations: [0.0, 0.7, 1.0]) {
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: center.x - innerR, y: center.y - innerR,
                                      width: innerR * 2, height: innerR * 2))
            ctx.clip()
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: innerR, options: [])
            ctx.restoreGState()
        }

        // Recessed hub fins around the socket.
        ctx.saveGState()
        for i in 0..<10 {
            let ang = Double(i) / 10.0 * Double.pi * 2
            ctx.setStrokeColor(a(P.steelHi, 0.55))
            ctx.setLineWidth(max(1, R * 0.010))
            ctx.move(to: CGPoint(x: center.x + CGFloat(cos(ang)) * innerR * 0.42,
                                 y: center.y + CGFloat(sin(ang)) * innerR * 0.42))
            ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(ang)) * innerR * 0.90,
                                    y: center.y + CGFloat(sin(ang)) * innerR * 0.90))
            ctx.strokePath()
            ctx.setStrokeColor(a(P.cyan, 0.16))
            ctx.setLineWidth(max(1, R * 0.0022))
            ctx.move(to: CGPoint(x: center.x + CGFloat(cos(ang + 0.045)) * innerR * 0.50,
                                 y: center.y + CGFloat(sin(ang + 0.045)) * innerR * 0.50))
            ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(ang + 0.045)) * innerR * 0.88,
                                    y: center.y + CGFloat(sin(ang + 0.045)) * innerR * 0.88))
            ctx.strokePath()
        }
        ctx.restoreGState()

        // Aperture rim.
        ctx.addEllipse(in: CGRect(x: center.x - innerR * 0.97, y: center.y - innerR * 0.97,
                                  width: innerR * 1.94, height: innerR * 1.94))
        ctx.setStrokeColor(a(P.cyan, 0.35))
        ctx.setLineWidth(max(1, R * 0.004))
        ctx.strokePath()

        // Four heavy clamps.
        for i in 0..<4 {
            let ang = Double(i) * Double.pi * 0.5 + Double.pi * 0.25
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: CGFloat(ang))
            let clamp = CGRect(x: R * 0.94, y: -R * 0.035, width: R * 0.20, height: R * 0.07)
            let cp = CGPath(roundedRect: clamp, cornerWidth: R * 0.012,
                            cornerHeight: R * 0.012, transform: nil)
            ctx.addPath(cp)
            ctx.setFillColor(a(P.steel, 0.98))
            ctx.fillPath()

            // Hazard stripes across the clamp pad.
            ctx.saveGState()
            ctx.addPath(cp)
            ctx.clip()
            var stripeX = R * 0.935
            var stripeIndex = 0
            while stripeX < R * 1.15 {
                if stripeIndex % 2 == 0 {
                    let stripe = CGMutablePath()
                    stripe.move(to: CGPoint(x: stripeX, y: -R * 0.05))
                    stripe.addLine(to: CGPoint(x: stripeX + R * 0.009, y: -R * 0.05))
                    stripe.addLine(to: CGPoint(x: stripeX + R * 0.030, y: R * 0.05))
                    stripe.addLine(to: CGPoint(x: stripeX + R * 0.021, y: R * 0.05))
                    stripe.closeSubpath()
                    ctx.addPath(stripe)
                    ctx.setFillColor(a(P.amber, 0.30))
                    ctx.fillPath()
                }
                stripeX += R * 0.018
                stripeIndex += 1
            }
            ctx.restoreGState()

            ctx.addPath(cp)
            ctx.setStrokeColor(a(P.edge, 0.55))
            ctx.setLineWidth(max(1, R * 0.0025))
            ctx.strokePath()
            ctx.setFillColor(a(P.cyan, 0.55))
            let dot = R * 0.010
            ctx.fillEllipse(in: CGRect(x: R * 1.04 - dot, y: -dot,
                                       width: dot * 2, height: dot * 2))
            ctx.restoreGState()
        }

        // Outer tick ring.
        for i in 0..<72 {
            let ang = Double(i) / 72.0 * Double.pi * 2
            let major = i % 6 == 0
            let r0 = R * 1.12
            let r1 = R * (major ? 1.17 : 1.145)
            ctx.setStrokeColor(a(major ? P.cyan : P.edge, major ? 0.45 : 0.16))
            ctx.setLineWidth(max(1, R * (major ? 0.0035 : 0.0018)))
            ctx.move(to: CGPoint(x: center.x + CGFloat(cos(ang)) * r0,
                                 y: center.y + CGFloat(sin(ang)) * r0))
            ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(ang)) * r1,
                                    y: center.y + CGFloat(sin(ang)) * r1))
            ctx.strokePath()
        }
    }

    // MARK: - Vault etching

    private static func drawVaultEtching(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                         center: CGPoint, radius R: CGFloat) {
        ctx.saveGState()
        ctx.setBlendMode(.screen)

        // Fine machined arc between the tick ring and the housing.
        ctx.setStrokeColor(a(P.edge, 0.22))
        ctx.setLineWidth(max(1, R * 0.0016))
        ctx.addArc(center: center, radius: R * 1.185,
                   startAngle: CGFloat(Double.pi * 0.10),
                   endAngle: CGFloat(Double.pi * 0.90), clockwise: false)
        ctx.strokePath()
        ctx.addArc(center: center, radius: R * 1.185,
                   startAngle: CGFloat(Double.pi * 1.10),
                   endAngle: CGFloat(Double.pi * 1.90), clockwise: false)
        ctx.strokePath()

        // Engraved sector legends, spaced between the locking clamps.
        let labels: [(Double, String)] = [
            (0.42, "VAULT-07"),
            (1.99, "AES-256"),
            (3.56, "SEC-04"),
            (5.13, "NODE-11")
        ]
        for (angle, text) in labels {
            drawRingText(ctx, text, center: center, angle: angle, radius: R * 1.205,
                         size: R * 0.038, color: a(P.cyan, 0.30), kern: R * 0.010)
        }

        // Hairline seams radiating across the housing band.
        for i in 0..<48 {
            let angle = Double(i) / 48.0 * Double.pi * 2.0
            ctx.setStrokeColor(a(P.edge, i % 4 == 0 ? 0.10 : 0.04))
            ctx.setLineWidth(max(1, R * 0.0009))
            ctx.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * R * 1.098,
                                 y: center.y + CGFloat(sin(angle)) * R * 1.098))
            ctx.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * R * 1.135,
                                    y: center.y + CGFloat(sin(angle)) * R * 1.135))
            ctx.strokePath()
        }

        ctx.restoreGState()
        _ = w
        _ = h
        _ = s
    }

    // MARK: - Atmosphere / vignette

    private static func drawAtmosphere(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                       center: CGPoint, horizon: CGFloat) {
        ctx.saveGState()
        ctx.setBlendMode(.screen)

        // Fog banks on the horizon.
        for (fx, fy, fr, alpha) in [(0.28, 0.585, 0.34, 0.07),
                                    (0.72, 0.585, 0.34, 0.07),
                                    (0.50, 0.560, 0.50, 0.05)] {
            let colors = [a(P.cyan, CGFloat(alpha)), a(P.deep, 0.0)] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0.0, 1.0]) {
                ctx.drawRadialGradient(g,
                                       startCenter: CGPoint(x: w * fx, y: h * fy),
                                       startRadius: 0,
                                       endCenter: CGPoint(x: w * fx, y: h * fy),
                                       endRadius: s * CGFloat(fr) * 0.55,
                                       options: [])
            }
        }

        // Core bloom.
        let bloom = [a(P.cyan, 0.10), a(P.violet, 0.06), a(P.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bloom,
                              locations: [0.0, 0.35, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: s * 0.34, options: [])
        }
        ctx.restoreGState()
    }

    private static func drawVignette(_ ctx: CGContext, w: CGFloat, h: CGFloat, s: CGFloat,
                                     center: CGPoint) {
        ctx.saveGState()
        let colors = [a(P.black, 0.0), a(P.black, 0.10), a(P.black, 0.55)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                              locations: [0.45, 0.75, 1.0]) {
            ctx.drawRadialGradient(g, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: max(w, h) * 0.78,
                                   options: [])
        }
        // Corner darkening.
        let corners = [a(P.black, 0.35), a(P.black, 0.0)] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: corners,
                              locations: [0.0, 1.0]) {
            for c in [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0),
                      CGPoint(x: 0, y: h), CGPoint(x: w, y: h)] {
                ctx.drawRadialGradient(g, startCenter: c, startRadius: 0,
                                       endCenter: c, endRadius: s * 0.42, options: [])
            }
        }
        _ = h
        ctx.restoreGState()
    }
}
