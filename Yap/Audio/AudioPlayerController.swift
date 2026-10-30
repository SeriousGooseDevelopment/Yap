import Foundation
import AVFoundation

/// `AVAudioPlayer` wrapper behind the reading screen's player: play/pause, scrubbing,
/// ±15s skips and the 1× / 1.5× / 2× / 0.75× speed cycle.
@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    /// Playback position in seconds.
    @Published private(set) var time: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var rate: Float = 1

    static let rates: [Float] = [1, 1.5, 2, 0.75]

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var progress: Double { duration > 0 ? min(1, time / duration) : 0 }
    var hasAudio: Bool { player != nil }

    /// Always reopens the file: "Add voice" re-saves an entry's recording under the same URL.
    func load(url: URL, fallbackDuration: Double) {
        stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.enableRate = true
        player?.rate = rate
        player?.prepareToPlay()
        duration = player?.duration ?? fallbackDuration
        time = 0
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard let player else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        // Starting again from the very end replays from the top.
        if player.currentTime >= player.duration - 0.2 { player.currentTime = 0 }
        player.rate = rate
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        tick()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        stopTimer()
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = max(0, min(player.duration, seconds))
        player.currentTime = clamped
        time = clamped
    }

    func skip(_ delta: Double) { seek(to: (player?.currentTime ?? time) + delta) }

    func cycleRate() {
        let index = Self.rates.firstIndex(of: rate) ?? 0
        rate = Self.rates[(index + 1) % Self.rates.count]
        player?.rate = rate
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let player else { return }
        time = player.currentTime
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    deinit { timer?.invalidate() }
}

extension AudioPlayerController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.stopTimer()
            self.time = self.duration
        }
    }
}
