import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: Store
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent entries")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.top, 18)
                .padding(.bottom, 4)

            if store.entries.isEmpty {
                emptyState
                    .padding(.top, 22)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            store.openDetail(entry)
                        } label: {
                            entryRow(entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Opens this entry to read and edit")

                        if index < store.entries.count - 1 {
                            Rectangle()
                                .fill(theme.separator)
                                .frame(height: 1 / UIScreen.main.scale)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func entryRow(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(entry.text)
                .font(.body)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 7) {
                if entry.hasAudio {
                    Image(systemName: "waveform")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
                Text(store.relativeLabel(for: entry))
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                Spacer(minLength: 8)
                Text("Estimated · \(Mood.label(entry.mood))")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.vertical, 17)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: "waveform")
                .font(.title2.weight(.medium))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            Text("Your journal starts with one thought.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Text("Speak freely. Yap turns your words into an entry you can revisit and edit.")
                .font(.body)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Transcribed on this iPhone", systemImage: "lock.fill")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
    }
}
