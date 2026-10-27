import SwiftUI

/// Simple word-wrapping layout used for the live transcript, so each word can be its
/// own `Text` and animate in independently (see `WordIn`).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        y += lineHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Mirrors the design's `yapWordIn` keyframe: fade + slight rise + blur, triggered once
/// per word as it's appended to the live transcript.
struct WordIn: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || appeared ? 1 : 0)
            .blur(radius: reduceMotion || appeared ? 0 : 3)
            .offset(y: reduceMotion || appeared ? 0 : 5)
            .onAppear {
                guard !reduceMotion else {
                    appeared = true
                    return
                }
                withAnimation(.easeOut(duration: 0.24)) { appeared = true }
            }
    }
}

extension View {
    func wordIn() -> some View { modifier(WordIn()) }
}

/// A compact system glass button for navigation actions in the floating layer.
struct CircleIconButton<Icon: View>: View {
    let theme: Theme
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            icon().frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}

struct MoodDot: View {
    let color: Color
    var size: CGFloat = 9
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

/// Waveform + play/pause + scrub bar for a journal entry's recording — added so the entry
/// detail screen has *some* visual trace that it came from spoken audio, which it previously
/// didn't at all (see the design review, "prove the voice in the voice journal"). Hidden
/// entirely for entries with no stored audio (the design's seed entries).
struct WaveformPlayer: View {
    let entry: JournalEntry
    let theme: Theme
    @StateObject private var controller = AudioPlayerController()

    var body: some View {
        if let waveform = entry.waveform, !waveform.isEmpty {
            content(waveform)
        }
    }

    @ViewBuilder
    private func content(_ waveform: [Float]) -> some View {
        HStack(spacing: 12) {
            Button(action: controller.togglePlay) {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(theme.accent)
            .accessibilityLabel(controller.isPlaying ? "Pause recording" : "Play recording")

            GeometryReader { geo in
                let playedCount = Int(controller.progress * Double(waveform.count))
                let barWidth = max(1.5, (geo.size.width - CGFloat(waveform.count - 1) * 2) / CGFloat(waveform.count))
                HStack(alignment: .center, spacing: 2) {
                    ForEach(Array(waveform.enumerated()), id: \.offset) { idx, level in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(idx < playedCount ? theme.accent : theme.textTertiary)
                            .frame(width: barWidth, height: max(3, CGFloat(level) * 26))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            controller.seek(toFraction: value.location.x / geo.size.width)
                        }
                )
            }
                    .frame(height: 44)
                    .accessibilityElement()
                    .accessibilityLabel("Recording playback position")
                    .accessibilityValue("\(Int(controller.progress * 100)) percent")
                    .accessibilityAdjustableAction { direction in
                        let step = direction == .increment ? 0.05 : -0.05
                        controller.seek(toFraction: min(1, max(0, controller.progress + step)))
                    }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBg))
        .onAppear { controller.load(url: entry.audioURL) }
    }
}

struct Pill: View {
    let text: String
    let theme: Theme
    var dotColor: Color? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let dotColor {
                Circle().fill(dotColor).frame(width: 7, height: 7)
            }
            // textPrimary at reduced opacity, not textSecondary — the "Anxious"/"General"
            // chips were nearly invisible against true black in dark mode (see design
            // review); pillBg/pillBorder give them their own contrast step from `bg`.
            Text(text).font(.caption.weight(.medium)).foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Capsule().fill(theme.pillBg))
        .overlay(Capsule().strokeBorder(theme.pillBorder, lineWidth: 1))
    }
}
