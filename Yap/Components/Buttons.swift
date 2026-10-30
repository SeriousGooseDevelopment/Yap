import SwiftUI

/// The prototype's filled blue capsule button.
struct PrimaryButton: View {
    var title: String
    var height: CGFloat = 56
    var weight: Font.Weight = .semibold
    /// Icon before the title (the mic on "Record first entry").
    var leading: Glyph? = nil
    /// Small arrow right after the title ("Get Started →").
    var inlineArrow = false
    /// Arrow pinned to the trailing edge ("Continue" on screens 03 and 05).
    var edgeArrow = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: leading == nil ? 8 : 12) {
                if let leading { GlyphView(glyph: leading, size: 24, lineWidth: 1.7) }
                Text(title)
                    .font(.sf(17, weight))
                    .tracking(-0.17)
                if inlineArrow { GlyphView(glyph: .arrowRight, size: 18, lineWidth: 2) }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .trailing) {
                if edgeArrow {
                    GlyphView(glyph: .arrowRightLong, size: height > 52 ? 26 : 22, lineWidth: 1.8)
                        .foregroundStyle(.white)
                        .padding(.trailing, 22)
                }
            }
            .background {
                Capsule()
                    .fill(Palette.yap)
                    .overlay(alignment: .top) {
                        // `inset 0 1px 0 rgba(255,255,255,.25)`
                        Capsule().fill(.white.opacity(0.25)).frame(height: 1).padding(.horizontal, height / 2)
                    }
                    .shadow(color: Palette.yap.opacity(0.35), radius: 12, x: 0, y: 12)
            }
        }
        .buttonStyle(.press)
    }
}

/// Blue text button under a primary button ("Sign In", "Not now").
struct TextButton: View {
    var title: String
    var height: CGFloat = 48
    var weight: Font.Weight = .medium
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.sf(17, weight))
                .foregroundStyle(Palette.yap)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(.press)
    }
}

/// 44pt round button on a soft fill (onboarding back, recorder "more").
struct RoundIconButton: View {
    var glyph: Glyph
    var size: CGFloat = 44
    var iconSize: CGFloat = 20
    var lineWidth: CGFloat = 2.2
    var fill: Color = Palette.fill
    var foreground: Color = Palette.ink
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundIconLabel(glyph: glyph, size: size, iconSize: iconSize, lineWidth: lineWidth, fill: fill, foreground: foreground)
        }
        .buttonStyle(.press)
        .accessibilityLabel(label)
    }
}

struct RoundIconLabel: View {
    var glyph: Glyph
    var size: CGFloat = 44
    var iconSize: CGFloat = 20
    var lineWidth: CGFloat = 2.2
    var fill: Color = Palette.fill
    var foreground: Color = Palette.ink

    var body: some View {
        GlyphView(glyph: glyph, size: iconSize, lineWidth: lineWidth)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .contentShape(Circle())
    }
}

/// "‹ Back" in the accent color (writing and reading screens).
struct BackLink: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                GlyphView(glyph: .chevronLeft, size: 22, lineWidth: 2.2)
                Text("Back").font(.sf(17))
            }
            .foregroundStyle(Palette.yap)
            .frame(height: 44)
            .padding(.trailing, 8)
        }
        .buttonStyle(.press)
    }
}

/// The 62pt blue mic button beside the tab bar and on the writing screen. Reports its
/// center so the recorder can grow out of it.
struct RecordButton: View {
    var label = "Record a thought"
    var action: (CGPoint) -> Void
    @State private var frame: CGRect = .zero

    var body: some View {
        Button {
            action(CGPoint(x: frame.midX, y: frame.midY))
        } label: {
            GlyphView(glyph: .mic, size: 26, lineWidth: 1.9)
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background {
                    Circle()
                        .fill(Palette.yap)
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.3)).frame(width: 30, height: 1).padding(.top, 1)
                        }
                        .shadow(color: Palette.yap.opacity(0.4), radius: 12, x: 0, y: 12)
                }
        }
        .buttonStyle(.press)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .accessibilityLabel(label)
    }
}
