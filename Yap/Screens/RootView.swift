import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: Theme {
        Theme(dark: colorScheme == .dark, highContrast: colorSchemeContrast == .increased)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NavigationStack {
                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 22)
                            .padding(.top, 12)
                            .padding(.bottom, 18)

                        Picker("Journal section", selection: $store.segment) {
                            Text("Journal").tag(Segment.dashboard)
                            Text("Patterns").tag(Segment.insights)
                        }
                        .pickerStyle(.segmented)
                        .tint(theme.accent)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                        ScrollView(.vertical) {
                            Group {
                                if store.segment == .dashboard {
                                    DashboardView(theme: theme)
                                } else {
                                    InsightsView(theme: theme)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            recordAction
                        }
                    }
                    .background(theme.bg.ignoresSafeArea())
                    .navigationDestination(isPresented: detailIsPresented) {
                        DetailView(theme: theme)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .accessibilityHidden(store.recordingOpen)

                RecordingView(transcriber: store.transcriber, theme: theme)
                    .offset(y: store.recordingOpen ? 0 : geometry.size.height)
                    .opacity(store.recordingOpen ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.4),
                        value: store.recordingOpen
                    )
                    .allowsHitTesting(store.recordingOpen)
                    .accessibilityHidden(!store.recordingOpen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Microphone access needed", isPresented: $store.micDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow microphone access in Settings so Yap can transcribe your entries on-device.")
        }
        .alert("Couldn't start transcription", isPresented: Binding(
            get: { store.transcriberError != nil },
            set: { if !$0 { store.transcriberError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.transcriberError ?? "")
        }
    }

    private var detailIsPresented: Binding<Bool> {
        Binding(
            get: { store.detailEntry != nil },
            set: { isPresented in
                if !isPresented, store.detailEntry != nil {
                    store.closeDetail()
                }
            }
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Yap")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var recordAction: some View {
        Button(action: store.startNewRecording) {
            Label("Record a thought", systemImage: "mic.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 18))
        .tint(theme.accent)
        .accessibilityHint("Starts a new voice journal entry")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(theme.bg.ignoresSafeArea())
        .allowsHitTesting(!store.recordingOpen && store.detailEntry == nil)
        .opacity(store.recordingOpen || store.detailEntry != nil ? 0 : 1)
    }
}
