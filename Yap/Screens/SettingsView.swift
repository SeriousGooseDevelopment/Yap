import SwiftUI

/// Prototype screen 17. Rows open native menus, the reminder time sheet or alerts.
struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var lock: AppLock
    @Environment(\.screen) private var screen
    @Environment(\.openURL) private var openURL
    @State private var showReminderSheet = false
    @State private var editingName = false
    @State private var nameDraft = ""

    /// The prototype's support address. Replace with a mailbox you own before shipping.
    static let supportEmail = "support@yap.app"

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0"
    }

    private let biometry = AppLock.biometry

    var body: some View {
        ZStack(alignment: .top) {
            Palette.canvas

            Text("Settings")
                .font(.news(36, 500))
                .tracking(-0.72)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.top, screen.y(60))

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    profile
                    section("Journal") {
                        reminderRow
                        voiceRow
                        appearanceRow
                        privacyRow
                        exportRow
                    }
                    section("Support") {
                        row(.help, "Help & Support", separator: true) { showHelp() }
                        row(.info, "About Yap", separator: false) { showAbout() }
                    }
                    deleteAllRow
                    Text("Yap \(version)")
                        .font(.sf(12))
                        .foregroundStyle(Palette.ink3)
                        .frame(maxWidth: .infinity)
                }
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 170, trailing: 20))
            }
            .scrollIndicators(.hidden)
            .padding(.top, screen.y(112))
        }
        .ignoresSafeArea(.container)
        .sheet(isPresented: $showReminderSheet) {
            TimeWheelSheet(title: "Daily reminder", initial: prefs.reminderTime, canTurnOff: prefs.remindersOn, onDone: setReminder) {
                prefs.remindersOn = false
                Reminders.cancel()
                store.showToast("Reminders turned off")
            }
        }
        .alert("Your name", isPresented: $editingName) {
            TextField("First name", text: $nameDraft)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                prefs.name = String(trimmed.prefix(24))
                if prefs.remindersOn {
                    Reminders.schedule(hour: prefs.reminderTime.hour, minute: prefs.reminderTime.minute, name: prefs.name)
                }
            }
        } message: {
            Text("Used in greetings and reminders.")
        }
    }

    // MARK: Rows

    private var profile: some View {
        Button {
            nameDraft = prefs.name
            editingName = true
        } label: {
            HStack(spacing: 14) {
                Text(prefs.initials)
                    .font(.news(19, 500))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Palette.track))
                VStack(alignment: .leading, spacing: 2) {
                    Text(prefs.firstName.isEmpty ? "You" : prefs.firstName).font(.sf(17, .semibold)).foregroundStyle(Palette.ink)
                    Text("Stored only on this iPhone").font(.sf(13)).foregroundStyle(Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                chevron
            }
            .frame(height: 72)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressDim)
        .accessibilityHint("Edit your name")
    }

    private var reminderRow: some View {
        row(.bell, "Notifications", value: prefs.remindersOn ? prefs.reminderTime.label : "Off", separator: true) {
            showReminderSheet = true
        }
    }

    private var voiceRow: some View {
        Menu {
            Picker("Voice & Transcription", selection: $prefs.cleanUpAllowed) {
                Text("On-device").tag(false)
                Text("Clean Up allowed").tag(true)
            }
        } label: {
            rowLabel(.voice, "Voice & Transcription", value: prefs.cleanUpAllowed ? "Clean Up allowed" : "On-device", separator: true)
        }
        .menuOrder(.fixed)
    }

    private var appearanceRow: some View {
        Menu {
            Picker("Appearance", selection: $prefs.appearance) {
                ForEach(Preferences.Appearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        } label: {
            rowLabel(.appearance, "Appearance", value: prefs.appearance.rawValue, separator: true)
        }
        .menuOrder(.fixed)
    }

    private var privacyRow: some View {
        Menu {
            Toggle("Lock with \(biometry.name)", isOn: Binding(get: { prefs.lockEnabled }, set: setLock))
            Toggle("Hide in app switcher", isOn: $prefs.hideInSwitcher)
        } label: {
            rowLabel(.shield, "Privacy", value: prefs.lockEnabled ? "\(biometry.name) on" : "Off", separator: true)
        }
        .menuOrder(.fixed)
    }

    private var exportRow: some View {
        Menu {
            Picker("Format", selection: $prefs.exportFormat) {
                ForEach(Preferences.ExportFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Divider()
            Button("Export now", action: exportNow)
                .disabled(store.entries.isEmpty)
        } label: {
            rowLabel(.export, "Export", value: prefs.exportFormat.rawValue, separator: false)
        }
        .menuOrder(.fixed)
    }

    private var deleteAllRow: some View {
        Button {
            store.alert = AppAlert(
                title: "Delete all entries?",
                message: "This removes every entry, recording and photo from this iPhone. It can’t be undone.",
                actions: [
                    AppAlert.Action(label: "Cancel", role: .cancel),
                    AppAlert.Action(label: "Delete", role: .destructive) { store.deleteAll() },
                ]
            )
        } label: {
            HStack(spacing: 14) {
                GlyphView(glyph: .trash, size: 22, lineWidth: 1.8)
                Text("Delete all entries").font(.sf(16.5))
                Spacer()
            }
            .foregroundStyle(Palette.danger)
            .frame(height: 50)
            .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressDim)
        .disabled(store.entries.isEmpty)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.sf(17, .semibold)).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
        }
    }

    private func row(_ glyph: Glyph, _ title: String, value: String? = nil, separator: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(glyph, title, value: value, separator: separator)
        }
        .buttonStyle(.pressDim)
    }

    private func rowLabel(_ glyph: Glyph, _ title: String, value: String? = nil, separator: Bool) -> some View {
        HStack(spacing: 14) {
            GlyphView(glyph: glyph, size: 22, lineWidth: 1.8).foregroundStyle(Palette.ink2)
            Text(title).font(.sf(16.5)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, alignment: .leading)
            if let value { Text(value).font(.sf(15)).foregroundStyle(Palette.ink3) }
            chevron
        }
        .frame(height: 50)
        .overlay(alignment: .bottom) {
            if separator { Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 36) }
        }
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        GlyphView(glyph: .chevronRight, size: 14, lineWidth: 2.4).foregroundStyle(Palette.chevron)
    }

    // MARK: Actions

    private func setReminder(_ time: Preferences.ClockTime) {
        Task {
            guard await store.withSystemPrompt({ await Reminders.requestAuthorization() }) else {
                store.alert = AppAlert(
                    title: "Notifications are off",
                    message: "Allow notifications for Yap in Settings to get a daily reminder.",
                    actions: [
                        AppAlert.Action(label: "Not Now", role: .cancel),
                        AppAlert.Action(label: "Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        },
                    ]
                )
                return
            }
            if time == Preferences.ClockTime(hour: 8, minute: 0) {
                prefs.reminderPreset = .morning
            } else if time == Preferences.ClockTime(hour: 21, minute: 0) {
                prefs.reminderPreset = .evening
            } else {
                prefs.customReminder = time
                prefs.reminderPreset = .custom
            }
            prefs.remindersOn = true
            Reminders.schedule(hour: time.hour, minute: time.minute, name: prefs.name)
            store.showToast("Reminder set for \(time.label)")
        }
    }

    private func setLock(_ on: Bool) {
        guard on else {
            prefs.lockEnabled = false
            lock.clear()
            return
        }
        Task {
            if await store.withSystemPrompt({ await AppLock.authenticate(reason: "Lock Yap with \(biometry.name)") }) {
                prefs.lockEnabled = true
            }
        }
    }

    private func exportNow() {
        let count = store.entries.count
        guard let url = Exporter.exportJournal(store.entries, format: prefs.exportFormat) else { return }
        SharePresenter.present([url]) { completed in
            if completed { store.showToast("Exported \(Fmt.count(count, "entry", "entries"))") }
        }
    }

    private func showHelp() {
        store.alert = AppAlert(
            title: "Help & Support",
            message: "Write to \(Self.supportEmail) and a person will reply within a day.",
            actions: [
                AppAlert.Action(label: "Close", role: .cancel),
                AppAlert.Action(label: "Email us") {
                    if let url = URL(string: "mailto:\(Self.supportEmail)?subject=Yap%20\(version)") { openURL(url) }
                },
            ]
        )
    }

    private func showAbout() {
        store.alert = AppAlert(
            title: "Yap \(version)",
            message: "Your entries stay on this iPhone. Speech is transcribed on the device, and nothing is sent anywhere unless you choose Clean Up.",
            actions: [AppAlert.Action(label: "OK", role: .cancel)]
        )
    }
}
