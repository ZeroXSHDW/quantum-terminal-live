import AppKit
import QuartzCore
import Foundation
import ImageIO

final class QuantumCanvas: NSView {
    private let wallpaper: NSImage
    private let startedAt = CACurrentMediaTime()
    private var timer: Timer?
    private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var isSuspended = false

    init(imageURL: URL, maxPixelSize: Int) {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        let downsampledImage: NSImage? = {
            guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, sourceOptions as CFDictionary),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
                return nil
            }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }()
        guard let image = downsampledImage else {
            fatalError("Unable to load wallpaper at \(imageURL.path)")
        }
        wallpaper = image
        super.init(frame: .zero)
        wantsLayer = true
        startAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func startAnimation() {
        guard timer == nil, !isSuspended else { return }
        // The M5 Pro can comfortably keep the live layer smooth at 30 fps;
        // Low Power Mode automatically drops to 15 fps to preserve battery.
        let framesPerSecond = lowPowerMode ? 15.0 : 30.0
        let animationTimer = Timer(timeInterval: 1.0 / framesPerSecond, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        timer = animationTimer
        RunLoop.main.add(animationTimer, forMode: .common)
    }

    func pauseAnimation() {
        isSuspended = true
        timer?.invalidate()
        timer = nil
    }

    func resumeAnimation() {
        isSuspended = false
        startAnimation()
        needsDisplay = true
    }

    func setLowPowerMode(_ enabled: Bool) {
        guard lowPowerMode != enabled else { return }
        lowPowerMode = enabled
        guard !isSuspended else { return }
        timer?.invalidate()
        timer = nil
        startAnimation()
    }

    deinit {
        timer?.invalidate()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let bounds = self.bounds
        let elapsed = CACurrentMediaTime() - startedAt
        context.interpolationQuality = .high

        NSColor(calibratedRed: 0.005, green: 0.008, blue: 0.025, alpha: 1).setFill()
        bounds.fill()

        let imageSize = wallpaper.size
        // A nearly imperceptible camera drift gives the desktop a premium live
        // feel while keeping the secure core anchored for icon legibility.
        let scaleBreath = 1.004 + 0.004 * CGFloat(sin(elapsed * 0.17))
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height) * scaleBreath
        let drawnSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drift = min(bounds.width, bounds.height)
        let driftX = CGFloat(sin(elapsed * 0.11)) * drift * 0.0015
        let driftY = CGFloat(cos(elapsed * 0.13)) * drift * 0.0010
        let imageRect = NSRect(
            x: bounds.midX - drawnSize.width / 2 + driftX,
            y: bounds.midY - drawnSize.height / 2 + driftY,
            width: drawnSize.width,
            height: drawnSize.height
        )
        wallpaper.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)

        context.saveGState()
        context.setBlendMode(.screen)

        // A soft blue-violet bloom breathes behind the central secure core.
        let center = CGPoint(x: bounds.midX, y: bounds.height * 0.53)
        let pulse = CGFloat((sin(elapsed * 0.72) + 1) * 0.5)
        let glowRadius = min(bounds.width, bounds.height) * (0.19 + pulse * 0.012)
        let glowColors = [
            NSColor(calibratedRed: 0.18, green: 0.22, blue: 1.0, alpha: 0.12).cgColor,
            NSColor(calibratedRed: 0.16, green: 0.08, blue: 0.80, alpha: 0.035).cgColor,
            NSColor.clear.cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0.0, 0.42, 1.0]) {
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: glowRadius, options: [])
        }

        // A slow, restrained scan sweep keeps the wallpaper alive without
        // competing with desktop icons or turning into Matrix-style rain.
        let sweep = CGFloat((sin(elapsed * 0.42) + 1) * 0.5) * bounds.height
        for (width, alpha) in [(24.0, 0.015), (10.0, 0.035), (3.0, 0.13)] {
            context.setStrokeColor(NSColor(calibratedRed: 0.12, green: 0.38, blue: 1, alpha: alpha).cgColor)
            context.setLineWidth(width)
            context.move(to: CGPoint(x: bounds.minX, y: sweep))
            context.addLine(to: CGPoint(x: bounds.maxX, y: sweep))
            context.strokePath()
        }

        // Pulsing secure-core rings add a gentle breathing motion to the base art.
        for index in 0..<4 {
            let radius = min(bounds.width, bounds.height) * (0.09 + CGFloat(index) * 0.035) + pulse * 16
            context.setStrokeColor(NSColor(calibratedRed: 0.22, green: 0.24, blue: 1, alpha: 0.06 + 0.025 * Double(3 - index)).cgColor)
            context.setLineWidth(index == 0 ? 3 : 1)
            context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }

        // A faint energy wave travels outward from the core once per cycle.
        // It is intentionally quieter than the fixed rings and stays inside
        // the central geometry so it does not compete with desktop content.
        let wavePhase = CGFloat((elapsed * 0.12).truncatingRemainder(dividingBy: 1.0))
        let waveRadius = min(bounds.width, bounds.height) * (0.085 + wavePhase * 0.105)
        let waveAlpha = 0.075 * (1.0 - wavePhase) * (1.0 - wavePhase)
        context.setStrokeColor(NSColor(calibratedRed: 0.30, green: 0.40, blue: 1, alpha: waveAlpha).cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: center.x - waveRadius, y: center.y - waveRadius, width: waveRadius * 2, height: waveRadius * 2))

        // Rotating arc segments imply active telemetry without introducing
        // dense text or Matrix-style falling characters.
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        for index in 0..<3 {
            let radius = min(bounds.width, bounds.height) * (0.135 + CGFloat(index) * 0.028)
            let rotation = CGFloat(elapsed * (0.045 + Double(index) * 0.018)) * (index.isMultiple(of: 2) ? 1 : -1)
            context.rotate(by: rotation)
            context.setStrokeColor(NSColor(calibratedRed: 0.25, green: 0.45, blue: 1, alpha: 0.10 - Double(index) * 0.018).cgColor)
            context.setLineWidth(index == 0 ? 2.5 : 1.2)
            context.addArc(center: .zero, radius: radius, startAngle: CGFloat(index) * 1.9, endAngle: CGFloat(index) * 1.9 + 0.82 + pulse * 0.16, clockwise: false)
            context.strokePath()
        }
        context.restoreGState()

        // Coherent signal packets ride the existing horizontal telemetry
        // rails. Their motion is sparse and deliberate so the wallpaper
        // feels active without becoming a distracting data-wall effect.
        for lane in 0..<4 {
            let laneSeed = Double(lane) * 1.37
            let laneY = center.y + (CGFloat(lane) - 1.5) * min(bounds.width, bounds.height) * 0.021
            let phase = CGFloat((sin(elapsed * (0.16 + Double(lane) * 0.025) + laneSeed) + 1) * 0.5)
            let x = bounds.minX + bounds.width * (0.12 + phase * 0.76)
            let trail = bounds.width * (0.018 + CGFloat(lane % 2) * 0.008)
            context.setStrokeColor(NSColor(calibratedRed: 0.16, green: 0.52, blue: 1, alpha: 0.055).cgColor)
            context.setLineWidth(2)
            context.move(to: CGPoint(x: max(bounds.minX, x - trail), y: laneY))
            context.addLine(to: CGPoint(x: x, y: laneY))
            context.strokePath()
            context.setFillColor(NSColor(calibratedRed: 0.35, green: 0.78, blue: 1, alpha: 0.24).cgColor)
            context.fillEllipse(in: CGRect(x: x - 3.5, y: laneY - 3.5, width: 7, height: 7))
        }

        // Sparse moving signal nodes create depth while keeping the composition calm.
        for index in 0..<18 {
            let seed = Double(index) * 1.731
            let x = bounds.width * CGFloat((sin(seed * 2.17) + 1) * 0.5)
            let baseY = bounds.height * CGFloat((cos(seed * 1.43) + 1) * 0.5)
            let y = baseY + CGFloat(sin(elapsed * (0.28 + Double(index % 4) * 0.04) + seed)) * 18
            let radius = CGFloat(1.2 + Double(index % 3))
            let alpha = CGFloat(0.12 + 0.07 * ((index % 4) == 0 ? 1 : 0))
            context.setFillColor(NSColor(calibratedRed: 0.25, green: 0.55, blue: 1, alpha: alpha).cgColor)
            context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }

        // Two restrained orbital beacons make the secure core feel like an
        // active system rather than a slowly breathing still image. Their
        // long periods keep movement legible without distracting from icons.
        for index in 0..<2 {
            let radius = min(bounds.width, bounds.height) * (0.19 + CGFloat(index) * 0.035)
            let angularSpeed = 0.20 + Double(index) * 0.055
            let direction = index == 0 ? 1.0 : -1.0
            let angle = elapsed * angularSpeed * direction + Double(index) * 2.4
            let beacon = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius * 0.46
            )
            let tangent = CGPoint(
                x: -sin(angle) * CGFloat(direction),
                y: cos(angle) * CGFloat(direction) * 0.46
            )
            context.setStrokeColor(NSColor(calibratedRed: 0.30, green: 0.58, blue: 1, alpha: 0.12).cgColor)
            context.setLineWidth(2)
            context.move(to: CGPoint(x: beacon.x - tangent.x * 22, y: beacon.y - tangent.y * 22))
            context.addLine(to: CGPoint(x: beacon.x + tangent.x * 6, y: beacon.y + tangent.y * 6))
            context.strokePath()
            context.setFillColor(NSColor(calibratedRed: 0.54, green: 0.70, blue: 1, alpha: 0.34).cgColor)
            context.fillEllipse(in: CGRect(x: beacon.x - 4, y: beacon.y - 4, width: 8, height: 8))
        }

        context.restoreGState()

        // A barely-there edge vignette keeps the desktop calm around icons
        // while preserving the brighter blue-violet focal geometry.
        context.saveGState()
        context.setBlendMode(.normal)
        let vignetteColors = [
            NSColor.clear.cgColor,
            NSColor(calibratedWhite: 0.0, alpha: 0.16).cgColor
        ] as CFArray
        if let vignette = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: vignetteColors, locations: [0.54, 1.0]) {
            context.drawRadialGradient(
                vignette,
                startCenter: CGPoint(x: bounds.midX, y: bounds.height * 0.52),
                startRadius: 0,
                endCenter: CGPoint(x: bounds.midX, y: bounds.height * 0.52),
                endRadius: max(bounds.width, bounds.height) * 0.72,
                options: []
            )
        }
        context.restoreGState()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var powerObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let imagePath = Bundle.main.path(forResource: "quantum-terminal-live-wallpaper-8k", ofType: "png") else {
            fatalError("Bundled wallpaper is missing")
        }
        let imageURL = URL(fileURLWithPath: imagePath)

        installWindows(imageURL: imageURL)

        // Rebuild the live layer when a display is connected, disconnected,
        // or changes mode so every screen gets the correct Retina scaling.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.installWindows(imageURL: imageURL)
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let pauseNames: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ]
        for name in pauseNames {
            workspaceObservers.append(workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.setAnimationPaused(true)
            })
        }
        let resumeNames: [Notification.Name] = [
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]
        for name in resumeNames {
            workspaceObservers.append(workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.setAnimationPaused(false)
            })
        }
        powerObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSProcessInfoPowerStateDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setLowPowerMode(ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
    }

    private func installWindows(imageURL: URL) {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll(keepingCapacity: true)

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = NSWindow.Level(rawValue: -100)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.hasShadow = false
            let workingPixelSize = Int(ceil(max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor * 1.12))
            window.contentView = QuantumCanvas(imageURL: imageURL, maxPixelSize: workingPixelSize)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func setAnimationPaused(_ paused: Bool) {
        for window in windows {
            guard let canvas = window.contentView as? QuantumCanvas else { continue }
            if paused {
                canvas.pauseAnimation()
            } else {
                canvas.resumeAnimation()
            }
        }
    }

    private func setLowPowerMode(_ enabled: Bool) {
        for window in windows {
            (window.contentView as? QuantumCanvas)?.setLowPowerMode(enabled)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers {
            workspaceCenter.removeObserver(observer)
        }
        if let powerObserver {
            NotificationCenter.default.removeObserver(powerObserver)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
