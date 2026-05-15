import XCTest
@testable import PanicGuardWatchApp

final class HRSamplerTests: XCTestCase {

    // NOTE: HRSampler talks to HealthKit — full integration tests require a
    // device or a mocked HKHealthStore. These stubs define the contract.

    func test_samplerProtocol_conformance() {
        let _: HRSampling = HRSampler(mode: .mock(.panic))
        // 컴파일 통과 = 프로토콜 준수 확인
    }

    func test_startThenStop_doesNotCrash() {
        let sampler = HRSampler(mode: .mock(.panic))
        sampler.startSampling(handler: { _, _ in })
        sampler.stopSampling()
    }

    func test_startSampling_storesActiveQuery() {
        // mock 모드에서 "query" 역할 = timer
        let sampler = HRSampler(mode: .mock(.panic))
        sampler.startSampling(handler: { _, _ in })
        XCTAssertNotNil(sampler.timer)
        sampler.stopSampling()
    }

    func test_stopSampling_clearsActiveQuery() {
        let sampler = HRSampler(mode: .mock(.panic))
        sampler.startSampling(handler: { _, _ in })
        sampler.stopSampling()
        XCTAssertNil(sampler.timer)
    }

    func test_requestAuthorization_requestsHeartRatePermission() {
        // iOS/watchOS simulator에서 HealthKit 미지원 → 특정 에러 throw 확인
        let sampler = HRSampler(mode: .real)
        let expectation = expectation(description: "auth completes")
        Task {
            do {
                try await sampler.requestAuthorization()
            } catch let err as NSError {
                XCTAssertEqual(err.domain, "HealthKitUnavailable")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
    }

    func test_newHeartRateSample_callsHandler() {
        let sampler = HRSampler(mode: .mock(.panic))
        let expectation = expectation(description: "handler called")
        sampler.startSampling { bpm, stepCount in
            XCTAssertGreaterThan(bpm, 0)
            XCTAssertGreaterThanOrEqual(stepCount, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
        sampler.stopSampling()
    }
}
