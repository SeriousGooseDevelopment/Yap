import SwiftUI
import UIKit

/// Design tokens from `Yap Prototype.dc.html`. The prototype only defines a light palette;
/// the dark values are this app's own, tuned so the same hierarchy (ink → secondary →
/// tertiary, white cards on a cool canvas, one blue accent) holds against a near-black
/// canvas. Every token is a dynamic color, so views never branch on the color scheme.
enum Palette {
    // Accent ramp (`--yap`, `--yap-deep`, `--yap-50/100/200`).
    static let yap = Color(light: 0x2F6BF2, dark: 0x5B8DFF)
    static let yapDeep = Color(light: 0x1F55D8, dark: 0x9DBBFF)
    static let yap50 = Color(light: 0xF4F7FE, dark: 0x101A2E)
    static let yap100 = Color(light: 0xE5EDFE, dark: 0x1A2A4D)
    static let yap200 = Color(light: 0xC6D6FC, dark: 0x2B4384)
    /// `color-mix(in srgb, var(--yap) 55%, #fff)` — the third heat-map step.
    static let yapMid = Color(light: 0x8DAEF8, dark: 0x3A5BA6)

    // Ink.
    static let ink = Color(light: 0x0D1B2E, dark: 0xEEF2F8)
    static let ink2 = Color(light: 0x4F5D73, dark: 0xA3AEC0)
    static let ink3 = Color(light: 0x6B788C, dark: 0x8390A5)
    static let placeholder = Color(light: 0xA3ADBD, dark: 0x5F6B80)
    /// Words the recognizer may still revise.
    static let interim = Color(light: 0x8592A6, dark: 0x6F7C92)
    static let chevron = Color(light: 0xA3ADBD, dark: 0x5F6B80)
    static let iconInk = Color(light: 0x2E3A4E, dark: 0xC9D2E0)
    static let danger = Color(light: 0xC4382F, dark: 0xFF6B5E)

    // Surfaces.
    /// Full-bleed screens (onboarding, recording, reading, writing).
    static let screen = Color(light: 0xFFFFFF, dark: 0x0B0F17)
    /// Tab screens sit on a cool canvas so white cards lift off it.
    static let canvas = Color(light: 0xF5F7FB, dark: 0x0B0F17)
    static let card = Color(light: 0xFFFFFF, dark: 0x161D29)
    static let cardStack1 = Color(light: 0xFAFBFC, dark: 0x131A25)
    static let cardStack2 = Color(light: 0xF4F5F8, dark: 0x10161F)
    /// `#F2F3F6` circular buttons and the notification preview.
    static let fill = Color(light: 0xF2F3F6, dark: 0x1E2633)
    /// `rgba(13,27,46,.05)` soft button fill.
    static let fillSoft = Color(light: 0x0D1B2E, dark: 0xFFFFFF, lightAlpha: 0.05, darkAlpha: 0.08)
    /// `rgba(13,27,46,.06)` segmented-control track.
    static let track = Color(light: 0x0D1B2E, dark: 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.09)
    static let progressTrack = Color(light: 0xE3E7EE, dark: 0x263041)
    static let heatEmpty = Color(light: 0xEBEEF3, dark: 0x1E2633)
    static let barIdle = Color(light: 0x4F5D73, dark: 0x7C889C)
    static let dotIdle = Color(light: 0x0D1B2E, dark: 0xFFFFFF, lightAlpha: 0.14, darkAlpha: 0.18)
    static let separator = Color(light: 0x0D1B2E, dark: 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.12)
    static let hairline = Color(light: 0x0D1B2E, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.08)
    static let grabber = Color(light: 0xD9DEE6, dark: 0x3A4456)
    static let radioRing = Color(light: 0xC5CCD8, dark: 0x4A5568)
    /// Frosted floating bars (`rgba(255,255,255,.84)` over a blur).
    static let frost = Color(light: 0xFFFFFF, dark: 0x1A2230, lightAlpha: 0.84, darkAlpha: 0.82)
    static let shadow = Color(light: 0x0D1B2E, dark: 0x000000, lightAlpha: 1, darkAlpha: 1)

    /// UIKit mirrors for the text views.
    enum UI {
        static let ink = UIColor(light: 0x0D1B2E, dark: 0xEEF2F8)
        static let ink2 = UIColor(light: 0x4F5D73, dark: 0xA3AEC0)
        static let yap = UIColor(light: 0x2F6BF2, dark: 0x5B8DFF)
        static let yap100 = UIColor(light: 0xE5EDFE, dark: 0x1A2A4D)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }

    convenience init(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        self.init { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: alpha))
    }

    init(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) {
        self.init(uiColor: UIColor(light: light, dark: dark, lightAlpha: lightAlpha, darkAlpha: darkAlpha))
    }
}

extension View {
    /// The prototype's card recipe: white fill, a 0.5pt hairline ring, and a soft drop
    /// shadow (`0 0 0 .5px rgba(13,27,46,.06), 0 10px 24px -16px rgba(13,27,46,.22)`).
    func yapCard(radius: CGFloat, fill: Color = Palette.card, shadow: Double = 0.07) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .shadow(color: Palette.shadow.opacity(shadow), radius: 12, x: 0, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 0.5)
                }
        }
    }

    /// Frosted floating bar used by the tab bar, recorder controls, and the player.
    func yapFrost<S: InsettableShape>(_ shape: S, tint: Color = Palette.frost) -> some View {
        background {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(tint))
                .overlay(shape.strokeBorder(Palette.hairline, lineWidth: 0.5))
                .shadow(color: Palette.shadow.opacity(0.12), radius: 15, x: 0, y: 10)
        }
    }
}
