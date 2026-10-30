import SwiftUI

/// Prototype screens 11 and 12. Opens as "Listening…" with the level meter in the middle;
/// once the first words arrive the meter drops toward the controls and the live
/// transcript takes the page.
struct RecordingView: View {
    @EnvironmentObject private var store: Store
    // Observed directly: `Store` doesn't forward `Transcriber`'s changes, so reading it
    // through `store.transcriber` would only redraw when some unrelated `Store` value changed.
    @ObservedObject var transcriber: Transcriber
    let session: RecordingSession
    @Environment(\.screen) private var screen
    @State private var meter = LevelMeter()

    private var transcript: Bool { session.showsTranscript }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.screen

            if !transcript {
                SoftGlow(size: 460, strength: 0.07)
                    .position(x: screen.size.width / 2, y: screen.y(165) + 230)
                    .transition(.opacity)
            }

            header

            if transcript {
                transcriptPage
                    .transition(.opacity.animation(.easeOut(duration: 0.42).delay(0.17)))
            } else {
                listeningLabel
                    .padding(.top, screen.y(596))
                    .transition(.opacity)
            }

            TimelineView(.animation) { context in
                let level = meter.step(target: Double(transcriber.levels.last ?? 0) * 1.4, at: context.date)
                ZStack {
                    if !transcript {
                        SoftGlow(size: 210, strength: 0.2)
                            .scaleEffect(1 + (session.isPaused ? 0 : level) * 0.4)
                    }
                    LiveBars(level: level, isPaused: session.isPaused, isRecording: true)
                }
            }
            .frame(height: 210)
            .position(x: screen.size.width / 2, y: transcript ? screen.size.height - screen.bottom(137) - 45 : screen.y(350) + 45)
            .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.7), value: transcript)

            controls
                .padding(.bottom, screen.bottom(41))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .disabled(session.isFinishing)
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Wordmark(size: transcript ? 30 : 32)
            Spacer()
            Menu {
                Button {} label: { Text("Language"); Text("English (US)") }
                    .disabled(true)
                Button {} label: { Text("Input"); Text(transcriber.inputName) }
                    .disabled(true)
                Divider()
                Button("Discard recording", role: .destructive) { store.askDiscardRecording() }
            } label: {
                RoundIconLabel(glyph: .ellipsis, iconSize: 20, fill: transcript ? Palette.fillSoft : Palette.fill)
            }
            .menuOrder(.fixed)
            .accessibilityLabel("More")
        }
        .frame(height: 48)
        .padding(.horizontal, transcript ? 16 : 14)
        .padding(.top, screen.y(transcript ? 54 : 58))
    }

    private var listeningLabel: some View {
        VStack(spacing: 6) {
            Text(session.isPaused ? "Paused" : "Listening…")
                .font(.sf(20, .medium))
                .tracking(-0.2)
                .foregroundStyle(Palette.yap)
            ElapsedClock(session: session)
                .font(.sf(17))
                .foregroundStyle(Palette.ink2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var transcriptPage: some View {
        VStack(spacing: 0) {
            HStack {
                ElapsedClock(session: session)
                Spacer()
                Text(session.isPaused ? "Paused" : session.context)
            }
            .font(.sf(13))
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 24)
            .padding(.top, screen.y(116))

            ScrollView {
                LiveTranscript(text: transcriber.liveText, isPaused: session.isPaused)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            // Short transcripts start at the top; as it grows, the newest line stays in view.
            .defaultScrollAnchor(.top, for: .alignment)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollIndicators(.hidden)
            .padding(.top, screen.y(156) - screen.y(116) - 16)
            .padding(.bottom, screen.bottom(236))
        }
    }

    @ViewBuilder
    private var controls: some View {
        if transcript {
            HStack(spacing: 0) {
                control(.closeLarge, size: 52, iconSize: 20, lineWidth: 2, fill: Palette.fillSoft, foreground: Palette.ink2, label: "Discard") {
                    store.askDiscardRecording()
                }
                .frame(maxWidth: .infinity)
                Button(action: store.finishRecording) {
                    Circle()
                        .fill(Palette.yap100)
                        .frame(width: 68, height: 68)
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.yap).frame(width: 24, height: 24))
                }
                .buttonStyle(.press)
                .accessibilityLabel("Stop and save")
                .frame(maxWidth: .infinity)
                pauseButton(size: 52, fill: Palette.fillSoft)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 88)
            .yapFrost(Capsule(), tint: Palette.frost)
            .padding(.horizontal, 24)
            .transition(.opacity)
        } else {
            HStack {
                control(.close, size: 50, iconSize: 22, lineWidth: 1.8, fill: Palette.fill, foreground: Palette.ink2, label: "Discard") {
                    store.askDiscardRecording()
                }
                Spacer()
                Button(action: store.finishRecording) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.yap)
                        .frame(width: 28, height: 28)
                        .shadow(color: Palette.yap.opacity(0.5), radius: 9, x: 0, y: 6)
                        .shadow(color: Palette.yap.opacity(0.18), radius: 12)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .accessibilityLabel("Stop and save")
                Spacer()
                pauseButton(size: 50, fill: Palette.fill)
            }
            .padding(.horizontal, 29)
            .frame(height: 86)
            .background {
                Capsule()
                    .fill(Palette.card)
                    .shadow(color: Palette.shadow.opacity(0.12), radius: 19, x: 0, y: 18)
                    .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.5))
            }
            .padding(.horizontal, 28)
            .transition(.opacity)
        }
    }

    private func control(_ glyph: Glyph, size: CGFloat, iconSize: CGFloat, lineWidth: CGFloat, fill: Color, foreground: Color,
                         label: String, action: @escaping () -> Void) -> some View {
        RoundIconButton(glyph: glyph, size: size, iconSize: iconSize, lineWidth: lineWidth, fill: fill, foreground: foreground, label: label, action: action)
    }

    private func pauseButton(size: CGFloat, fill: Color) -> some View {
        Button(action: store.togglePause) {
            Group {
                if session.isPaused {
                    GlyphView(glyph: .mic, size: 20, lineWidth: 1.9)
                } else {
                    GlyphView(glyph: transcript ? .pauseWide : .pause, size: transcript ? 20 : 17)
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .popOnChange(of: session.isPaused)
        }
        .buttonStyle(.press)
        .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
    }
}

/// "0:05", ticking from the session's own clock.
struct ElapsedClock: View {
    let session: RecordingSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            Text(Fmt.clock(session.elapsed(at: context.date)))
                .monospacedDigit()
        }
        .accessibilityLabel("Recording time")
    }
}

/// The live transcript in journal type. The newest couple of words stay grey until the
/// recognizer has been quiet for a moment, as the prototype's interim words do.
struct LiveTranscript: View {
    var text: String
    var isPaused: Bool
    @State private var settled = true

    private static let size: CGFloat = 25

    var body: some View {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let interimFrom = settled || isPaused ? words.count : max(0, words.count - 2)
        FlowLayout(spacing: Self.size * 0.25, lineSpacing: Self.size * 0.46) {
            ForEach(words.indices, id: \.self) { i in
                Text(words[i])
                    .font(.news(Self.size))
                    .tracking(-0.125)
                    .foregroundStyle(i >= interimFrom ? Palette.interim : Palette.ink)
                    .animation(.easeOut(duration: 0.55), value: i >= interimFrom)
                    .wordIn()
            }
            Caret(height: Self.size * 1.05)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement()
        .accessibilityLabel(text.isEmpty ? "Listening" : text)
        .accessibilityAddTraits(.updatesFrequently)
        .task(id: text) {
            settled = false
            try? await Task.sleep(nanoseconds: 800_000_000)
            if !Task.isCancelled { settled = true }
        }
    }
}

/// Blinking 2pt caret (`yapBlink 1.1s steps(1)`).
struct Caret: View {
    var height: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.55)) { context in
            let on = Int(context.date.timeIntervalSinceReferenceDate / 0.55) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(Palette.yap)
                .frame(width: 2, height: height)
                .opacity(on ? 1 : 0)
        }
        .accessibilityHidden(true)
    }
}

/// Smooths the 10Hz peak level for the meter: quick to rise, slow to fall.
final class LevelMeter {
    private var value = 0.0
    private var last: Date?

    func step(target: Double, at date: Date) -> Double {
        let dt = min(0.1, last.map { date.timeIntervalSince($0) } ?? 0.016)
        last = date
        let clamped = min(1, max(0, target))
        let rate = clamped > value ? 0.4 : 0.1
        value += (clamped - value) * min(1, rate * dt * 60)
        return value
    }
}

/// The circular reveal the recorder opens with, growing out of the button that started it.
struct CircleReveal: ViewModifier, Animatable {
    var radius: CGFloat
    var center: CGPoint
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func body(content: Content) -> some View {
        content.clipShape(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        )
    }
}
