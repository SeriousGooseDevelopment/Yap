import Speech

/// Authorization for Apple's on-device Speech framework — the only transcription engine
/// Yap has (see `Transcriber`), separate from the microphone permission in
/// `AudioPermission.swift`. Denial here is fatal to recording: without it there's no way
/// to produce a transcript, mood, or topics, only raw unusable audio — `Transcriber`
/// reports `.speechPermissionDenied` so `Store` can surface a clear reason rather than
/// silently failing.
enum SpeechPermission {
    @MainActor
    static func request() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default: return false
        }
    }
}
