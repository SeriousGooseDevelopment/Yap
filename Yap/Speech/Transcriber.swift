import Foundation
import AVFoundation
import Speech

/// Thread-safe accumulator for raw 16kHz mono samples captured off the audio-tap thread.
/// The tap callback runs on a real-time audio thread, not the main actor, so it talks to
/// this plain lock-guarded object directly instead of hopping to `@MainActor` per buffer
/// (roughly every 30-60ms) just to append to an array.
final class AudioSampleAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var peak: Float = 0

    func append(_ newSamples: [Float]) {
        guard !newSamples.isEmpty else { return }
        lock.lock()
        samples.append(contentsOf: newSamples)
        lock.unlock()
        var p: Float = 0
        for s in newSamples { p = max(p, abs(s)) }
        peak = p
    }

    func drain() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        return samples
    }

    func reset() {
        lock.lock(); samples.removeAll(); lock.unlock()
        peak = 0
    }

    var latestPeak: Float { peak }
}

/// One engine, one job: Apple's on-device `SFSpeechRecognizer` drives both the *live*
/// captions while recording and the transcript that gets *saved* — there's no separate
/// model to bundle or load. Previously this ran a second, independent pass through a
/// bundled Whisper CoreML model (594MB→144MB across two revisions) for a more-accurate
/// saved transcript; that model's own memory footprint crashed a real iPhone 12 into a
/// full reboot once, and even the safer 144MB `base.en` build still meant a multi-second
/// wait after Stop and ~150MB of app storage for marginal accuracy gain over Apple's own
/// on-device recognizer, which is already quite good and ships with the OS for free.
/// Dropping it entirely means: zero bundle size, zero load time, zero crash class, and a
/// saved transcript that's ready within ~1s of tapping Stop (waiting only for the
/// recognizer's own `isFinal` result, which resolves any misheard words using the full
/// utterance's context — more accurate than the live partials but the same engine).
@MainActor
final class Transcriber: ObservableObject {
    @Published private(set) var liveText: String = ""
    /// Recent relative input energy (0...1), most recent last. Drives the waveform bars.
    @Published private(set) var levels: [Float] = Array(repeating: 0, count: 8)
    /// The complete 16kHz mono sample set from the most recently finished recording —
    /// `Store.commitEntry` persists this via `EntryAudioStore` so the detail screen can
    /// show a real waveform + playback.
    @Published private(set) var lastRecordedSamples: [Float] = []
    /// Flips true when the OS force-stops capture out from under us (incoming call, Siri,
    /// alarm, another app taking the mic). `Store` observes this and finalizes the
    /// recording when it fires, rather than leaving `recordingPhase` stuck at `.recording`
    /// with a dead tap.
    @Published private(set) var wasInterrupted = false

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    /// Everything transcribed before the current recognition task started. A restarted
    /// request (see `restartRecognitionTask`) always reports its transcript from zero, so
    /// every update layers on top of this rather than replacing `liveText` outright —
    /// otherwise a pause-triggered restart would visibly wipe everything said so far.
    private var confirmedTextPrefix = ""
    private let accumulator = AudioSampleAccumulator()
    private var levelTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var resampleConverter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: EntryAudioStore.sampleRate, channels: 1, interleaved: false)!

    /// Returns whether capture actually started, and if not, a human-readable reason —
    /// `Store.startRecording` commits the UI to `.recording` phase *before* calling this
    /// (so the timer starts responsively); if this returns false, `Store` must undo that
    /// commit and show the reason rather than leaving the UI stuck showing a live
    /// recording with nothing actually being captured.
    func startRecording() async -> Result<Void, TranscriberError> {
        liveText = ""
        confirmedTextPrefix = ""
        wasInterrupted = false
        levels = Array(repeating: 0, count: 8)
        accumulator.reset()

        let speechAuthorized = await SpeechPermission.request()
        guard speechAuthorized else {
            return .failure(.speechPermissionDenied)
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            return .failure(.recognizerUnavailable)
        }
        self.recognizer = recognizer
        return startCapture(with: recognizer)
    }

    private func startCapture(with recognizer: SFSpeechRecognizer) -> Result<Void, TranscriberError> {
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let typeValue = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue), type == .began else { return }
            Task { @MainActor in
                guard let self else { return }
                self.wasInterrupted = true
                self.stopCapture()
            }
        }
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        resampleConverter = AVAudioConverter(from: format, to: targetFormat)
        let accumulator = self.accumulator
        let converter = resampleConverter
        let targetFormat = self.targetFormat

        inputNode.removeTap(onBus: 0)
        // Route through `self.recognitionRequest` (not a captured local) — `restartRecognitionTask`
        // swaps in a new request object on pause/error, and a tap that kept appending to the
        // original, abandoned request would mean the *new* task never receives any audio.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            guard let converter, let samples = Self.resample(buffer, to: targetFormat, using: converter) else { return }
            accumulator.append(samples)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            return .failure(.engineStartFailed(error.localizedDescription))
        }

        recognitionTask = makeRecognitionTask(recognizer: recognizer, request: request)
        startLevelTimer()
        return .success(())
    }

    /// Converts a captured buffer (native mic format, typically 48kHz) down to the stored
    /// 16kHz mono format used for the waveform + saved `.m4a` — replaces WhisperKit's
    /// `AudioProcessor.resampleAudio`/`convertBufferToArray` utilities, which no longer
    /// exist in this target now that the WhisperKit dependency is gone entirely.
    private static func resample(_ buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat, using converter: AVAudioConverter) -> [Float]? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }
        var error: NSError?
        var consumed = false
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channelData = output.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: channelData[0], count: Int(output.frameLength)))
    }

    /// Shared by the initial task and every restart so pause-triggered restarts keep
    /// working across an arbitrarily long recording, not just once.
    private func makeRecognitionTask(recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.updateLiveText(with: result.bestTranscription.formattedString)
                }
                // A task ends either via an error or by naturally reporting a final result
                // after enough silence (the on-device recognizer has its own timeout) —
                // both leave the mic tap feeding a request nobody's listening to anymore
                // unless we restart. 203 ("no speech detected") on an otherwise-live task
                // is routine noise, not an end signal, so it's excluded.
                let isNoSpeechNoise = (error as NSError?)?.code == 203
                let ended = (error != nil && !isNoSpeechNoise) || result?.isFinal == true
                if ended, self.recognitionTask != nil {
                    self.restartRecognitionTask()
                }
            }
        }
    }

    /// A restarted request's transcript always starts from zero, so every update is
    /// layered on top of `confirmedTextPrefix` rather than replacing `liveText` outright.
    private func updateLiveText(with segment: String) {
        if confirmedTextPrefix.isEmpty {
            liveText = segment
        } else if segment.isEmpty {
            liveText = confirmedTextPrefix
        } else {
            liveText = confirmedTextPrefix + " " + segment
        }
    }

    private func restartRecognitionTask() {
        guard let recognizer else { return }
        confirmedTextPrefix = liveText
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request
        recognitionTask = makeRecognitionTask(recognizer: recognizer, request: request)
    }

    private func startLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                var tail = self.levels
                tail.append(self.accumulator.latestPeak)
                self.levels = Array(tail.suffix(8))
            }
        }
    }

    private func stopCapture() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        levelTimer?.invalidate()
        levelTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
    }

    // MARK: - Stop / final result

    /// Stops capture and returns the transcript immediately — no waiting for a separate
    /// "final" result. That wait used to add up to ~900ms on top of the live partial
    /// already on screen, for a cleanup pass that rarely changed much; live partials are
    /// the *same* on-device recognizer, so the marginal accuracy gain wasn't worth the
    /// lag once the multi-second Whisper pass this replaced was already gone. Any
    /// last-moment audio the recognizer hadn't caught up to yet is still captured in
    /// `lastRecordedSamples` for playback — only the live *text* stops updating here.
    func stopAndTranscribeFinal() async -> String {
        let text = liveText
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        stopCapture()
        lastRecordedSamples = accumulator.drain()
        return text
    }

    func cancelRecording() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        stopCapture()
        liveText = ""
    }
}

enum TranscriberError: Error, Equatable {
    case speechPermissionDenied
    case recognizerUnavailable
    case engineStartFailed(String)

    var message: String {
        switch self {
        case .speechPermissionDenied:
            return "Yap needs Speech Recognition access to transcribe your entries. Allow it in Settings."
        case .recognizerUnavailable:
            return "On-device speech recognition isn't available on this device right now."
        case .engineStartFailed(let reason):
            return "Couldn't start the microphone: \(reason)"
        }
    }
}
