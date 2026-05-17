import XCTest
@testable import PanicGuard

final class iPhoneHRFetcherTests: XCTestCase {

    // MARK: - Simulator behavior

    func test_fetch_returnsNil_whenHealthKitUnavailable() async {
        // iOS simulator does not support HealthKit — no HR samples → must return nil
        // to prevent GemmaAgent from receiving a misleading 0 BPM payload.
        #if targetEnvironment(simulator)
        let fetcher = iPhoneHRFetcher()
        let result = await fetcher.fetch()
        XCTAssertNil(result, "fetch() must return nil when no Watch HR data is available")
        #endif
    }

    // MARK: - MockHRFetcher contract

    func test_mockFetcher_returnsConfiguredPayload() async {
        let expected = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 130, slopeBPMPerMin: 15),
            context: .init(isMoving: false, stepsLast5Min: 10)
        )
        let mock = MockHRFetcher(payload: expected)
        let result = await mock.fetch()
        XCTAssertEqual(result, expected)
    }

    func test_mockFetcher_returnsNil_whenConfiguredWithNil() async {
        let mock = MockHRFetcher(payload: nil)
        let result = await mock.fetch()
        XCTAssertNil(result)
    }

    // MARK: - HRFeatureExtractor integration (no HealthKit required)

    func test_singleHRSample_producesZeroSlope() {
        // Linear slope requires >= 2 samples — single sample must not crash and returns slope 0.
        let extractor = HRFeatureExtractor()
        let payload = extractor.extract(hrSamples: [85], stepCount: 0)
        XCTAssertEqual(payload.currentHRMetrics.meanBPM, 85)
        XCTAssertEqual(payload.currentHRMetrics.slopeBPMPerMin, 0)
    }

    func test_lowStepCount_isMovingFalse() {
        // Threshold: stepCount > 30 → isMoving. Exactly 30 must be false.
        let extractor = HRFeatureExtractor()
        let payload = extractor.extract(hrSamples: [90], stepCount: 30)
        XCTAssertFalse(payload.context.isMoving)
    }

    func test_highStepCount_isMovingTrue() {
        let extractor = HRFeatureExtractor()
        let payload = extractor.extract(hrSamples: [90], stepCount: 31)
        XCTAssertTrue(payload.context.isMoving)
    }

    func test_multipleHRSamples_positiveSlope() {
        // Rising HR over time must produce a positive slope.
        let extractor = HRFeatureExtractor()
        let rising = [70.0, 90.0, 110.0, 130.0, 150.0]
        let payload = extractor.extract(hrSamples: rising, stepCount: 0)
        XCTAssertGreaterThan(payload.currentHRMetrics.slopeBPMPerMin, 0)
    }

    func test_stepsPassedThrough_toPayload() {
        let extractor = HRFeatureExtractor()
        let payload = extractor.extract(hrSamples: [80], stepCount: 42)
        XCTAssertEqual(payload.context.stepsLast5Min, 42)
    }
}

// MARK: - HRFetching protocol conformance

final class HRFetchingProtocolTests: XCTestCase {

    func test_iPhoneHRFetcher_conformsToHRFetchingProtocol() {
        // Compile-time check: iPhoneHRFetcher must satisfy HRFetching.
        let _: any HRFetching = iPhoneHRFetcher()
        // If this compiles, the protocol is satisfied.
    }

    func test_mockHRFetcher_conformsToHRFetchingProtocol() {
        let _: any HRFetching = MockHRFetcher(payload: nil)
    }

    func test_hrFetching_canBeUsedAsExistential() async {
        let fetcher: any HRFetching = MockHRFetcher(payload: HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 90, slopeBPMPerMin: 5),
            context: .init(isMoving: false, stepsLast5Min: 3)
        ))
        let result = await fetcher.fetch()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.currentHRMetrics.meanBPM, 90)
    }
}

// MARK: - MockHRFetcher

struct MockHRFetcher: HRFetching {
    let payload: HRFeaturePayload?
    func fetch() async -> HRFeaturePayload? { payload }
}
