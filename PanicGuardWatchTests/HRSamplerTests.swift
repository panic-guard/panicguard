import XCTest
@testable import PanicGuardWatchApp

final class HRSamplerTests: XCTestCase {

    // NOTE: HRSampler talks to HealthKit — full integration tests require a
    // device or a mocked HKHealthStore. These stubs define the contract.

    func test_samplerProtocol_conformance() {
        // TODO: verify HRSampler conforms to HRSampling at compile time
    }

    func test_startThenStop_doesNotCrash() {
        // TODO: mock HKHealthStore, call start+stop, assert no error thrown
    }
}
