import SwiftUI

/// A quiet paper-and-ink palette for a journal whose primary material is the user's own
/// words. Blue is reserved for actions; mood is shown with both color and a clear label.
struct Theme {
    let dark: Bool
    let highContrast: Bool

    init(dark: Bool, highContrast: Bool = false) {
        self.dark = dark
        self.highContrast = highContrast
    }

    var bg: Color { dark ? Color(hex: 0x151A17) : Color(hex: 0xF7F6F1) }
    var cardBg: Color { dark ? Color(hex: 0x202722) : Color(hex: 0xFFFEFA) }
    var textPrimary: Color {
        if highContrast { return dark ? Color.white : Color(hex: 0x111411) }
        return dark ? Color(hex: 0xF3F2EB) : Color(hex: 0x242A27)
    }
    var textSecondary: Color {
        if highContrast { return dark ? Color.white : Color(hex: 0x111411) }
        return dark ? Color(hex: 0xB7C0B9) : Color(hex: 0x626B65)
    }
    var textTertiary: Color { textSecondary }
    var separator: Color { dark ? Color(hex: 0x3A433D) : Color(hex: 0xDEE1DA) }
    var trackBg: Color { dark ? Color(hex: 0x333C36) : Color(hex: 0xE5E8E2) }
    var emptyCell: Color { dark ? Color(hex: 0x27302A) : Color(hex: 0xE9EBE5) }
    var accent: Color { dark ? Color(hex: 0x8EB6D6) : Color(hex: 0x3F6687) }
    var pillBg: Color { dark ? Color(hex: 0x29322C) : Color(hex: 0xEAEFEA) }
    var pillBorder: Color { dark ? Color(hex: 0x465148) : Color(hex: 0xD8DED7) }
    var todayRing: Color { accent }

    func moodColor(_ score: Double) -> Color {
        let c = Mood.color(score, dark: dark)
        return Color(red: c.r / 255, green: c.g / 255, blue: c.b / 255)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
