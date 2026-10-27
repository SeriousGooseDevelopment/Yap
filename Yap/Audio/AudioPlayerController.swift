import Foundation
import AVFoundation

/// Thin `AVAudioPlayer` wrapper backing `WaveformPlayer` in `DetailView`. Playback only —
/// no editing/trimming, matching the design review's scoped ask.
@MainActor
final class AudioPlayerController: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    /// 0...1
    @Published private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var loadedURL: URL?

    func load(url: URL) {
        guard loadedURL != url else { return }
        loadedURL = url
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        progress = 0
        isPlaying = false
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            #if !os(macOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(toFraction fraction: Double) {
        guard let player, player.duration > 0 else { return }
        let clamped = max(0, min(1, fraction))
        player.currentTime = clamped * player.duration
        progress = clamped
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    private func tick() {
        guard let player, player.duration > 0 else { return }
        progress = player.currentTime / player.duration
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    deinit { timer?.invalidate() }
}

extension AudioPlayerController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.progress = 0
            self.stopTimer()
        }
    }
}
