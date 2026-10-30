import Foundation
import NaturalLanguage
import Combine
import SwiftUI
import UIKit

enum Tab: String, Hashable { case journal, insights, settings }

/// Pushed screens. The tab screens (journal, calendar, insights, settings) live in the
/// stack's root view, so the floating tab bar is covered whenever something is pushed.
enum Route: Hashable {
    /// `zoom` opens the entry with the zoom transition from its journal card.
    case reading(id: String, zoom: Bool)
    case writing
}

struct RecordingSession {
    enum Mode { case new, append }

    var mode: Mode
    /// Center of the button that started the recording, in global coordinates — where the
    /// circular reveal grows from and collapses back to.
    var origin: CGPoint
    var startedAt = Date()
    var clockStart = Date()
    var accumulated: TimeInterval = 0
    var isPaused = false
    /// Flips once the first words arrive: "Listening…" morphs into the live transcript.
    var showsTranscript = false
    var isFinishing = false

    func elapsed(at now: Date = Date()) -> TimeInterval {
        accumulated + (isPaused ? 0 : max(0, now.timeIntervalSince(clockStart)))
    }

    var context: String { mode == .append ? "Adding to entry" : "New entry" }
}

/// The entry open on the writing screen — a new recording or an existing entry being edited.
struct Draft {
    enum Origin: Equatable { case tab(Tab), reading }

    let id: String
    var isNew: Bool
    var origin: Origin
    var date: Date
    var title: String
    /// Paragraphs separated by a blank line, with `InlineMarkdown` spans.
    var body: String
    var photo: String?
    var duration: Double?
    var waveform: [Float]?
    /// Paragraphs from this index on just arrived from a recording and animate in.
    var appendedFrom: Int?
    /// The photo the saved entry had when editing began, so a replaced or discarded
    /// photo file can be cleaned up.
    var savedPhoto: String?
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// A native alert described as data, so the store can raise one from anywhere.
struct AppAlert: Identifiable {
    struct Action {
        var label: String
        var role: ButtonRole?
        var run: () -> Void = {}
    }

    let id = UUID()
    var title: String
    var message: String
    var actions: [Action]
}

enum RecordingExit { case unreveal, settle }

@MainActor
final class Store: ObservableObject {
    let prefs: Preferences
    let lock = AppLock()
    let transcriber = Transcriber()
    let player = AudioPlayerController()
    private let liveActivity = LiveActivityController()

    @Published private(set) var entries: [JournalEntry] = []

    // Navigation
    @Published var tab: Tab = .journal
    @Published var path: [Route] = []
    @Published var calendarOpen = false
    @Published var selectedDay = Calendar.current.startOfDay(for: Date())
    @Published var calendarDay = Calendar.current.startOfDay(for: Date())
    @Published var searchOn = false
    @Published var query = ""
    @Published var insightsRange: InsightsRange = .month

    // Recording + writing
    @Published var recording: RecordingSession?
    @Published var recordingExit: RecordingExit = .unreveal
    @Published var draft: Draft?
    @Published var draftSaved = false
    /// Bumped when the draft's text changes from outside the editor (a recording appended,
    /// Clean Up), so the editor reloads.
    @Published var draftRevision = 0
    @Published var isCleaningUp = false

    // Feedback
    @Published var toast: Toast?
    @Published var alert: AppAlert?
    /// A just-saved entry, highlighted once when the journal shows it.
    @Published var flashEntryID: String?
    /// True while a system prompt Yap asked for (microphone, notifications, Face ID) is on
    /// screen. The scene goes inactive under it, but that's no reason to cover the app.
    @Published private(set) var systemPromptActive = false

    /// Audio recorded for the current draft but not yet saved with it.
    private var pendingSamples: [Float]?
    private var cancellables = Set<AnyCancellable>()

    init(prefs: Preferences) {
        self.prefs = prefs
        // A real first launch starts with zero entries — sample data is DEBUG-only (`-seedDemo`).
        entries = (EntryStore.load() ?? []).sorted { $0.date > $1.date }
        applyLaunchOverrides()

        // The OS can stop capture out from under us (a call, Siri, another app taking the
        // mic). Keep what was captured, the same as tapping Stop.
        transcriber.$wasInterrupted
            .filter { $0 }
            .sink { [weak self] _ in self?.finishRecording() }
            .store(in: &cancellables)

        // The first recognized words turn "Listening…" into the live transcript.
        transcriber.$liveText
            .filter { !$0.isEmpty }
            .sink { [weak self] _ in
                guard let self, var session = self.recording, !session.showsTranscript else { return }
                session.showsTranscript = true
                withAnimation(.easeOut(duration: 0.42)) { self.recording = session }
            }
            .store(in: &cancellables)

        // Live Activity snapshots of the level meter, a few times a second at most.
        transcriber.$levels
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.updateLiveActivity() }
            .store(in: &cancellables)

        RecordingIntentBridge.handler = { [weak self] in self?.finishRecording() }
        liveActivity.endStale()
    }

    /// DEBUG-only entry points for screenshotting states with no cold-launch path.
    private func applyLaunchOverrides() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if args.contains("-seedDemo"), entries.isEmpty { entries = EntryStore.seedEntries() }
        if args.contains("-resetOnboarding") { prefs.onboarded = false }
        if args.contains("-skipOnboarding") {
            prefs.onboarded = true
            if prefs.name.isEmpty { prefs.name = "Jordan" }
        }
        if let t = value("-tab"), let tab = Tab(rawValue: t) { self.tab = tab }
        if args.contains("-openCalendar") { calendarOpen = true }
        if args.contains("-openReading"), let first = entries.first { path = [.reading(id: first.id, zoom: false)] }
        if args.contains("-openWriting"), let first = entries.first { edit(first) }
        if let mode = value("-appearance"), let a = Preferences.Appearance(rawValue: mode) { prefs.appearance = a }
        // The recorder without a live mic: "Listening…", or the transcript page with sample words.
        // A finished "recording" with this transcript and no audio, straight to its draft.
        if let words = value("-simulateRecording") {
            applyRecording(text: words, samples: [], session: RecordingSession(mode: .new, origin: .zero))
        }
        if args.contains("-openRecording") {
            var session = RecordingSession(mode: .new, origin: CGPoint(x: 351, y: 802))
            if let words = value("-recordingTranscript") {
                transcriber.debugShow(words)
                session.showsTranscript = true
            }
            recording = session
        }
        #endif
    }

    // MARK: - Entries

    func entry(_ id: String) -> JournalEntry? { entries.first { $0.id == id } }

    func entries(on day: Date) -> [JournalEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, inSameDayAs: day) }.sorted { $0.date > $1.date }
    }

    private func persist() { EntryStore.save(entries) }

    func deleteEntry(_ id: String) {
        guard let entry = entry(id) else { return }
        entries.removeAll { $0.id == id }
        persist()
        EntryAudioStore.delete(entryID: id)
        PhotoStore.delete(entry.photo)
        player.stop()
        if case .reading(let open, _)? = path.last, open == id { path.removeLast() }
        showToast("Entry deleted")
    }

    func deleteAll() {
        player.stop()
        entries = []
        EntryStore.deleteAll()
        EntryAudioStore.deleteAll()
        PhotoStore.deleteAll()
        showToast("All entries deleted")
    }

    // MARK: - Navigation

    func select(_ tab: Tab) {
        searchOn = false
        query = ""
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3)) { self.tab = tab }
    }

    func open(_ id: String, zoom: Bool = false) {
        player.stop()
        path.append(.reading(id: id, zoom: zoom))
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    // MARK: - Recording

    func startRecording(_ mode: RecordingSession.Mode = .new, from origin: CGPoint) {
        guard recording == nil else { return }
        player.stop()
        if mode == .new {
            searchOn = false
            query = ""
        }
        recordingExit = .unreveal
        withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: 0.66)) {
            recording = RecordingSession(mode: mode, origin: origin)
        }
        Task {
            guard await withSystemPrompt({ await AudioPermission.request() }) else {
                closeRecording(.unreveal)
                alert = Self.settingsAlert(
                    title: "Microphone access is off",
                    message: "Allow the microphone in Settings so Yap can hear you while you record."
                )
                return
            }
            // The recorder can be dismissed while the permission prompt is up.
            guard recording != nil else { return }
            switch await withSystemPrompt({ await self.transcriber.startRecording() }) {
            case .success:
                recording?.clockStart = Date()
                recording?.startedAt = Date()
                if let session = recording { liveActivity.start(context: session.context) }
            case .failure(let error):
                closeRecording(.unreveal)
                alert = error == .speechPermissionDenied
                    ? Self.settingsAlert(title: "Speech recognition is off", message: error.message)
                    : AppAlert(title: "Couldn’t start recording", message: error.message, actions: [AppAlert.Action(label: "OK", role: .cancel)])
            }
        }
    }

    func togglePause() {
        guard var session = recording, !session.isFinishing else { return }
        if session.isPaused {
            transcriber.resume()
            session.clockStart = Date()
            session.isPaused = false
        } else {
            transcriber.pause()
            session.accumulated = session.elapsed()
            session.isPaused = true
        }
        recording = session
        updateLiveActivity()
    }

    func askDiscardRecording() {
        guard let session = recording, !session.isFinishing else { return }
        let wasPaused = session.isPaused
        if !wasPaused { togglePause() }
        alert = AppAlert(
            title: "Discard this recording?",
            message: "What you’ve said so far won’t be saved.",
            actions: [
                AppAlert.Action(label: "Keep", role: .cancel) { [weak self] in
                    if !wasPaused { self?.togglePause() }
                },
                AppAlert.Action(label: "Discard", role: .destructive) { [weak self] in
                    self?.transcriber.cancelRecording()
                    self?.closeRecording(.unreveal)
                },
            ]
        )
    }

    /// Stop and save: the transcript becomes a draft on the writing screen. A new recording
    /// opens a new draft; "Add voice" appends to the draft already open.
    func finishRecording() {
        guard var session = recording, !session.isFinishing else { return }
        session.isFinishing = true
        recording = session
        let finished = session
        Task {
            let text = await transcriber.stopAndTranscribeFinal()
            applyRecording(text: text, samples: transcriber.lastRecordedSamples, session: finished)
        }
    }

    /// Turns a finished recording into the draft on the writing screen.
    private func applyRecording(text: String, samples: [Float], session finished: RecordingSession) {
        let seconds = Double(samples.count) / EntryAudioStore.sampleRate
        let paragraphs = TranscriptFormatter.paragraphs(text)

        // Tapped Stop before anything was captured: back out like a discard.
        if paragraphs.isEmpty && seconds < 0.5 {
            closeRecording(.unreveal)
            return
        }

        if finished.mode == .append, var draft {
            let existing = JournalEntry.paragraphs(in: draft.body)
            let base = pendingSamples ?? (draft.isNew ? [] : EntryAudioStore.loadSamples(entryID: draft.id) ?? [])
            let combined = base + samples
            pendingSamples = combined
            draft.body = (existing + paragraphs).joined(separator: "\n\n")
            draft.appendedFrom = existing.count
            draft.duration = Double(combined.count) / EntryAudioStore.sampleRate
            draft.waveform = EntryAudioStore.waveform(from: combined, buckets: 48)
            self.draft = draft
            draftSaved = false
            draftRevision += 1
        } else {
            pendingSamples = samples
            draft = Draft(
                id: UUID().uuidString,
                isNew: true,
                origin: .tab(tab),
                date: finished.startedAt,
                title: JournalEntry.autoTitle(from: text),
                body: paragraphs.joined(separator: "\n\n"),
                photo: nil,
                duration: seconds,
                waveform: EntryAudioStore.waveform(from: samples, buckets: 48),
                appendedFrom: 0,
                savedPhoto: nil
            )
            draftSaved = false
            draftRevision += 1
            // Push the writing screen underneath the recorder, which then settles away.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { path = [.writing] }
        }
        closeRecording(.settle)
    }

    private func closeRecording(_ exit: RecordingExit) {
        liveActivity.end()
        recordingExit = exit
        let animation: Animation = exit == .settle
            ? .timingCurve(0.32, 0.72, 0, 1, duration: 0.54)
            : .timingCurve(0.5, 0, 0.2, 1, duration: 0.54)
        // A beat later, so the recorder has rendered with the exit transition it leaves with.
        DispatchQueue.main.async {
            withAnimation(animation) { self.recording = nil }
        }
    }

    private func updateLiveActivity() {
        guard let session = recording, !session.isFinishing else { return }
        liveActivity.update(
            elapsed: session.elapsed(),
            isPaused: session.isPaused,
            levels: transcriber.levels.map(Double.init)
        )
    }

    private static func settingsAlert(title: String, message: String) -> AppAlert {
        AppAlert(title: title, message: message, actions: [
            AppAlert.Action(label: "Not Now", role: .cancel),
            AppAlert.Action(label: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            },
        ])
    }

    // MARK: - Writing

    func edit(_ entry: JournalEntry) {
        player.stop()
        pendingSamples = nil
        draft = Draft(
            id: entry.id, isNew: false, origin: .reading, date: entry.date,
            title: entry.displayTitle, body: entry.text, photo: entry.photo,
            duration: entry.duration, waveform: entry.waveform, appendedFrom: nil, savedPhoto: entry.photo
        )
        draftSaved = false
        draftRevision += 1
        path.append(.writing)
    }

    /// Writes the draft into the journal. Returns the saved entry.
    @discardableResult
    private func commitDraft() -> JournalEntry? {
        guard var draft else { return nil }
        let body = JournalEntry.paragraphs(in: draft.body).joined(separator: "\n\n")
        let plain = InlineMarkdown.plain(body)
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        var waveform = draft.waveform
        var duration = draft.duration
        if let samples = pendingSamples {
            waveform = EntryAudioStore.save(samples: samples, entryID: draft.id)
            duration = Double(samples.count) / EntryAudioStore.sampleRate
            pendingSamples = nil
        }
        if draft.savedPhoto != draft.photo { PhotoStore.delete(draft.savedPhoto) }

        let entry = JournalEntry(
            id: draft.id,
            date: draft.date,
            mood: Self.sentiment(of: plain),
            topics: ThemeClassifier.themes(in: plain),
            text: body,
            waveform: waveform,
            title: title.isEmpty ? JournalEntry.autoTitle(from: plain) : title,
            duration: duration,
            photo: draft.photo
        )
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i] = entry
        } else {
            entries.insert(entry, at: 0)
            entries.sort { $0.date > $1.date }
        }
        persist()

        draft.isNew = false
        draft.savedPhoto = draft.photo
        draft.waveform = waveform
        draft.duration = duration
        self.draft = draft
        return entry
    }

    func saveDraft() {
        guard let draft, !draftSaved, let entry = commitDraft() else { return }
        draftSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            switch draft.origin {
            case .reading:
                pop()
                showToast("Changes saved")
            case .tab(let tab):
                self.tab = tab
                if tab == .journal {
                    calendarOpen = false
                    searchOn = false
                    selectedDay = Calendar.current.startOfDay(for: entry.date)
                    flashEntryID = entry.id
                }
                path = []
                showToast("Saved to your journal")
            }
        }
    }

    /// The writing screen's Back button.
    func leaveWriting() {
        guard let draft else { return pop() }
        if draft.isNew && !draftSaved {
            alert = AppAlert(
                title: "Save this entry?",
                message: "You can keep editing it later from your journal.",
                actions: [
                    AppAlert.Action(label: "Discard", role: .destructive) { [weak self] in self?.discardDraft() },
                    AppAlert.Action(label: "Save") { [weak self] in self?.saveDraft() },
                ]
            )
            return
        }
        // Edits to an existing entry are kept on the way out, as in Notes.
        if !draft.isNew && !draftSaved { commitDraft() }
        pop()
    }

    private func discardDraft() {
        if let draft, draft.photo != draft.savedPhoto { PhotoStore.delete(draft.photo) }
        pendingSamples = nil
        draft = nil
        pop()
    }

    func setDraftPhoto(_ data: Data?) {
        guard var draft else { return }
        let previous = draft.photo
        draft.photo = data.flatMap(PhotoStore.save)
        // A photo picked and then replaced before saving was never part of the entry.
        if previous != draft.savedPhoto { PhotoStore.delete(previous) }
        withAnimation(Motion.ios(0.54)) { self.draft = draft }
        draftSaved = false
    }

    /// Format › Clean Up. Sends the draft's text to the cleanup service, but only once
    /// the user has allowed it (Settings › Voice & Transcription, or the prompt here).
    func cleanUpDraft() {
        guard !isCleaningUp, let draft, !InlineMarkdown.plain(draft.body).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard prefs.cleanUpAllowed else {
            alert = AppAlert(
                title: "Clean Up uses a server",
                message: "Yap sends this entry’s text to NVIDIA to remove filler words like “um” and false starts. Your words aren’t rephrased, and nothing else leaves this iPhone.",
                actions: [
                    AppAlert.Action(label: "Cancel", role: .cancel),
                    AppAlert.Action(label: "Clean Up") { [weak self] in
                        self?.prefs.cleanUpAllowed = true
                        self?.cleanUpDraft()
                    },
                ]
            )
            return
        }
        isCleaningUp = true
        let paragraphs = JournalEntry.paragraphs(in: draft.body).map(InlineMarkdown.plain)
        Task {
            defer { isCleaningUp = false }
            do {
                let cleaned = try await JournalSimplifier.simplify(paragraphs.joined(separator: "\n\n"))
                guard var current = self.draft, current.id == draft.id else { return }
                current.body = JournalEntry.paragraphs(in: cleaned).joined(separator: "\n\n")
                current.appendedFrom = nil
                self.draft = current
                draftSaved = false
                draftRevision += 1
                showToast("Cleaned up")
            } catch {
                alert = AppAlert(title: "Couldn’t clean up this entry", message: error.localizedDescription, actions: [AppAlert.Action(label: "OK", role: .cancel)])
            }
        }
    }

    /// Runs work that may raise a system prompt, keeping the privacy cover out of its way.
    func withSystemPrompt<T>(_ work: () async -> T) async -> T {
        systemPromptActive = true
        defer { systemPromptActive = false }
        return await work()
    }

    // MARK: - Feedback

    func showToast(_ text: String) { toast = Toast(text: text) }

    func copyText(of entry: JournalEntry) {
        UIPasteboard.general.string = Exporter.plainText(entry)
        showToast("Text copied")
    }

    /// On-device sentiment via NaturalLanguage — no network, no paid API.
    static func sentiment(of text: String) -> Double {
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
}
