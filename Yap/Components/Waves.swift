import SwiftUI

/// The prototype's seeded Park–Miller generator, so every wave has the same shape it has
/// in the prototype.
struct SeededRandom {
    private var x: Int

    init(seed: Int) {
        let s = (seed * 9973) % 2_147_483_647
        x = s == 0 ? 1 : s
    }

    mutating func next() -> Double {
        x = (x * 16807) % 2_147_483_647
        return Double(x) / 2_147_483_647
    }
}

enum WaveShape {
    /// `shape(n, seed)`: a voice-like envelope of bar heights in 0...1.
    static func heights(_ n: Int, seed: Int) -> [Double] {
        generate(n, seed: seed, animated: false).heights
    }

    /// The prototype's animated `wave()` draws two more random values per bar for its
    /// `yapBar` period and phase, so the heights differ from `heights(_:seed:)`.
    static func animated(_ n: Int, seed: Int) -> (heights: [Double], timing: [(Double, Double)]) {
        generate(n, seed: seed, animated: true)
    }

    private static func generate(_ n: Int, seed: Int, animated: Bool) -> (heights: [Double], timing: [(Double, Double)]) {
        var random = SeededRandom(seed: seed)
        var heights: [Double] = []
        var timing: [(Double, Double)] = []
        for i in 0..<n {
            let env = 0.35 + 0.65 * sin(Double.pi * (Double(i) + 0.5) / Double(n))
            let osc = abs(0.6 * sin(Double(i) * 0.47 + Double(seed)) + 0.4 * sin(Double(i) * 0.17 + Double(seed) * 2.3))
            heights.append(min(1, env * (0.25 + 0.75 * osc) * (0.7 + 0.5 * random.next())))
            if animated {
                let period = 0.55 + random.next() * 0.6
                let delay = -random.next() * 1.2
                timing.append((period, delay))
            }
        }
        return (heights, timing)
    }
}

/// Screen 02's small animated waveform above the sample entry.
struct MiniWave: View {
    var count = 40
    var barWidth: CGFloat = 2.5
    var gap: CGFloat = 2.6
    var maxHeight: CGFloat = 36
    var seed = 9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let wave: (heights: [Double], timing: [(Double, Double)])

    init(count: Int = 40, barWidth: CGFloat = 2.5, gap: CGFloat = 2.6, maxHeight: CGFloat = 36, seed: Int = 9) {
        self.count = count
        self.barWidth = barWidth
        self.gap = gap
        self.maxHeight = maxHeight
        self.seed = seed
        wave = WaveShape.animated(count, seed: seed)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { i in
                    let (period, delay) = wave.timing[i]
                    let phase = ((t - delay) / period).truncatingRemainder(dividingBy: 2)
                    let tri = phase < 1 ? phase : 2 - phase
                    let eased = (1 - cos(Double.pi * tri)) / 2
                    Capsule()
                        .fill(Palette.yap)
                        .frame(width: barWidth, height: max(3, (wave.heights[i] * maxHeight).rounded()))
                        .scaleEffect(y: reduceMotion ? 1 : 0.32 + 0.68 * eased)
                }
            }
            .frame(height: maxHeight)
        }
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.14),
                                     .init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
        .accessibilityHidden(true)
    }
}

/// A static row of bars that grows out from the middle when it appears (screens 05, 09).
struct GrowBars: View {
    struct Bar {
        var x: CGFloat // center, relative to the middle of the screen
        var height: CGFloat
        var width: CGFloat = 2.5
        var opacity: Double = 1
    }

    var bars: [Bar]
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(bars.indices, id: \.self) { i in
                let bar = bars[i]
                let mid = Double(bars.count - 1) / 2
                Capsule()
                    .fill(Palette.yap)
                    .opacity(bar.opacity)
                    .frame(width: bar.width, height: bar.height)
                    .scaleEffect(y: grown || reduceMotion ? 1 : 0.001)
                    .offset(x: bar.x)
                    .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.18 + abs(Double(i) - mid) * 0.034), value: grown)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { grown = true }
        .accessibilityHidden(true)
    }

    /// Screen 05: 21 bars, 12.8pt apart.
    static let microphone: [Bar] = {
        let heights: [CGFloat] = [3, 6, 9, 14, 16, 22, 39, 22, 21, 40, 65, 40, 21, 22, 39, 22, 16, 14, 9, 6, 3]
        let lefts: [CGFloat] = [71.4, 84.2, 97.0, 109.8, 122.6, 135.4, 148.3, 161.0, 173.8, 186.6, 199.4, 212.3, 225.0, 237.8, 250.6, 263.4, 276.3, 289.1, 301.9, 314.6, 327.4]
        return zip(lefts, heights).map { Bar(x: $0 + 1.25 - 201, height: $1) }
    }()

    /// Screen 09: 19 bars with the tall center stroke.
    static let allSet: [Bar] = {
        let lefts: [CGFloat] = [85.0, 101.7, 114.7, 127.1, 139.1, 152.1, 164.6, 176.5, 188.0, 199.2, 210.9, 222.8, 234.3, 246.2, 259.2, 271.7, 284.2, 296.7, 313.3]
        let heights: [CGFloat] = [3.6, 6.6, 10.2, 19.4, 23.0, 36.8, 59.7, 29.6, 63.8, 106.2, 59.7, 29.6, 59.7, 36.8, 23.0, 19.4, 10.2, 6.6, 3.6]
        let opacities: [Double] = [0.6, 0.6, 1, 1, 1, 1, 1, 1, 1, 1, 0.55, 1, 1, 1, 1, 1, 1, 0.6, 0.6]
        return lefts.indices.map { i in
            let width: CGFloat = i == 9 ? 3 : 2.6
            return Bar(x: lefts[i] + width / 2 - 201, height: heights[i], width: width, opacity: opacities[i])
        }
    }()
}

/// The recorder's level meter (screens 11 and 12): 16 bars and 9 dots around the center,
/// swaying gently while idle and following the mic level while recording.
struct LiveBars: View {
    var level: Double
    var isPaused: Bool
    var isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dots: [CGFloat] = [-145, -132, -120, -107, 95, 108, 120, 133, 146]
    private static let bars: [(x: CGFloat, h: CGFloat, o: Double)] = [
        (-95, 6, 0.7), (-83, 11, 0.8), (-70, 18, 0.85), (-58, 26, 0.9), (-45, 18, 0.45), (-38, 24, 0.85),
        (-26, 55, 0.95), (-13, 65, 1), (0, 84, 1), (13, 65, 1), (25, 42, 0.95), (38, 25, 0.9),
        (51, 19, 0.85), (64, 14, 0.8), (77, 9, 0.7), (87, 5, 0.35),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(Self.dots.indices, id: \.self) { i in
                    let x = Self.dots[i]
                    Circle()
                        .fill(Palette.yap)
                        .opacity(0.2 + 0.4 * (1 - (abs(x) - 95) / 51))
                        .frame(width: 2.5, height: 2.5)
                        .offset(x: x)
                }
                ForEach(Self.bars.indices, id: \.self) { i in
                    let bar = Self.bars[i]
                    let speed = 1.6 + (Double(i) * 0.37).truncatingRemainder(dividingBy: 0.9) * 2.4
                    let sway = 0.5 + 0.5 * sin(t * speed + Double(i) * 1.7)
                    let scale = !isRecording ? 0.72 + 0.28 * sway
                        : isPaused ? 0.14 + 0.04 * sway
                        : 0.26 + min(1.2, level * 2.3) * (0.5 + 0.5 * sway) + 0.08 * sway
                    Capsule()
                        .fill(LinearGradient(stops: [
                            .init(color: Palette.yap.opacity(0.62), location: 0),
                            .init(color: Palette.yap, location: 0.3),
                            .init(color: Palette.yap, location: 0.7),
                            .init(color: Palette.yap.opacity(0.62), location: 1),
                        ], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2.5, height: bar.h)
                        .opacity(bar.o)
                        .shadow(color: bar.h > 50 ? Palette.yap.opacity(0.35) : .clear, radius: 3)
                        .scaleEffect(y: reduceMotion ? (isPaused ? 0.2 : 0.8) : scale)
                        .offset(x: bar.x)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
        }
        .accessibilityHidden(true)
    }
}

/// The reading screen's scrubbable waveform: played bars in the accent color.
struct PlayerWave: View {
    var levels: [Double]
    var progress: Double
    var onScrub: (Double) -> Void

    var body: some View {
        let played = Int((progress * Double(levels.count)).rounded())
        HStack(spacing: 3.1) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(i < played ? Palette.yap : Palette.yap200)
                    .frame(width: 3, height: max(3, (levels[i] * 34).rounded()))
            }
        }
        .frame(height: 36)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let width = Double(levels.count) * 3 + Double(levels.count - 1) * 3.1
                    onScrub(max(0, min(1, value.location.x / width)))
                }
        )
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.12), value: played)
    }
}
