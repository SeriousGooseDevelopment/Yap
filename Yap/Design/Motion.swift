import SwiftUI

/// The prototype's motion vocabulary.
enum Motion {
    /// `cubic-bezier(.32,.72,0,1)` — iOS sheet/navigation easing, used for every slide.
    static func ios(_ duration: Double = 0.5) -> Animation { .timingCurve(0.32, 0.72, 0, 1, duration: duration) }
    /// `cubic-bezier(.2,.8,.2,1)` — staggered fade-ups and list changes.
    static func soft(_ duration: Double = 0.54) -> Animation { .timingCurve(0.2, 0.8, 0.2, 1, duration: duration) }
    /// `cubic-bezier(.3,1.6,.5,1)` — the springy release after a press.
    static let pop = Animation.spring(response: 0.36, dampingFraction: 0.55)
}

/// The prototype's `[data-st]` entrance: each block fades up 8pt, staggered 70ms by index,
/// starting 120ms after the screen arrives.
struct StaggerIn: ViewModifier {
    var index: Int
    var delay: Double = 0.12
    var distance: CGFloat = 8
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : distance)
            .onAppear {
                withAnimation(Motion.soft().delay(delay + Double(index) * 0.07)) { shown = true }
            }
    }
}

extension View {
    func staggerIn(_ index: Int, delay: Double = 0.12, distance: CGFloat = 8) -> some View {
        modifier(StaggerIn(index: index, delay: delay, distance: distance))
    }

    /// Horizontal shake for a rejected action (`[0,-9,8,-5,3,0]` over 400ms).
    func shake(_ trigger: Int) -> some View {
        keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { content, x in
            content.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-9, duration: 0.08)
                LinearKeyframe(8, duration: 0.08)
                LinearKeyframe(-5, duration: 0.08)
                LinearKeyframe(3, duration: 0.08)
                LinearKeyframe(0, duration: 0.08)
            }
        }
    }

    /// One-shot scale "pop" when `trigger` changes (`pop()` in the prototype).
    func popOnChange<T: Equatable>(of trigger: T, scale: CGFloat = 1.12) -> some View {
        keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { content, s in
            content.scaleEffect(s)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(scale, duration: 0.14)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
            }
        }
    }
}

/// Press feedback from the prototype's pointer handlers: buttons scale to 0.95 (cards to
/// 0.975) and spring back; list rows dim slightly instead (`data-press="bg"`).
struct PressStyle: ButtonStyle {
    enum Kind { case scale, soft, dim, none }
    var kind: Kind = .scale

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(kind == .scale && pressed ? 0.95 : kind == .soft && pressed ? 0.975 : 1)
            .brightness(kind == .dim && pressed ? -0.05 : 0)
            .animation(pressed ? .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.14) : Motion.pop, value: pressed)
    }
}

extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle(kind: .scale) }
    static var pressSoft: PressStyle { PressStyle(kind: .soft) }
    static var pressDim: PressStyle { PressStyle(kind: .dim) }
    static var pressNone: PressStyle { PressStyle(kind: .none) }
}

/// Lays out a screen against the prototype's 402×874 canvas: horizontal values are used
/// as-is, vertical offsets from the top scale with the screen height so shorter phones
/// keep the same proportions.
struct ScreenMetrics {
    var size: CGSize
    var safeTop: CGFloat
    var safeBottom: CGFloat

    func y(_ value: CGFloat) -> CGFloat { value * min(1.08, max(0.76, size.height / 874)) }

    /// iPhone SE-height screens (667pt), where the denser pages tighten up.
    var isCompact: Bool { size.height < 740 }

    /// Distance from the bottom edge for bars the prototype pins at `bottom: 41px` above a
    /// home indicator. Home-button phones (no bottom inset) get a smaller margin.
    func bottom(_ value: CGFloat) -> CGFloat { safeBottom > 0 ? value : max(12, value - 26) }
}

private struct ScreenMetricsKey: EnvironmentKey {
    static let defaultValue = ScreenMetrics(size: CGSize(width: 402, height: 874), safeTop: 62, safeBottom: 34)
}

extension EnvironmentValues {
    var screen: ScreenMetrics {
        get { self[ScreenMetricsKey.self] }
        set { self[ScreenMetricsKey.self] = newValue }
    }
}
