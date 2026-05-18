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
            .components(separatedBy: .punctuationCharacters)
            .joined()
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
            let displayTranscript = transcript.replacingOccurrences(of: "\n", with: " ")
            var lines = """
            - Target phrase: "\(displayPhrase)"
            - Spoken transcript: "\(displayTranscript)"
            - Exact match: \(match)
            - speech_recognized: true
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
            - speech_recognized: false (user could not speak coherently)
            """
        }

        return """
        You are a panic-detection triage assistant.
        Output two INDEPENDENT probabilities from the sensor readings below.

        ## Readings

        ### Heart Rate
        \(hrSection)

        ### Baseline
        \(baselineSection)

        ### Vocal Anchor
        \(anchorSection)

        ## Rules

        **likelihoodPanic** — psychogenic: unexplained HR elevation + cognitive/vocal distress
        **likelihoodPhysicalAnomaly** — cardiac/autonomic: HR disproportionate to exertion (independent; both can be simultaneously high)

        Conditions → likelihoodPanic target:

        workout detected + speech_recognized: true
        → < 0.15 (non-step exercise; low panic even if step count is near zero)

        "within expected range" + speech_recognized: true
        → < 0.30

        "HIGHER THAN EXPECTED" + sedentary + speech_recognized: false
        → > 0.70; also raise physicalAnomaly if HR is extreme

        "HIGHER THAN EXPECTED" + sedentary + speech_recognized: true
        → 0.40–0.65; raise physicalAnomaly (unexplained HR with intact cognition)

        "HIGHER THAN EXPECTED" + jogging/brisk walk + speech_recognized: false
        → Elevated; steep slope warrants concern even with movement

        "within expected range" + sedentary + speech_recognized: false
        → 0.45–0.60 (vocal failure without elevated HR = pre-panic cognitive/respiratory symptoms; user self-initiated triage)

        Vocal quality overrides — apply to any "within expected range" + sedentary case:
        "significant disruption" (rate ≥40% slower) OR "significantly elevated" pause (≥4×) OR exact match: false
        → 0.45–0.60; override the base case regardless of speech_recognized value
        "mild disruption" (rate 15–40% slower) OR "moderately elevated" pause (2–4×)
        → 0.25–0.40; do not override HR evidence
        "similar to baseline" + exact match: true
        → < 0.25; strong evidence against panic

        ## Thresholds

        likelihoodPanic: < 0.40 no intervention | 0.40–0.74 grounding | ≥ 0.75 breathing guide | ≥ 0.90 + high → emergency contact
        likelihoodPhysicalAnomaly > 0.70 + likelihoodPanic < 0.40 → medical alert
        If the clinical picture warrants crossing a threshold, the number must reflect it.

        ## Output

        Respond with exactly this JSON inside <answer> tags. No text outside.

        <answer>
        {
          "likelihoodPanic": <0.0–1.0>,
          "likelihoodPhysicalAnomaly": <0.0–1.0>,
          "confidence": "<high|medium|low>",
          "reasoningSummary": "<one sentence>"
        }
        </answer>

        confidence "low" if baseline HR unavailable. Both values are independent — do not sum to 1.0.
        """
    }
}
