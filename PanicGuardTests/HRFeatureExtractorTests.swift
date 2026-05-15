import XCTest
@testable import PanicGuard

final class HRFeatureExtractorTests: XCTestCase {

    private let sut = HRFeatureExtractor()

    // MARK: - Mean BPM

    func test_meanBPM_computedCorrectly() {
        let result = sut.extract(hrSamples: [80, 100, 120], stepCount: 0)
        XCTAssertEqual(result.currentHRMetrics.meanBPM, 100, accuracy: 0.001)
    }

    func test_meanBPM_singleSample_returnsThatValue() {
        let result = sut.extract(hrSamples: [95], stepCount: 0)
        XCTAssertEqual(result.currentHRMetrics.meanBPM, 95, accuracy: 0.001)
    }

    func test_meanBPM_emptySamples_returnsZero() {
        let result = sut.extract(hrSamples: [], stepCount: 0)
        XCTAssertEqual(result.currentHRMetrics.meanBPM, 0, accuracy: 0.001)
    }

    // MARK: - Slope (BPM/min)

    func test_slope_risingHR_isPositive() {
        // 10 samples linearly rising from 70 → 130
        let samples = (0..<10).map { 70.0 + Double($0) * (60.0 / 9.0) }
        let result = sut.extract(hrSamples: samples, stepCount: 0)
        XCTAssertGreaterThan(result.currentHRMetrics.slopeBPMPerMin, 0)
    }

    func test_slope_flatHR_isNearZero() {
        let samples = Array(repeating: 80.0, count: 10)
        let result = sut.extract(hrSamples: samples, stepCount: 0)
        XCTAssertEqual(result.currentHRMetrics.slopeBPMPerMin, 0, accuracy: 0.001)
    }

    func test_slope_fallingHR_isNegative() {
        // 10 samples linearly falling from 130 → 70
        let samples = (0..<10).map { 130.0 - Double($0) * (60.0 / 9.0) }
        let result = sut.extract(hrSamples: samples, stepCount: 0)
        XCTAssertLessThan(result.currentHRMetrics.slopeBPMPerMin, 0)
    }

    // MARK: - Context

    func test_isMoving_trueWhen_stepCountAboveThreshold() {
        let result = sut.extract(hrSamples: [80], stepCount: 31)
        XCTAssertTrue(result.context.isMoving)
    }

    func test_isMoving_falseWhen_stepCountBelowThreshold() {
        let result = sut.extract(hrSamples: [80], stepCount: 30)
        XCTAssertFalse(result.context.isMoving)
    }
}
