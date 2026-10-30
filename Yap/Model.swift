import Foundation
import UIKit
import AVFoundation

struct JournalEntry: Identifiable, Codable, Equatable {
    let id: String
    var date: Date
    /// Rough on-device sentiment estimate from -1 (more negative wording) to 1 (more positive wording).
    var mood: Double
    var topics: [String]
    /// The entry's words. Paragraphs are separated by a blank line; `**bold**` and
    /// `*italic*` spans come from the writing screen's Format menu.
    var text: String
    /// Superseded by `date` formatting; kept optional so older `entries.json` files decode.
    var timeLabel: String? = nil
    /// Peak-amplitude buckets (0...1) for the entry's recording, or nil for entries with no
    /// stored audio. Optional so old `entries.json` files without this field still decode.
    var waveform: [Float]? = nil
    /// User-editable title. Entries saved before titles existed derive one from their text.
    var title: String? = nil
    /// Length of the stored recording in seconds.
    var duration: Double? = nil
    /// File name of an attached photo in `PhotoStore`.
    var photo: String? = nil

    var hasAudio: Bool { waveform?.isEmpty == false }
    var audioURL: URL { EntryAudioStore.fileURL(for: id) }

    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        return Self.autoTitle(from: InlineMarkdown.plain(text))
    }

    var paragraphs: [String] { Self.paragraphs(in: text) }
    var plainText: String { paragraphs.map(InlineMarkdown.plain).joined(separator: " ") }

    /// Seconds of audio, or a reading-pace estimate (150 wpm) for text-only entries.
    var seconds: Double {
        if let duration, duration > 0 { return duration }
        let words = plainText.split(whereSeparator: \.isWhitespace).count
        return max(20, Double(words) / 150 * 60)
    }

    /// Whole minutes as shown on cards ("2 min"); never zero, as in the prototype.
    var minutes: Int { max(1, Int((seconds / 60).rounded())) }

    static func paragraphs(in text: String) -> [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The prototype titles a new recording with its first four words.
    static func autoTitle(from text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace).prefix(4).joined(separator: " ")
        let trimmed = words.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:—–-"))
        guard let first = trimmed.first else { return "New entry" }
        return first.uppercased() + trimmed.dropFirst()
    }
}

/// Transcript → paragraphs, as the prototype does it: sentences, two per paragraph.
enum TranscriptFormatter {
    static func sentences(_ text: String) -> [String] {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return [] }
        var result: [String] = []
        var current = ""
        for ch in collapsed {
            current.append(ch)
            if ".!?".contains(ch) {
                result.append(current)
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { result.append(current) }
        return result.compactMap { raw in
            let s = raw.trimmingCharacters(in: .whitespaces)
            guard let first = s.first else { return nil }
            let capitalized = first.uppercased() + s.dropFirst()
            return ".!?".contains(capitalized.last!) ? capitalized : capitalized + "."
        }
    }

    static func paragraphs(_ text: String) -> [String] {
        let s = sentences(text)
        return stride(from: 0, to: s.count, by: 2).map { s[$0..<min($0 + 2, s.count)].joined(separator: " ") }
    }
}

/// `**bold**` / `*italic*` inline spans — the only formatting the writing screen offers.
enum InlineMarkdown {
    struct Run {
        var text: String
        var bold: Bool
        var italic: Bool
    }

    static func plain(_ text: String) -> String {
        runs(text).map(\.text).joined()
    }

    /// Splits one paragraph into styled runs. Unmatched markers are kept as literal text.
    static func runs(_ text: String) -> [Run] {
        let chars = Array(text)
        var result: [Run] = []
        var bold = false, italic = false
        var buffer = ""
        var i = 0
        func flush() {
            if !buffer.isEmpty { result.append(Run(text: buffer, bold: bold, italic: italic)) }
            buffer = ""
        }
        func closes(_ marker: String, from index: Int) -> Bool {
            String(chars[index...]).contains(marker)
        }
        while i < chars.count {
            if chars[i] == "*" {
                let isDouble = i + 1 < chars.count && chars[i + 1] == "*"
                let marker = isDouble ? "**" : "*"
                let opening = isDouble ? !bold : !italic
                if !opening || closes(marker, from: i + marker.count) {
                    flush()
                    if isDouble { bold.toggle() } else { italic.toggle() }
                    i += marker.count
                    continue
                }
            }
            buffer.append(chars[i])
            i += 1
        }
        flush()
        return result
    }

    /// Wraps a styled run, keeping surrounding whitespace outside the markers.
    static func wrap(_ text: String, bold: Bool, italic: Bool) -> String {
        guard bold || italic else { return text }
        let core = text.trimmingCharacters(in: .whitespaces)
        guard !core.isEmpty else { return text }
        let leading = String(text.prefix(while: { $0 == " " }))
        let trailing = String(text.reversed().prefix(while: { $0 == " " }))
        let marker = (bold ? "**" : "") + (italic ? "*" : "")
        return leading + marker + core + String(marker.reversed()) + trailing
    }
}

/// On-device keyword themes for Insights and for each entry's `topics`. Replaces the
/// prototype's three hardcoded themes ("Gratitude", "Focus", "Rest") with the same
/// vocabulary plus a few more, matched as whole words in the entry text.
enum ThemeClassifier {
    static let vocabulary: [(name: String, keywords: [String])] = [
        ("Gratitude", ["grateful", "thankful", "gratitude", "appreciate", "appreciated", "blessed", "lucky"]),
        ("Focus", ["focus", "focused", "productive", "finished", "concentrate", "distracted", "distraction", "deep work"]),
        ("Rest", ["rest", "rested", "slept", "sleep", "nap", "tired", "relax", "relaxed", "recharge", "reset"]),
        ("Work", ["work", "job", "meeting", "office", "boss", "project", "client", "deadline", "coworker", "colleague", "team"]),
        ("Family", ["mom", "dad", "family", "sister", "brother", "parents", "kids", "son", "daughter", "grandma", "grandpa"]),
        ("Friends", ["friend", "friends", "hang out", "hung out", "laughed", "dinner with"]),
        ("Health", ["run", "ran", "walk", "walked", "gym", "workout", "exercise", "yoga", "doctor", "sick"]),
        ("Love", ["partner", "boyfriend", "girlfriend", "husband", "wife", "date night", "relationship"]),
        ("Money", ["money", "budget", "bill", "bills", "rent", "salary", "afford", "expensive"]),
        ("Stress", ["stressed", "anxious", "worried", "overwhelmed", "pressure", "behind"]),
    ]

    /// Range of the first keyword match for `theme` in `text`, if any.
    static func match(_ theme: String, in text: String) -> Range<String.Index>? {
        guard let keywords = vocabulary.first(where: { $0.name == theme })?.keywords else { return nil }
        var best: Range<String.Index>?
        for keyword in keywords {
            let pattern = "(?<![\\p{L}\\p{N}])\(NSRegularExpression.escapedPattern(for: keyword))(?![\\p{L}\\p{N}])"
            if let r = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
               best == nil || r.lowerBound < best!.lowerBound {
                best = r
            }
        }
        return best
    }

    static func themes(in text: String, max: Int = 3) -> [String] {
        let scored = vocabulary.compactMap { theme -> (String, Int)? in
            let count = theme.keywords.filter { match(theme.name, keyword: $0, in: text) }.count
            return count > 0 ? (theme.name, count) : nil
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(max).map(\.0)
    }

    private static func match(_ theme: String, keyword: String, in text: String) -> Bool {
        let pattern = "(?<![\\p{L}\\p{N}])\(NSRegularExpression.escapedPattern(for: keyword))(?![\\p{L}\\p{N}])"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// A short quote around the theme's first keyword, cut at clause boundaries:
    /// "…grateful for a slow morning before everyone woke up." Starts at the clause the
    /// keyword is in, or at the keyword itself when that clause runs long.
    static func quote(_ theme: String, in text: String) -> String? {
        guard let r = match(theme, in: text) else { return nil }
        let boundaries = ",;.!?\n"
        let clauseStart = text[..<r.lowerBound].lastIndex(where: { boundaries.contains($0) }).map { text.index(after: $0) } ?? text.startIndex
        let sentenceStart = clauseStart == text.startIndex || ".!?\n".contains(text[text.index(before: clauseStart)])
        let end = text[r.upperBound...].firstIndex(where: { boundaries.contains($0) }) ?? text.endIndex

        var clause = text[clauseStart..<end].trimmingCharacters(in: .whitespaces)
        var lowercaseFirst = sentenceStart
        if clause.split(separator: " ").count > 12 {
            clause = text[r.lowerBound..<end].split(separator: " ").prefix(12).joined(separator: " ")
            lowercaseFirst = sentenceStart && text[clauseStart..<r.lowerBound].trimmingCharacters(in: .whitespaces).isEmpty
        }
        // A sentence-initial capital isn't part of the quote ("Grateful for…" → "…grateful for…"), but "I" stays.
        if lowercaseFirst, let first = clause.first, !(first == "I" && (clause.count == 1 || !clause.dropFirst().first!.isLetter)) {
            clause = first.lowercased() + clause.dropFirst()
        }
        return "“…\(clause).”"
    }
}

/// Loads/saves journal entries as JSON in the app's Documents directory.
enum EntryStore {
    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("entries.json")
    }

    static func load() -> [JournalEntry]? {
        guard let data = try? Data(contentsOf: fileURL),
              var entries = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return nil }
        // Entries recorded before durations were stored: read the length off the audio file once.
        var migrated = false
        for i in entries.indices where entries[i].duration == nil && entries[i].hasAudio {
            if let file = try? AVAudioFile(forReading: entries[i].audioURL), file.fileFormat.sampleRate > 0 {
                entries[i].duration = Double(file.length) / file.fileFormat.sampleRate
                migrated = true
            }
        }
        if migrated { save(entries) }
        return entries
    }

    static func save(_ entries: [JournalEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// DEBUG-only demo journal for screenshots (`-seedDemo`). Mirrors the prototype's
    /// sample entries, dated relative to today. Never written for a real user.
    static func seedEntries() -> [JournalEntry] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func mk(_ id: String, _ dayOffset: Int, _ hour: Int, _ minute: Int, _ title: String, _ paragraphs: [String], _ seconds: Double) -> JournalEntry {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            let text = paragraphs.joined(separator: "\n\n")
            return JournalEntry(id: "seed-\(id)", date: date, mood: 0.4, topics: ThemeClassifier.themes(in: text), text: text, title: title, duration: seconds)
        }
        return [
            mk("1", 0, 20, 14, "A clearer mind", ["Today I finally had a moment to slow down and think about what matters. I’ve been feeling more clear lately, and I’m grateful for the people in my life who make it feel lighter.", "I want to keep building good habits, staying consistent, and focusing on what I can control."], 128),
            mk("2", 0, 12, 3, "Good day", ["Got a lot done today. Feeling grateful and excited for what’s next. The review went better than I expected, and I left before six for once.", "I want to remember how it felt to be ahead of things instead of chasing them."], 236),
            mk("3", 0, 8, 11, "Morning thoughts", ["Woke up early, feeling motivated. I want to make the most of this week before it gets busy again.", "Coffee on the balcony and no phone for the first twenty minutes. That helped more than I expected."], 184),
            mk("4", 1, 21, 2, "Slow Sunday", ["Spent most of the day at home. Read, cooked, called Dad. Nothing big happened and that was the point."], 170),
            mk("5", 2, 19, 48, "The long walk", ["Walked all the way to the river and back. I kept thinking about the conversation with Sam and what I actually want from the next year.", "I don’t need to decide tonight. It helps to say it out loud, though."], 352),
            mk("6", 3, 20, 31, "Small wins", ["Finally finished the draft without opening my email. Focus is easier when I decide the night before what the morning is for."], 118),
            mk("7", 4, 22, 5, "Tired but okay", ["Long day. I’m tired but okay. Slept badly last night, so tonight is an early one."], 70),
            mk("8", 10, 21, 40, "Rest", ["Slept nine hours and it felt like a reset. I forget how much better everything is when I actually rest."], 58),
            mk("9", 14, 20, 22, "Gratitude list", ["Grateful for a slow morning before everyone woke up, for the bakery on the corner, and for Mia checking in."], 64),
            mk("10", 18, 7, 15, "Before work", ["Quiet start. I want today to be about one thing only: the proposal."], 49),
        ]
    }
}

/// Photos attached to entries, stored as JPEGs next to `entries.json`.
enum PhotoStore {
    private static let cache = NSCache<NSString, UIImage>()

    private static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for name: String) -> URL { directory.appendingPathComponent(name) }

    /// Downscales to at most 2048pt on the long edge and writes a JPEG. Returns its file name.
    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let longEdge = max(image.size.width, image.size.height)
        let scale = min(1, 2048 / max(1, longEdge))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: url(for: name), options: .atomic)
        } catch {
            return nil
        }
        cache.setObject(resized, forKey: name as NSString)
        return name
    }

    static func image(_ name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: url(for: name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: url(for: name))
    }

    static func deleteAll() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
    }
}
