import XCTest
import WatchConnectivity
@testable import PanicGuard

// Tests for PhoneConnector's message-parsing logic.
// WCSession cannot be instantiated in unit tests, so we call the WCSessionDelegate
// methods directly on PhoneConnector to verify callback wiring.
// Callbacks are dispatched via DispatchQueue.main.async, so tests use XCTestExpectation.
final class PhoneConnectorTests: XCTestCase {

    private var sut: PhoneConnector!

    override func setUp() {
        super.setUp()
        sut = PhoneConnector()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - HR batch via transferUserInfo (background)

    func test_didReceiveUserInfo_hrBatch_callsOnHRBatchReceived() {
        let exp = expectation(description: "onHRBatchReceived called")
        var receivedSamples: [Double]?
        var receivedSteps: Int?
        sut.onHRBatchReceived = { samples, steps in
            receivedSamples = samples
            receivedSteps = steps
            exp.fulfill()
        }

        let userInfo: [String: Any] = ["hrSamples": [72.0, 85.0, 110.0], "stepCount": 12]
        sut.session(WCSession.default, didReceiveUserInfo: userInfo)

        waitForExpectations(timeout: 1)
        XCTAssertEqual(receivedSamples, [72.0, 85.0, 110.0])
        XCTAssertEqual(receivedSteps, 12)
    }

    func test_didReceiveUserInfo_missingHRSamples_doesNotCallCallback() {
        sut.onHRBatchReceived = { _, _ in XCTFail("Must not be called") }

        sut.session(WCSession.default, didReceiveUserInfo: ["stepCount": 5])

        // Give main queue time to drain — callback must NOT fire.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    func test_didReceiveUserInfo_missingStepCount_doesNotCallCallback() {
        sut.onHRBatchReceived = { _, _ in XCTFail("Must not be called") }

        sut.session(WCSession.default, didReceiveUserInfo: ["hrSamples": [80.0]])

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    func test_didReceiveUserInfo_unrelatedPayload_doesNotCallCallback() {
        sut.onHRBatchReceived = { _, _ in XCTFail("Must not be called") }

        sut.session(WCSession.default, didReceiveUserInfo: ["type": "userProfile", "ecPhone": "01012345678"])

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    // MARK: - Silent invitation via sendMessage (foreground)

    func test_didReceiveMessage_silentInvitation_callsOnSilentInvitation() {
        let exp = expectation(description: "onSilentInvitation called")
        sut.onSilentInvitation = { exp.fulfill() }

        sut.session(WCSession.default, didReceiveMessage: ["type": "silentInvitation"])

        waitForExpectations(timeout: 1)
    }

    func test_didReceiveMessage_unknownType_doesNotCallSilentInvitation() {
        sut.onSilentInvitation = { XCTFail("Must not be called") }

        sut.session(WCSession.default, didReceiveMessage: ["type": "unrelated"])

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    func test_didReceiveMessage_hrBatch_callsOnHRBatchReceived() {
        let exp = expectation(description: "onHRBatchReceived called")
        var receivedSamples: [Double]?
        sut.onHRBatchReceived = { samples, _ in
            receivedSamples = samples
            exp.fulfill()
        }

        let msg: [String: Any] = ["type": "hrBatch", "hrSamples": [90.0, 100.0], "stepCount": 0]
        sut.session(WCSession.default, didReceiveMessage: msg)

        waitForExpectations(timeout: 1)
        XCTAssertEqual(receivedSamples, [90.0, 100.0])
    }

    // MARK: - Callback not set (must not crash)

    func test_didReceiveUserInfo_withoutCallback_doesNotCrash() {
        sut.onHRBatchReceived = nil
        let userInfo: [String: Any] = ["hrSamples": [80.0], "stepCount": 0]
        XCTAssertNoThrow(sut.session(WCSession.default, didReceiveUserInfo: userInfo))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    func test_didReceiveMessage_withoutCallback_doesNotCrash() {
        sut.onSilentInvitation = nil
        XCTAssertNoThrow(sut.session(WCSession.default, didReceiveMessage: ["type": "silentInvitation"]))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}
