import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var store: Store
    let theme: Theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Mood rhythm")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 18)

            Text("An estimate from your words · past 14 days")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(store.gridCells(theme: theme)) { cell in
                    moodCell(cell)
                }
            }
            .padding(.top, 15)

            HStack {
                Text("13 days ago")
                Spacer()
                Text("Today")
            }
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
            .padding(.top, 7)

            VStack(alignment: .leading, spacing: 5) {
                Label("More difficult", systemImage: "minus")
                Label("Steady", systemImage: "equal")
                Label("More positive", systemImage: "plus")
            }
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
            .padding(.top, 10)

            Text("Topics")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 32)
                .padding(.bottom, 4)

            Text("Entry mentions · bars relative to the top topic")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .padding(.bottom, 8)

            if store.topicStats.isEmpty {
                Text("Topics will appear here as you add entries.")
                    .font(.body)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.topicStats) { stat in
                        topicRow(stat)
                        if stat.id != store.topicStats.last?.id {
                            Rectangle()
                                .fill(theme.separator)
                                .frame(height: 1 / UIScreen.main.scale)
                        }
                    }
                }
            }

            Text("Patterns")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 32)
                .padding(.bottom, 4)

            Text("A rough read of topics and tone, calculated on this iPhone.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.insightCards.isEmpty {
                Text("Add a few more entries to see patterns. Early estimates can miss context.")
                    .font(.body)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(store.insightCards.enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "waveform")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.accent)
                                .padding(.top, 2)
                                .accessibilityHidden(true)
                            Text(text)
                                .font(.body)
                                .lineSpacing(4)
                                .foregroundStyle(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 15)
                        if index < store.insightCards.count - 1 {
                            Rectangle()
                                .fill(theme.separator)
                                .frame(height: 1 / UIScreen.main.scale)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func moodCell(_ cell: Store.GridCell) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 9)
                .fill(cell.color.map { $0.opacity(0.22) } ?? theme.emptyCell)
                .frame(height: 34)
                .overlay {
                    if let symbol = cell.moodSymbol {
                        Image(systemName: symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.textPrimary)
                    } else {
                        Text("·")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(cell.isToday ? theme.todayRing : .clear, lineWidth: 2)
                }

            Text(cell.dayNumber)
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: cell))
    }

    private func accessibilityLabel(for cell: Store.GridCell) -> String {
        if let mood = cell.moodDescription {
            return "\(cell.dateDescription). \(mood)."
        }
        return "\(cell.dateDescription). No entry."
    }

    private func topicRow(_ stat: Store.TopicStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(stat.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(stat.count) \(stat.count == 1 ? "entry" : "entries")")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.trackBg)
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: max(8, geo.size.width * stat.pct / 100))
                }
            }
            .frame(height: 6)

            HStack(spacing: 5) {
                Text("Estimated tone")
                Text("·")
                Text(Mood.label(stat.avgMood))
                    .foregroundStyle(theme.textPrimary)
            }
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}
