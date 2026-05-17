import XCTest
@testable import PanicGuard

final class WatchingGuardTests: XCTestCase {

    private let sut = WatchingGuard()

    // MARK: - Sustained elevation

    func test_elevatedHR_noMovement_returnsSustained() {
        // baseline 70, mean 110 BPM (40 over baseline = 57% above), steps 12
        let result = sut.isSustainedElevation(
            hrSamples: [108, 110, 112, 110],
            baseline: 70,
            stepCount: 12
        )
        XCTAssertTrue(result)
    }

    func test_elevatedHR_withMovement_returnsNotSustained() {
        // same HR elevation but steps = 45 (exercise, not panic)
        let result = sut.isSustainedElevation(
            hrSamples: [108, 110, 112, 110],
            baseline: 70,
            stepCount: 45
        )
        XCTAssertFalse(result)
    }

    // MARK: - Below threshold

    func test_normalHR_returnsFalse() {
        // HR within baseline ± 5 BPM → well below 20% elevation threshold
        let result = sut.isSustainedElevation(
            hrSamples: [68, 70, 72, 71],
            baseline: 70,
            stepCount: 5
        )
        XCTAssertFalse(result)
    }

    func test_mildElevation_returnsFalse() {
        // 10 BPM above baseline (80 BPM vs threshold 84 = 70 * 1.20)
        let result = sut.isSustainedElevation(
            hrSamples: [79, 80, 81, 80],
            baseline: 70,
            stepCount: 5
        )
        XCTAssertFalse(result)
    }

    func test_emptySamples_returnsFalse() {
        let result = sut.isSustainedElevation(hrSamples: [], baseline: 70, stepCount: 0)
        XCTAssertFalse(result)
    }

    func test_exactThresholdBoundary_returnsTrue() {
        // Exactly at 20% above baseline: 70 * 1.20 = 84 BPM
        let result = sut.isSustainedElevation(
            hrSamples: [84],
            baseline: 70,
            stepCount: 0
        )
        XCTAssertTrue(result)
    }

    func test_justBelowThreshold_returnsFalse() {
        // 83.9 BPM — just under 84 BPM threshold
        let result = sut.isSustainedElevation(
            hrSamples: [83.9],
            baseline: 70,
            stepCount: 0
        )
        XCTAssertFalse(result)
    }

    func test_stepCountBoundary_movingAt30Steps_returnsFalse() {
        // stepCount == 30 is the moving threshold (>= 30 → isMoving)
        let result = sut.isSustainedElevation(
            hrSamples: [110],
            baseline: 70,
            stepCount: 30
        )
        XCTAssertFalse(result)
    }

    func test_stepCountBoundary_notMovingAt29Steps_returnsTrue() {
        let result = sut.isSustainedElevation(
            hrSamples: [110],
            baseline: 70,
            stepCount: 29
        )
        XCTAssertTrue(result)
    }
}
