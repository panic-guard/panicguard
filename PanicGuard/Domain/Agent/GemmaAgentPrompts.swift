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

    // MARK: - Single-turn triage prompt

    /// Embeds all pre-collected signals into one prompt so the LLM needs only one turn.
    static func triagePrompt(context: Context) -> String {
        let stepsPerMin = context.features.context.stepsLast5Min / 5

        let hrSection = """
        - Current mean HR: \(Int(context.features.currentHRMetrics.meanBPM)) BPM
        - HR slope: \(String(format: "%.1f", context.features.currentHRMetrics.slopeBPMPerMin)) BPM/min
        - User is actively moving: \(context.features.context.isMoving)
        - Steps last 5 min: \(context.features.context.stepsLast5Min) (~\(stepsPerMin) steps/min)
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

        let anchorSection: String
        if let transcript = context.anchor.transcript {
            let match = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ==
                        context.anchor.targetPhrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            anchorSection = """
            - Target phrase: "\(context.anchor.targetPhrase)"
            - Spoken transcript: "\(transcript)"
            - Exact match: \(match)
            - recognition_failed: false
            """
        } else {
            anchorSection = """
            - Target phrase: "\(context.anchor.targetPhrase)"
            - recognition_failed: true (user could not speak coherently)
            """
        }

        return """
        You are a clinical triage assistant for a wearable panic-detection app.
        Given the sensor readings below, estimate the probability that the user is having a \
        panic attack versus experiencing normal physical exertion or another physical cause.

        ## Sensor Readings

        ### Heart Rate
        \(hrSection)

        ### User Baseline
        \(baselineSection)

        ### Vocal Anchor Test
        \(anchorSection)

        ## How to interpret the signals

        Heart rate elevation alone is non-specific — it occurs in both panic and exercise. \
        You must weigh all signals together:

        **Movement context**
        High step rate (> 60 steps/min) combined with isMoving=true is strong evidence of \
        physical exertion. Panic attacks cause tachycardia at rest, not during vigorous locomotion. \
        Low or zero steps with a sudden HR spike is consistent with panic.

        **HR slope**
        A steep sudden rise (> 20 BPM/min) without movement suggests autonomic activation typical \
        of panic. A gradual rise (< 10 BPM/min) during activity is a normal exercise warm-up pattern.

        **Vocal anchor**
        The user was asked to verbalize a short calming phrase. Being able to speak it clearly \
        (recognition_failed: false) indicates the user is cognitively composed — a meaningful \
        indicator against acute panic. Failing to produce speech (recognition_failed: true) suggests \
        the user is too distressed to verbalize, which substantially raises panic likelihood.

        **HR / baseline ratio**
        A ratio > 2.0 with no movement deserves more weight than the same ratio during active exercise, \
        where such elevation is physiologically expected.

        Reason holistically. Do not mechanically threshold any single signal — consider the full picture.

        ## Output

        Respond with exactly this JSON inside <answer> tags. No other text outside the tags.

        <answer>
        {
          "likelihoodPanic": <0.0–1.0>,
          "likelihoodPhysicalAnomaly": <0.0–1.0>,
          "confidence": "<high|medium|low>",
          "reasoningSummary": "<one sentence covering the key combination of signals>"
        }
        </answer>

        - likelihoodPanic and likelihoodPhysicalAnomaly are independent probabilities (need not sum to 1.0)
        - Use confidence "low" when baseline HR is unavailable
        """
    }
}
