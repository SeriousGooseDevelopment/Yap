import SwiftUI

/// Prototype screen 14: the entry with its photo, text and recording. While playing, the
/// sentence being spoken is highlighted and kept in view ("follow along"); tapping a
/// sentence plays from there.
struct ReadingView: View {
    let id: String
    @EnvironmentObject private var store: Store
    @ObservedObject var player: AudioPlayerController
    @Environment(\.screen) private var screen
    @State private var document = ReaderDocument(paragraphs: [])
    @State private var reader = ReaderController()
    @State private var follow = true
    @State private var position = ScrollPosition(edge: .top)
    @State private var scrollOffset: CGFloat = 0
    @State private var textTop: CGFloat = 0
    @State private var playPops = 0
    @State private var ratePops = 0
    @State private var spins: (back: Int, forward: Int) = (0, 0)

    var body: some View {
        ZStack(alignment: .top) {
            Palette.screen.ignoresSafeArea()
            if let entry = store.entry(id) {
                content(entry)
                if entry.hasAudio { playerCard(entry) }
            }
            topBar
        }
        .ignoresSafeArea(.container)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
        .onChange(of: store.entry(id)?.text) { _, _ in load() }
        .onDisappear { player.stop() }
        .onChange(of: activeSentence) { _, active in keepInView(active) }
    }

    private var activeSentence: Int? {
        guard player.isPlaying || player.time > 0 else { return nil }
        return document.sentence(at: player.time, duration: player.duration)
    }

    private func load() {
        guard let entry = store.entry(id) else { return }
        document = ReaderDocument(paragraphs: entry.paragraphs)
        if entry.hasAudio { player.load(url: entry.audioURL, fallbackDuration: entry.seconds) }
    }

    // MARK: Page

    private func content(_ entry: JournalEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let name = entry.photo, let image = PhotoStore.image(name) {
                    Color.clear
                        .frame(height: 214)
                        .overlay(Image(uiImage: image).resizable().scaledToFill())
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 22)
                        .accessibilityLabel("Entry photo")
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.displayTitle)
                        .font(.news(32, 500))
                        .tracking(-0.48)
                        .newsLines(32, lineHeight: 1.15)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(Fmt.readingMeta(entry))
                        .font(.sf(14))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, 8)
                    ReaderText(
                        document: document,
                        active: follow ? activeSentence : nil,
                        controller: reader
                    ) { sentence in
                        guard entry.hasAudio, sentence < document.starts.count else { return }
                        player.seek(to: document.starts[sentence] * player.duration)
                        if !player.isPlaying { player.play() }
                    }
                    .padding(.top, 18)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { textTop = $0 }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 280)
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in scrollOffset = y }
        .scrollIndicators(.hidden)
        .padding(.top, screen.y(110))
        .overlay(alignment: .bottom) {
            LinearGradient(stops: [.init(color: Palette.screen.opacity(0), location: 0), .init(color: Palette.screen, location: 0.46)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 250)
                .allowsHitTesting(false)
        }
    }

    /// While following along, scroll when the spoken sentence leaves the comfortable band.
    private func keepInView(_ sentence: Int?) {
        guard follow, player.isPlaying, let sentence, sentence < document.sentences.count,
              let rect = reader.rect(of: document.sentences[sentence]) else { return }
        let visibleY = textTop + rect.minY
        guard visibleY > 380 || visibleY < 0 else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            position.scrollTo(y: max(0, scrollOffset + visibleY - 120))
        }
    }

    private var topBar: some View {
        HStack {
            BackLink { store.pop() }
            Spacer()
            if let entry = store.entry(id) {
                HStack(spacing: 8) {
                    Menu {
                        Button("Share Text") { SharePresenter.present([Exporter.plainText(entry)]) }
                        Button("Share Recording") { SharePresenter.present([entry.audioURL]) }
                            .disabled(!entry.hasAudio)
                        Button("Export as Markdown") {
                            if let url = Exporter.markdownFile(entry) { SharePresenter.present([url]) }
                        }
                    } label: {
                        GlyphView(glyph: .share, size: 19, lineWidth: 1.9)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 40, height: 40)
                    }
                    .menuOrder(.fixed)
                    .accessibilityLabel("Share")

                    Menu {
                        Button("Edit Entry") { store.edit(entry) }
                        Button("Copy Text") { store.copyText(of: entry) }
                        Divider()
                        Button("Delete Entry", role: .destructive) { confirmDelete(entry) }
                    } label: {
                        RoundIconLabel(glyph: .ellipsis, size: 40, iconSize: 19, fill: Palette.fillSoft)
                    }
                    .menuOrder(.fixed)
                    .accessibilityLabel("More")
                }
            }
        }
        .frame(height: 48)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.top, screen.y(54))
    }

    private func confirmDelete(_ entry: JournalEntry) {
        store.alert = AppAlert(
            title: "Delete this entry?",
            message: "It will be removed from this iPhone, along with its recording.",
            actions: [
                AppAlert.Action(label: "Cancel", role: .cancel),
                AppAlert.Action(label: "Delete", role: .destructive) { store.deleteEntry(entry.id) },
            ]
        )
    }

    // MARK: Player

    private func playerCard(_ entry: JournalEntry) -> some View {
        let levels = entry.waveform.map { EntryAudioStore.bars($0, count: 54).map(Double.init) }
            ?? WaveShape.heights(54, seed: Self.seed(entry.id))
        return VStack(spacing: 0) {
            PlayerWave(levels: levels, progress: player.progress) { fraction in
                player.seek(to: fraction * player.duration)
            }
            .accessibilityElement()
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(Fmt.clock(player.time)) of \(Fmt.clock(player.duration))")
            .accessibilityAdjustableAction { direction in
                player.skip(direction == .increment ? 15 : -15)
            }

            HStack {
                Text(Fmt.clock(player.time))
                Spacer()
                Text(Fmt.clock(player.duration))
            }
            .font(.sf(12, .medium))
            .monospacedDigit()
            .foregroundStyle(Palette.ink2)
            .padding(.top, 8)
            .accessibilityHidden(true)

            HStack(spacing: 0) {
                Button {
                    ratePops += 1
                    player.cycleRate()
                } label: {
                    Text(Self.rateLabel(player.rate))
                        .font(.sf(14, .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 44, minHeight: 32)
                        .background(Capsule().fill(Palette.fillSoft))
                        .popOnChange(of: ratePops)
                }
                .buttonStyle(.press)
                .accessibilityLabel("Playback speed")
                .accessibilityValue(Self.rateLabel(player.rate))
                .frame(maxWidth: .infinity)

                skipButton(forward: false).frame(maxWidth: .infinity)

                Button {
                    playPops += 1
                    player.togglePlay()
                } label: {
                    GlyphView(glyph: player.isPlaying ? .pauseWide : .play, size: 22)
                        .offset(x: player.isPlaying ? 0 : 2)
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            Circle()
                                .fill(Palette.yap)
                                .shadow(color: Palette.yap.opacity(0.4), radius: 12, x: 0, y: 12)
                        )
                        .popOnChange(of: playPops, scale: 1.08)
                }
                .buttonStyle(.press)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                .frame(maxWidth: .infinity)

                skipButton(forward: true).frame(maxWidth: .infinity)

                Button {
                    follow.toggle()
                } label: {
                    GlyphView(glyph: .follow, size: 20, lineWidth: 2)
                        .foregroundStyle(follow ? Palette.yap : Palette.ink2)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(follow ? Palette.yap100 : Palette.fillSoft))
                        .popOnChange(of: follow)
                        .animation(.easeOut(duration: 0.25), value: follow)
                }
                .buttonStyle(.press)
                .accessibilityLabel("Follow along")
                .accessibilityAddTraits(follow ? .isSelected : [])
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 16, trailing: 20))
        .yapFrost(RoundedRectangle(cornerRadius: 32, style: .continuous), tint: Palette.frost)
        .padding(.horizontal, 16)
        .padding(.bottom, screen.bottom(36))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .staggerIn(1, delay: 0.12, distance: 8)
    }

    private func skipButton(forward: Bool) -> some View {
        Button {
            if forward { spins.forward += 1 } else { spins.back += 1 }
            player.skip(forward ? 15 : -15)
        } label: {
            SkipGlyph(forward: forward)
                .foregroundStyle(Palette.ink)
                .keyframeAnimator(initialValue: 0.0, trigger: forward ? spins.forward : spins.back) { view, angle in
                    view.rotationEffect(.degrees(angle))
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(forward ? 60 : -60, duration: 0.18)
                        SpringKeyframe(0, duration: 0.28, spring: .bouncy)
                    }
                }
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.press)
        .accessibilityLabel(forward ? "Forward 15 seconds" : "Back 15 seconds")
    }

    private static func rateLabel(_ rate: Float) -> String {
        rate == rate.rounded() ? "\(Int(rate))×" : "\(rate)×"
    }

    /// The prototype's per-entry waveform seed, for entries without a recorded waveform.
    private static func seed(_ id: String) -> Int {
        var h = 0
        for scalar in id.unicodeScalars { h = (h * 31 + Int(scalar.value)) % 997 }
        return h % 23 + 2
    }
}
