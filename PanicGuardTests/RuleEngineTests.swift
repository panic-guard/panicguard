import XCTest
@testable import PanicGuard

final class RuleEngineTests: XCTestCase {

    private let sut = RuleEngine()

    // MARK: - Helpers

    private func result(
        likelihoodPanic: Double,
        likelihoodPhysicalAnomaly: Double = 0.05,
        confidence: TriageResult.Confidence = .high
    ) -> TriageResult {
        TriageResult(
            likelihoodPanic: likelihoodPanic,
            likelihoodPhysicalAnomaly: likelihoodPhysicalAnomaly,
            confidence: confidence,
            reasoningSummary: "test"
        )
    }

    // MARK: - Breathing guide threshold

    func test_highPanicLikelihood_selectsBreathingGuide() {
        // likelihoodPanic 0.75 exactly, medium confidence — priority 2 not triggered
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.75, confidence: .medium)),
            .breathingGuide
        )
    }

    func test_moderatePanicLikelihood_selectsGroundingExercise() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.55)),
            .groundingExercise
        )
    }

    // MARK: - Physical anomaly path

    func test_highPhysicalAnomaly_andLowPanic_selectsMedicalAlert() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.20, likelihoodPhysicalAnomaly: 0.80)),
            .medicalAlert
        )
    }

    // MARK: - Low likelihood

    func test_lowBothLikelihoods_selectsCalm() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.20, likelihoodPhysicalAnomaly: 0.20)),
            .calm
        )
    }

    // MARK: - Confidence modifier

    func test_lowConfidence_doesNotEscalateToEmergency() {
        // likelihoodPanic 0.95 but confidence is low — falls to .breathingGuide, not .emergencyContact
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.95, confidence: .low)),
            .breathingGuide
        )
    }

    // MARK: - Emergency contact

    func test_emergencyContact_requiresHighConfidence() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.92, confidence: .high)),
            .emergencyContact
        )
    }

    func test_emergencyContact_withMediumConfidence_selectsBreathingGuide() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.92, confidence: .medium)),
            .breathingGuide
        )
    }

    // MARK: - Panic boundary values

    func test_panicExactlyAt_0_75_selectsBreathingGuide() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.75, confidence: .low)),
            .breathingGuide
        )
    }

    func test_panicJustBelow_0_75_selectsGroundingExercise() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.749)),
            .groundingExercise
        )
    }

    func test_panicExactlyAt_0_40_selectsGroundingExercise() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.40)),
            .groundingExercise
        )
    }

    func test_panicJustBelow_0_40_selectsCalm() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.399)),
            .calm
        )
    }

    func test_emergencyContactExactlyAt_0_90_highConfidence() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.90, confidence: .high)),
            .emergencyContact
        )
    }

    func test_panicJustBelow_0_90_highConfidence_selectsBreathingGuide() {
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.899, confidence: .high)),
            .breathingGuide
        )
    }

    // MARK: - Physical anomaly boundary values

    func test_physicalAnomalyExactlyAt_0_70_doesNotTriggerMedicalAlert() {
        // > 0.70 is required; exactly 0.70 falls through to .calm
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.20, likelihoodPhysicalAnomaly: 0.70)),
            .calm
        )
    }

    func test_physicalAnomalyJustAbove_0_70_triggersMedicalAlert() {
        // Confidence is irrelevant for the medical alert path
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.20, likelihoodPhysicalAnomaly: 0.701, confidence: .low)),
            .medicalAlert
        )
    }

    // MARK: - Physical anomaly + panic interaction

    func test_highAnomaly_panicBelow_0_40_prioritisesMedicalAlert() {
        // Anomaly check runs first when likelihoodPanic < 0.40
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.30, likelihoodPhysicalAnomaly: 0.85, confidence: .high)),
            .medicalAlert
        )
    }

    func test_highAnomaly_panicAbove_0_40_selectsGroundingExercise() {
        // likelihoodPanic >= 0.40 disqualifies the priority-1 medicalAlert condition
        XCTAssertEqual(
            sut.selectIntervention(for: result(likelihoodPanic: 0.50, likelihoodPhysicalAnomaly: 0.80)),
            .groundingExercise
        )
    }
}
