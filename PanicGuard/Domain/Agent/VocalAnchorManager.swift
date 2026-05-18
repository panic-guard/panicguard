import Foundation
import AVFoundation
#if canImport(Speech)
import Speech

protocol VocalAnchorManaging {
    func captureAnchor(phrase: String, timeout: TimeInterval) async throws -> VocalAnchorResult
    func recognize(phrase: String, url: URL) async -> VocalAnchorResult
}

final class VocalAnchorManager: VocalAnchorManaging {

    // Held so stopRecordingEarly() can interrupt an in-progress recording.
    // AVAudioRecorder.stop() is documented as safe to call from any thread.
    private var activeRecorder: AVAudioRecorder?

    // MARK: - Public interface

    /// Stops the current recording immediately; recognition runs on whatever was captured so far.
    func stopRecordingEarly() {
        activeRecorder?.stop()
    }

    /// Records audio for `timeout` seconds, then runs on-device speech recognition on the file.
    func captureAnchor(phrase: String, timeout: TimeInterval) async throws -> VocalAnchorResult {
        await requestPermissionsIfNeeded()
        guard let url = await record(duration: timeout) else {
            return VocalAnchorResult(targetPhrase: phrase, transcript: nil)
        }
        defer { try? FileManager.default.removeItem(at: url) }
        return await recognize(phrase: phrase, url: url)
    }

    /// Runs on-device speech recognition on an audio file URL.
    /// Auth is re-checked here because this method is public and can be called directly (e.g. in tests).
    func recognize(phrase: String, url: URL) async -> VocalAnchorResult {
        // Phrases are always English — pin to en-US regardless of device locale.
        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            return VocalAnchorResult(targetPhrase: phrase, transcript: nil)
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.contextualStrings = [phrase]

        return await withCheckedContinuation { cont in
            var resumed = false
            let finish: (VocalAnchorResult) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: result)
            }
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    let transcript = result.bestTranscription.formattedString
                    let metrics = self.vocalMetrics(from: result.bestTranscription.segments, transcript: transcript)
                    finish(VocalAnchorResult(targetPhrase: phrase, transcript: transcript, vocalMetrics: metrics))
                } else if error != nil {
                    finish(VocalAnchorResult(targetPhrase: phrase, transcript: nil))
                }
            }
        }
    }

    // MARK: - Private

    /// Extracts word-level timing from SFTranscriptionSegments.
    /// WPM uses transcript word count for accuracy. Pauses are computed from segment gaps;
    /// if Apple merges all words into 1 segment (fluent speech), pauses are 0 — correct behaviour.
    /// Returns nil only when transcript has fewer than 2 words or duration is zero.
    private func vocalMetrics(from segments: [SFTranscriptionSegment], transcript: String) -> VocalMetrics? {
        let wordCount = transcript.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        guard wordCount >= 2, let last = segments.last else { return nil }
        let totalDuration = last.timestamp + last.duration
        guard totalDuration > 0 else { return nil }

        var pauses: [Double] = []
        for i in 1..<segments.count {
            let gap = segments[i].timestamp - (segments[i - 1].timestamp + segments[i - 1].duration)
            if gap > 0 { pauses.append(gap) }
        }

        let meanPause = pauses.isEmpty ? 0 : pauses.reduce(0, +) / Double(pauses.count)

        return VocalMetrics(
            speakingRateWPM: Double(wordCount) / totalDuration * 60.0,
            maxPauseSeconds: pauses.max() ?? 0,
            meanPauseSeconds: meanPause,
            totalPauseSeconds: pauses.filter { $0 > 0.3 }.reduce(0, +),
            durationSeconds: totalDuration
        )
    }

    /// Requests Speech and microphone permissions if not yet determined.
    /// Called only from captureAnchor() before recording begins.
    private func requestPermissionsIfNeeded() async {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
            }
        }
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
    }

    private func record(duration: TimeInterval) async -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            activeRecorder = recorder
            guard recorder.record() else { activeRecorder = nil; return nil }

            // Poll every 200 ms so stopRecordingEarly() takes effect quickly.
            let deadline = Date().addingTimeInterval(duration)
            while Date() < deadline && recorder.isRecording && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            if recorder.isRecording { recorder.stop() }
            activeRecorder = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            return url
        } catch {
            activeRecorder = nil
            return nil
        }
    }
}
#else
// watchOS — Speech framework is iOS-only
protocol VocalAnchorManaging {
    func captureAnchor(phrase: String, timeout: TimeInterval) async throws -> VocalAnchorResult
    func recognize(phrase: String, url: URL) async -> VocalAnchorResult
}

final class VocalAnchorManager: VocalAnchorManaging {
    func captureAnchor(phrase: String, timeout: TimeInterval) async throws -> VocalAnchorResult {
        VocalAnchorResult(targetPhrase: phrase, transcript: nil)
    }
    func recognize(phrase: String, url: URL) async -> VocalAnchorResult {
        VocalAnchorResult(targetPhrase: phrase, transcript: nil)
    }
}
#endif
