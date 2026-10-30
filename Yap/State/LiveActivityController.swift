import Foundation
import ActivityKit

/// Starts, updates and ends the recording Live Activity. Every call is a no-op when Live
/// Activities are turned off for Yap.
@MainActor
final class LiveActivityController {
    private var activity: Activity<RecordingActivityAttributes>?

    /// Ends activities left over from a recording the app didn't get to finish (it was
    /// terminated mid-recording), so a stale "recording" card doesn't linger.
    func endStale() {
        for stale in Activity<RecordingActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func start(context: String) {
        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RecordingActivityAttributes.ContentState(timerStart: Date(), elapsed: 0, isPaused: false, levels: [])
        activity = try? Activity.request(
            attributes: RecordingActivityAttributes(context: context),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(elapsed: TimeInterval, isPaused: Bool, levels: [Double]) {
        guard let activity else { return }
        let state = RecordingActivityAttributes.ContentState(
            timerStart: Date().addingTimeInterval(-elapsed),
            elapsed: elapsed,
            isPaused: isPaused,
            levels: Array(levels.suffix(8))
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
