import XCTest
@testable import PanicGuard

final class HRFeatureExtractorTests: XCTestCase {

    // MARK: - Mean BPM

    func test_meanBPM_computedCorrectly() {
        // TODO: [80, 100, 120] → mean 100
    }

    func test_meanBPM_singleSample_returnsThatValue() {
        // TODO
    }

    func test_meanBPM_emptySamples_returnsZero() {
        // TODO
    }

    // MARK: - Slope (bpm/min)

    func test_slope_risingHR_isPositive() {
        // TODO: simulate 10 samples over 1 min climbing from 70 → 130
    }

    func test_slope_flatHR_isNearZero() {
        // TODO
    }

    func test_slope_fallingHR_isNegative() {
        // TODO
    }

    // MARK: - Context

    func test_isMoving_trueWhen_stepCountAboveThreshold() {
        // TODO: > 30 steps in 5 min → isMoving true
    }

    func test_isMoving_falseWhen_stepCountBelowThreshold() {
        // TODO
    }
}
