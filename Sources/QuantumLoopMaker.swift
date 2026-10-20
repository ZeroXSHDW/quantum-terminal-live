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
let loopDuration = QuantumScene.loopDuration
let frameCount = Int(fps) * Int(loopDuration)

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
    AVVideoAverageBitRateKey: 22_000_000,
    AVVideoMaxKeyFrameIntervalKey: fps * 2,
    AVVideoExpectedSourceFrameRateKey: fps
]
// IEC_sRGB is only exposed on macOS 15+. On macOS 14 the writer falls back to
// the Rec.709 transfer function; both are explicit and avoid guesswork.
var colorProperties: [String: Any] = [
    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
]
if #available(macOS 15.0, *) {
    colorProperties[AVVideoTransferFunctionKey] = AVVideoTransferFunction_IEC_sRGB
} else {
    colorProperties[AVVideoTransferFunctionKey] = AVVideoTransferFunction_ITU_R_709_2
}
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.hevc,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoColorPropertiesKey: colorProperties,
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
let canvasSize = CGSize(width: CGFloat(width), height: CGFloat(height))

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
    let time = Double(index) / Double(fps)
    QuantumScene.render(context, size: canvasSize, time: time, base: sourceCG)

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
