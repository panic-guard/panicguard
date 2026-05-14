import Foundation

/// Step 2: wraps MediaPipe LLM Inference to run the Gemma 4 agentic triage workflow.
final class GemmaAgent: PanicTriageAgentProtocol {

    // MARK: - Tool implementations (called by the agent loop)

    private func getUserBaseline() -> String {
        // TODO: fetch from UserProfileStore (age, resting HR)
        return "{}"
    }

    private func getVocalAnchorResult(_ anchor: VocalAnchorResult) -> String {
        // TODO: serialize anchor into JSON for the LLM tool response
        return "{}"
    }

    private func calculateRiskRatio(currentHR: Double, baselineHR: Double) -> String {
        // TODO: return ratio JSON
        return "{}"
    }

    // MARK: - PanicTriageAgentProtocol

    func runTriage(
        features: HRFeaturePayload,
        vocalAnchor: VocalAnchorResult
    ) async throws -> TriageResult {
        // TODO: implement multi-step agent loop using MediaPipe LLM Inference API
        fatalError("not implemented")
    }
}
