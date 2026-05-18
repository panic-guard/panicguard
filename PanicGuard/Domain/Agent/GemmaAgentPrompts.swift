import Foundation

/// All prompt templates for the GemmaAgent triage workflow.
/// Edit this file to tune prompts without touching agent logic.
enum GemmaAgentPrompts {

    struct Context {
        let features: HRFeaturePayload
        let anchor: VocalAnchorResult
        let profile: UserProfile?
        let riskRatio: Double?
    }

    // MARK: - Pre-computed labels (quantitative reasoning in Swift, not LLM)

    static func activityLabel(stepsPerMin: Int, hasActiveWorkout: Bool = false, activeEnergyKcal: Double = 0) -> String {
        if (hasActiveWorkout || activeEnergyKcal >= 3.0) && stepsPerMin < 10 {
            return "strength training or non-step exercise (workout detected)"
        }
        switch stepsPerMin {
        case 0..<10:  return "sedentary (essentially at rest)"
        case 10..<40: return "slow walk"
        case 40..<70: return "brisk walk"
        default:      return "jogging / running"
        }
    }

    static func slopeLabel(bpmPerMin: Double) -> String {
        switch bpmPerMin {
        case ..<5:    return "flat"
        case 5..<15:  return "gradual"
        case 15..<25: return "moderate"
        default:      return "steep"
        }
    }

    static func speechRateLabel(_ wpm: Double) -> String {
        switch wpm {
        case ..<60:  return "very slow — possible difficulty speaking"
        case 60..<100: return "slow"
        case 100..<170: return "normal"
        default:     return "fast — possible rushing or anxiety"
        }
    }

    static func maxPauseLabel(_ seconds: Double) -> String {
        switch seconds {
        case ..<0.5:  return "fluent"
        case 0.5..<1.5: return "moderate pause"
        default:      return "long pause — hesitation or difficulty"
        }
    }

    /// Compares current speaking rate against the calm-state baseline.
    static func vocalRateChangeLabel(baselineWPM: Double, currentWPM: Double) -> String {
        guard baselineWPM > 0 else { return "no baseline" }
        let ratio = currentWPM / baselineWPM
        let pct = Int(round((1 - ratio) * 100))
        switch ratio {
        case 0.85...: return "similar to baseline"
        case 0.60..<0.85: return "\(pct)% slower than baseline — mild disruption"
        default: return "\(pct)% slower than baseline — significant disruption"
        }
    }

    /// Compares current pause against the calm-state baseline pause.
    static func pauseMultiplierLabel(baselinePause: Double, currentPause: Double) -> String {
        guard baselinePause > 0.01 else { return maxPauseLabel(currentPause) }
        let ratio = currentPause / baselinePause
        switch ratio {
        case ..<2.0: return String(format: "similar to baseline (%.1fx)", ratio)
        case 2.0..<4.0: return String(format: "%.1fx baseline — moderately elevated", ratio)
        default: return String(format: "%.1fx baseline — significantly elevated", ratio)
        }
    }

    /// Normalizes a phrase for exact-match comparison:
    /// collapses newlines and multiple spaces, lowercases.
    static func normalizePhrase(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    /// Returns true if current HR is within physiologically expected range for the given exertion level.
    static func isHRProportionate(meanBPM: Double, stepsPerMin: Int, baselineHR: Double, hasActiveWorkout: Bool = false, activeEnergyKcal: Double = 0) -> Bool {
        if hasActiveWorkout || activeEnergyKcal >= 3.0 {
            return meanBPM <= baselineHR + 85  // full exercise headroom for non-step activity
        }
        let headroom: Double
        switch stepsPerMin {
        case 0..<10:  headroom = 25   // sedentary: up to +25 BPM is benign
        case 10..<40: headroom = 45   // slow walk
        case 40..<70: headroom = 65   // brisk walk
        default:      headroom = 85   // jogging/running: HR can be 85+ above rest
        }
        return meanBPM <= baselineHR + headroom
    }

    // MARK: - Single-turn triage prompt

    /// Embeds all pre-collected signals into one prompt so the LLM needs only one turn.
    /// Quantitative interpretation (slope severity, activity level, HR proportionality)
    /// is computed in Swift so the LLM reasons over semantic labels, not raw numbers.
    static func triagePrompt(context: Context) -> String {
        let meanBPM = context.features.currentHRMetrics.meanBPM
        let slope = context.features.currentHRMetrics.slopeBPMPerMin
        let stepsPerMin = context.features.context.stepsLast5Min / 5
        let baselineHR = context.profile?.baselineHR ?? 70.0
        let hasWorkout = context.features.context.hasActiveWorkout
        let energyKcal = context.features.context.activeEnergyKcal

        let activity = activityLabel(stepsPerMin: stepsPerMin, hasActiveWorkout: hasWorkout, activeEnergyKcal: energyKcal)
        let slopeSeverity = slopeLabel(bpmPerMin: slope)
        let proportionate = isHRProportionate(meanBPM: meanBPM, stepsPerMin: stepsPerMin, baselineHR: baselineHR, hasActiveWorkout: hasWorkout, activeEnergyKcal: energyKcal)
        let hrNote = proportionate
            ? "within expected range for \(activity)"
            : "HIGHER THAN EXPECTED for \(activity) — unexplained elevation"
        let workoutLine = hasWorkout
            ? "\n        - Active workout session detected (HKWorkout)"
            : (energyKcal >= 3.0 ? String(format: "\n        - Caloric expenditure: %.1f kcal in last 5 min — likely non-step exercise", energyKcal) : "")

        let hrSection = """
        - Current mean HR: \(Int(meanBPM)) BPM — \(hrNote)
        - HR slope: \(String(format: "%.1f", slope)) BPM/min — \(slopeSeverity)
        - Activity level: ~\(stepsPerMin) steps/min — \(activity)\(workoutLine)
        """

        let baselineSection: String
        if let profile = context.profile {
            let ratio = context.riskRatio.map { String(format: "%.2f", $0) } ?? "N/A"
            baselineSection = """
            - Age: \(profile.age)
            - Resting HR (baseline): \(Int(profile.baselineHR)) BPM
            - Current HR / resting HR ratio: \(ratio)
            """
        } else {
            baselineSection = "- Baseline unavailable (onboarding incomplete)"
        }

        let displayPhrase = context.anchor.targetPhrase.replacingOccurrences(of: "\n", with: " ")
        let anchorSection: String
        if let transcript = context.anchor.transcript {
            let match = normalizePhrase(context.anchor.targetPhrase) == normalizePhrase(transcript)
            var lines = """
            - Target phrase: "\(displayPhrase)"
            - Spoken transcript: "\(transcript)"
            - Exact match: \(match)
            - recognition_failed: false
            """
            if let m = context.anchor.vocalMetrics {
                let hesitationPct = m.durationSeconds > 0
                    ? Int((m.totalPauseSeconds / m.durationSeconds * 100).rounded())
                    : 0
                lines += "\n- Speaking rate: \(Int(m.speakingRateWPM)) WPM — \(speechRateLabel(m.speakingRateWPM))"
                lines += "\n- Max pause: \(String(format: "%.2f", m.maxPauseSeconds))s — \(maxPauseLabel(m.maxPauseSeconds))"
                lines += "\n- Mean pause: \(String(format: "%.2f", m.meanPauseSeconds))s — \(maxPauseLabel(m.meanPauseSeconds))"
                lines += "\n- Hesitation ratio: \(hesitationPct)% of speech was significant pauses"
                if let b = context.profile?.baselineVocalMetrics {
                    lines += "\n- Rate vs calm baseline: \(vocalRateChangeLabel(baselineWPM: b.speakingRateWPM, currentWPM: m.speakingRateWPM))"
                    lines += "\n- Max pause vs calm baseline: \(pauseMultiplierLabel(baselinePause: b.maxPauseSeconds, currentPause: m.maxPauseSeconds))"
                    lines += "\n- Mean pause vs calm baseline: \(pauseMultiplierLabel(baselinePause: b.meanPauseSeconds, currentPause: m.meanPauseSeconds))"
                }
            }
            anchorSection = lines
        } else {
            anchorSection = """
            - Target phrase: "\(displayPhrase)"
            - recognition_failed: true (user could not speak coherently)
            """
        }

        return """
        You are a clinical triage assistant for a wearable panic-detection app.
        Estimate two INDEPENDENT probabilities based on the sensor readings below.
        The readings include pre-interpreted labels — use them directly in your reasoning.

        ## Sensor Readings

        ### Heart Rate
        \(hrSection)

        ### User Baseline
        \(baselineSection)

        ### Vocal Anchor Test
        \(anchorSection)

        ## Output Definitions

        **likelihoodPanic** — probability of a panic attack:
        Psychogenic tachycardia from fear or anxiety. Key markers: HR higher than expected \
        for activity level, flat or moderate slope at rest, cognitive distress (recognition_failed: true).

        **likelihoodPhysicalAnomaly** — probability of a cardiac or autonomic anomaly:
        Arrhythmia, SVT, or tachycardia disproportionate to observed exertion. \
        NOT simply "not panic" — both probabilities can be high simultaneously \
        (e.g. arrhythmia-triggered anxiety). Key marker: HR unexplained by exertion level.

        ## Reasoning Guide

        Use the pre-computed labels above:

        Active workout session detected OR caloric expenditure ≥3 kcal/5 min + recognition_failed: false
        → Non-step exercise (strength training, cycling, rowing). likelihoodPanic should be VERY LOW (< 0.15) even if HR is elevated and step count is near zero.

        "within expected range" + gradual or flat slope + recognition_failed: false
        → Strong evidence of normal exercise. likelihoodPanic should be LOW (< 0.3).

        "HIGHER THAN EXPECTED" + sedentary + recognition_failed: true
        → Strong panic signal. likelihoodPanic should be HIGH (> 0.7). \
          Also consider elevated physical anomaly if HR is extreme.

        "HIGHER THAN EXPECTED" + sedentary + recognition_failed: false
        → Mixed signal. Panic is possible but anchor success tempers it. \
          Physical anomaly likelihood rises.

        "HIGHER THAN EXPECTED" + jogging or brisk walk + recognition_failed: true
        → Ambiguous. Failed anchor during vigorous activity could be exercise exhaustion. \
          Weigh the slope severity — steep slope at high steps/min still warrants concern.

        recognition_failed: false always reduces likelihoodPanic relative to the HR signal alone.
        recognition_failed: true always increases likelihoodPanic regardless of movement.

        When vocal metrics and a calm-state baseline are available:
        "significant disruption" in rate (≥40% slower) OR max pause "significantly elevated" (≥4x baseline)
        → Treat as equivalent weight to recognition_failed: true.
        "mild disruption" in rate OR "moderately elevated" pauses
        → Moderately increase likelihoodPanic; do not override HR evidence.
        "similar to baseline" + exact match: true
        → Strong evidence against panic; reduce likelihoodPanic significantly.
        When no baseline exists, use absolute WPM labels (< 80 WPM is slow, > 170 is fast).

        ## Output

        Respond with exactly this JSON inside <answer> tags. No other text outside the tags.

        <answer>
        {
          "likelihoodPanic": <0.0–1.0>,
          "likelihoodPhysicalAnomaly": <0.0–1.0>,
          "confidence": "<high|medium|low>",
          "reasoningSummary": "<one sentence covering the key label combination>"
        }
        </answer>

        - likelihoodPanic and likelihoodPhysicalAnomaly are INDEPENDENT — do not force them to sum to 1.0
        - Use confidence "low" when baseline HR is unavailable
        """
    }
}
