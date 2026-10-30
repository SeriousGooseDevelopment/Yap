import Foundation
import ActivityKit
import AppIntents

/// The recording Live Activity (prototype screen 18): recording keeps going when the phone
/// locks, with the elapsed time, a level snapshot and a Stop button on the Lock Screen.
/// Compiled into both the app and the widget extension.
struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Wall-clock start of the current running stretch, offset by time already recorded,
        /// so `Text(timerInterval:)` can count on its own between updates.
        var timerStart: Date
        var elapsed: TimeInterval
        var isPaused: Bool
        /// Recent input levels (0...1), oldest first.
        var levels: [Double]
    }

    /// "New entry" or "Adding to entry".
    var context: String
}

/// The Live Activity's Stop button. As a `LiveActivityIntent` it runs in the app's process,
/// where `RecordingIntentBridge.handler` finishes the recording exactly like tapping Stop.
struct StopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop and Save"
    static var description = IntentDescription("Stops the current Yap recording and keeps it as a draft.")

    func perform() async throws -> some IntentResult {
        await RecordingIntentBridge.stop()
        return .result()
    }
}

@MainActor
enum RecordingIntentBridge {
    /// Set by the app's `Store`; nil inside the widget extension.
    static var handler: (() -> Void)?

    static func stop() { handler?() }
}
