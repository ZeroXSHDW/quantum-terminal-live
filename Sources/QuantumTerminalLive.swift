import AppKit
import QuartzCore
import Foundation
import ImageIO
import IOKit.ps
import CoreGraphics

/// Seconds since the last keyboard/mouse/tablet event across the combined
/// session. Used for idle dimming and the activity-reactive rain.
private let anyInputEvent = CGEventType(rawValue: UInt32.max)!
private func idleSeconds() -> Double {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEvent)
}

/// Draws one animated pass. The static master lives in a sibling layer below
/// this one, so the compositor can pan/zoom it without redrawing it. The live
/// desktop uses two of these: a reduced-resolution geometry layer and a full
/// Retina text layer, so the HUD is crisp while the heavy vector work stays
/// cheap.
final class QuantumOverlayLayer: CALayer {
    weak var canvas: QuantumCanvas?
    var phase: QuantumScene.OverlayPhase = .geometry

    override func draw(in ctx: CGContext) {
        guard let canvas else { return }
        canvas.drawOverlay(in: ctx, size: bounds.size, phase: phase)
    }
}

/// One borderless canvas per display. The scene is shared with the 8K screen
/// saver renderer so the desktop and the saver always match.
///
/// The static 8K master is a `contents` image on the lower layer. Only the
/// animated overlay is redrawn at 20 fps, and its backing store is capped at
/// roughly 3.3 megapixels so Retina and 6K displays stay responsive.
final class QuantumCanvas: NSView {
    private let sourceImage: CGImage
    private let baseLayer = CALayer()
    private let geometryLayer = QuantumOverlayLayer()
    private let textLayer = QuantumOverlayLayer()
    private let startedAt = CACurrentMediaTime()
    private var timer: Timer?
    private var suspended = false
    private var frameInterval: TimeInterval = 1.0 / 20.0

    init(imageURL: URL, maxPixelSize: Int) {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, sourceOptions as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            sourceImage = Self.fallbackImage()
            super.init(frame: .zero)
            wantsLayer = true
            layer?.isOpaque = false
            layer?.masksToBounds = true
            layer?.backgroundColor = nil
            setupLayers()
            startAnimation()
            return
        }
        sourceImage = image
        super.init(frame: .zero)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.masksToBounds = true
        layer?.backgroundColor = nil
        setupLayers()
        startAnimation()
    }

    /// A dark-green solid used when the bundled master is missing, so the
    /// wallpaper never hard-crashes on a broken install.
    private static func fallbackImage() -> CGImage {
        let width = 8, height = 8
        let space = CGColorSpaceCreateDeviceRGB()
        let color = CGColor(red: 0.0, green: 0.06, blue: 0.02, alpha: 1.0)
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            // Truly nothing to render: return a 1×1 via a minimal context.
            let tiny = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8,
                                 bytesPerRow: 4, space: space,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            tiny.setFillColor(color)
            tiny.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            return tiny.makeImage()!
        }
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    private func setupLayers() {
        baseLayer.contents = sourceImage
        baseLayer.contentsGravity = .resizeAspectFill
        baseLayer.actions = ["transform": NSNull(), "position": NSNull(),
                             "bounds": NSNull(), "contentsScale": NSNull()]

        geometryLayer.canvas = self
        geometryLayer.phase = .geometry
        textLayer.canvas = self
        textLayer.phase = .text
        for overlay in [geometryLayer, textLayer] {
            overlay.isOpaque = false
            overlay.masksToBounds = true
            overlay.needsDisplayOnBoundsChange = true
            overlay.actions = ["contents": NSNull(), "bounds": NSNull(),
                               "position": NSNull(), "contentsScale": NSNull()]
        }

        layer?.addSublayer(baseLayer)
        layer?.addSublayer(geometryLayer)
        layer?.addSublayer(textLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
        let geometryScale = self.overlayScale(for: bounds.size, backingScale: scale)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseLayer.contentsScale = scale
        baseLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        baseLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        geometryLayer.contentsScale = geometryScale
        geometryLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        geometryLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.contentsScale = scale
        textLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()

        updateBaseTransform(time: CACurrentMediaTime() - startedAt)
        geometryLayer.setNeedsDisplay()
        textLayer.setNeedsDisplay()
    }

    /// Keep the vector geometry near 3.3 megapixels. The static master and the
    /// text layer stay at native backing resolution.
    private func overlayScale(for size: CGSize, backingScale: CGFloat) -> CGFloat {
        let points = max(1.0, size.width * size.height)
        let ideal = sqrt(3_300_000.0 / points)
        return min(backingScale, max(1.0, ideal))
    }

    private func updateBaseTransform(time: Double) {
        let duration = QuantumScene.loopDuration
        let t = ((time.truncatingRemainder(dividingBy: duration)) + duration)
            .truncatingRemainder(dividingBy: duration)
        let s = min(bounds.width, bounds.height)
        let phase = t * QuantumScene.omega
        let breath = 1.002 + 0.003 * CGFloat(cos(phase))
        let driftX = CGFloat(sin(phase)) * s * 0.0013
        let driftY = CGFloat(cos(phase)) * s * 0.0009

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseLayer.transform = CATransform3DMakeScale(breath, breath, 1)
        baseLayer.position = CGPoint(x: bounds.midX + driftX, y: bounds.midY + driftY)
        CATransaction.commit()
    }

    fileprivate func drawOverlay(in ctx: CGContext, size: CGSize,
                                 phase: QuantumScene.OverlayPhase) {
        ctx.clear(CGRect(origin: .zero, size: size))
        let elapsed = CACurrentMediaTime() - startedAt
        switch phase {
        case .geometry:
            QuantumScene.renderOverlayGeometry(ctx, size: size, time: elapsed,
                                               wallClock: Date())
        case .text:
            QuantumScene.renderOverlayText(ctx, size: size, time: elapsed,
                                           wallClock: Date())
        }
    }

    private func startAnimation() {
        guard timer == nil, !suspended else { return }
        let animationTimer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in
            guard let self, !self.suspended else { return }
            let idle = idleSeconds()
            QuantumScene.activity = idle < 3.0 ? CGFloat(1.0 - idle / 3.0) : 0.0
            self.updateBaseTransform(time: CACurrentMediaTime() - self.startedAt)
            self.geometryLayer.setNeedsDisplay()
            self.textLayer.setNeedsDisplay()
        }
        animationTimer.tolerance = 0.001
        timer = animationTimer
        RunLoop.main.add(animationTimer, forMode: .common)
    }

    /// Changes the animation cadence without dropping the current frame.
    func setFrameInterval(_ interval: TimeInterval) {
        guard interval != frameInterval else { return }
        frameInterval = interval
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        startAnimation()
    }

    /// Dims only the neon overlay (geometry + text), leaving the static master
    /// at full brightness. `0` hides the HUD, `1` is full intensity.
    func setOverlayOpacity(_ opacity: CGFloat) {
        geometryLayer.opacity = Float(opacity)
        textLayer.opacity = Float(opacity)
    }

    func pauseAnimation() {
        suspended = true
        timer?.invalidate()
        timer = nil
    }

    func resumeAnimation() {
        suspended = false
        startAnimation()
        geometryLayer.setNeedsDisplay()
        textLayer.setNeedsDisplay()
    }

    func ensureAnimating() {
        guard !suspended else { return }
        if timer == nil { startAnimation() }
        geometryLayer.setNeedsDisplay()
        textLayer.setNeedsDisplay()
    }

    deinit {
        timer?.invalidate()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var imageURL: URL!
    private var screenObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var watchdog: Timer?
    private var activityToken: NSObjectProtocol?
    private var pausedForDisplaySleep = false
    private var userPaused = false
    private var hasBooted = false
    private var dimWhenIdle = UserDefaults.standard.object(forKey: "DimWhenIdle") as? Bool ?? true
    private var overlayIntensity = UserDefaults.standard.object(forKey: "OverlayIntensity") as? Double ?? 1.0
    private var statusItem: NSStatusItem?

    private var effectivelyPaused: Bool { pausedForDisplaySleep || userPaused }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        // App Nap must not throttle a wallpaper that is supposed to stay live.
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep,
                      .suddenTerminationDisabled,
                      .automaticTerminationDisabled],
            reason: "Quantum Terminal live desktop wallpaper"
        )

        if let path = Bundle.main.path(forResource: "quantum-terminal-live-wallpaper-8k",
                                       ofType: "png") {
            imageURL = URL(fileURLWithPath: path)
        } else {
            // Missing master: the canvas falls back to a solid colour instead
            // of crashing, so a broken install still shows a live desktop.
            imageURL = URL(fileURLWithPath: "/nonexistent-wallpaper.png")
        }
        installWindows()
        applyThrottle()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.installWindows()
        }

        // Display sleep is the only state where animation is pointless.
        // Session resign (lock screen / fast user switch) deliberately does NOT
        // pause the layer: it must already be live when the session returns.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        sleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.setPaused(true)
        }
        wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.setPaused(false)
        }

        // Watchdog: restores animation and missing per-display windows after
        // wake, screen hot-plug, lock/unlock, or any unexpected timer stall.
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.ensureLive()
        }
        timer.tolerance = 0.5
        watchdog = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func installWindows() {
        guard imageURL != nil else { return }
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
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            let workingPixelSize = Int(ceil(max(screen.frame.width, screen.frame.height)
                                             * screen.backingScaleFactor * 1.12))
            let canvas = QuantumCanvas(imageURL: imageURL, maxPixelSize: workingPixelSize)
            if effectivelyPaused { canvas.pauseAnimation() }
            canvas.setOverlayOpacity(CGFloat(overlayIntensity))
            window.contentView = canvas
            window.orderFrontRegardless()
            windows.append(window)
        }

        // A one-time boot reveal: the desktop fades in on first launch (and
        // only then; hot-plugs and wakes stay instant).
        if !hasBooted {
            hasBooted = true
            for window in windows {
                window.alphaValue = 0.0
                window.animator().alphaValue = 1.0
            }
        }
    }

    private func setPaused(_ paused: Bool) {
        pausedForDisplaySleep = paused
        applyPauseToCanvases()
    }

    private func setUserPaused(_ paused: Bool) {
        userPaused = paused
        applyPauseToCanvases()
        rebuildMenu()
    }

    private func applyPauseToCanvases() {
        let shouldPause = effectivelyPaused
        for window in windows {
            guard let canvas = window.contentView as? QuantumCanvas else { continue }
            if shouldPause { canvas.pauseAnimation() } else { canvas.resumeAnimation() }
        }
    }

    private func ensureLive() {
        // Covers a missed screensDidWake notification (sleep/wake races,
        // clamshell, display hot-plug) without trusting notifications alone.
        if pausedForDisplaySleep && CGDisplayIsAsleep(CGMainDisplayID()) == 0 {
            setPaused(false)
        }

        let screens = NSScreen.screens
        if windows.count != screens.count || windows.isEmpty {
            installWindows()
            return
        }
        guard !effectivelyPaused else { return }
        for window in windows {
            (window.contentView as? QuantumCanvas)?.ensureAnimating()
        }
        applyThrottle()
        applyIdleDim()
    }

    /// Fades the wallpaper when the Mac has been idle for a while (menu-bar
    /// toggle). Reduces OLED wear without pausing the live clock.
    private func applyIdleDim() {
        guard dimWhenIdle, !effectivelyPaused else {
            for window in windows where window.alphaValue != 1.0 {
                window.animator().alphaValue = 1.0
            }
            return
        }
        let idle = idleSeconds()
        let target: CGFloat = idle > 300 ? 0.45 : 1.0
        for window in windows where window.alphaValue != target {
            window.animator().alphaValue = target
        }
    }

    /// Drops the cadence when the wallpaper is fully covered, when running on
    /// battery, or when Low Power Mode is enabled. The desktop stays live (the
    /// clock keeps advancing) but stops burning a full core in the background.
    private func applyThrottle() {
        let interval: TimeInterval
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            interval = 1.0 / 2.0
        } else {
            let allHidden = !windows.isEmpty && windows.allSatisfy {
                !$0.occlusionState.contains(.visible)
            }
            if allHidden {
                interval = 1.0 / 2.0
            } else if Self.isOnBattery() {
                interval = 1.0 / 10.0
            } else {
                interval = 1.0 / 20.0
            }
        }
        for window in windows {
            (window.contentView as? QuantumCanvas)?.setFrameInterval(interval)
        }
    }

    private static func isOnBattery() -> Bool {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let type = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String? else {
            return false
        }
        return type == kIOPSBatteryPowerValue || type == "Battery Power"
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "terminal",
                                   accessibilityDescription: "Quantum Terminal Live")
            button.image?.isTemplate = true
        }
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let versionItem = NSMenuItem(title: "Quantum Terminal Live v\(version)",
                                         action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)
            menu.addItem(.separator())
        }

        let pauseTitle = userPaused ? "Resume Animation" : "Pause Animation"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause(_:)),
                                   keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let dimItem = NSMenuItem(title: "Dim When Idle", action: #selector(toggleDim(_:)),
                                 keyEquivalent: "")
        dimItem.target = self
        dimItem.state = dimWhenIdle ? .on : .off
        menu.addItem(dimItem)

        let intensityItem = NSMenuItem(title: "Intensity", action: nil, keyEquivalent: "")
        let intensityMenu = NSMenu()
        let levels: [(String, Double)] = [("Vivid", 1.0), ("Standard", 0.78), ("Dim", 0.55)]
        for (name, value) in levels {
            let item = NSMenuItem(title: name, action: #selector(setIntensity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(overlayIntensity - value) < 0.01 ? .on : .off
            intensityMenu.addItem(item)
        }
        intensityItem.submenu = intensityMenu
        menu.addItem(intensityItem)

        menu.addItem(.separator())

        let aerialItem = NSMenuItem(title: "Open Aerial…", action: #selector(openAerial(_:)),
                                    keyEquivalent: "")
        aerialItem.target = self
        menu.addItem(aerialItem)

        let revealItem = NSMenuItem(title: "Reveal App in Finder", action: #selector(revealApp(_:)),
                                    keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Quantum Terminal Live",
                                  action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func togglePause(_ sender: Any?) {
        setUserPaused(!userPaused)
    }

    @objc private func toggleDim(_ sender: Any?) {
        dimWhenIdle.toggle()
        UserDefaults.standard.set(dimWhenIdle, forKey: "DimWhenIdle")
        rebuildMenu()
        if !dimWhenIdle {
            for window in windows where window.alphaValue != 1.0 {
                window.animator().alphaValue = 1.0
            }
        }
    }

    @objc private func setIntensity(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let value = item.representedObject as? Double else {
            return
        }
        overlayIntensity = value
        UserDefaults.standard.set(value, forKey: "OverlayIntensity")
        for window in windows {
            (window.contentView as? QuantumCanvas)?.setOverlayOpacity(CGFloat(value))
        }
        rebuildMenu()
    }

    @objc private func openAerial(_ sender: Any?) {
        let url = URL(fileURLWithPath: "/Applications/Aerial.app")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        } else {
            // Aerial is not installed; open the project docs for the saver instead.
            let fallback = URL(fileURLWithPath: "/Users/Shared/Aerial")
            NSWorkspace.shared.open(fallback)
        }
    }

    @objc private func revealApp(_ sender: Any?) {
        let appURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Applications/Quantum Terminal Live.app")
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        if let sleepObserver { workspaceCenter.removeObserver(sleepObserver) }
        if let wakeObserver { workspaceCenter.removeObserver(wakeObserver) }
        watchdog?.invalidate()
        if let activityToken { ProcessInfo.processInfo.endActivity(activityToken) }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
