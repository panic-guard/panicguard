import XCTest
@testable import PanicGuard

final class RuleEngineTests: XCTestCase {

    // MARK: - Breathing guide threshold

    func test_highPanicLikelihood_selectsBreathingGuide() {
        // TODO: likelihoodPanic >= 0.75 → .breathingGuide
    }

    func test_moderatePanicLikelihood_selectsGroundingExercise() {
        // TODO: 0.40 <= likelihoodPanic < 0.75 → .groundingExercise
    }

    // MARK: - Physical anomaly path

    func test_highPhysicalAnomaly_andLowPanic_selectsNone() {
        // TODO: likelihoodPhysicalAnomaly > 0.7, likelihoodPanic < 0.4 → .none (possible cardiac)
    }

    // MARK: - Low likelihood

    func test_lowBothLikelihoods_selectsNone() {
        // TODO: both < 0.4 → .none
    }

    // MARK: - Confidence modifier

    func test_lowConfidence_doesNotEscalateToEmergency() {
        // TODO: even high panic but low confidence → no emergency contact
    }
}
