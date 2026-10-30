import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var lock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoom

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            // The window's own insets leave the keyboard out, unlike the proxy's.
            let window = Self.windowInsets ?? UIEdgeInsets(top: insets.top, left: 0, bottom: insets.bottom, right: 0)
            let metrics = ScreenMetrics(
                size: CGSize(width: geo.size.width + insets.leading + insets.trailing, height: geo.size.height + insets.top + insets.bottom),
                safeTop: window.top,
                safeBottom: window.bottom
            )
            ZStack {
                Group {
                    if prefs.onboarded {
                        mainStack
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.985)), removal: .opacity))
                    } else {
                        OnboardingFlow()
                            .transition(.opacity)
                    }
                }
                // The page behind the recorder sinks back while the recorder grows over it.
                .scaleEffect(store.recording == nil ? 1 : 0.94)
                .brightness(store.recording == nil ? 0 : -0.08)
                .accessibilityHidden(store.recording != nil)

                if let session = store.recording {
                    RecordingView(transcriber: store.transcriber, session: session)
                        .transition(recorderTransition(session.origin))
                        .zIndex(10)
                }

                ToastOverlay(toast: store.toast, safeTop: metrics.safeTop)
                    .ignoresSafeArea()
                    .zIndex(30)

                if lock.isLocked {
                    LockScreen()
                        .transition(.opacity)
                        .zIndex(40)
                }

                if prefs.hideInSwitcher && prefs.onboarded && scenePhase != .active && !lock.isLocked && !store.systemPromptActive {
                    PrivacyCover()
                        .zIndex(50)
                }
            }
            .environment(\.screen, metrics)
        }
        .background(Palette.screen.ignoresSafeArea())
        .alert(store.alert?.title ?? "", isPresented: alertShown, presenting: store.alert) { alert in
            ForEach(alert.actions.indices, id: \.self) { i in
                let action = alert.actions[i]
                Button(action.label, role: action.role) {
                    store.alert = nil
                    DispatchQueue.main.async { action.run() }
                }
            }
        } message: { alert in
            Text(alert.message)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                store.player.pause()
                if prefs.lockEnabled && prefs.onboarded { lock.lock() }
            case .active:
                if lock.isLocked { lock.unlock() }
            default:
                break
            }
        }
    }

    private static var windowInsets: UIEdgeInsets? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets
    }

    private var alertShown: Binding<Bool> {
        Binding(get: { store.alert != nil }, set: { if !$0 { store.alert = nil } })
    }

    private var mainStack: some View {
        NavigationStack(path: $store.path) {
            TabsRoot(zoom: zoom)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .reading(let id, let zoomed):
                        if zoomed {
                            ReadingView(id: id, player: store.player)
                                .navigationTransition(.zoom(sourceID: id, in: zoom))
                        } else {
                            ReadingView(id: id, player: store.player)
                        }
                    case .writing:
                        WritingView()
                    }
                }
        }
    }

    /// Opens as a circle growing from the record button; leaves either by shrinking back
    /// into it (discarded) or by lifting away to reveal the draft (saved).
    private func recorderTransition(_ origin: CGPoint) -> AnyTransition {
        let reveal = AnyTransition.modifier(
            active: CircleReveal(radius: 31, center: origin),
            identity: CircleReveal(radius: 1100, center: origin)
        )
        switch store.recordingExit {
        case .settle:
            return .asymmetric(insertion: reveal, removal: .opacity.combined(with: .offset(y: -16)))
        case .unreveal:
            return .asymmetric(insertion: reveal, removal: reveal.combined(with: .opacity))
        }
    }
}

/// Journal (with its calendar), Insights and Settings under the floating tab bar.
struct TabsRoot: View {
    var zoom: Namespace.ID
    @EnvironmentObject private var store: Store
    @Environment(\.screen) private var screen

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            Group {
                switch store.tab {
                case .journal: JournalView(zoom: zoom)
                case .insights: InsightsView()
                case .settings: SettingsView()
                }
            }
            .id(store.tab)
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity))

            TabBar()
                .padding(.bottom, max(0, screen.bottom(41) - screen.safeBottom))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.keyboard)
        }
    }
}

/// Covers the journal until Face ID (or the passcode) unlocks it.
struct LockScreen: View {
    @EnvironmentObject private var lock: AppLock
    private let biometry = AppLock.biometry

    var body: some View {
        ZStack {
            Palette.screen.ignoresSafeArea()
            VStack(spacing: 18) {
                Wordmark(size: 64)
                GlyphView(glyph: .lock, size: 22, lineWidth: 2).foregroundStyle(Palette.ink2)
                Text("Your journal is locked")
                    .font(.sf(15))
                    .foregroundStyle(Palette.ink2)
            }
            PrimaryButton(title: biometry == .none ? "Unlock" : "Unlock with \(biometry.name)", height: 52, weight: .medium) {
                lock.unlock()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// Shown while Yap is in the app switcher, so entries never appear in its snapshot.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Palette.screen
            Wordmark(size: 64)
        }
        .ignoresSafeArea()
    }
}

/// Keeps the edge-swipe back gesture working with the navigation bar hidden.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1 && NavigationGate.allowsPop
    }
}
