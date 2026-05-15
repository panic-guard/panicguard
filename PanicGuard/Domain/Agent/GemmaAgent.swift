import Foundation
import MediaPipeTasksGenAI

/// Step 2: wraps MediaPipe LLM Inference to run the Gemma 4 agentic triage workflow.
final class GemmaAgent: PanicTriageAgentProtocol {

    // MARK: - Configuration

    struct Configuration {
        /// Caps KV-cache and output length — keep ≤512 on iPhone 14 Pro to stay under 4 GB peak.
        var maxTokens: Int = 512
        /// Model-level topk ceiling; the session topk must be ≤ this value.
        var maxTopk: Int = 40
        /// Per-session sampling: very low for deterministic triage output.
        var temperature: Float = 0.1
        /// Per-session topk; controls diversity within the model-level ceiling.
        var topk: Int = 10
    }

    // MARK: - Error

    enum AgentError: LocalizedError {
        case modelNotFound(path: String)
        case engineInit(Error)
        case malformedResponse(String)

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let p):  return "Model file not found at: \(p)"
            case .engineInit(let e):     return "LLM engine init failed: \(e.localizedDescription)"
            case .malformedResponse(let r): return "Malformed LLM response: \(r)"
            }
        }
    }

    // MARK: - Private state

    private let engine: LlmInference
    /// Reused across sessions; temperature and topk are session-level, not model-level.
    private let sessionOptions: LlmInference.Session.Options
    private let userProfileStore: UserProfileStoring

    // MARK: - Init

    init(
        modelPath: String,
        configuration: Configuration = .init(),
        userProfileStore: UserProfileStoring
    ) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw AgentError.modelNotFound(path: modelPath)
        }
        let modelOptions = LlmInference.Options(modelPath: modelPath)
        modelOptions.maxTokens = configuration.maxTokens
        modelOptions.maxTopk = configuration.maxTopk
        do {
            engine = try LlmInference(options: modelOptions)
        } catch {
            throw AgentError.engineInit(error)
        }
        let sessionOpts = LlmInference.Session.Options()
        sessionOpts.temperature = configuration.temperature
        sessionOpts.topk = configuration.topk
        self.sessionOptions = sessionOpts
        self.userProfileStore = userProfileStore
    }

    // MARK: - Tool implementations (called by the agent loop)

    private func getUserBaseline() -> String {
        struct Payload: Encodable {
            let age: Int
            let baseline_hr_bpm: Double
        }
        guard let profile = try? userProfileStore.load(),
              let data = try? JSONEncoder().encode(
                  Payload(age: profile.age, baseline_hr_bpm: profile.baselineHR)
              ),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"error":"profile_unavailable"}"#
        }
        return json
    }

    private func getVocalAnchorResult(_ anchor: VocalAnchorResult) -> String {
        struct Payload: Encodable {
            let target_phrase: String
            let spoken_transcript: String
            // nil transcript (recognition failure) is a strong panic signal fed to the LLM
            let recognition_failed: Bool
        }
        let payload = Payload(
            target_phrase: anchor.targetPhrase,
            spoken_transcript: anchor.transcript ?? "",
            recognition_failed: anchor.transcript == nil
        )
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func calculateRiskRatio(currentHR: Double, baselineHR: Double) -> String {
        struct Payload: Encodable {
            let risk_ratio: Double
            let current_hr_bpm: Int
            let baseline_hr_bpm: Int
        }
        let ratio = baselineHR > 0 ? (currentHR / baselineHR * 100).rounded() / 100 : 0
        let payload = Payload(
            risk_ratio: ratio,
            current_hr_bpm: Int(currentHR),
            baseline_hr_bpm: Int(baselineHR)
        )
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    // MARK: - PanicTriageAgentProtocol

    func runTriage(
        features: HRFeaturePayload,
        vocalAnchor: VocalAnchorResult
    ) async throws -> TriageResult {
        // TODO: implement multi-step agent loop:
        //   1. Build system prompt with tool schemas + HRFeaturePayload JSON
        //   2. Loop: call engine.generateResponse, parse <tool_call> tags
        //   3. Dispatch tool calls → getUserBaseline / getVocalAnchorResult / calculateRiskRatio
        //   4. Feed tool results back as next turn
        //   5. Parse final <answer> block into TriageResult
        fatalError("not implemented")
    }
}
