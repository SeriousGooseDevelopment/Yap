import Foundation

enum InsightsRange: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }
}

/// Everything the Insights screen shows for one range, computed from real entries.
/// The prototype hardcodes its themes, quotes and "usually around 8 PM"; here they come
/// from the journal itself.
struct InsightsSummary {
    struct Bar: Identifiable {
        let id: Int
        /// Minutes spoken that day (week, month) or entries that month (year).
        var value: Double
        var isCurrent: Bool
    }

    struct Theme: Identifiable {
        var id: String { name }
        var name: String
        var count: Int
        var quote: String?
    }

    var count: Int
    var minutes: Int
    var streak: Int
    var unit: String
    var from: String
    var to: String
    var bars: [Bar]
    var longest: JournalEntry?
    var usualTime: String?
    var themes: [Theme]

    init(entries all: [JournalEntry], range: InsightsRange, now: Date = Date()) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let entries: [JournalEntry]
        switch range {
        case .week:
            let start = cal.date(byAdding: .day, value: -6, to: today) ?? today
            entries = all.filter { $0.date >= start }
            bars = (0..<7).map { i in
                let day = cal.date(byAdding: .day, value: i, to: start) ?? start
                let minutes = all.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
                return Bar(id: i, value: Double(minutes), isCurrent: i == 6)
            }
            unit = entries.count == 1 ? "entry this week" : "entries this week"
            from = start.formatted(.dateTime.weekday(.abbreviated).day())
            to = "Today"
        case .month:
            let start = cal.dateInterval(of: .month, for: today)?.start ?? today
            entries = all.filter { $0.date >= start }
            let days = cal.component(.day, from: today)
            bars = (0..<days).map { i in
                let day = cal.date(byAdding: .day, value: i, to: start) ?? start
                let minutes = all.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
                return Bar(id: i, value: Double(minutes), isCurrent: i == days - 1)
            }
            let month = today.formatted(.dateTime.month(.wide))
            unit = entries.count == 1 ? "entry in \(month)" : "entries in \(month)"
            from = start.formatted(.dateTime.month(.abbreviated).day())
            to = "Today"
        case .year:
            let start = cal.dateInterval(of: .year, for: today)?.start ?? today
            entries = all.filter { $0.date >= start }
            let months = cal.component(.month, from: today)
            bars = (0..<months).map { i in
                let month = cal.date(byAdding: .month, value: i, to: start) ?? start
                let n = all.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }.count
                return Bar(id: i, value: Double(n), isCurrent: i == months - 1)
            }
            let year = today.formatted(.dateTime.year())
            unit = entries.count == 1 ? "entry in \(year)" : "entries in \(year)"
            from = start.formatted(.dateTime.month(.abbreviated))
            to = today.formatted(.dateTime.month(.abbreviated))
        }

        count = entries.count
        minutes = entries.reduce(0) { $0 + $1.minutes }
        streak = Self.currentStreak(all, today: today)
        longest = entries.max { $0.seconds < $1.seconds }

        // Median time of day, rounded to the hour: "8 PM".
        let minutesOfDay = entries.map { cal.component(.hour, from: $0.date) * 60 + cal.component(.minute, from: $0.date) }.sorted()
        if minutesOfDay.isEmpty {
            usualTime = nil
        } else {
            let median = minutesOfDay[minutesOfDay.count / 2]
            let hour = Int((Double(median) / 60).rounded()) % 24
            usualTime = cal.date(bySettingHour: hour, minute: 0, second: 0, of: today)?.formatted(.dateTime.hour())
        }

        var counts: [String: Int] = [:]
        var mentions: [String: [JournalEntry]] = [:] // newest first
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            for theme in ThemeClassifier.themes(in: entry.plainText, max: ThemeClassifier.vocabulary.count) {
                counts[theme, default: 0] += 1
                mentions[theme, default: []].append(entry)
            }
        }
        let ranked: [(key: String, value: Int)] = counts.sorted { a, b in
            a.value != b.value ? a.value > b.value : a.key < b.key
        }
        // Each theme quotes its newest mention that another theme isn't already quoting.
        var used = Set<String>()
        themes = ranked.prefix(3).map { theme in
            let quotes = (mentions[theme.key] ?? []).compactMap { ThemeClassifier.quote(theme.key, in: $0.plainText) }
            let quote = quotes.first { !used.contains($0) } ?? quotes.first
            if let quote { used.insert(quote) }
            return Theme(name: theme.key, count: theme.value, quote: quote)
        }
    }

    /// Consecutive days with at least one entry, ending today — or yesterday, so the streak
    /// doesn't read zero all day before tonight's entry.
    static func currentStreak(_ entries: [JournalEntry], today: Date) -> Int {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.date) })
        var day = days.contains(today) ? today : (cal.date(byAdding: .day, value: -1, to: today) ?? today)
        var n = 0
        while days.contains(day) {
            n += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return n
    }
}

/// The calendar's 17-week heat map, Sunday-first columns ending with the current week.
struct HeatGrid {
    static let weeks = 17

    let start: Date
    let today: Date

    init(now: Date = Date()) {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        cal.timeZone = Calendar.current.timeZone
        today = Calendar.current.startOfDay(for: now)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        start = cal.date(byAdding: .day, value: -7 * (Self.weeks - 1), to: weekStart) ?? weekStart
    }

    var cellCount: Int { Self.weeks * 7 }

    func date(_ index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index, to: start) ?? start
    }

    func index(of date: Date) -> Int? {
        let d = Calendar.current.dateComponents([.day], from: start, to: Calendar.current.startOfDay(for: date)).day ?? -1
        return d >= 0 && d < cellCount ? d : nil
    }

    func isFuture(_ index: Int) -> Bool { date(index) > today }
}
