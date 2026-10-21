import AppKit
import ImageIO

// Renders a short animated GIF preview of the live scene using ImageIO.
// The frames are deterministic (seeded RNG + fixed clock), so the preview is
// a faithful sample of the real wallpaper rather than a mock.
//
// usage: RenderPreview input.png output.gif width height startTime duration fps
//
// Example (shows the calm scene sweeping into the 15 s alert lockdown):
//   RenderPreview master.png preview-live.gif 480 300 12.0 10.0 10

guard CommandLine.arguments.count >= 8 else {
    fputs("usage: RenderPreview input.png output.gif width height startTime duration fps\n", stderr)
    exit(2)
}
let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let width = Int(CommandLine.arguments[3])!
let height = Int(CommandLine.arguments[4])!
let startTime = Double(CommandLine.arguments[5])!
let duration = Double(CommandLine.arguments[6])!
let fps = Double(CommandLine.arguments[7])!

guard width > 0, height > 0, duration > 0, fps > 0 else {
    fputs("invalid dimensions/duration/fps\n", stderr)
    exit(2)
}

let url = URL(fileURLWithPath: input) as CFURL
guard let source = CGImageSourceCreateWithURL(url, nil),
      let base = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("cannot load base image\n", stderr)
    exit(3)
}

let space = CGColorSpaceCreateDeviceRGB()
let frameCount = max(1, Int(duration * fps))
let frameDelay = 1.0 / fps

guard let dest = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: output) as CFURL,
    "com.compuserve.gif" as CFString, frameCount, nil) else {
    fputs("cannot create GIF destination\n", stderr)
    exit(4)
}

// Loop forever so the README preview animates continuously.
CGImageDestinationSetProperties(dest, [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
] as CFDictionary)

for i in 0..<frameCount {
    let t = startTime + Double(i) / fps
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        exit(5)
    }
    QuantumScene.render(ctx, size: CGSize(width: width, height: height),
                        time: t, base: base)
    guard let image = ctx.makeImage() else { exit(6) }
    CGImageDestinationAddImage(dest, image, [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameDelay]
    ] as CFDictionary)
}

guard CGImageDestinationFinalize(dest) else {
    fputs("failed to finalize GIF\n", stderr)
    exit(7)
}
print("wrote \(output) (\(frameCount) frames, \(width)x\(height), t=\(startTime)..\(startTime + duration))")
