import SwiftUI

/// Serif headline plus supporting copy, the block every onboarding screen uses.
struct OnboardingTitle: View {
    var title: String
    var message: String
    var size: CGFloat = 34
    var lineHeight: CGFloat = 1.12
    var gap: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            Text(title)
                .font(.news(size, 500))
                .tracking(-0.02 * size)
                .newsLines(size, lineHeight: lineHeight)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.sf(16.5))
                .sfLines(16.5, lineHeight: 1.5)
                .foregroundStyle(Palette.ink2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
    }
}

/// The faint accent halo behind onboarding illustrations.
struct SoftGlow: View {
    var size: CGFloat
    var strength: Double = 0.08

    var body: some View {
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: Palette.yap.opacity(strength), location: 0),
                .init(color: Palette.yap.opacity(strength * 0.4), location: 0.55),
                .init(color: Palette.yap.opacity(0), location: 1),
            ], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Screen 08. Turning the lock on asks for Face ID (or Touch ID / passcode) once, so it
/// can never be enabled on a device that can't unlock it.
struct FaceIDScreen: View {
    var next: () -> Void
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.screen) private var screen
    @State private var phase = Phase.idle
    @State private var scans = 0
    @State private var tick: CGFloat = 0
    @State private var pops = 0

    enum Phase { case idle, scanning, done }

    private let biometry = AppLock.biometry

    var body: some View {
        ZStack(alignment: .top) {
            SoftGlow(size: 500)
                .position(x: screen.size.width / 2, y: screen.y(20) + 250)

            face
                .frame(width: 132, height: 132)
                .position(x: screen.size.width / 2, y: screen.y(199) + 66)

            OnboardingTitle(
                title: "Keep it just for you.",
                message: biometry == .none
                    ? "Lock Yap with your passcode. Your entries are also hidden in the app switcher."
                    : "Lock Yap with \(biometry.name). Your entries are also hidden in the app switcher."
            )
            .padding(.top, screen.y(430))
            .staggerIn(1)

            VStack(spacing: 6) {
                PrimaryButton(title: "Use \(biometry.name)", action: enable)
                TextButton(title: "Not now") {
                    prefs.lockEnabled = false
                    next()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, screen.bottom(40))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .staggerIn(2)
        }
        .background(Palette.screen)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var face: some View {
        Group {
            if phase == .done {
                ZStack {
                    GlyphView(glyph: .faceFrame, size: 132, lineWidth: 0.6)
                    TickShape()
                        .trim(from: 0, to: tick)
                        .stroke(style: StrokeStyle(lineWidth: 0.6 * 132 / 19, lineCap: .round, lineJoin: .round))
                }
                .popOnChange(of: pops, scale: 1.08)
            } else if biometry == .faceID {
                GlyphView(glyph: .faceID, size: 132, lineWidth: 0.6)
            } else {
                ZStack {
                    GlyphView(glyph: .faceFrame, size: 132, lineWidth: 0.6)
                    Image(systemName: biometry == .touchID ? "touchid" : biometry == .opticID ? "opticid" : "lock")
                        .font(.system(size: 54, weight: .ultraLight))
                }
            }
        }
        .foregroundStyle(Palette.yap)
        .keyframeAnimator(initialValue: Scan(), trigger: scans) { view, s in
            view
                .scaleEffect(s.scale)
                .rotation3DEffect(.degrees(s.angle), axis: (x: 0, y: 1, z: 0))
                .opacity(s.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                CubicKeyframe(20, duration: 0.33)
                CubicKeyframe(-20, duration: 0.34)
                CubicKeyframe(0, duration: 0.33)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.9, duration: 0.33)
                CubicKeyframe(0.94, duration: 0.34)
                CubicKeyframe(1, duration: 0.33)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(0.35, duration: 0.25)
                LinearKeyframe(1, duration: 0.25)
                LinearKeyframe(0.35, duration: 0.25)
                LinearKeyframe(1, duration: 0.25)
            }
        }
        .accessibilityHidden(true)
    }

    private struct Scan {
        var angle: Double = 0
        var scale: CGFloat = 1
        var opacity: Double = 1
    }

    private func enable() {
        guard phase == .idle else { return }
        phase = .scanning
        scans += 1
        Task {
            let ok = await AppLock.authenticate(reason: "Lock Yap with \(biometry.name)")
            guard ok else {
                phase = .idle
                return
            }
            prefs.lockEnabled = true
            phase = .done
            tick = 0
            withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.48)) { tick = 1 }
            pops += 1
            try? await Task.sleep(nanoseconds: 900_000_000)
            next()
        }
    }
}

/// The check drawn inside the Face ID frame once the lock is on.
private struct TickShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 19
        return Glyph.faceTick.applying(
            CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -2.5, y: -2.5)
        )
    }
}

/// Screen 09.
struct AllSetScreen: View {
    var recordFirst: () -> Void
    var toJournal: () -> Void
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.screen) private var screen

    var body: some View {
        ZStack(alignment: .top) {
            Ellipse()
                .fill(EllipticalGradient(stops: [
                    .init(color: Palette.yap.opacity(0.09), location: 0),
                    .init(color: Palette.yap.opacity(0.04), location: 0.5),
                    .init(color: Palette.yap.opacity(0), location: 1),
                ], center: .center))
                .frame(width: 380, height: 340)
                .position(x: screen.size.width / 2, y: screen.y(126) + 170)

            GrowBars(bars: GrowBars.allSet)
                .frame(height: 110)
                .position(x: screen.size.width / 2, y: screen.y(296))

            VStack(spacing: 15) {
                Text(prefs.firstName.isEmpty ? "You’re all set." : "You’re all set, \(prefs.firstName).")
                    .font(.news(38, 500))
                    .tracking(-0.76)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Palette.ink)
                Text("Tap the mic and talk about anything. How today went is a good place to start.")
                    .font(.sf(16))
                    .lineSpacing(23.5 - 19)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, screen.y(472))
            .staggerIn(1)

            VStack(spacing: 6) {
                PrimaryButton(title: "Record first entry", height: 52, weight: .medium, leading: .mic, action: recordFirst)
                TextButton(title: "Go to my journal", height: 44, weight: .regular, action: toJournal)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, screen.bottom(65))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .staggerIn(2)
        }
        .background(Palette.screen)
        .ignoresSafeArea()
    }
}
