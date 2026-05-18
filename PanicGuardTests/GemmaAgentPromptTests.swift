import XCTest
@testable import PanicGuard

// MARK: - Prompt label classification tests
//
// GemmaAgentPrompts.triagePrompt() is pure string interpolation — no need to test it.
// What IS worth testing: the classification functions with their switch boundaries,
// since a wrong threshold directly mis-labels signals sent to the LLM.

final class GemmaAgentPromptTests: XCTestCase {

    // MARK: - activityLabel boundaries

    func test_activityLabel_sedentary_under10StepsPerMin() {
        // 45 steps / 5 min = 9 steps/min → sedentary
        XCTAssertTrue(GemmaAgentPrompts.activityLabel(stepsPerMin: 9).contains("sedentary"))
    }

    func test_activityLabel_slowWalk_10to39StepsPerMin() {
        XCTAssertTrue(GemmaAgentPrompts.activityLabel(stepsPerMin: 10).contains("slow walk"))
        XCTAssertTrue(GemmaAgentPrompts.activityLabel(stepsPerMin: 39).contains("slow walk"))
    }

    func test_activityLabel_briskWalk_40to69StepsPerMin() {
        XCTAssertTrue(GemmaAgentPrompts.activityLabel(stepsPerMin: 40).contains("brisk walk"))
        XCTAssertTrue(GemmaAgentPrompts.activityLabel(stepsPerMin: 69).contains("brisk walk"))
    }

    func test_activityLabel_jogging_70plusStepsPerMin() {
        XCTAssertTrue(GemmaAgentPrompts.activityLabel(stepsPerMin: 70).contains("jogging"))
        XCTAssertTrue(GemmaAgentPrompts.activityLabel(stepsPerMin: 84).contains("jogging"))
    }

    // MARK: - slopeLabel boundaries

    func test_slopeLabel_flat_under5() {
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 0),   "flat")
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 4.9), "flat")
    }

    func test_slopeLabel_gradual_5to14() {
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 5),    "gradual")
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 14.9), "gradual")
    }

    func test_slopeLabel_moderate_15to24() {
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 15),   "moderate")
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 24.9), "moderate")
    }

    func test_slopeLabel_steep_25plus() {
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 25), "steep")
        XCTAssertEqual(GemmaAgentPrompts.slopeLabel(bpmPerMin: 32), "steep")
    }

    // MARK: - isHRProportionate boundaries

    func test_proportionate_sedentary_withinHeadroom25() {
        // baseline 65, headroom +25 → up to 90 BPM is proportionate
        XCTAssertTrue(GemmaAgentPrompts.isHRProportionate(meanBPM: 90,  stepsPerMin: 5, baselineHR: 65))
        XCTAssertFalse(GemmaAgentPrompts.isHRProportionate(meanBPM: 91, stepsPerMin: 5, baselineHR: 65))
    }

    func test_proportionate_slowWalk_withinHeadroom45() {
        // baseline 65, headroom +45 → up to 110 BPM is proportionate
        XCTAssertTrue(GemmaAgentPrompts.isHRProportionate(meanBPM: 110,  stepsPerMin: 20, baselineHR: 65))
        XCTAssertFalse(GemmaAgentPrompts.isHRProportionate(meanBPM: 111, stepsPerMin: 20, baselineHR: 65))
    }

    func test_proportionate_jogging_withinHeadroom85() {
        // baseline 65, headroom +85 → up to 150 BPM is proportionate (110 BPM at 84 steps/min = normal)
        XCTAssertTrue(GemmaAgentPrompts.isHRProportionate(meanBPM: 110,  stepsPerMin: 84, baselineHR: 65))
        XCTAssertTrue(GemmaAgentPrompts.isHRProportionate(meanBPM: 150,  stepsPerMin: 84, baselineHR: 65))
        XCTAssertFalse(GemmaAgentPrompts.isHRProportionate(meanBPM: 151, stepsPerMin: 84, baselineHR: 65))
    }

    func test_proportionate_highHR_atRest_isDisproportionate() {
        // 148 BPM, sedentary → 148 > 65+25=90 → not proportionate
        XCTAssertFalse(GemmaAgentPrompts.isHRProportionate(meanBPM: 148, stepsPerMin: 1, baselineHR: 65))
    }

    // MARK: - vocalRateChangeLabel boundaries

    func test_vocalRateChangeLabel_similarToBaseline_over85percent() {
        // 119 / 140 = 0.85 → boundary of "similar"
        XCTAssertTrue(GemmaAgentPrompts.vocalRateChangeLabel(baselineWPM: 140, currentWPM: 119).contains("similar"))
    }

    func test_vocalRateChangeLabel_mildDisruption_60to85percent() {
        // 84 / 140 = 0.60 → boundary of mild/significant
        let label = GemmaAgentPrompts.vocalRateChangeLabel(baselineWPM: 140, currentWPM: 98)
        XCTAssertTrue(label.contains("mild disruption"))
    }

    func test_vocalRateChangeLabel_mildDisruption_containsPercentage() {
        // 98 / 140 ≈ 0.70 → 30% slower
        let label = GemmaAgentPrompts.vocalRateChangeLabel(baselineWPM: 140, currentWPM: 98)
        XCTAssertTrue(label.contains("30%"))
    }

    func test_vocalRateChangeLabel_significantDisruption_under60percent() {
        // 70 / 140 = 0.50 → significant
        let label = GemmaAgentPrompts.vocalRateChangeLabel(baselineWPM: 140, currentWPM: 70)
        XCTAssertTrue(label.contains("significant disruption"))
        XCTAssertTrue(label.contains("50%"))
    }

    func test_vocalRateChangeLabel_noBaseline_returnsNoBaseline() {
        XCTAssertEqual(GemmaAgentPrompts.vocalRateChangeLabel(baselineWPM: 0, currentWPM: 100), "no baseline")
    }

    // MARK: - pauseMultiplierLabel boundaries

    func test_pauseMultiplierLabel_similar_under2x() {
        // 0.18 / 0.10 = 1.8x → similar
        XCTAssertTrue(GemmaAgentPrompts.pauseMultiplierLabel(baselinePause: 0.10, currentPause: 0.18).contains("similar"))
    }

    func test_pauseMultiplierLabel_moderatelyElevated_2to4x() {
        // 0.30 / 0.10 = 3.0x → moderately elevated
        let label = GemmaAgentPrompts.pauseMultiplierLabel(baselinePause: 0.10, currentPause: 0.30)
        XCTAssertTrue(label.contains("moderately elevated"))
    }

    func test_pauseMultiplierLabel_significantlyElevated_over4x() {
        // 0.50 / 0.10 = 5.0x → significantly elevated
        let label = GemmaAgentPrompts.pauseMultiplierLabel(baselinePause: 0.10, currentPause: 0.50)
        XCTAssertTrue(label.contains("significantly elevated"))
    }

    func test_pauseMultiplierLabel_noBaseline_usesAbsoluteMaxPauseLabel() {
        // baselinePause < 0.01 → falls back to maxPauseLabel(2.0) → "long pause"
        let label = GemmaAgentPrompts.pauseMultiplierLabel(baselinePause: 0.0, currentPause: 2.0)
        XCTAssertTrue(label.contains("long pause"))
    }

    // MARK: - normalizePhrase

    func test_normalizePhrase_removesNewlines() {
        XCTAssertEqual(
            GemmaAgentPrompts.normalizePhrase("The morning light\nis calm and still."),
            "the morning light is calm and still"
        )
    }

    func test_normalizePhrase_stripsPunctuation() {
        XCTAssertEqual(GemmaAgentPrompts.normalizePhrase("Slow and steady, I am here."), "slow and steady i am here")
        XCTAssertEqual(GemmaAgentPrompts.normalizePhrase("This moment is enough."), "this moment is enough")
    }

    func test_normalizePhrase_collapsesMultipleSpaces() {
        XCTAssertEqual(GemmaAgentPrompts.normalizePhrase("hello  world"), "hello world")
    }

    func test_normalizePhrase_lowercases() {
        XCTAssertEqual(GemmaAgentPrompts.normalizePhrase("The Sky Is Wide"), "the sky is wide")
    }

    // MARK: - Exact match fix (\n bug)

    func test_prompt_exactMatchTrue_whenPhraseHasNewlineButTranscriptDoesNot() {
        // Core regression test: \n in targetPhrase must not cause exact match to fail.
        let anchor = VocalAnchorResult(
            targetPhrase: "The morning light\nis calm and still.",
            transcript: "the morning light is calm and still."
        )
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor))
        XCTAssertTrue(prompt.contains("Exact match: true"), "Phrase with \\n must match equivalent transcript without \\n")
    }

    func test_prompt_exactMatchFalse_whenTranscriptDiffers() {
        let anchor = VocalAnchorResult(
            targetPhrase: "The morning light\nis calm and still.",
            transcript: "the morning sky is calm"
        )
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor))
        XCTAssertTrue(prompt.contains("Exact match: false"))
    }

    // MARK: - Prompt contains vocal metrics

    func test_prompt_containsVocalMetrics_whenPresent() {
        let metrics = VocalMetrics(
            speakingRateWPM: 72, maxPauseSeconds: 2.30,
            meanPauseSeconds: 0.9, totalPauseSeconds: 3.5, durationSeconds: 9.2
        )
        let anchor = VocalAnchorResult(targetPhrase: "I am safe", transcript: "i am safe", vocalMetrics: metrics)
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor))
        XCTAssertTrue(prompt.contains("72"), "Prompt must include speaking rate WPM")
        XCTAssertTrue(prompt.contains("2.30"), "Prompt must include max pause")
        XCTAssertTrue(prompt.contains("Hesitation ratio:"), "Prompt must include hesitation ratio")
        XCTAssertFalse(prompt.contains("Speech duration:"), "Prompt must not include redundant speech duration")
    }

    func test_prompt_hesitationRatio_isPercentageOfDuration() {
        // totalPauseSeconds=3.5, durationSeconds=10.0 → 35%
        let metrics = VocalMetrics(
            speakingRateWPM: 80, maxPauseSeconds: 1.5,
            meanPauseSeconds: 0.6, totalPauseSeconds: 3.5, durationSeconds: 10.0
        )
        let anchor = VocalAnchorResult(targetPhrase: "I am safe", transcript: "i am safe", vocalMetrics: metrics)
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor))
        XCTAssertTrue(prompt.contains("35%"), "Hesitation ratio must be computed as totalPause / duration")
    }

    func test_prompt_meanPause_hasLabel() {
        let metrics = VocalMetrics(
            speakingRateWPM: 80, maxPauseSeconds: 1.5,
            meanPauseSeconds: 1.8, totalPauseSeconds: 2.0, durationSeconds: 8.0
        )
        let anchor = VocalAnchorResult(targetPhrase: "I am safe", transcript: "i am safe", vocalMetrics: metrics)
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor))
        // 1.8s mean pause → "long pause — hesitation or difficulty"
        XCTAssertTrue(prompt.contains("Mean pause:") && prompt.contains("long pause"),
                      "Mean pause must carry a semantic label, not just a raw number")
    }

    func test_prompt_omitsVocalMetrics_whenNil() {
        let anchor = VocalAnchorResult(targetPhrase: "I am safe", transcript: "i am safe", vocalMetrics: nil)
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor))
        XCTAssertFalse(prompt.contains("Speaking rate:"))
    }

    func test_prompt_containsBaselineComparison_whenBaselineAvailable() {
        let baseline = VocalMetrics(
            speakingRateWPM: 138, maxPauseSeconds: 0.28,
            meanPauseSeconds: 0.11, totalPauseSeconds: 0, durationSeconds: 5.2
        )
        let current = VocalMetrics(
            speakingRateWPM: 68, maxPauseSeconds: 2.1,
            meanPauseSeconds: 0.9, totalPauseSeconds: 3.0, durationSeconds: 12.5
        )
        let profile = UserProfile(age: 30, baselineHR: 72, baselineVocalMetrics: baseline)
        let anchor = VocalAnchorResult(targetPhrase: "I am safe", transcript: "i am safe", vocalMetrics: current)
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor, profile: profile))
        XCTAssertTrue(prompt.contains("calm baseline"), "Prompt must include calm baseline comparison")
    }

    func test_prompt_omitsBaselineComparison_whenNoBaseline() {
        let current = VocalMetrics(
            speakingRateWPM: 68, maxPauseSeconds: 2.1,
            meanPauseSeconds: 0.9, totalPauseSeconds: 3.0, durationSeconds: 12.5
        )
        let profile = UserProfile(age: 30, baselineHR: 72, baselineVocalMetrics: nil)
        let anchor = VocalAnchorResult(targetPhrase: "I am safe", transcript: "i am safe", vocalMetrics: current)
        let prompt = GemmaAgentPrompts.triagePrompt(context: makePromptContext(anchor: anchor, profile: profile))
        XCTAssertFalse(prompt.contains("calm baseline"))
    }
}

// MARK: - Helpers

private func makePromptContext(
    anchor: VocalAnchorResult = VocalAnchorResult(targetPhrase: "I am safe", transcript: "i am safe"),
    profile: UserProfile? = UserProfile(age: 30, baselineHR: 72)
) -> GemmaAgentPrompts.Context {
    GemmaAgentPrompts.Context(
        features: HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 145, slopeBPMPerMin: 30),
            context: .init(isMoving: false, stepsLast5Min: 12)
        ),
        anchor: anchor,
        profile: profile,
        riskRatio: nil
    )
}
