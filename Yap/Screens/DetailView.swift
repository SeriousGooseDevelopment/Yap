import SwiftUI

struct DetailView: View {
    @EnvironmentObject var store: Store
    let theme: Theme
    @State private var showDeleteConfirm = false
    @State private var showSimplifyDisclosure = false
    @State private var showSimplifyReview = false
    @State private var isSimplifying = false
    @State private var simplifyErrorMessage: String?
    @State private var originalText = ""
    @State private var cleanedText = ""

    var body: some View {
        ZStack {
            if let entry = store.detailEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(store.detailDateLabel(for: entry))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(theme.textPrimary)

                        Text(entry.timeLabel)
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.top, 4)

                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            Pill(text: "Estimated tone · \(Mood.label(entry.mood))", theme: theme)
                            ForEach(entry.topics, id: \.self) { topic in
                                Pill(text: topic, theme: theme)
                            }
                        }
                        .padding(.top, 16)

                        if entry.hasAudio {
                            WaveformPlayer(entry: entry, theme: theme)
                                .padding(.top, 18)
                        }

                        Rectangle()
                            .fill(theme.separator)
                            .frame(height: 1)
                            .padding(.vertical, 20)

                        EditableTranscriptView(
                            text: Binding(
                                get: { store.detailEntry?.text ?? entry.text },
                                set: { store.updateDetailText($0) }
                            ),
                            textColor: UIColor(theme.textPrimary),
                            accentColor: UIColor(theme.accent),
                            onEmptyCommit: { showDeleteConfirm = true }
                        )
                        .padding(.bottom, 16)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    continueAction(for: entry)
                }
            }
        }
        .background(theme.bg.ignoresSafeArea())
        .navigationTitle("Journal entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSimplifying {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Cleaning up entry")
                } else {
                    Button("Clean Up", systemImage: "wand.and.stars") {
                        showSimplifyDisclosure = true
                    }
                    .disabled(store.detailEntry?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    .accessibilityHint("Sends this entry to NVIDIA only after you confirm")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete entry")
            }
        }
        .tint(theme.accent)
        .confirmationDialog("Clean up this entry?", isPresented: $showSimplifyDisclosure, titleVisibility: .visible) {
            Button("Send Text to NVIDIA") { simplify() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Yap sends this entry’s text to NVIDIA online to remove spoken filler. You can review the result before it replaces your original.")
        }
        .alert("Delete this entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let entry = store.detailEntry { store.deleteEntry(entry) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also removes its saved audio and can’t be undone.")
        }
        .alert(
            "Couldn’t clean up this entry",
            isPresented: Binding(
                get: { simplifyErrorMessage != nil },
                set: { if !$0 { simplifyErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(simplifyErrorMessage ?? "Try again when you have a connection.")
        }
        .sheet(isPresented: $showSimplifyReview) {
            SimplifyReviewSheet(
                originalText: originalText,
                cleanedText: cleanedText,
                theme: theme,
                onApply: {
                    store.updateDetailText(cleanedText)
                    showSimplifyReview = false
                },
                onKeepOriginal: { showSimplifyReview = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func continueAction(for entry: JournalEntry) -> some View {
        Button(action: { store.continueRecording(for: entry) }) {
            Label("Continue this entry", systemImage: "mic.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 18))
        .tint(theme.accent)
        .accessibilityHint("Adds another recording to this entry")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(theme.bg.ignoresSafeArea())
    }

    private func simplify() {
        guard let entry = store.detailEntry else { return }
        let text = entry.text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        originalText = text
        isSimplifying = true
        Task {
            do {
                cleanedText = try await JournalSimplifier.simplify(text)
                showSimplifyReview = true
            } catch {
                simplifyErrorMessage = error.localizedDescription
            }
            isSimplifying = false
        }
    }
}

private struct SimplifyReviewSheet: View {
    let originalText: String
    let cleanedText: String
    let theme: Theme
    let onApply: () -> Void
    let onKeepOriginal: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Review the edit")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Cleaned version")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.top, 6)
                    Text(cleanedText)
                        .font(.body)
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle().fill(theme.separator).frame(height: 1).padding(.vertical, 8)

                    Text("Original")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                    Text(originalText)
                        .font(.body)
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }

            VStack(spacing: 8) {
                Button("Use cleaned version", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                Button("Keep original", action: onKeepOriginal)
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(theme.bg)
        }
        .background(theme.bg.ignoresSafeArea())
    }
}
