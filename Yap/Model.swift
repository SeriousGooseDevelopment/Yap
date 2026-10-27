import Foundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: String
    var date: Date
    /// Rough on-device sentiment estimate from -1 (more negative wording) to 1 (more positive wording).
    var mood: Double
    var topics: [String]
    var text: String
    var timeLabel: String
    /// Peak-amplitude buckets (0...1) for the entry's recording, or nil for entries with no
    /// stored audio (the design's seed entries). Optional so old `entries.json` files without
    /// this field still decode — see `EntryAudioStore`.
    var waveform: [Float]? = nil

    var hasAudio: Bool { waveform?.isEmpty == false }
    var audioURL: URL { EntryAudioStore.fileURL(for: id) }

    var dayOffset: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }
}

enum Mood {
    /// Continuous, deliberately muted terracotta -> amber -> sage ramp, replacing the
    /// original design's literal systemRed/systemYellow/systemGreen. Stock stoplight hues
    /// read as form-validation states, not a reflective mood signal (see the design review:
    /// Apple's own Health app moved State of Mind to a similar desaturated continuous ramp
    /// for the same reason). Tuned slightly brighter/more saturated for `dark` so it doesn't
    /// go muddy against true black, rather than reusing the light-mode values verbatim.
    static func color(_ score: Double, dark: Bool) -> (r: Double, g: Double, b: Double) {
        let c = max(-1, min(1, score))
        // Hue in degrees: -1 -> muted rose, 0 -> ochre, +1 -> soft leaf green.
        let hue: Double = c <= 0 ? lerp(12, 40, c + 1) : lerp(40, 142, c)
        let sat: Double = dark ? 0.34 : 0.28
        let bri: Double = dark ? 0.76 : 0.82
        return hsbToRGB(hue: hue, sat: sat, bri: bri)
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private static func hsbToRGB(hue: Double, sat: Double, bri: Double) -> (r: Double, g: Double, b: Double) {
        let h = hue / 60
        let c = bri * sat
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = bri - c
        let (r1, g1, b1): (Double, Double, Double)
        switch h {
        case 0..<1: (r1, g1, b1) = (c, x, 0)
        case 1..<2: (r1, g1, b1) = (x, c, 0)
        case 2..<3: (r1, g1, b1) = (0, c, x)
        case 3..<4: (r1, g1, b1) = (0, x, c)
        case 4..<5: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return ((r1 + m) * 255, (g1 + m) * 255, (b1 + m) * 255)
    }

    static func label(_ score: Double) -> String {
        if score >= 0.5 { return "Very positive" }
        if score >= 0.15 { return "Positive" }
        if score > -0.15 { return "Steady" }
        if score > -0.5 { return "Mixed" }
        return "Heavy"
    }
}

/// Simple on-device keyword classifier standing in for a paid topic-tagging API.
/// Scans the transcript for whole-word/phrase matches against a small topic vocabulary.
enum TopicClassifier {
    static let vocabulary: [String: [String]] = [
        "Work": ["work", "job", "meeting", "office", "boss", "project", "colleague", "standup", "client", "deploy", "shipped", "release", "team", "coworker"],
        "Deadlines": ["deadline", "due", "overdue", "crunch", "behind schedule", "late night", "pushed up", "moved up"],
        "Friends": ["friend", "hang out", "hung out", "laugh", "buddy", "dinner with"],
        "Relationships": ["relationship", "partner", "boyfriend", "girlfriend", "husband", "wife", "mom", "dad", "family", "walk with"],
        "Sleep": ["sleep", "slept", "tired", "bed", "nap", "alarm", "insomnia", "woke up", "rest"],
        "Money": ["money", "budget", "bill", "pay", "expensive", "cost", "rent", "salary", "afford"],
    ]

    static func topics(in text: String, max: Int = 3) -> [String] {
        let lowered = text.lowercased()
        var scored: [(String, Int)] = []
        for (topic, keywords) in vocabulary {
            let count = keywords.reduce(0) { count, keyword in
                let pattern = "(?<![\\p{L}\\p{N}])\(NSRegularExpression.escapedPattern(for: keyword))(?![\\p{L}\\p{N}])"
                return count + (lowered.range(of: pattern, options: .regularExpression) == nil ? 0 : 1)
            }
            if count > 0 { scored.append((topic, count)) }
        }
        scored.sort { $0.1 > $1.1 }
        let top = scored.prefix(max).map(\.0)
        return top.isEmpty ? ["General"] : Array(top)
    }
}

/// Loads/saves journal entries as JSON in the app's Documents directory.
enum EntryStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("entries.json")
    }

    static func load() -> [JournalEntry]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([JournalEntry].self, from: data)
    }

    static func save(_ entries: [JournalEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func seedEntries() -> [JournalEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        func mk(_ offset: Int, _ mood: Double, _ topics: [String], _ text: String, _ time: String) -> JournalEntry {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            return JournalEntry(id: "seed-\(offset)", date: date, mood: mood, topics: topics, text: text, timeLabel: time)
        }
        return [
            mk(13, -0.2, ["Work"], "Spent most of the day untangling a bug that turned out to be a typo. Mostly just tired.", "9:12 PM"),
            mk(11, 0.6, ["Friends"], "Had dinner with Priya for the first time in months. Good to laugh about nothing in particular.", "7:48 PM"),
            mk(9, -0.6, ["Work", "Deadlines"], "The deadline moved up a week and nobody told me until standup. Feeling behind before the day even started.", "8:05 AM"),
            mk(8, 0.1, ["Sleep"], "Slept okay, not great. Woke up before the alarm again.", "7:30 AM"),
            mk(7, 0.7, ["Relationships"], "Long walk with Sam after work. Talked through the thing we'd been avoiding. Feels lighter.", "6:52 PM"),
            mk(6, -0.4, ["Work", "Deadlines"], "Another late night pushing the release. Tuesday deadlines are becoming a pattern I don't like.", "11:41 PM"),
            mk(5, 0.3, ["Sleep", "Work"], "Actually got to bed before midnight. Small win.", "7:15 AM"),
            mk(4, 0.8, ["Relationships", "Friends"], "Quiet Sunday. Called my mom, then read on the porch until it got dark.", "4:20 PM"),
            mk(3, -0.3, ["Money"], "Looked at the budget and didn't love what I saw. Nothing urgent, just annoying.", "9:03 PM"),
            mk(2, 0.5, ["Work"], "Shipped the feature. Team seemed relieved. So was I.", "6:37 PM"),
            mk(1, -0.5, ["Work", "Deadlines"], "Back-to-back meetings about a deadline that keeps moving. Hard to focus on anything else.", "10:58 PM"),
            mk(0, 0.4, ["Sleep", "Relationships"], "Slow morning. Coffee on the balcony before anyone else was up.", "8:42 AM"),
        ].sorted { $0.dayOffset < $1.dayOffset }
    }
}
