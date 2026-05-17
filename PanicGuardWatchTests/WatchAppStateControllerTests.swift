import XCTest
@testable import PanicGuardWatchApp

// Tests for the Watch-side AppStateController state machine.
// Covers:
//   1. New transitions: hrElevationDetected, elevationSustained (Watch mirrors iPhone logic)
//   2. iPhone push path: onWatchStateReceived() drives state directly (robust to missed events)
//   3. interventionDismissed → idle (Watch does NOT do post-episode logging; iPhone owns that)
@MainActor
final class WatchAppStateControllerTests: XCTestCase {

    private var sut: AppStateController!

    override func setUp() {
        super.setUp()
        sut = AppStateController()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_isIdle() {
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - hrElevationDetected

    func test_hrElevationDetected_fromIdle_transitionsToWatching() {
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .watching)
    }

    func test_hrElevationDetected_fromWatching_isIgnored() {
        sut.send(.hrElevationDetected)   // idle → watching
        sut.send(.hrElevationDetected)   // watching + same event: ignored
        XCTAssertEqual(sut.state, .watching)
    }

    func test_hrElevationDetected_fromSilentInvitation_isIgnored() {
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        sut.send(.hrElevationDetected)   // silentInvitation + event: ignored
        XCTAssertEqual(sut.state, .silentInvitation)
    }

    // MARK: - elevationSustained

    func test_elevationSustained_fromWatching_transitionsToSilentInvitation() {
        sut.send(.hrElevationDetected)   // idle → watching
        sut.send(.elevationSustained)    // watching → silentInvitation
        XCTAssertEqual(sut.state, .silentInvitation)
    }

    func test_elevationSustained_fromIdle_isIgnored() {
        sut.send(.elevationSustained)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - iPhone push: onWatchStateReceived

    func test_onWatchStateReceived_silentInvitation_fromIdle_directTransition() {
        // iPhone may push silentInvitation even if Watch missed the watching push.
        sut.onWatchStateReceived("silentInvitation")
        XCTAssertEqual(sut.state, .silentInvitation)
    }

    func test_onWatchStateReceived_watching_transitionsToWatching() {
        sut.onWatchStateReceived("watching")
        XCTAssertEqual(sut.state, .watching)
    }

    func test_onWatchStateReceived_idle_transitionsToIdle() {
        sut.send(.hrElevationDetected)   // idle → watching
        sut.onWatchStateReceived("idle")
        XCTAssertEqual(sut.state, .idle)
    }

    func test_onWatchStateReceived_unknownKey_doesNotTransition() {
        sut.onWatchStateReceived("activeTriage")
        XCTAssertEqual(sut.state, .idle)
    }

    func test_onWatchStateReceived_idle_fromSilentInvitation_resetsToIdle() {
        // Phone dismissed → Watch must also reset so it doesn't show stale invitation.
        sut.onWatchStateReceived("silentInvitation")
        sut.onWatchStateReceived("idle")
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - interventionDismissed → idle (Watch skips postEpisodeLog)

    func test_interventionDismissed_fromIntervention_transitionsToIdle() {
        sut.send(.userRequestedDirectIntervention)   // idle → intervention
        sut.send(.interventionDismissed)
        XCTAssertEqual(sut.state, .idle)
    }

    func test_interventionDismissed_neverReachesPostEpisodeLog() {
        sut.send(.userRequestedDirectIntervention)
        sut.send(.interventionDismissed)
        XCTAssertNotEqual(sut.state, .postEpisodeLog)
    }

    func test_interventionDismissed_fromSilentInvitationPath_transitionsToIdle() {
        sut.onWatchStateReceived("silentInvitation")
        sut.send(.userRequestedDirectIntervention)
        sut.send(.interventionDismissed)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - resetToIdle

    func test_resetToIdle_fromSilentInvitation_transitionsToIdle() {
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        sut.send(.resetToIdle)
        XCTAssertEqual(sut.state, .idle)
    }

    func test_resetToIdle_fromWatching_transitionsToIdle() {
        sut.send(.hrElevationDetected)
        sut.send(.resetToIdle)
        XCTAssertEqual(sut.state, .idle)
    }

    func test_resetToIdle_fromIntervention_transitionsToIdle() {
        sut.send(.userRequestedDirectIntervention)
        sut.send(.resetToIdle)
        XCTAssertEqual(sut.state, .idle)
    }
}
