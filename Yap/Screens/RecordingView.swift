import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Must be @ObservedObject, not read through `store.transcriber`: Store's own
    // @Published changes are what trigger SwiftUI re-renders, and Store does not forward
    // Transcriber's objectWillChange. Reading `store.transcriber.liveText` without this
    // subscribed directly meant the view only ever redrew when some Store property
    // changed (e.g. recordingPhase flipping at Stop) and merely picked up whatever liveText
    // happened to hold by then — i.e. transcript text only ever appeared to "arrive" at Stop.
    @ObservedObject var transcriber: Transcriber
    let theme: Theme

    @State private var pulseOn = false
    @State private var breathe = false
    @State private var transcriptContentHeight: CGFloat = 0
    @State private var transcriptContainerHeight: CGFloat = 0
    @State private var showCancelConfirm = false

    private var phase: RecordingPhase { store.recordingPhase }

    private var displayText: String {
        switch phase {
        case .idle: return ""
        case .recording, .processing: return transcriber.liveText
        case .done: return store.doneEntry?.text ?? transcriber.liveText
        }
    }

    private var words: [String] {
        displayText.split(separator: " ").map(String.init)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 18)
                .padding(.top, 18)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if phase == .idle {
                            idlePrompt
                        } else if phase == .recording {
                            Label("Listening", systemImage: "record.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.21))
                                .accessibilityAddTraits(.updatesFrequently)
                        } else if phase == .processing {
                            Label("Finishing your transcript…", systemImage: "waveform")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.textSecondary)
                        }

                        if phase == .done, let entry = store.doneEntry {
                            Pill(text: Mood.label(entry.mood), theme: theme, dotColor: theme.moodColor(entry.mood))
                        }
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            // Plain text, no per-word color animation — matches how Apple's
                            // own dictation (Notes, Messages) actually looks: words just
                            // appear. "Recording is live" is already signaled three other
                            // ways here (the pulsing red ring, the waveform bars, the
                            // ticking timer); a fourth, on the text itself, was competing
                            // signal rather than new information, and risked an odd flicker
                            // if the recognizer revised a word right as the next one landed.
                            ForEach(Array(words.enumerated()), id: \.offset) { _, w in
                                Text(w)
                                    .font(.title2)
                                    .foregroundStyle(theme.textPrimary)
                                    .wordIn()
                            }
                        }
                        // Zero-height anchor scrolled to as the transcript grows — a
                        // teleprompter-style follow, not a jump-to-top-on-every-word reset.
                        Color.clear.frame(height: 1).id("transcriptEnd")
                    }
                    .padding(22)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TranscriptHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: TranscriptContainerHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(TranscriptHeightKey.self) { transcriptContentHeight = $0 }
                .onPreferenceChange(TranscriptContainerHeightKey.self) { transcriptContainerHeight = $0 }
                .onChange(of: words.count) {
                    // Only start auto-following once the transcript has grown past half the
                    // visible area — short transcripts just grow in place with no scrolling.
                    guard transcriptContainerHeight > 0, transcriptContentHeight > transcriptContainerHeight / 2 else { return }
                    if reduceMotion {
                        proxy.scrollTo("transcriptEnd", anchor: .bottom)
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("transcriptEnd", anchor: .bottom)
                        }
                    }
                }
            }

            bottomControls
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(idleBackground)
        .onChange(of: phase) { _, newPhase in
            pulseOn = (newPhase == .recording && !reduceMotion)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { breathe = true }
        }
        .alert("Discard this recording?", isPresented: $showCancelConfirm) {
            Button("Discard", role: .destructive) { store.cancelRecording() }
            Button("Keep Recording", role: .cancel) {}
        } message: {
            Text("What you've said so far will be lost.")
        }
    }

    private var idlePrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What’s on your mind?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Text("Speak naturally. You can review and edit the transcript when you’re done.")
                .font(.body)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Transcribed on this iPhone", systemImage: "lock.fill")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 26)
        .padding(.bottom, 10)
    }

    /// The X sits right in the top corner — an easy accidental tap mid-sentence with
    /// nothing to undo once it fires. Only prompts when there's actually something at risk
    /// (recording, with real words captured already); tapping X on an empty/just-opened
    /// sheet still cancels immediately, since there's nothing to lose there.
    private func requestCancel() {
        let hasContent = !transcriber.liveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if phase == .recording, hasContent {
            showCancelConfirm = true
        } else {
            store.cancelRecording()
        }
    }

    /// A calm ambient treatment for the idle screen, replacing the flat blank field the
    /// design review called out ("reads as unloaded, not listening"). Subtle by design —
    /// a slow breathing radial glow behind where the mic button sits, and skipped entirely
    /// under Reduce Motion.
    private var idleBackground: some View {
        ZStack {
            theme.bg
            if phase == .idle {
                RadialGradient(
                    colors: [theme.accent.opacity(theme.dark ? 0.16 : 0.09), theme.bg.opacity(0)],
                    center: .init(x: 0.5, y: 0.86),
                    startRadius: breathe ? 40 : 10,
                    endRadius: breathe ? 260 : 190
                )
                .ignoresSafeArea()
            }
        }
    }

    private var topBar: some View {
        HStack {
            // Hidden once stopped (.processing/.done): cancelRecording() tears down the
            // transcriber immediately, but Store's own stopRecordingEarly() Task — already
            // running independently — would go on to commit the entry and open its detail
            // view moments later regardless, since nothing had told it to stop. Tapping
            // "cancel" at that point looked like it worked and then got silently undone.
            if phase == .idle || phase == .recording {
                CircleIconButton(theme: theme, action: requestCancel) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityLabel("Cancel recording")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            if phase != .idle {
                Text(timerLabel)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
                    .accessibilityLabel("Recording time \(timerLabel)")
            }
        }
    }

    private var timerLabel: String {
        let mm = store.elapsed / 60
        let ss = store.elapsed % 60
        return "\(mm):\(ss < 10 ? "0" : "")\(ss)"
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                if phase == .recording {
                    waveCluster
                }
                recordButton
                if phase == .recording {
                    waveCluster
                }
            }
            if phase == .idle {
                Text("Start recording")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            } else if phase == .recording {
                Text("Tap to finish this entry")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            } else if phase == .done {
                Text("Entry saved")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            } else if phase == .processing {
                Text("Saving your entry…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var waveCluster: some View {
        let recent = Array(transcriber.levels.suffix(3))
        return HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                // Keep a calm, static waveform under Reduce Motion. The listening label
                // and timer still provide clear live confirmation without animated bars.
                let level = reduceMotion
                    ? [CGFloat(0.2), CGFloat(0.38), CGFloat(0.24)][i]
                    : CGFloat(i < recent.count ? recent[i] : 0)
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textSecondary)
                    .frame(width: 3, height: max(6, 6 + level * 26))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: level)
            }
        }
    }

    private var recordButton: some View {
        ZStack {
            if phase == .recording {
                if !reduceMotion {
                    Circle().stroke(Color(red: 1, green: 0.23, blue: 0.19), lineWidth: 1.5)
                        .scaleEffect(pulseOn ? 1.9 : 0.75)
                        .opacity(pulseOn ? 0 : 0.45)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulseOn)
                    Circle().stroke(Color(red: 1, green: 0.23, blue: 0.19), lineWidth: 1.5)
                        .scaleEffect(pulseOn ? 1.9 : 0.75)
                        .opacity(pulseOn ? 0 : 0.45)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(0.5), value: pulseOn)
                }
            }
            Button(action: store.recordButtonAction) {
                Group {
                    switch phase {
                    case .idle:
                        Image(systemName: "mic.fill").font(.title2).foregroundStyle(recordIconColor)
                    case .recording:
                        RoundedRectangle(cornerRadius: 6).fill(recordIconColor).frame(width: 22, height: 22)
                    case .processing:
                        ProgressView().tint(recordIconColor)
                    case .done:
                        Image(systemName: "checkmark").font(.title2.weight(.bold)).foregroundStyle(recordIconColor)
                    }
                }
                .frame(width: 64, height: 64)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(recordButtonColor)
            .shadow(color: .black.opacity(0.22), radius: 8, y: 6)
            .disabled(phase == .processing || phase == .done)
            .frame(width: 64, height: 64)
            .accessibilityLabel(accessibilityButtonLabel)
        }
        .frame(width: 76, height: 76)
    }

    private var recordButtonColor: Color {
        switch phase {
        case .idle: return theme.accent
        case .recording: return Color(red: 1, green: 0.23, blue: 0.19)
        case .processing: return theme.dark ? Color(white: 0.28) : Color(white: 0.78)
        case .done: return Color(red: 0.2, green: 0.78, blue: 0.35)
        }
    }

    private var accessibilityButtonLabel: String {
        switch phase {
        case .idle: return "Start recording"
        case .recording: return "Stop recording"
        case .processing: return "Saving entry"
        case .done: return "Entry saved"
        }
    }

    private var recordIconColor: Color {
        switch phase {
        case .idle: return theme.dark ? .black : .white
        case .recording, .done: return .black
        case .processing: return theme.dark ? .white : .black
        }
    }
}

private struct TranscriptHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TranscriptContainerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
