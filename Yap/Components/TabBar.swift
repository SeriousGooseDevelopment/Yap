import SwiftUI

/// The floating tab bar: a frosted pill with Journal / Insights / Settings and a sliding
/// selection, plus the record button beside it.
struct TabBar: View {
    @EnvironmentObject private var store: Store
    @State private var taps: [Tab: Int] = [:]

    private let tabs: [(tab: Tab, title: String, glyph: Glyph)] = [
        (.journal, "Journal", .tabJournal),
        (.insights, "Insights", .tabInsights),
        (.settings, "Settings", .tabSettings),
    ]

    var body: some View {
        HStack(spacing: 14) {
            pill
            RecordButton { origin in store.startRecording(from: origin) }
        }
        .padding(.horizontal, 20)
    }

    private var pill: some View {
        let index = CGFloat(tabs.firstIndex { $0.tab == store.tab } ?? 0)
        return HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { item in
                let selected = item.tab == store.tab
                Button {
                    taps[item.tab, default: 0] += 1
                    if store.tab == item.tab {
                        if item.tab == .journal, store.calendarOpen {
                            withAnimation(Motion.ios(0.5)) { store.calendarOpen = false }
                        }
                    } else {
                        store.select(item.tab)
                    }
                } label: {
                    VStack(spacing: 2) {
                        GlyphView(glyph: item.glyph, size: 22, lineWidth: 1.9)
                            .keyframeAnimator(initialValue: CGFloat(1), trigger: taps[item.tab, default: 0]) { icon, scale in
                                icon.scaleEffect(scale)
                            } keyframes: { _ in
                                KeyframeTrack {
                                    CubicKeyframe(0.78, duration: 0.12)
                                    CubicKeyframe(1.1, duration: 0.16)
                                    CubicKeyframe(1, duration: 0.16)
                                }
                            }
                        Text(item.title).font(.sf(10.5, selected ? .semibold : .medium))
                    }
                    .foregroundStyle(selected ? Palette.yap : Palette.ink2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressNone)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .background(alignment: .leading) {
            GeometryReader { geo in
                let width = (geo.size.width - 10) / 3
                Capsule()
                    .fill(Palette.yap100)
                    .frame(width: width, height: geo.size.height - 10)
                    .offset(x: 5 + index * width, y: 5)
                    .animation(Motion.ios(0.5), value: index)
            }
        }
        .frame(height: 62)
        .yapFrost(Capsule())
        .animation(.easeOut(duration: 0.3), value: store.tab)
    }
}
