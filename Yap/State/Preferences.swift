import Foundation
import SwiftUI

/// Everything the user chooses in onboarding and Settings, persisted in `UserDefaults`.
@MainActor
final class Preferences: ObservableObject {
    enum ReminderPreset: String { case morning, evening, custom }
    enum Appearance: String, CaseIterable { case automatic = "Automatic", light = "Light", dark = "Dark" }
    enum ExportFormat: String, CaseIterable { case markdown = "Markdown", pdf = "PDF", plainText = "Plain text" }

    /// A wall-clock time for the daily reminder.
    struct ClockTime: Equatable {
        var hour: Int // 0...23
        var minute: Int

        var label: String {
            var parts = DateComponents()
            parts.hour = hour
            parts.minute = minute
            let date = Calendar.current.date(from: parts) ?? Date()
            return date.formatted(date: .omitted, time: .shortened)
        }
    }

    private let defaults: UserDefaults

    @Published var name: String { didSet { defaults.set(name, forKey: "name") } }
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var reminderPreset: ReminderPreset { didSet { defaults.set(reminderPreset.rawValue, forKey: "reminderPreset") } }
    @Published var customReminder: ClockTime {
        didSet {
            defaults.set(customReminder.hour, forKey: "customReminderHour")
            defaults.set(customReminder.minute, forKey: "customReminderMinute")
        }
    }
    @Published var remindersOn: Bool { didSet { defaults.set(remindersOn, forKey: "remindersOn") } }
    @Published var lockEnabled: Bool { didSet { defaults.set(lockEnabled, forKey: "lockEnabled") } }
    @Published var hideInSwitcher: Bool { didSet { defaults.set(hideInSwitcher, forKey: "hideInSwitcher") } }
    /// "Voice & Transcription": on-device only, or Clean Up allowed to use a server.
    @Published var cleanUpAllowed: Bool { didSet { defaults.set(cleanUpAllowed, forKey: "cleanUpAllowed") } }
    @Published var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    @Published var exportFormat: ExportFormat { didSet { defaults.set(exportFormat.rawValue, forKey: "exportFormat") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        name = defaults.string(forKey: "name") ?? ""
        onboarded = defaults.bool(forKey: "onboarded")
        reminderPreset = ReminderPreset(rawValue: defaults.string(forKey: "reminderPreset") ?? "") ?? .evening
        customReminder = ClockTime(
            hour: defaults.object(forKey: "customReminderHour") as? Int ?? 7,
            minute: defaults.object(forKey: "customReminderMinute") as? Int ?? 30
        )
        remindersOn = defaults.bool(forKey: "remindersOn")
        lockEnabled = defaults.bool(forKey: "lockEnabled")
        hideInSwitcher = defaults.object(forKey: "hideInSwitcher") as? Bool ?? true
        cleanUpAllowed = defaults.bool(forKey: "cleanUpAllowed")
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .automatic
        exportFormat = ExportFormat(rawValue: defaults.string(forKey: "exportFormat") ?? "") ?? .markdown
    }

    var reminderTime: ClockTime {
        switch reminderPreset {
        case .morning: return ClockTime(hour: 8, minute: 0)
        case .evening: return ClockTime(hour: 21, minute: 0)
        case .custom: return customReminder
        }
    }

    var firstName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var initials: String {
        let letters = firstName.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "Y" : letters.joined()
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func reset() {
        for key in ["name", "onboarded", "reminderPreset", "customReminderHour", "customReminderMinute",
                    "remindersOn", "lockEnabled", "hideInSwitcher", "cleanUpAllowed", "appearance", "exportFormat"] {
            defaults.removeObject(forKey: key)
        }
    }
}
