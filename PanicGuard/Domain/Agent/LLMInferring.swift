import Foundation

/// Testability seam over MediaPipe LlmInference.Session.
/// The real conformance wraps a single Session; tests inject MockLLMSession.
protocol LLMSessionProtocol {
    /// Send the next user turn and return the assistant's full response text.
    func sendMessage(_ text: String) async throws -> String
}
