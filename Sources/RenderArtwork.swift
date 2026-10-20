import AppKit
import CoreGraphics

guard CommandLine.arguments.count >= 4 else {
    fputs("usage: RenderArtwork out.jpg width height\n", stderr)
    exit(2)
}
let out = CommandLine.arguments[1]
let width = Int(CommandLine.arguments[2])!
let height = Int(CommandLine.arguments[3])!
let image = QuantumArtwork.generateBase(width: width, height: height)
let rep = NSBitmapImageRep(cgImage: image)
let isPNG = out.lowercased().hasSuffix(".png")
let data = isPNG
    ? rep.representation(using: .png, properties: [:])!
    : rep.representation(using: .jpeg, properties: [.compressionFactor: 0.90])!
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
