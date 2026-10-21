import AppKit
import ImageIO
import QuartzCore

// Frame-cost microbenchmark for the scene renderer. Run with `make bench`.
// Numbers are flat-out (no display pacing), so they exaggerate main-thread
// load; the live app self-throttles to its target frame interval.

let space = CGColorSpaceCreateDeviceRGB()
func makeContext(_ width: Int, _ height: Int) -> CGContext {
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(3) }
    return ctx
}
func bench(_ label: String, _ width: Int, _ height: Int, _ time: Double, _ phase: QuantumScene.OverlayPhase) {
    let ctx = makeContext(width, height)
    let size = CGSize(width: width, height: height)
    func one() {
        switch phase {
        case .geometry: QuantumScene.renderOverlayGeometry(ctx, size: size, time: time)
        case .text: QuantumScene.renderOverlayText(ctx, size: size, time: time)
        }
    }
    one()
    let start = CACurrentMediaTime()
    let n = 40
    for _ in 0..<n { one() }
    print(String(format: "%-36@ %.1f ms/frame", label, (CACurrentMediaTime() - start) / Double(n) * 1000.0))
}

bench("geometry 2253x1463 t=8", 2253, 1463, 8.0, .geometry)
bench("geometry 2253x1463 t=15.3 (alert)", 2253, 1463, 15.3, .geometry)
bench("text 3024x1964 t=8", 3024, 1964, 8.0, .text)
bench("text 3024x1964 t=15.3 (alert)", 3024, 1964, 15.3, .text)
