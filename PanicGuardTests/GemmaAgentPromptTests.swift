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
}
