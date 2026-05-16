import XCTest
@testable import PanicGuardWatchApp

final class HRSamplerTests: XCTestCase {

    // NOTE: HRSampler talks to HealthKit — full integration tests require a
    // device or a mocked HKHealthStore. These stubs define the contract.

    func test_samplerProtocol_conformance() {
        let _: HRSampling = HRSampler(mode: .mock(.panic))
        // Compile-time conformance check
    }

    func test_startThenStop_doesNotCrash() {
        let sampler = HRSampler(mode: .mock(.panic))
        sampler.startSampling(handler: { _, _ in })
        sampler.stopSampling()
    }

    func test_startSampling_storesActiveQuery() {
        // mock mode where "query" role is a timer
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

    func test_requestAuthorization_requestsHeartRatePermission() throws {
        // watchOS 시뮬레이터는 HealthKit이 활성화되어 있어 권한 UI를 대기하다 hang됨
        #if targetEnvironment(simulator)
        throw XCTSkip("HealthKit authorization UI cannot appear on watchOS simulator")
        #else
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
        #endif
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
