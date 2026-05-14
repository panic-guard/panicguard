import Foundation

// MARK: - Shared value types

/// Step 1 output: statistical summary produced by HRFeatureExtractor.
struct HRFeaturePayload: Codable, Equatable {
    struct HRMetrics: Codable, Equatable {
        let meanBPM: Double
        let slopeBPMPerMin: Double
    }
    struct Context: Codable, Equatable {
        let isMoving: Bool
        let stepsLast5Min: Int
    }
    let currentHRMetrics: HRMetrics
    let context: Context
}

/// Step 2 output: final LLM triage decision.
struct TriageResult: Codable, Equatable {
    let likelihoodPanic: Double          // 0.0 – 1.0
    let likelihoodPhysicalAnomaly: Double
    let confidence: Confidence
    let reasoningSummary: String

    enum Confidence: String, Codable {
        case high, medium, low
    }
}

/// Vocal anchor input fed to the LLM tool call.
struct VocalAnchorResult: Equatable {
    let targetPhrase: String
    let transcript: String?             // nil if speech recognition failed entirely
}

// MARK: - Step 1 protocol

protocol HRFeatureExtracting {
    /// Converts raw HR + step samples into a symbolic JSON payload.
    func extract(hrSamples: [Double], stepCount: Int) -> HRFeaturePayload
}

// MARK: - Step 2 protocol

protocol PanicTriageAgentProtocol {
    /// Runs the Gemma 4 multi-step agentic workflow and returns a TriageResult.
    func runTriage(
        features: HRFeaturePayload,
        vocalAnchor: VocalAnchorResult
    ) async throws -> TriageResult
}

// MARK: - Step 3 protocol

protocol RuleEngineProtocol {
    /// Deterministically maps a TriageResult to an intervention action.
    func selectIntervention(for result: TriageResult) -> InterventionAction
}
