import Foundation

// MARK: - Fixed scenario (hardcoded inputs, LLM bypassed)

struct FixedScenario: Identifiable {
    let id: String
    let title: String
    let description: String
    let outcomeLabel: String
    let hrFeatures: HRFeaturePayload
    let baselineHR: Double
    let vocalAnchorResult: VocalAnchorResult
    let baselineVocalMetrics: VocalMetrics
    let triageResult: TriageResult

    static let all: [FixedScenario] = [acutePanic, moderatePanic, mildAnxiety, physicalAnomaly]

    static let acutePanic = FixedScenario(
        id: "acutePanic",
        title: "Acute Panic",
        description: "148 BPM · steep slope · sedentary",
        outcomeLabel: "Breathing + Emergency",
        hrFeatures: HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 148, slopeBPMPerMin: 30),
            context: .init(isMoving: false, stepsLast5Min: 12)
        ),
        baselineHR: 68,
        vocalAnchorResult: VocalAnchorResult(
            targetPhrase: "The morning light is calm and still.",
            transcript: "The morning light is... still.",
            vocalMetrics: VocalMetrics(
                speakingRateWPM: 65, maxPauseSeconds: 1.8,
                meanPauseSeconds: 0.7, totalPauseSeconds: 2.4, durationSeconds: 5.6
            )
        ),
        baselineVocalMetrics: VocalMetrics(
            speakingRateWPM: 115, maxPauseSeconds: 0.3,
            meanPauseSeconds: 0.15, totalPauseSeconds: 0.8, durationSeconds: 4.2
        ),
        triageResult: TriageResult(
            likelihoodPanic: 0.92, likelihoodPhysicalAnomaly: 0.15,
            confidence: .high,
            reasoningSummary: "Very high unexplained HR, steep slope, sedentary — severe panic with significantly disrupted speech."
        )
    )

    static let moderatePanic = FixedScenario(
        id: "moderatePanic",
        title: "Moderate Panic",
        description: "132 BPM · moderate slope · sedentary",
        outcomeLabel: "Breathing Guide",
        hrFeatures: HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 132, slopeBPMPerMin: 15),
            context: .init(isMoving: false, stepsLast5Min: 25)
        ),
        baselineHR: 72,
        vocalAnchorResult: VocalAnchorResult(
            targetPhrase: "Soft breath, soft sky.",
            transcript: "Soft breath soft sky",
            vocalMetrics: VocalMetrics(
                speakingRateWPM: 82, maxPauseSeconds: 0.9,
                meanPauseSeconds: 0.4, totalPauseSeconds: 1.2, durationSeconds: 3.8
            )
        ),
        baselineVocalMetrics: VocalMetrics(
            speakingRateWPM: 110, maxPauseSeconds: 0.3,
            meanPauseSeconds: 0.18, totalPauseSeconds: 0.7, durationSeconds: 4.0
        ),
        triageResult: TriageResult(
            likelihoodPanic: 0.78, likelihoodPhysicalAnomaly: 0.12,
            confidence: .medium,
            reasoningSummary: "Elevated HR with moderate slope, sedentary — consistent with moderate panic, speech mildly disrupted."
        )
    )

    static let mildAnxiety = FixedScenario(
        id: "mildAnxiety",
        title: "Mild Anxiety",
        description: "115 BPM · gradual slope · sedentary",
        outcomeLabel: "Grounding Exercise",
        hrFeatures: HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 115, slopeBPMPerMin: 8),
            context: .init(isMoving: false, stepsLast5Min: 30)
        ),
        baselineHR: 75,
        vocalAnchorResult: VocalAnchorResult(
            targetPhrase: "The water is still and quiet.",
            transcript: "The water is still and quiet.",
            vocalMetrics: VocalMetrics(
                speakingRateWPM: 100, maxPauseSeconds: 0.55,
                meanPauseSeconds: 0.25, totalPauseSeconds: 0.8, durationSeconds: 3.8
            )
        ),
        baselineVocalMetrics: VocalMetrics(
            speakingRateWPM: 120, maxPauseSeconds: 0.25,
            meanPauseSeconds: 0.12, totalPauseSeconds: 0.5, durationSeconds: 3.5
        ),
        triageResult: TriageResult(
            likelihoodPanic: 0.52, likelihoodPhysicalAnomaly: 0.10,
            confidence: .medium,
            reasoningSummary: "Moderate HR elevation, gradual slope — mild anxiety pattern, speech near baseline."
        )
    )

    static let physicalAnomaly = FixedScenario(
        id: "physicalAnomaly",
        title: "Physical Anomaly",
        description: "158 BPM · steep slope · sedentary",
        outcomeLabel: "Medical Alert",
        hrFeatures: HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 158, slopeBPMPerMin: 25),
            context: .init(isMoving: false, stepsLast5Min: 8)
        ),
        baselineHR: 65,
        vocalAnchorResult: VocalAnchorResult(
            targetPhrase: "Slow and steady, I am here.",
            transcript: "Slow and steady, I am here.",
            vocalMetrics: VocalMetrics(
                speakingRateWPM: 112, maxPauseSeconds: 0.4,
                meanPauseSeconds: 0.18, totalPauseSeconds: 0.7, durationSeconds: 3.6
            )
        ),
        baselineVocalMetrics: VocalMetrics(
            speakingRateWPM: 108, maxPauseSeconds: 0.28,
            meanPauseSeconds: 0.14, totalPauseSeconds: 0.6, durationSeconds: 3.8
        ),
        triageResult: TriageResult(
            likelihoodPanic: 0.22, likelihoodPhysicalAnomaly: 0.82,
            confidence: .high,
            reasoningSummary: "Extremely high HR while sedentary with fluent speech — possible cardiac anomaly, panic unlikely."
        )
    )
}

// MARK: - Custom scenario activity level

enum DemoActivity: String, CaseIterable {
    case resting = "Resting"
    case walking = "Walking"
    case running = "Running"

    func hrFeatures(bpm: Double) -> HRFeaturePayload {
        let slope: Double
        let steps: Int
        switch self {
        case .resting:
            slope = bpm > 100 ? (bpm - 80) * 0.3 : 2
            steps = 5
        case .walking:
            slope = max(5, (bpm - 90) * 0.2)
            steps = 200
        case .running:
            slope = max(3, (bpm - 120) * 0.1)
            steps = 500
        }
        return HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: bpm, slopeBPMPerMin: slope),
            context: .init(isMoving: self != .resting, stepsLast5Min: steps)
        )
    }
}
