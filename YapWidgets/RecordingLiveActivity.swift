import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

@main
struct YapWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
    }
}

/// Prototype screen 18: the recording card on the Lock Screen, plus Dynamic Island views.
struct RecordingLiveActivity: Widget {
    fileprivate static let yap = Color(red: 47 / 255, green: 107 / 255, blue: 242 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color(red: 14 / 255, green: 22 / 255, blue: 46 / 255).opacity(0.46))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        AppTile(size: 22)
                        Text("Yap").font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 14) {
                        LevelBars(state: context.state, count: 30, maxHeight: 28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        StopButton(size: 44)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                GlyphView(glyph: .yapMark, size: 22, lineWidth: 2.4)
                    .foregroundStyle(Self.yap)
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: 44)
            } minimal: {
                GlyphView(glyph: .yapMark, size: 20, lineWidth: 2.4)
                    .foregroundStyle(Self.yap)
            }
            .keylineTint(Self.yap)
        }
    }

    struct LockScreenCard: View {
        let context: ActivityViewContext<RecordingActivityAttributes>

        var body: some View {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        AppTile(size: 22)
                        Text("Yap").font(.system(size: 15, weight: .semibold))
                        Text(context.state.isPaused ? "Paused" : context.attributes.context)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    HStack(spacing: 14) {
                        LevelBars(state: context.state, count: 30, maxHeight: 28)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ElapsedText(state: context.state)
                            .font(.system(size: 22, weight: .semibold))
                    }
                }
                StopButton(size: 54)
            }
            .foregroundStyle(.white)
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 16))
        }
    }

    /// White rounded tile with the Yap mark, standing in for the app icon.
    struct AppTile: View {
        var size: CGFloat

        var body: some View {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(.white)
                .frame(width: size, height: size)
                .overlay {
                    GlyphView(glyph: .yapMark, size: size * 0.82, lineWidth: 2.2)
                        .foregroundStyle(RecordingLiveActivity.yap)
                }
        }
    }

    struct ElapsedText: View {
        let state: RecordingActivityAttributes.ContentState

        var body: some View {
            Text(
                timerInterval: state.timerStart...Date.distantFuture,
                pauseTime: state.isPaused ? state.timerStart.addingTimeInterval(state.elapsed) : nil,
                countsDown: false,
                showsHours: false
            )
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.white)
        }
    }

    struct StopButton: View {
        var size: CGFloat

        var body: some View {
            Button(intent: StopRecordingIntent()) {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.09, style: .continuous)
                            .fill(.white)
                            .frame(width: size / 3, height: size / 3)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop and save")
        }
    }

    /// A Live Activity can't animate continuously, so the bars are the prototype's wave
    /// shape scaled by the most recent level snapshot.
    struct LevelBars: View {
        let state: RecordingActivityAttributes.ContentState
        var count: Int
        var maxHeight: CGFloat

        var body: some View {
            let level = state.isPaused ? 0 : min(1, (state.levels.suffix(4).max() ?? 0) * 1.6)
            let shape = Self.shape(count, seed: 5)
            HStack(spacing: 2.2) {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: 2.5, height: max(3, (state.isPaused ? 0.08 : shape[i] * (0.4 + 0.6 * level)) * maxHeight))
                }
            }
            .frame(height: maxHeight)
            .accessibilityHidden(true)
        }

        /// The prototype's deterministic wave envelope (`shape(n, seed)`).
        static func shape(_ n: Int, seed: Double) -> [Double] {
            var x = Int((seed * 9973).truncatingRemainder(dividingBy: 2_147_483_647))
            if x == 0 { x = 1 }
            func random() -> Double {
                x = (x * 16807) % 2_147_483_647
                return Double(x) / 2_147_483_647
            }
            return (0..<n).map { i in
                let env = 0.35 + 0.65 * sin(Double.pi * (Double(i) + 0.5) / Double(n))
                let osc = abs(0.6 * sin(Double(i) * 0.47 + seed) + 0.4 * sin(Double(i) * 0.17 + seed * 2.3))
                return min(1, env * (0.25 + 0.75 * osc) * (0.7 + 0.5 * random()))
            }
        }
    }
}
