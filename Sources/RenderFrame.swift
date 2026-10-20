import AppKit
import ImageIO

guard CommandLine.arguments.count >= 5 else {
    fputs("usage: RenderPreview input.png output.jpg width height [time]\n", stderr)
    exit(2)
}
let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let width = Int(CommandLine.arguments[3])!
let height = Int(CommandLine.arguments[4])!
let time = CommandLine.arguments.count > 5 ? Double(CommandLine.arguments[5])! : 15.0

let url = URL(fileURLWithPath: input) as CFURL
guard let source = CGImageSourceCreateWithURL(url, nil),
      let base = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("cannot load base image\n", stderr)
    exit(3)
}

let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: width, height: height,
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(4)
}
QuantumScene.render(ctx, size: CGSize(width: width, height: height),
                    time: time, base: base)
guard let image = ctx.makeImage() else { exit(5) }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .jpeg,
                                    properties: [.compressionFactor: 0.94]) else { exit(6) }
try data.write(to: URL(fileURLWithPath: output))
print("wrote \(output) at t=\(time)")
