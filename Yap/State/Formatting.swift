import Foundation

/// Date and text formatting shared by the screens, matching the prototype's strings
/// ("8:14" + "PM" on cards, "Monday, Oct 26 · 8:14 PM · 2 min" on the reading screen).
enum Fmt {
    /// Whether the user's locale shows a 12-hour clock.
    static var uses12Hour: Bool {
        (DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }

    private static func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    private static let hm12 = { let f = DateFormatter(); f.locale = .current; f.dateFormat = "h:mm"; return f }()
    private static let ampm = { let f = DateFormatter(); f.locale = .current; f.dateFormat = "a"; return f }()
    private static let hm24 = formatter("Hm")

    /// Card time column: ("8:14", "PM"), or ("20:14", "") on a 24-hour clock.
    static func clockParts(_ date: Date) -> (time: String, period: String) {
        uses12Hour ? (hm12.string(from: date), ampm.string(from: date)) : (hm24.string(from: date), "")
    }

    static func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }

    static func minutes(_ entry: JournalEntry) -> String { "\(entry.minutes) min" }

    /// "Monday, Oct 26 · 8:14 PM · 2 min"
    static func readingMeta(_ entry: JournalEntry) -> String {
        let day = entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return "\(day) · \(time(entry.date)) · \(minutes(entry))"
    }

    /// "Oct 26 · 8:14 PM · 2 min"
    static func searchMeta(_ entry: JournalEntry) -> String {
        "\(entry.date.formatted(.dateTime.month(.abbreviated).day())) · \(time(entry.date)) · \(minutes(entry))"
    }

    /// "Oct 26, 2026 · 8:14 PM"
    static func writingDate(_ date: Date) -> String {
        "\(date.formatted(.dateTime.month(.abbreviated).day().year())) · \(time(date))"
    }

    /// "Monday, October 26"
    static func longDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// "October 2026"
    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    /// "2:08"
    static func clock(_ seconds: Double) -> String {
        let t = max(0, Int(seconds.rounded(.down)))
        return "\(t / 60):" + String(format: "%02d", t % 60)
    }

    static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }

    /// The prototype's `snip`: cut at a word boundary and end with an ellipsis.
    static func snippet(_ text: String, limit: Int = 64) -> String {
        guard text.count > limit else { return text }
        let cut = String(text.prefix(limit))
        let atWord = cut.range(of: " ", options: .backwards).map { String(cut[..<$0.lowerBound]) } ?? cut
        return atWord.trimmingCharacters(in: CharacterSet(charactersIn: ",.;:")) + "…"
    }

    /// The prototype's `around`: a window of text around the first match of `query`.
    static func around(_ text: String, query: String) -> String {
        guard let match = text.range(of: query, options: .caseInsensitive) else { return snippet(text, limit: 80) }
        let matchStart = text.distance(from: text.startIndex, to: match.lowerBound)
        let windowStart = max(0, matchStart - 28)
        var start = text.index(text.startIndex, offsetBy: windowStart)
        if windowStart > 0, let space = text[..<start].range(of: " ", options: .backwards) {
            start = space.upperBound
        } else if windowStart > 0 {
            start = text.startIndex
        }
        let endOffset = min(text.count, text.distance(from: text.startIndex, to: match.upperBound) + 50)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        let body = text[start..<end].trimmingCharacters(in: .whitespaces)
        return (start > text.startIndex ? "…" : "") + body + (end < text.endIndex ? "…" : "")
    }
}
