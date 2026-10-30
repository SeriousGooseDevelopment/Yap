import SwiftUI

/// Prototype screens 01–09. Steps slide like a navigation stack (the new screen in from the
/// right, the old one drifting 120pt left), under a shared chrome with back, six progress
/// dashes and Skip.
struct OnboardingFlow: View {
    enum Step: Int, CaseIterable {
        case welcome, talk, privacy, name, microphone, reminder, faceID, allSet

        /// 1...6 for the progress dashes; nil where the chrome is hidden.
        var progress: Int? {
            switch self {
            case .welcome, .allSet: return nil
            default: return rawValue
            }
        }

        var next: Step? { Step(rawValue: rawValue + 1) }
        var previous: Step? { self == .welcome ? nil : Step(rawValue: rawValue - 1) }

        var skip: Step? {
            switch self {
            case .talk, .privacy: return .name
            case .microphone: return .reminder
            case .reminder: return .faceID
            case .faceID: return .allSet
            default: return nil
            }
        }
    }

    @EnvironmentObject private var store: Store
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.screen) private var screen
    @State private var step: Step = Self.launchStep
    @State private var forward = true

    /// DEBUG screenshot hook: `-onboardingStep name` opens a given step.
    private static var launchStep: Step {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-onboardingStep"), i + 1 < args.count,
           let step = Step.allCases.first(where: { "\($0)" == args[i + 1] }) {
            return step
        }
        #endif
        return .welcome
    }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.screen.ignoresSafeArea()

            page(step)
                .id(step)
                .zIndex(Double(step.rawValue))
                .transition(forward
                    ? .asymmetric(insertion: .move(edge: .trailing), removal: .offset(x: -120))
                    : .asymmetric(insertion: .offset(x: -120), removal: .move(edge: .trailing)))

            if let progress = step.progress {
                chrome(progress: progress)
                    .zIndex(100)
                    .transition(forward
                        ? .asymmetric(insertion: .move(edge: .trailing), removal: .offset(x: -120).combined(with: .opacity))
                        : .asymmetric(insertion: .offset(x: -120).combined(with: .opacity), removal: .move(edge: .trailing)))
            }
        }
    }

    @ViewBuilder
    private func page(_ step: Step) -> some View {
        switch step {
        case .welcome:
            WelcomeScreen(start: { go(.talk) }, signIn: finish)
        case .talk:
            JustTalkScreen(next: { go(.privacy) })
        case .privacy:
            PrivacyScreen(next: { go(.name) })
        case .name:
            NameScreen(next: { go(.microphone) })
        case .microphone:
            MicrophoneScreen(next: { go(.reminder) })
        case .reminder:
            ReminderScreen(next: { go(.faceID) })
        case .faceID:
            FaceIDScreen(next: { go(.allSet) })
        case .allSet:
            AllSetScreen(recordFirst: recordFirst, toJournal: finish)
        }
    }

    private func chrome(progress: Int) -> some View {
        HStack {
            RoundIconButton(glyph: .chevronLeft, label: "Back") {
                if let previous = step.previous { go(previous, forward: false) }
            }
            Spacer()
            HStack(spacing: 5) {
                ForEach(1...6, id: \.self) { i in
                    Capsule()
                        .fill(Palette.progressTrack)
                        .frame(width: 24, height: 4)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Palette.yap)
                                .scaleEffect(x: i <= progress ? 1 : 0.001, anchor: .leading)
                                .animation(Motion.ios(0.55).delay(i == progress ? 0.14 : 0), value: progress)
                        }
                        .clipShape(Capsule())
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Step \(progress) of 6")
            Spacer()
            Button("Skip") {
                if let skip = step.skip { go(skip) }
            }
            .font(.sf(16))
            .foregroundStyle(Palette.ink2)
            .frame(width: 44, alignment: .trailing)
            .opacity(step.skip == nil ? 0 : 1)
            .allowsHitTesting(step.skip != nil)
            .animation(.easeOut(duration: 0.3), value: step.skip == nil)
        }
        .frame(height: 44)
        .padding(.leading, 14)
        .padding(.trailing, 20)
        .padding(.top, screen.y(58))
        .ignoresSafeArea(.container, edges: .top)
    }

    private func go(_ target: Step, forward isForward: Bool = true) {
        forward = isForward
        // Let the outgoing page pick up the new direction before it's removed.
        DispatchQueue.main.async {
            withAnimation(Motion.ios(isForward ? 0.56 : 0.5)) { step = target }
        }
    }

    private func finish() {
        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.44)) { prefs.onboarded = true }
    }

    private func recordFirst() {
        finish()
        let origin = CGPoint(x: screen.size.width - 20 - 31, y: screen.size.height - screen.bottom(41) - 31)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
            store.startRecording(from: origin)
        }
    }
}

/// Screen 01.
struct WelcomeScreen: View {
    var start: () -> Void
    var signIn: () -> Void
    @Environment(\.screen) private var screen

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                EllipticalGradient(colors: [Palette.yap100, Palette.yap100.opacity(0)], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.64)
                    .frame(width: geo.size.width * 2.2, height: geo.size.height * 1.04)
                    .position(x: geo.size.width / 2, y: 0)
            }

            SilkLines()
                .frame(height: 230)
                .padding(.top, screen.y(436))

            VStack(spacing: 0) {
                Wordmark(size: 100)
                    .padding(.trailing, 8)
                Text("Speak. Reflect. Be you.")
                    .font(.news(27))
                    .tracking(-0.27)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 24)
                Text("Turn your voice into a beautiful journal in real time.")
                    .font(.sf(16))
                    .sfLines(16, lineHeight: 1.45)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, screen.y(188))
            .staggerIn(0)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    GlyphView(glyph: .lock, size: 14, lineWidth: 2)
                    Text("Transcribed on your iPhone. Private by default.")
                }
                .font(.sf(13))
                .foregroundStyle(Palette.ink2)
                .padding(.bottom, 8)
                PrimaryButton(title: "Get Started", inlineArrow: true, action: start)
                TextButton(title: "Sign In", action: signIn)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, screen.bottom(40))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .staggerIn(2)
        }
        .background(Palette.screen)
        .ignoresSafeArea()
    }
}

/// Screen 02.
struct JustTalkScreen: View {
    var next: () -> Void
    @Environment(\.screen) private var screen

    var body: some View {
        ZStack(alignment: .top) {
            SoftGlow(size: 500, strength: 0.08)
                .position(x: 201, y: screen.y(60) + 250)

            sampleCard
                .padding(.horizontal, 36)
                .padding(.top, screen.y(140))
                .staggerIn(0)

            OnboardingTitle(
                title: "Just talk. Yap writes it down.",
                message: "Speak the way you think. Your words appear as you go, ready to read, edit and play back later."
            )
            .padding(.top, screen.y(486))
            .staggerIn(1)

            VStack(spacing: 6) {
                PrimaryButton(title: "Continue", action: next)
                Color.clear.frame(height: 48)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, screen.bottom(40))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .staggerIn(2)
        }
        .background(Palette.screen)
        .ignoresSafeArea()
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            MiniWave()
                .frame(height: 58)
                .frame(maxWidth: .infinity)
            TimelineView(.periodic(from: .now, by: 0.55)) { context in
                let caretOn = Int(context.date.timeIntervalSinceReferenceDate / 0.55) % 2 == 0
                let lighter = Text("lighter.").foregroundStyle(Palette.interim)
                let caret = Text("|").foregroundStyle(caretOn ? Palette.yap : Color.clear)
                Text("I finally had a moment to slow down tonight, and I’m grateful for the people who make things feel \(lighter)\(caret)")
                    .foregroundStyle(Palette.ink)
                    .font(.news(21))
                    .newsLines(21, lineHeight: 1.45)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 22, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.card)
                .shadow(color: Palette.shadow.opacity(0.12), radius: 22, x: 0, y: 22)
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5))
        }
        .background(alignment: .top) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Palette.cardStack2)
                    .shadow(color: Palette.shadow.opacity(0.06), radius: 10, x: 0, y: 8)
                    .padding(.horizontal, 32)
                    .offset(y: 28)
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Palette.cardStack1)
                    .shadow(color: Palette.shadow.opacity(0.08), radius: 12, x: 0, y: 10)
                    .padding(.horizontal, 16)
                    .offset(y: 14)
            }
        }
    }
}

/// Screen 03. The prototype's sixth pill read "Synced with your iCloud"; Yap keeps entries
/// on the device only, so that pill describes the app lock instead.
struct PrivacyScreen: View {
    var next: () -> Void
    @Environment(\.screen) private var screen

    var body: some View {
        ZStack(alignment: .top) {
            GlyphView(glyph: .lockLarge, size: 56, lineWidth: 1.6)
                .foregroundStyle(Palette.iconInk)
                .position(x: 201, y: screen.y(273) + 28)
                .frame(maxWidth: .infinity)
                .staggerIn(0)

            PrivacyPills()

            OnboardingTitle(
                title: "Private by design.",
                message: "Speech becomes text right on this iPhone. Your entries stay on this iPhone, and nothing goes to a server unless you choose Clean Up.",
                size: 36,
                gap: 14
            )
            .padding(.top, screen.y(524))
            .staggerIn(1)

            PrimaryButton(title: "Continue", height: 52, weight: .medium, edgeArrow: true, action: next)
                .padding(.horizontal, 26)
                .padding(.bottom, screen.bottom(63))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .staggerIn(2)
        }
        .background(Palette.screen)
        .ignoresSafeArea()
    }
}

/// The floating "Recorded here / Transcribed here / …" pills on screen 03, each rising in,
/// drifting up and fading on a nine-second loop, staggered 1.5s apart.
struct PrivacyPills: View {
    @Environment(\.screen) private var screen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Pill {
        var text: String
        var glyph: Glyph
        var leading: CGFloat?
        var trailing: CGFloat?
        var top: CGFloat
    }

    private let pills: [Pill] = [
            Pill(text: "Recorded here", glyph: .pillMic, leading: 48, top: 198),
            Pill(text: "Transcribed here", glyph: .pillWave, trailing: 12, top: 317),
            Pill(text: "Optional \(AppLock.biometry.name) lock", glyph: .lock, leading: 64, top: 392),
            Pill(text: "No server by default", glyph: .pillShield, trailing: 36, top: 172),
            Pill(text: "Stored here", glyph: .pillPhone, leading: 30, top: 300),
            Pill(text: "Clean Up only if you ask", glyph: .pillSpark, trailing: 28, top: 418),
        ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                ForEach(pills.indices, id: \.self) { k in
                    let pill = pills[k]
                    let state = reduceMotion ? (opacity: k < 3 ? 1.0 : 0.0, y: 0.0, scale: 1.0) : Self.state(at: t, index: k)
                    HStack(spacing: 9) {
                        GlyphView(glyph: pill.glyph, size: 18, lineWidth: 1.8).foregroundStyle(Palette.iconInk)
                        Text(pill.text)
                            .font(.sf(13.5, .medium))
                            .tracking(-0.07)
                            .foregroundStyle(Palette.ink)
                            .fixedSize()
                    }
                    .padding(.leading, 13)
                    .padding(.trailing, 15)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(Palette.card)
                            .shadow(color: Palette.shadow.opacity(0.1), radius: 13, x: 0, y: 10)
                            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.5))
                    )
                    .scaleEffect(state.scale)
                    .offset(y: state.y)
                    .opacity(state.opacity)
                    .frame(maxWidth: .infinity, alignment: pill.leading != nil ? .leading : .trailing)
                    .padding(.leading, pill.leading ?? 0)
                    .padding(.trailing, pill.trailing ?? 0)
                    .padding(.top, screen.y(pill.top))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recorded, transcribed and stored on this iPhone. No server by default.")
    }

    /// `yapPill`: rise in by 7%, drift up until 40%, gone by 44% of the 9s cycle.
    private static func state(at t: Double, index k: Int) -> (opacity: Double, y: Double, scale: Double) {
        let period = 9.0
        let at = ((3.5 - 1.5 * Double(k)).truncatingRemainder(dividingBy: period) + period).truncatingRemainder(dividingBy: period)
        let p = ((t + at).truncatingRemainder(dividingBy: period)) / period
        switch p {
        case ..<0.07:
            let e = backOut(p / 0.07)
            return (min(1, e), 10 * (1 - e), 0.9 + 0.1 * e)
        case ..<0.40:
            return (1, -8 * (p - 0.07) / 0.33, 1)
        case ..<0.44:
            let e = pow((p - 0.40) / 0.04, 2)
            return (1 - e, -8 - 5 * e, 1 - 0.02 * e)
        default:
            return (0, -13, 0.98)
        }
    }

    /// Approximates `cubic-bezier(.2,.9,.3,1.25)`: a quick rise with a slight overshoot.
    private static func backOut(_ x: Double) -> Double {
        let c = 1.2
        return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2)
    }
}

/// Screen 04.
struct NameScreen: View {
    var next: () -> Void
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.screen) private var screen
    @FocusState private var focused: Bool
    @State private var shakes = 0

    private var valid: Bool { !prefs.firstName.isEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.screen.ignoresSafeArea()

            OnboardingTitle(
                title: "What should Yap call you?",
                message: "Used in greetings and reminders. You can change it in Settings."
            )
            .padding(.top, screen.y(128))
            .staggerIn(0)
            .ignoresSafeArea(.container, edges: .top)

            VStack(alignment: .leading, spacing: 8) {
                Text("First name").font(.sf(13, .medium)).foregroundStyle(Palette.ink3)
                TextField("", text: Binding(get: { prefs.name }, set: { prefs.name = String($0.prefix(24)) }),
                          prompt: Text("Your name").foregroundStyle(Palette.placeholder))
                    .font(.news(34))
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.yap)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit(advance)
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.yap).frame(height: 2) }
                    .shake(shakes)
            }
            .padding(.horizontal, 28)
            .padding(.top, screen.y(300))
            .staggerIn(1)
            .ignoresSafeArea(.container, edges: .top)

            // Rides on top of the keyboard, like the prototype's Continue.
            PrimaryButton(title: "Continue", action: advance)
                .opacity(valid ? 1 : 0.4)
                .animation(.easeOut(duration: 0.25), value: valid)
                .padding(.horizontal, 24)
                .padding(.bottom, focused ? 14 : 6)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    private func advance() {
        guard valid else {
            shakes += 1
            return
        }
        prefs.name = prefs.firstName
        focused = false
        next()
    }
}

/// Screen 05. "Allow access" brings up the real system prompts (screen 06 is iOS's own).
struct MicrophoneScreen: View {
    var next: () -> Void
    @Environment(\.screen) private var screen
    @State private var asking = false

    var body: some View {
        ZStack(alignment: .top) {
            GrowBars(bars: GrowBars.microphone)
                .frame(height: 70)
                .position(x: screen.size.width / 2, y: screen.isCompact ? 132 : screen.y(263.6))

            VStack(alignment: .leading, spacing: screen.isCompact ? 24 : 40) {
                OnboardingTitle(
                    title: "Yap listens only when you ask.",
                    message: "Allow the microphone and speech recognition so Yap can turn your voice into text.",
                    size: 36,
                    lineHeight: 1.05,
                    gap: 18
                )
                .staggerIn(0)

                VStack(alignment: .leading, spacing: 17) {
                    permissionRow(.mic, "Microphone", "Hears you while you record")
                    permissionRow(.speech, "Speech recognition", "Writes down what you say, on this iPhone")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .staggerIn(1)
            }
            .padding(.top, screen.isCompact ? 206 : screen.y(396))

            VStack(spacing: 7) {
                PrimaryButton(title: "Allow access", height: 52, weight: .medium, edgeArrow: true) {
                    guard !asking else { return }
                    asking = true
                    Task {
                        _ = await AudioPermission.request()
                        _ = await SpeechPermission.request()
                        asking = false
                        next()
                    }
                }
                TextButton(title: "Not now", height: 44, action: next)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, screen.bottom(41))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .staggerIn(2)
        }
        .background(Palette.screen)
        .ignoresSafeArea()
    }

    private func permissionRow(_ glyph: Glyph, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 25) {
            GlyphView(glyph: glyph, size: 28, lineWidth: 1.6).foregroundStyle(Palette.ink2)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.sf(16, .semibold)).foregroundStyle(Palette.ink).frame(minHeight: 20)
                Text(detail).font(.sf(14)).foregroundStyle(Palette.ink2).frame(minHeight: 20)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Screen 07.
struct ReminderScreen: View {
    var next: () -> Void
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.screen) private var screen
    @State private var showCustom = false
    @State private var replay = 0
    @State private var asking = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                OnboardingTitle(
                    title: "When do you like to reflect?",
                    message: "One gentle reminder a day. Change it or turn it off anytime."
                )
                .staggerIn(0)

                VStack(spacing: 0) {
                    row(.morning, "Morning", Preferences.ClockTime(hour: 8, minute: 0).label, separator: true)
                    row(.evening, "Evening", Preferences.ClockTime(hour: 21, minute: 0).label, separator: true)
                    row(.custom, "Custom time", prefs.reminderPreset == .custom ? prefs.customReminder.label : "", separator: false)
                }
                .background(Palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .staggerIn(1)

                // The preview is a nicety; SE-height screens need the room for the buttons.
                if !screen.isCompact {
                    Text("Preview")
                        .font(.sf(13, .medium))
                        .foregroundStyle(Palette.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 28)

                    NotificationPreview(time: prefs.reminderTime.label, message: Reminders.body(for: prefs.name), replay: replay)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }
            }
            .padding(.top, screen.y(128))

            VStack(spacing: 6) {
                PrimaryButton(title: "Turn on reminders") {
                    guard !asking else { return }
                    asking = true
                    Task {
                        let allowed = await Reminders.requestAuthorization()
                        prefs.remindersOn = allowed
                        if allowed {
                            Reminders.schedule(hour: prefs.reminderTime.hour, minute: prefs.reminderTime.minute, name: prefs.name)
                        }
                        asking = false
                        next()
                    }
                }
                TextButton(title: "Not now") {
                    prefs.remindersOn = false
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
        .sheet(isPresented: $showCustom) {
            TimeWheelSheet(title: "Custom time", initial: prefs.customReminder) { time in
                prefs.customReminder = time
                prefs.reminderPreset = .custom
                replay += 1
            }
        }
    }

    private func row(_ preset: Preferences.ReminderPreset, _ label: String, _ time: String, separator: Bool) -> some View {
        let on = prefs.reminderPreset == preset
        return Button {
            if preset == .custom {
                showCustom = true
            } else if !on {
                withAnimation(.easeOut(duration: 0.3)) { prefs.reminderPreset = preset }
                replay += 1
            }
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(.sf(16.5, on ? .semibold : .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(time)
                    .font(.sf(15, on ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(on ? Palette.yap : Palette.ink3)
                if preset == .custom {
                    GlyphView(glyph: .chevronRight, size: 14, lineWidth: 2.4).foregroundStyle(Palette.chevron)
                } else {
                    Circle()
                        .strokeBorder(Palette.radioRing, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Circle()
                                .fill(Palette.yap)
                                .overlay(GlyphView(glyph: .check, size: 15, lineWidth: 2.6).foregroundStyle(.white))
                                .scaleEffect(on ? 1 : 0.001)
                                .opacity(on ? 1 : 0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: on)
                        }
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 64)
            .background(on ? Palette.yap50 : Palette.card)
            .overlay(alignment: .bottom) {
                if separator { Rectangle().fill(Palette.separator.opacity(0.8)).frame(height: 0.5).padding(.leading, 18) }
            }
        }
        .buttonStyle(.pressDim)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The reminder preview card; drops in from above each time the time changes.
struct NotificationPreview: View {
    var time: String
    var message: String
    var replay: Int
    @State private var hidden = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
                .frame(width: 38, height: 38)
                .overlay(GlyphView(glyph: .yapMark, size: 30, lineWidth: 2).foregroundStyle(Palette.yap))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Yap").font(.sf(15, .semibold)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(time).font(.sf(13)).foregroundStyle(Palette.ink3)
                }
                Text(message)
                    .font(.sf(15))
                    .sfLines(15, lineHeight: 1.35)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.fill))
        .opacity(hidden ? 0 : 1)
        .offset(y: hidden && !reduceMotion ? -30 : 0)
        .scaleEffect(hidden && !reduceMotion ? 0.94 : 1)
        .blur(radius: hidden && !reduceMotion ? 2 : 0)
        .accessibilityElement(children: .combine)
        .onAppear { drop(after: 0.38) }
        .onChange(of: replay) { drop(after: 0) }
    }

    private func drop(after delay: Double) {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { hidden = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.02) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) { hidden = false }
        }
    }
}
