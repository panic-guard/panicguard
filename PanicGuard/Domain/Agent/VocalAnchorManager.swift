import Foundation
import AVFoundation
#if canImport(Speech)
import Speech
#endif

protocol VocalAnchorManaging {
    /// Displays the anchor phrase and records + transcribes the user's reading for up to `timeout` seconds.
    func captureAnchor(phrase: String, timeout: TimeInterval) async throws -> VocalAnchorResult
}

final class VocalAnchorManager: VocalAnchorManaging {
    func captureAnchor(phrase: String, timeout: TimeInterval) async throws -> VocalAnchorResult {
        // TODO: start AVAudioEngine + SFSpeechRecognizer offline recognition
        fatalError("not implemented")
    }
}
