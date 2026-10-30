import SwiftUI

/// The welcome screen's eleven silk lines: a voice wave that draws itself in from the left,
/// keeps breathing, and carries a slow sheen. Ported from the prototype's `silkComp`.
/// Drawn in the prototype's 402×230 space. Tap to replay.
struct SilkLines: View {
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let ends: [Double] = [356, 382, 338, 372, 390, 348, 376, 330, 368, 384, 344]
    private static let envelope: [Double] = stride(from: -6.0, through: 396, by: 3).map { 1 - smoothstep(110, 300, $0) }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 4 : timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                context.scaleBy(x: size.width / 402, y: size.height / 230)
                let wake = reduceMotion ? 1 : 0.2 + 0.8 * Self.easeOut(Self.clamp(t / 2.6))
                let u = reduceMotion ? 0 : Self.easeInOut((t + 1.2).truncatingRemainder(dividingBy: 6.5) / 6.5)
                let shift = -460 + u * 920
                let gradient = Gradient(stops: [
                    .init(color: Palette.yap.opacity(0.55), location: 0),
                    .init(color: Palette.yap.opacity(0.55), location: 0.4),
                    .init(color: Palette.yap, location: 0.5),
                    .init(color: Palette.yap.opacity(0.55), location: 0.6),
                    .init(color: Palette.yap.opacity(0.55), location: 1),
                ])
                let shading = GraphicsContext.Shading.linearGradient(
                    gradient, startPoint: CGPoint(x: shift, y: 0), endPoint: CGPoint(x: 402 + shift, y: 0)
                )
                for i in 0..<Self.ends.count {
                    let reveal = reduceMotion ? 1 : Self.easeOut(Self.clamp((t - 0.1 - abs(Double(i) - 5) * 0.08) / 1.7))
                    guard reveal > 0 else { continue }
                    let path = Self.path(i, t: t, wake: wake).trimmedPath(from: 0, to: reveal)
                    var line = context
                    line.opacity = min(1, 0.2 + 0.75 * (1 - abs(Double(i) - 5) / 6))
                    line.stroke(path, with: shading, style: StrokeStyle(lineWidth: 1.35, lineCap: .round))
                }
            }
        }
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.14)],
                             startPoint: .leading, endPoint: .trailing))
        .contentShape(Rectangle())
        .onTapGesture { start = Date() }
        .accessibilityHidden(true)
    }

    private static func path(_ i: Int, t: Double, wake: Double) -> Path {
        let fi = Double(i)
        let base = 58 + fi * 11
        let amp = 48 * (1 - fi * 0.04)
        let end = ends[i] - 14 + 14 * (0.5 + 0.5 * sin(t * 0.55 + fi * 1.7))
        let phase = t * 1.15
        let twist = 0.35 * sin(t * 0.42 + fi * 0.22)
        var path = Path()
        var x = -6.0
        var k = 0
        while x <= end, k < envelope.count {
            let voice = 0.62 + 0.38 * sin(t * 0.9 - x * 0.011) * (0.7 + 0.3 * sin(t * 0.37 + 1.3))
            let wave = 0.62 * sin(x * 0.026 - phase + fi * 0.36 + twist) + 0.38 * sin(x * 0.061 - phase * 1.6 - fi * 0.24)
            let y = base + envelope[k] * amp * wake * voice * wave
            let point = CGPoint(x: x, y: y)
            if k == 0 { path.move(to: point) } else { path.addLine(to: point) }
            x += 3
            k += 1
        }
        return path
    }

    private static func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
    private static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = clamp((x - a) / (b - a))
        return t * t * (3 - 2 * t)
    }
    private static func easeOut(_ p: Double) -> Double { 1 - pow(1 - p, 3) }
    private static func easeInOut(_ p: Double) -> Double { p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2 }
}
