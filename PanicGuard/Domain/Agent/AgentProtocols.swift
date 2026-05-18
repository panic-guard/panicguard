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
        let activeEnergyKcal: Double   // kcal burned in last 5 min
        let hasActiveWorkout: Bool     // HKWorkout session present in last 30 min

        init(isMoving: Bool, stepsLast5Min: Int, activeEnergyKcal: Double = 0, hasActiveWorkout: Bool = false) {
            self.isMoving = isMoving
            self.stepsLast5Min = stepsLast5Min
            self.activeEnergyKcal = activeEnergyKcal
            self.hasActiveWorkout = hasActiveWorkout
        }
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

/// Word-level speech quality metrics extracted from SFTranscriptionSegment data.
/// nil when recognition failed or the transcript was too short to measure (< 2 words).
struct VocalMetrics: Codable, Equatable {
    let speakingRateWPM: Double     // words per minute over the spoken portion
    let maxPauseSeconds: Double     // longest gap between consecutive words
    let meanPauseSeconds: Double    // average inter-word gap (all gaps > 0)
    let totalPauseSeconds: Double   // sum of all inter-word gaps > 0.3 s
    let durationSeconds: Double     // time from first word start to last word end
}

/// Vocal anchor input fed to the LLM triage.
struct VocalAnchorResult: Equatable {
    let targetPhrase: String
    let transcript: String?         // nil if speech recognition failed entirely
    let vocalMetrics: VocalMetrics? // nil when transcript is nil or < 2 words recognized

    init(targetPhrase: String, transcript: String?, vocalMetrics: VocalMetrics? = nil) {
        self.targetPhrase = targetPhrase
        self.transcript = transcript
        self.vocalMetrics = vocalMetrics
    }
}

// MARK: - Step 1 protocol

protocol HRFeatureExtracting {
    func extract(hrSamples: [Double], stepCount: Int, activeEnergyKcal: Double, hasActiveWorkout: Bool) -> HRFeaturePayload
}

extension HRFeatureExtracting {
    func extract(hrSamples: [Double], stepCount: Int) -> HRFeaturePayload {
        extract(hrSamples: hrSamples, stepCount: stepCount, activeEnergyKcal: 0, hasActiveWorkout: false)
    }
}

// MARK: - Step 2 protocol

protocol PanicTriageAgentProtocol {
    /// Warms up the LLM session in the background so runTriage can reuse it.
    func preload() async
    /// Runs the single-turn Gemma 4 triage and returns a TriageResult.
    func runTriage(
        features: HRFeaturePayload,
        vocalAnchor: VocalAnchorResult
    ) async throws -> TriageResult
}

extension PanicTriageAgentProtocol {
    func preload() async {}
}

// MARK: - Step 3 protocol

protocol RuleEngineProtocol {
    /// Deterministically maps a TriageResult to an intervention action.
    func selectIntervention(for result: TriageResult) -> InterventionAction
}
