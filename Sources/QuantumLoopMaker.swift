import AVFoundation
import AppKit
import CoreGraphics
import CoreVideo
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: QuantumLoopMaker input.png output.mov\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let width = 7680
let height = 4800
let fps: Int32 = 30
// A longer cycle makes the screen saver feel genuinely live instead of
// repeating its telemetry too quickly. Every motion term below is still an
// integer-period function of this duration, so the loop remains seamless.
let loopDuration = 30.0
let frameCount = Int(fps) * Int(loopDuration)
let loopAngularVelocity = (Double.pi * 2.0) / loopDuration

guard let source = NSImage(contentsOf: inputURL),
      let sourceCG = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Unable to load source image\n", stderr)
    exit(3)
}

if FileManager.default.fileExists(atPath: outputURL.path) {
    try? FileManager.default.removeItem(at: outputURL)
}

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
let compression: [String: Any] = [
    // The screen saver is a detail-heavy 8K circuit image. 60 Mbps keeps
    // the fine blue/violet linework clean while remaining easy for Apple
    // Silicon hardware HEVC decode.
    AVVideoAverageBitRateKey: 60_000_000,
    AVVideoMaxKeyFrameIntervalKey: fps * 2,
    AVVideoExpectedSourceFrameRateKey: fps
]
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.hevc,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    // The master PNG is standard RGB/sRGB. Explicit tagging prevents Aerial
    // and macOS from guessing at the transfer curve or Y'CbCr conversion.
    AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_IEC_sRGB,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
    ],
    AVVideoCompressionPropertiesKey: compression
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
)
writer.add(input)
guard writer.startWriting() else {
    fputs("Unable to start writer: \(writer.error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(4)
}
writer.startSession(atSourceTime: .zero)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let frameDuration = CMTime(value: 1, timescale: fps)

for index in 0..<frameCount {
    while !input.isReadyForMoreMediaData {
        Thread.sleep(forTimeInterval: 0.002)
    }
    guard let pool = adaptor.pixelBufferPool else { exit(5) }
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
    guard let pixelBuffer else { exit(6) }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixelBuffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )!
    context.interpolationQuality = .high
    let time = Double(index) / Double(fps)
    // Every animated term is an integer-period function of the full loop.
    // This makes the final frame meet the first frame without a visible jump.
    let cameraBreath = 1.004 + 0.004 * cos(time * loopAngularVelocity)
    let drawWidth = CGFloat(width) * cameraBreath
    let drawHeight = CGFloat(height) * cameraBreath
    let drift = min(width, height)
    let driftX = sin(time * loopAngularVelocity) * Double(drift) * 0.0015
    let driftY = cos(time * loopAngularVelocity) * Double(drift) * 0.0010
    context.draw(sourceCG, in: CGRect(
        x: (CGFloat(width) - drawWidth) * 0.5 + CGFloat(driftX),
        y: (CGFloat(height) - drawHeight) * 0.5 + CGFloat(driftY),
        width: drawWidth,
        height: drawHeight
    ))
    context.setBlendMode(.screen)

    let center = CGPoint(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.53)
    let breathe = CGFloat((sin(time * loopAngularVelocity) + 1) * 0.5)
    let glowRadius = CGFloat(min(width, height)) * (0.19 + breathe * 0.012)
    let glowColors: [CGColor] = [
        CGColor(red: 0.18, green: 0.22, blue: 1.0, alpha: 0.12),
        CGColor(red: 0.16, green: 0.08, blue: 0.80, alpha: 0.035),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ]
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors as CFArray, locations: [0.0, 0.42, 1.0]) {
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: glowRadius, options: [])
    }

    let sweepY = CGFloat((1.0 - cos(time * loopAngularVelocity)) * 0.5) * CGFloat(height)
    for (lineWidth, alpha) in [(52.0, 0.012), (18.0, 0.035), (4.0, 0.18)] {
        context.setStrokeColor(CGColor(red: 0.16, green: 0.4, blue: 1, alpha: alpha))
        context.setLineWidth(lineWidth)
        context.move(to: CGPoint(x: 0, y: sweepY))
        context.addLine(to: CGPoint(x: CGFloat(width), y: sweepY))
        context.strokePath()
    }

    for ring in 0..<7 {
        let radius = CGFloat(min(width, height)) * (0.055 + CGFloat(ring) * 0.032) + breathe * 20
        context.setStrokeColor(CGColor(red: 0.3, green: 0.3, blue: 1, alpha: 0.035 + 0.02 * Double(6 - ring)))
        context.setLineWidth(ring == 0 ? 5 : 2)
        context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    let wavePhase = CGFloat((time / loopDuration).truncatingRemainder(dividingBy: 1.0))
    let waveRadius = CGFloat(min(width, height)) * (0.085 + wavePhase * 0.105)
    let waveAlpha = 0.075 * (1.0 - wavePhase) * (1.0 - wavePhase)
    context.setStrokeColor(CGColor(red: 0.30, green: 0.40, blue: 1, alpha: waveAlpha))
    context.setLineWidth(4)
    context.strokeEllipse(in: CGRect(x: center.x - waveRadius, y: center.y - waveRadius, width: waveRadius * 2, height: waveRadius * 2))

    context.saveGState()
    context.translateBy(x: center.x, y: center.y)
    for ring in 0..<3 {
        let radius = CGFloat(min(width, height)) * (0.135 + CGFloat(ring) * 0.028)
        let rotation = CGFloat(time * loopAngularVelocity * Double(ring + 1)) * (ring.isMultiple(of: 2) ? 1 : -1)
        context.rotate(by: rotation)
        context.setStrokeColor(CGColor(red: 0.25, green: 0.45, blue: 1, alpha: 0.10 - Double(ring) * 0.018))
        context.setLineWidth(ring == 0 ? 4 : 2)
        context.addArc(center: .zero, radius: radius, startAngle: CGFloat(ring) * 1.9, endAngle: CGFloat(ring) * 1.9 + 0.82 + breathe * 0.16, clockwise: false)
        context.strokePath()
    }
    context.restoreGState()

    for lane in 0..<4 {
        let laneSeed = Double(lane) * 1.37
        let laneY = center.y + (CGFloat(lane) - 1.5) * CGFloat(min(width, height)) * 0.021
        let phase = CGFloat((sin(time * loopAngularVelocity * Double(lane + 1) + laneSeed) + 1) * 0.5)
        let x = CGFloat(width) * (0.12 + phase * 0.76)
        let trail = CGFloat(width) * (0.018 + CGFloat(lane % 2) * 0.008)
        context.setStrokeColor(CGColor(red: 0.16, green: 0.52, blue: 1, alpha: 0.055))
        context.setLineWidth(4)
        context.move(to: CGPoint(x: max(0, x - trail), y: laneY))
        context.addLine(to: CGPoint(x: x, y: laneY))
        context.strokePath()
        context.setFillColor(CGColor(red: 0.35, green: 0.78, blue: 1, alpha: 0.24))
        context.fillEllipse(in: CGRect(x: x - 7, y: laneY - 7, width: 14, height: 14))
    }

    for node in 0..<20 {
        let seed = Double(node) * 1.47
        let normalizedX = 0.5 + 0.46 * sin(seed + time * loopAngularVelocity * Double((node % 3) + 1))
        let x = CGFloat(normalizedX) * CGFloat(width)
        let y = CGFloat((sin(seed * 2.3) + 1) * 0.5) * CGFloat(height)
        let trail = CGFloat(0.025 + Double(node % 4) * 0.012) * CGFloat(width)
        context.setStrokeColor(CGColor(red: 0.25, green: 0.56, blue: 1, alpha: 0.14))
        context.setLineWidth(3)
        context.move(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: x + trail, y: y))
        context.strokePath()
        context.setFillColor(CGColor(red: 0.35, green: 0.7, blue: 1, alpha: 0.24))
        context.fillEllipse(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
    }

    // Paired orbital beacons add a readable live-system cue around the core.
    // Their integer-period speeds preserve a seamless 30-second loop.
    for beaconIndex in 0..<2 {
        let radius = CGFloat(min(width, height)) * (0.19 + CGFloat(beaconIndex) * 0.035)
        let direction = beaconIndex == 0 ? 1.0 : -1.0
        let angle = time * loopAngularVelocity * Double(beaconIndex == 0 ? 3 : 2) * direction + Double(beaconIndex) * 2.4
        let beacon = CGPoint(
            x: CGFloat(width) * 0.5 + cos(angle) * radius,
            y: CGFloat(height) * 0.53 + sin(angle) * radius * 0.46
        )
        let tangent = CGPoint(
            x: -sin(angle) * CGFloat(direction),
            y: cos(angle) * CGFloat(direction) * 0.46
        )
        context.setStrokeColor(CGColor(red: 0.30, green: 0.58, blue: 1, alpha: 0.12))
        context.setLineWidth(4)
        context.move(to: CGPoint(x: beacon.x - tangent.x * 44, y: beacon.y - tangent.y * 44))
        context.addLine(to: CGPoint(x: beacon.x + tangent.x * 12, y: beacon.y + tangent.y * 12))
        context.strokePath()
        context.setFillColor(CGColor(red: 0.54, green: 0.70, blue: 1, alpha: 0.34))
        context.fillEllipse(in: CGRect(x: beacon.x - 8, y: beacon.y - 8, width: 16, height: 16))
    }

    // Keep the outer frame quiet for screen-saver viewing and preserve the
    // high-contrast center as the visual anchor.
    let vignetteColors: [CGColor] = [
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.16)
    ]
    if let vignette = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: vignetteColors as CFArray, locations: [0.54, 1.0]) {
        context.setBlendMode(.normal)
        context.drawRadialGradient(
            vignette,
            startCenter: CGPoint(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.52),
            startRadius: 0,
            endCenter: CGPoint(x: CGFloat(width) * 0.5, y: CGFloat(height) * 0.52),
            endRadius: CGFloat(max(width, height)) * 0.72,
            options: []
        )
    }

    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
    adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
}

input.markAsFinished()
let group = DispatchGroup()
group.enter()
writer.finishWriting { group.leave() }
group.wait()
if writer.status != .completed {
    fputs("Video write failed: \(writer.error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(7)
}
print(outputURL.path)
