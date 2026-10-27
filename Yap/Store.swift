import Foundation
import NaturalLanguage
import Combine
import SwiftUI

enum Segment: Hashable { case dashboard, insights }
enum RecordingPhase { case idle, recording, processing, done }

@MainActor
final class Store: ObservableObject {
    /// Used only by the DEBUG `-dark` launch argument for screenshots. Normal launches
    /// inherit the system appearance.
    @Published var appearanceOverride: ColorScheme?
    @Published var segment: Segment = .dashboard
    @Published var entries: [JournalEntry] = []

    @Published var recordingOpen = false
    @Published var recordingPhase: RecordingPhase = .idle
    @Published var elapsed: Int = 0
    @Published var justAdded = false
    @Published var detailEntry: JournalEntry?
    @Published var micDenied = false
    @Published var transcriberError: String?

    let transcriber = Transcriber()

    private var elapsedTimer: Timer?
    private var lastCommittedEntry: JournalEntry?
    private var cancellables = Set<AnyCancellable>()
    /// Set by `continueRecording(for:)` when the mic is tapped from inside an existing
    /// note's detail view — `commitEntry` checks this to append to that entry instead of
    /// creating a new one. Cleared after every commit/cancel so it never bleeds into an
    /// unrelated later recording.
    private var continuingEntryID: String?

    init() {
        // A real user's very first launch must start genuinely empty — auto-seeding
        // sample entries ("Priya", "Sam", a fabricated 10-day streak, mood trends about
        // people/days that never happened) meant every new install opened straight into
        // what looked like someone else's private journal, which is a bad first
        // impression for an app whose whole pitch is on-device privacy. Seed data is now
        // opt-in only, for screenshots/demos — see `-seedDemo` in `applyLaunchOverrides`.
        entries = EntryStore.load() ?? []
        applyLaunchOverrides()

        // The OS force-stops capture out from under us for a phone call, Siri, an alarm,
        // or another app taking the mic — without this, `recordingPhase` would stay stuck
        // at `.recording` with the timer still ticking and nothing actually being
        // captured. Finalize with whatever was captured, same as tapping Stop.
        transcriber.$wasInterrupted
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self, self.recordingPhase == .recording else { return }
                self.stopRecordingEarly()
            }
            .store(in: &cancellables)
    }

    /// DEBUG-only entry points for screenshotting states that have no cold-launch path.
    private func applyLaunchOverrides() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        // Populates the sample entries for screenshots/demos only — never runs for a real
        // user, and never overwrites real saved data (EntryStore.load() above already won
        // if there's anything on disk).
        if args.contains("-seedDemo"), entries.isEmpty {
            entries = EntryStore.seedEntries()
        }
        if args.contains("-dark") { appearanceOverride = .dark }
        if let i = args.firstIndex(of: "-segment"), args.count > i + 1, args[i + 1] == "insights" {
            segment = .insights
        }
        if args.contains("-openRecording") { recordingOpen = true }
        if args.contains("-openDetail"), let first = entries.first { detailEntry = first }
        #endif
    }

    // MARK: - Navigation

    func goDashboard() { segment = .dashboard }
    func goInsights() { segment = .insights }
    func openDetail(_ entry: JournalEntry) { detailEntry = entry }
    func closeDetail() { detailEntry = nil }

    /// Edits from `EditableTranscriptView` land here on every keystroke — `detailEntry` is
    /// a struct copy, so it and the underlying `entries` row have to be updated together or
    /// the dashboard list would keep showing the pre-edit text after `closeDetail()`.
    func updateDetailText(_ newText: String) {
        guard var entry = detailEntry else { return }
        entry.text = newText
        detailEntry = entry
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].text = newText
            EntryStore.save(entries)
        }
    }

    func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        EntryStore.save(entries)
        EntryAudioStore.delete(entryID: entry.id)
        closeDetail()
    }

    // MARK: - Derived stats

    struct GridCell: Identifiable {
        let id: String
        let color: Color?
        let isToday: Bool
        let dayNumber: String
        let dateDescription: String
        let moodDescription: String?
        let moodSymbol: String?
    }

    func gridCells(theme: Theme) -> [GridCell] {
        var cells: [GridCell] = []
        for row in 0..<2 {
            for col in 0..<7 {
                let offset = row == 0 ? 13 - col : 6 - col
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date())) ?? Date()
                let dayEntries = entries.filter { $0.dayOffset == offset }
                let averageMood = dayEntries.isEmpty
                    ? nil
                    : dayEntries.map(\.mood).reduce(0, +) / Double(dayEntries.count)
                cells.append(GridCell(
                    id: "\(row)-\(col)",
                    color: averageMood.map { theme.moodColor($0) },
                    isToday: offset == 0,
                    dayNumber: date.formatted(.dateTime.day()),
                    dateDescription: date.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                    moodDescription: averageMood.map {
                        "Estimated tone: \(Mood.label($0)), average of \(dayEntries.count) \(dayEntries.count == 1 ? "entry" : "entries")"
                    },
                    moodSymbol: averageMood.map { $0 >= 0.15 ? "plus" : ($0 <= -0.15 ? "minus" : "equal") }
                ))
            }
        }
        return cells
    }

    struct TopicStat: Identifiable {
        let id: String
        let name: String
        let count: Int
        let avgMood: Double
        let pct: Double
    }

    var topicStats: [TopicStat] {
        var map: [String: (count: Int, sum: Double)] = [:]
        for e in entries {
            for t in e.topics {
                var v = map[t] ?? (0, 0)
                v.count += 1
                v.sum += e.mood
                map[t] = v
            }
        }
        let maxCount = map.values.map(\.count).max() ?? 1
        return map.map { name, v in
            TopicStat(id: name, name: name, count: v.count, avgMood: v.sum / Double(v.count), pct: max(14, Double(v.count) / Double(maxCount) * 100))
        }.sorted { $0.count > $1.count }
    }

    /// Deterministic, on-device generated insight copy — no network call, no paid API.
    /// Replaces the design's three hardcoded strings with sentences templated off the
    /// same topic/mood aggregates driving the bars above them.
    var insightCards: [String] {
        guard entries.count >= 5 else { return [] }
        var cards: [String] = []
        let stats = topicStats

        if let top = stats.max(by: { $0.count < $1.count }) {
            let moodPhrase: String
            if top.avgMood < -0.15 { moodPhrase = "more difficult" }
            else if top.avgMood > 0.15 { moodPhrase = "more positive" }
            else { moodPhrase = "fairly steady" }
            cards.append("\(top.name) is your most-mentioned topic, across \(top.count) entries. Their estimated tone reads \(moodPhrase).")
        }

        if stats.count > 1 {
            let minCount = stats.map(\.count).min() ?? 0
            let rare = stats.filter { $0.count <= minCount + 1 }
            if let best = rare.max(by: { $0.avgMood < $1.avgMood }) {
                cards.append("\(best.name) appears in \(best.count) entries. The estimated tone in those entries reads \(Mood.label(best.avgMood).lowercased()).")
            }
        }

        let sorted = entries.sorted { $0.date < $1.date }
        if sorted.count >= 4 {
            let mid = sorted.count / 2
            let firstHalf = sorted[..<mid].map(\.mood).reduce(0, +) / Double(mid)
            let secondHalf = sorted[mid...].map(\.mood).reduce(0, +) / Double(sorted.count - mid)
            let delta = secondHalf - firstHalf
            let trend = delta > 0.1 ? "more positive" : (delta < -0.1 ? "more difficult" : "fairly steady")
            cards.append("Compared with earlier entries, your recent writing reads \(trend). Treat this as a rough signal, not a verdict.")
        } else {
            cards.append("Keep adding entries to make these patterns more useful over time.")
        }

        return cards
    }

    // MARK: - Recording flow

    func openRecording() {
        recordingOpen = true
        recordingPhase = .idle
        elapsed = 0
    }

    /// The dashboard's floating mic button — always a fresh entry.
    func startNewRecording() {
        continuingEntryID = nil
        openRecording()
    }

    /// The mic button inside an existing note's detail view: the next recording gets
    /// appended to `entry` (text, mood/topics recomputed from the combined text, audio
    /// concatenated) instead of becoming a separate new entry — see `commitEntry`.
    func continueRecording(for entry: JournalEntry) {
        continuingEntryID = entry.id
        openRecording()
    }

    func recordButtonAction() {
        switch recordingPhase {
        case .idle: startRecording()
        case .recording: stopRecordingEarly()
        default: break
        }
    }

    /// `recordingPhase` only flips to `.recording` once mic permission is confirmed
    /// granted, so it stays `.idle` (and tappable) for that whole wait — a rapid
    /// double-tap on the record button during that window would otherwise fire this
    /// function twice concurrently, each installing its own audio tap and engine start.
    private var isStartingRecording = false

    private func startRecording() {
        guard !isStartingRecording else { return }
        isStartingRecording = true
        Task {
            defer { isStartingRecording = false }
            let granted = await AudioPermission.request()
            guard granted else {
                micDenied = true
                return
            }
            // The user can cancel (tap X) while we're waiting on the permission prompt
            // above — without this check, that cancellation would be silently undone the
            // moment the prompt resolves, since nothing else here knows the sheet was closed.
            guard recordingOpen else { return }
            recordingPhase = .recording
            elapsed = 0
            elapsedTimer?.invalidate()
            elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed += 1 }
            }
            let result = await transcriber.startRecording()
            if case .failure(let error) = result {
                // Don't leave the UI stuck showing a live "recording" state (timer
                // ticking) with nothing actually being captured — e.g. Speech Recognition
                // permission was denied, or the audio engine itself failed to start.
                elapsedTimer?.invalidate()
                recordingPhase = .idle
                transcriberError = error.message
            }
        }
    }

    func stopRecordingEarly() {
        elapsedTimer?.invalidate()
        recordingPhase = .processing
        Task {
            let text = await transcriber.stopAndTranscribeFinal()
            let committed = commitEntry(text: text, samples: transcriber.lastRecordedSamples)
            guard committed else {
                // Tap record then immediately tap stop by mistake, before saying anything,
                // and there's nothing to commit — `lastCommittedEntry` would still be
                // whatever was saved *last time*, so showing "done" and navigating there
                // would look like this tap did something to an unrelated older note. Treat
                // it like a cancel instead: quietly back out, nothing to celebrate.
                closeRecording()
                return
            }
            recordingPhase = .done
            // Just long enough for the checkmark to register as a confirmation flash, not
            // a wait — this used to be a full second stacked on top of a ~900ms transcript
            // wait that's gone now too, which is most of what made Stop feel slow.
            try? await Task.sleep(nanoseconds: 200_000_000)
            closeRecording()
            // Land on the entry that was just recorded rather than the dashboard — the
            // user just finished talking about it, not about to look at the whole list.
            if let entry = lastCommittedEntry { openDetail(entry) }
        }
    }

    func cancelRecording() {
        elapsedTimer?.invalidate()
        transcriber.cancelRecording()
        continuingEntryID = nil
        closeRecording()
    }

    private func closeRecording() {
        recordingOpen = false
        recordingPhase = .idle
        elapsed = 0
    }

    @discardableResult
    private func commitEntry(text: String, samples: [Float]) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Yap] commitEntry() text=\"\(trimmed)\" samples=\(samples.count)")
        guard !trimmed.isEmpty else {
            print("[Yap] commitEntry() BAILED: empty transcript, no entry saved")
            continuingEntryID = nil
            return false
        }

        if let continuingID = continuingEntryID, let idx = entries.firstIndex(where: { $0.id == continuingID }) {
            // Append to the note this recording continues, rather than creating a new
            // entry: combine the text (mood/topics recomputed over the whole thing, since
            // a longer note can shift its overall tone), and splice the audio by decoding
            // the existing clip back to samples and concatenating the new ones before
            // re-saving under the same entry ID.
            let combinedText = entries[idx].text.isEmpty ? trimmed : entries[idx].text + "\n\n" + trimmed
            let combinedSamples = (EntryAudioStore.loadSamples(entryID: continuingID) ?? []) + samples
            let mood = Self.sentiment(of: combinedText)
            let topics = TopicClassifier.topics(in: combinedText)
            let waveform = EntryAudioStore.save(samples: combinedSamples, entryID: continuingID)
            entries[idx].text = combinedText
            entries[idx].mood = mood
            entries[idx].topics = topics
            entries[idx].waveform = waveform
            EntryStore.save(entries)
            lastCommittedEntry = entries[idx]
            if detailEntry?.id == continuingID { detailEntry = entries[idx] }
            print("[Yap] commitEntry() continued entry \(continuingID), combined samples=\(combinedSamples.count)")
        } else {
            let mood = Self.sentiment(of: trimmed)
            let topics = TopicClassifier.topics(in: trimmed)
            let id = UUID().uuidString
            let waveform = EntryAudioStore.save(samples: samples, entryID: id)
            let entry = JournalEntry(id: id, date: Date(), mood: mood, topics: topics, text: trimmed, timeLabel: "Just now", waveform: waveform)
            entries.insert(entry, at: 0)
            EntryStore.save(entries)
            lastCommittedEntry = entry
        }

        continuingEntryID = nil
        justAdded = true
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            justAdded = false
        }
        return true
    }

    var doneEntry: JournalEntry? { lastCommittedEntry }

    /// On-device sentiment via NaturalLanguage (Apple's built-in analyzer, no network,
    /// no paid API) — replaces the design's hardcoded `mood: 0.6`.
    private static func sentiment(of text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        var weightedScore = 0.0
        var wordCount = 0
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .paragraph,
            scheme: .sentimentScore,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            let words = text[range].split(whereSeparator: { $0.isWhitespace }).count
            guard words > 0, let score = Double(tag?.rawValue ?? "") else { return true }
            weightedScore += score * Double(words)
            wordCount += words
            return true
        }
        return wordCount > 0 ? weightedScore / Double(wordCount) : 0
    }

    // MARK: - Relative labels

    func relativeLabel(for e: JournalEntry) -> String {
        if e.timeLabel == "Just now" { return "Just now" }
        let cal = Calendar.current
        let offset = e.dayOffset
        if offset == 0 { return "Today · \(e.timeLabel)" }
        if offset == 1 { return "Yesterday · \(e.timeLabel)" }
        let wd = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        if offset < 7 { return wd[cal.component(.weekday, from: e.date) - 1] + " · " + e.timeLabel }
        let mo = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return "\(mo[cal.component(.month, from: e.date) - 1]) \(cal.component(.day, from: e.date)) · \(e.timeLabel)"
    }

    func detailDateLabel(for e: JournalEntry) -> String {
        let offset = e.dayOffset
        if offset == 0 { return "Today" }
        if offset == 1 { return "Yesterday" }
        let cal = Calendar.current
        let wd = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let mo = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return "\(wd[cal.component(.weekday, from: e.date) - 1]), \(mo[cal.component(.month, from: e.date) - 1]) \(cal.component(.day, from: e.date))"
    }

}

private extension String {
    subscript(_ i: Int) -> String {
        String(self[index(startIndex, offsetBy: i)])
    }
}
