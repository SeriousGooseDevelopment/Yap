import Foundation
import AVFoundation

/// Persists each recording as a compressed `.m4a` alongside its `JournalEntry`, plus a small
/// downsampled waveform (peak amplitude per bucket, 0...1) for the reading screen's player.
enum EntryAudioStore {
    static let sampleRate: Double = 16000

    private static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioEntries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(for entryID: String) -> URL {
        directory.appendingPathComponent("\(entryID).m4a")
    }

    /// Writes the raw 16kHz mono Float32 samples captured while recording as AAC,
    /// and returns a downsampled waveform for display. Returns nil (no file written) if the
    /// clip is too short to be meaningful — callers should leave `JournalEntry.waveform` nil
    /// in that case so the reading screen hides the player rather than showing an empty one.
    @discardableResult
    static func save(samples: [Float], entryID: String, buckets: Int = 48) -> [Float]? {
        guard samples.count > Int(0.2 * sampleRate) else { return nil }
        let url = fileURL(for: entryID)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000,
        ]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(samples.count)) else {
                return nil
            }
            buffer.frameLength = buffer.frameCapacity
            samples.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress, let channel = buffer.floatChannelData?[0] else { return }
                channel.update(from: base, count: samples.count)
            }
            try file.write(from: buffer)
        } catch {
            return nil
        }
        return waveform(from: samples, buckets: buckets)
    }

    static func waveform(from samples: [Float], buckets: Int) -> [Float] {
        guard !samples.isEmpty, buckets > 0 else { return [] }
        let chunk = max(1, samples.count / buckets)
        var result: [Float] = []
        result.reserveCapacity(buckets)
        var i = 0
        while i < samples.count && result.count < buckets {
            let end = min(i + chunk, samples.count)
            var peak: Float = 0
            for j in i..<end { peak = max(peak, abs(samples[j])) }
            result.append(peak)
            i = end
        }
        let maxV = result.max() ?? 0
        guard maxV > 0.0001 else { return result }
        return result.map { min(1, $0 / maxV) }
    }

    /// Decodes an entry's stored `.m4a` back to raw 16kHz mono Float32 samples — used when
    /// "Add voice" appends a new recording to an existing entry, so both are re-saved as
    /// one clip under the same entry ID.
    static func loadSamples(entryID: String) -> [Float]? {
        let url = fileURL(for: entryID)
        guard FileManager.default.fileExists(atPath: url.path),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        guard let channelData = buffer.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
    }

    static func delete(entryID: String) {
        try? FileManager.default.removeItem(at: fileURL(for: entryID))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Resamples a stored waveform to `count` bars for display (max-pooling when shrinking,
    /// nearest-neighbour when stretching).
    static func bars(_ waveform: [Float], count: Int) -> [Float] {
        guard !waveform.isEmpty, count > 0 else { return [] }
        return (0..<count).map { i in
            let lo = Int(Double(i) / Double(count) * Double(waveform.count))
            let hi = max(lo + 1, Int(Double(i + 1) / Double(count) * Double(waveform.count)))
            return waveform[min(lo, waveform.count - 1)..<min(hi, waveform.count)].max() ?? 0
        }
    }
}
