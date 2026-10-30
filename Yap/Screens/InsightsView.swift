import SwiftUI

/// Prototype screen 16. Every number, bar, theme and quote is computed on-device from the
/// journal (`InsightsSummary`); the prototype hardcoded its themes and "around 8 PM".
struct InsightsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.screen) private var screen
    @State private var appearances = 0
    @State private var refresh = false

    var body: some View {
        let summary = InsightsSummary(entries: store.entries, range: store.insightsRange)
        ZStack(alignment: .top) {
            Palette.canvas

            Text("Insights")
                .font(.news(36, 500))
                .tracking(-0.72)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.top, screen.y(60))

            rangePicker
                .padding(.horizontal, 16)
                .padding(.top, screen.y(114))

            ScrollView {
                content(summary)
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 170, trailing: 20))
                    .opacity(refresh ? 0.5 : 1)
                    .offset(y: refresh ? 6 : 0)
            }
            .scrollIndicators(.hidden)
            .padding(.top, screen.y(170))
        }
        .ignoresSafeArea(.container)
        .onAppear { appearances += 1 }
    }

    private var rangePicker: some View {
        let index = CGFloat(InsightsRange.allCases.firstIndex(of: store.insightsRange) ?? 1)
        return HStack(spacing: 0) {
            ForEach(InsightsRange.allCases) { range in
                let selected = range == store.insightsRange
                Button {
                    guard !selected else { return }
                    var reset = Transaction()
                    reset.disablesAnimations = true
                    withTransaction(reset) { refresh = true }
                    withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.65)) { store.insightsRange = range }
                    withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32)) { refresh = false }
                } label: {
                    Text(range.rawValue)
                        .font(.sf(14, selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Palette.ink : Palette.ink2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressNone)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(alignment: .leading) {
            GeometryReader { geo in
                let width = (geo.size.width - 6) / 3
                Capsule()
                    .fill(Palette.card)
                    .shadow(color: Palette.shadow.opacity(0.12), radius: 1.5, x: 0, y: 1)
                    .frame(width: width, height: geo.size.height - 6)
                    .offset(x: 3 + index * width, y: 3)
                    .animation(Motion.ios(0.45), value: index)
            }
        }
        .frame(height: 36)
        .background(Capsule().fill(Palette.track))
    }

    @ViewBuilder
    private func content(_ s: InsightsSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(s.count)")
                        .font(.news(60))
                        .tracking(-1.2)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(s.count)))
                        .foregroundStyle(Palette.ink)
                    Text(s.unit).font(.sf(15)).foregroundStyle(Palette.ink2)
                }
                .accessibilityElement(children: .combine)
                VStack(spacing: 8) {
                    InsightBars(bars: s.bars, range: store.insightsRange)
                        .id("\(store.insightsRange.rawValue)-\(appearances)")
                    HStack {
                        Text(s.from).foregroundStyle(Palette.ink3)
                        Spacer()
                        Text(s.to).fontWeight(.semibold).foregroundStyle(Palette.yap)
                    }
                    .font(.sf(11, .medium))
                }
            }

            divider

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 0) {
                    stat(s.minutes, s.minutes == 1 ? "minute spoken" : "minutes spoken")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    stat(s.streak, s.streak == 1 ? "day in a row" : "days in a row")
                        .padding(.leading, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) { Rectangle().fill(Palette.separator).frame(width: 0.5) }
                }
                summarySentence(s)
                    .font(.news(17))
                    .newsLines(17, lineHeight: 1.45)
                    .fixedSize(horizontal: false, vertical: true)
            }

            divider

            VStack(alignment: .leading, spacing: 16) {
                Text("Recurring themes").font(.sf(17, .semibold)).foregroundStyle(Palette.ink)
                if s.themes.isEmpty {
                    Text("Themes show up here once a few entries talk about the same things.")
                        .font(.sf(15))
                        .foregroundStyle(Palette.ink2)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(s.themes) { theme in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(theme.name).font(.sf(15, .semibold)).foregroundStyle(Palette.ink)
                                    Spacer()
                                    Text(Fmt.count(theme.count, "entry", "entries"))
                                        .font(.sf(13)).monospacedDigit().foregroundStyle(Palette.ink2)
                                }
                                if let quote = theme.quote {
                                    Text(quote)
                                        .font(.news(15, italic: true))
                                        .foregroundStyle(Palette.ink2)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.vertical, 18)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)")
                .font(.news(44))
                .tracking(-0.88)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .foregroundStyle(Palette.ink)
            Text(label).font(.sf(13, .medium)).foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Your longest entry was 6 minutes, on Oct 24. You usually journal around 8 PM."
    private func summarySentence(_ s: InsightsSummary) -> Text {
        guard let longest = s.longest, let usual = s.usualTime else {
            return Text("Your longest entry and the time you usually journal show up here after your first entry.")
                .foregroundStyle(Palette.ink2)
        }
        let minutes = longest.minutes == 1 ? "1 minute" : "\(longest.minutes) minutes"
        let day = longest.date.formatted(.dateTime.month(.abbreviated).day())
        let longestText = Text(minutes).foregroundStyle(Palette.ink)
        let usualText = Text(usual).foregroundStyle(Palette.ink)
        return Text("Your longest entry was \(longestText), on \(day). You usually journal around \(usualText).")
            .foregroundStyle(Palette.ink2)
    }
}

/// The range's bar chart: minutes per day (week, month) or entries per month (year), with
/// the current period in the accent color. Empty periods are small dots.
private struct InsightBars: View {
    var bars: [InsightsSummary.Bar]
    var range: InsightsRange
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width: CGFloat = range == .week ? 26 : range == .year ? 20 : 8
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(bars.enumerated()), id: \.element.id) { i, bar in
                Group {
                    if bar.value > 0 {
                        let height = min(52, range == .year ? 8 + (bar.value * 0.95).rounded() : 8 + bar.value * 7)
                        RoundedRectangle(cornerRadius: min(8, width / 2), style: .continuous)
                            .fill(bar.isCurrent ? Palette.yap : Palette.barIdle)
                            .frame(width: width, height: height)
                            .scaleEffect(y: grown || reduceMotion ? 1 : 0.001, anchor: .bottom)
                            .animation(.spring(response: 0.5, dampingFraction: 0.62).delay(Double(i) * (range == .month ? 0.018 : 0.05)), value: grown)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Palette.dotIdle)
                            .frame(width: 4, height: 4)
                            .frame(width: range == .month ? 8 : width)
                    }
                }
                if i < bars.count - 1 { Spacer(minLength: 0) }
            }
        }
        .frame(height: 52, alignment: .bottom)
        .onAppear { grown = true }
        .accessibilityElement()
        .accessibilityLabel("Activity chart")
        .accessibilityValue("\(bars.filter { $0.value > 0 }.count) of \(bars.count) \(range == .year ? "months" : "days") with entries")
    }
}
