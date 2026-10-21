import AppKit
import ScreenSaver
import QuartzCore

@objc(QuantumTerminalScreenSaverView)
final class QuantumTerminalScreenSaverView: ScreenSaverView {
    private var wallpaper: NSImage?
    private let startedAt = CACurrentMediaTime()

    override init?(frame frameRect: NSRect, isPreview: Bool) {
        super.init(frame: frameRect, isPreview: isPreview)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        animationTimeInterval = 1.0 / 30.0
        if let path = Bundle(for: QuantumTerminalScreenSaverView.self).path(forResource: "quantum-terminal-live-wallpaper-8k", ofType: "png") {
            wallpaper = NSImage(contentsOfFile: path)
        }
    }

    override func animateOneFrame() {
        needsDisplay = true
    }

    override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds
        let elapsed = CACurrentMediaTime() - startedAt

        NSColor(calibratedRed: 0.003, green: 0.005, blue: 0.018, alpha: 1).setFill()
        bounds.fill()

        if let wallpaper {
            let imageSize = wallpaper.size
            let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
            let drawnSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let imageRect = NSRect(
                x: bounds.midX - drawnSize.width / 2,
                y: bounds.midY - drawnSize.height / 2,
                width: drawnSize.width,
                height: drawnSize.height
            )
            wallpaper.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        context.saveGState()
        context.setBlendMode(.screen)

        let center = CGPoint(x: bounds.midX, y: bounds.height * 0.53)
        let breathe = CGFloat((sin(elapsed * 0.8) + 1) * 0.5)

        // Slow scan sweep: a screensaver-appropriate version of the desktop motion.
        let sweep = CGFloat((elapsed.truncatingRemainder(dividingBy: 14.0)) / 14.0) * bounds.height
        for (width, alpha) in [(36.0, 0.012), (12.0, 0.03), (2.0, 0.16)] {
            context.setStrokeColor(NSColor(calibratedRed: 0.15, green: 0.38, blue: 1, alpha: alpha).cgColor)
            context.setLineWidth(width)
            context.move(to: CGPoint(x: bounds.minX, y: sweep))
            context.addLine(to: CGPoint(x: bounds.maxX, y: sweep))
            context.strokePath()
        }

        // Expanding rings give the secure core a calm, continuous heartbeat.
        for index in 0..<7 {
            let radius = min(bounds.width, bounds.height) * (0.055 + CGFloat(index) * 0.032) + breathe * 20
            let alpha = 0.04 + 0.02 * Double(6 - index)
            context.setStrokeColor(NSColor(calibratedRed: 0.25, green: 0.28, blue: 1, alpha: alpha).cgColor)
            context.setLineWidth(index == 0 ? 4 : 1)
            context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }

        // Moving signal beams and sparse nodes add depth without text or falling code.
        for index in 0..<12 {
            let seed = Double(index) * 1.47
            let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
            let travel = (elapsed * (0.04 + Double(index % 3) * 0.012) * direction + seed).truncatingRemainder(dividingBy: 1.0)
            let x = bounds.width * CGFloat((travel + 1).truncatingRemainder(dividingBy: 1.0))
            let y = bounds.height * CGFloat((sin(seed * 2.3) + 1) * 0.5)
            let length = bounds.width * CGFloat(0.025 + Double(index % 4) * 0.012)
            context.setStrokeColor(NSColor(calibratedRed: 0.23, green: 0.52, blue: 1, alpha: 0.12).cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + length * direction, y: y))
            context.strokePath()
            context.setFillColor(NSColor(calibratedRed: 0.36, green: 0.58, blue: 1, alpha: 0.2).cgColor)
            context.fillEllipse(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
        }

        context.restoreGState()
    }
}
