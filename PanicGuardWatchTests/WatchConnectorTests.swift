import XCTest
import WatchConnectivity
@testable import PanicGuardWatchApp

// Tests for WatchConnector's message-parsing logic on the Watch side.
// WCSession cannot be instantiated in unit tests, so we call delegate methods directly.
// Callbacks dispatch via DispatchQueue.main.async → positive tests use XCTestExpectation.
final class WatchConnectorTests: XCTestCase {

    private var sut: WatchConnector!

    override func setUp() {
        super.setUp()
        sut = WatchConnector()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - watchState messages from iPhone

    func test_didReceiveMessage_watchState_silentInvitation_callsCallback() {
        let exp = expectation(description: "onWatchStateReceived called")
        var received: String?
        sut.onWatchStateReceived = { name in
            received = name
            exp.fulfill()
        }
        sut.session(WCSession.default, didReceiveMessage: ["type": "watchState", "state": "silentInvitation"])
        waitForExpectations(timeout: 1)
        XCTAssertEqual(received, "silentInvitation")
    }

    func test_didReceiveMessage_watchState_watching_callsCallback() {
        let exp = expectation(description: "onWatchStateReceived called")
        var received: String?
        sut.onWatchStateReceived = { name in
            received = name
            exp.fulfill()
        }
        sut.session(WCSession.default, didReceiveMessage: ["type": "watchState", "state": "watching"])
        waitForExpectations(timeout: 1)
        XCTAssertEqual(received, "watching")
    }

    func test_didReceiveMessage_watchState_idle_callsCallback() {
        let exp = expectation(description: "onWatchStateReceived called")
        var received: String?
        sut.onWatchStateReceived = { name in
            received = name
            exp.fulfill()
        }
        sut.session(WCSession.default, didReceiveMessage: ["type": "watchState", "state": "idle"])
        waitForExpectations(timeout: 1)
        XCTAssertEqual(received, "idle")
    }

    func test_didReceiveMessage_nonWatchStateType_doesNotCallCallback() {
        sut.onWatchStateReceived = { _ in XCTFail("Must not be called") }
        sut.session(WCSession.default, didReceiveMessage: ["type": "userProfile", "ecPhone": "01012345678"])
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    func test_didReceiveMessage_watchStateMissingStateKey_doesNotCallCallback() {
        sut.onWatchStateReceived = { _ in XCTFail("Must not be called") }
        sut.session(WCSession.default, didReceiveMessage: ["type": "watchState"]) // no "state" key
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    func test_didReceiveMessage_watchState_nilCallback_doesNotCrash() {
        sut.onWatchStateReceived = nil
        XCTAssertNoThrow(
            sut.session(WCSession.default, didReceiveMessage: ["type": "watchState", "state": "silentInvitation"])
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    // MARK: - watchState via background transfer (fallback when Watch not reachable)

    func test_didReceiveUserInfo_watchState_silentInvitation_callsCallback() {
        let exp = expectation(description: "onWatchStateReceived via userInfo")
        var received: String?
        sut.onWatchStateReceived = { name in
            received = name
            exp.fulfill()
        }
        sut.session(WCSession.default, didReceiveUserInfo: ["type": "watchState", "state": "silentInvitation"])
        waitForExpectations(timeout: 1)
        XCTAssertEqual(received, "silentInvitation")
    }

    func test_didReceiveUserInfo_watchState_idle_callsCallback() {
        let exp = expectation(description: "onWatchStateReceived via userInfo idle")
        var received: String?
        sut.onWatchStateReceived = { name in
            received = name
            exp.fulfill()
        }
        sut.session(WCSession.default, didReceiveUserInfo: ["type": "watchState", "state": "idle"])
        waitForExpectations(timeout: 1)
        XCTAssertEqual(received, "idle")
    }

    func test_didReceiveUserInfo_watchStateMissingStateKey_doesNotCallCallback() {
        sut.onWatchStateReceived = { _ in XCTFail("Must not be called") }
        sut.session(WCSession.default, didReceiveUserInfo: ["type": "watchState"])
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    // MARK: - userProfile messages (regression — must still work after adding watchState handler)

    func test_didReceiveUserInfo_userProfile_callsProfileCallback() {
        let exp = expectation(description: "onProfileReceived called")
        var receivedPhone: String?
        sut.onProfileReceived = { phone in
            receivedPhone = phone
            exp.fulfill()
        }
        sut.session(WCSession.default, didReceiveUserInfo: ["type": "userProfile", "ecPhone": "+14155550123"])
        waitForExpectations(timeout: 1)
        XCTAssertEqual(receivedPhone, "+14155550123")
    }

    func test_didReceiveUserInfo_nilPhone_callsCallbackWithNil() {
        let exp = expectation(description: "onProfileReceived called with nil")
        var receivedPhone: String? = "sentinel"
        sut.onProfileReceived = { phone in
            receivedPhone = phone
            exp.fulfill()
        }
        sut.session(WCSession.default, didReceiveUserInfo: ["type": "userProfile"])
        waitForExpectations(timeout: 1)
        XCTAssertNil(receivedPhone)
    }
}
