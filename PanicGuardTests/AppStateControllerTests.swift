import XCTest
@testable import PanicGuard

final class AppStateControllerTests: XCTestCase {

    // MARK: - Happy-path transitions

    func test_onboardingComplete_transitionsToIdle() {
        // TODO
    }

    func test_hrElevationDetected_fromIdle_transitionsToWatching() {
        // TODO
    }

    func test_elevationSustained_fromWatching_transitionsToSilentInvitation() {
        // TODO
    }

    func test_userAcknowledged_fromSilentInvitation_transitionsToActiveTriage() {
        // TODO
    }

    func test_triageComplete_fromActiveTriage_transitionsToIntervention() {
        // TODO
    }

    func test_interventionDismissed_transitionsToPostEpisodeLog() {
        // TODO
    }

    func test_logComplete_transitionsBackToIdle() {
        // TODO
    }

    // MARK: - Illegal transitions

    func test_hrElevation_fromOnboarding_isIgnored() {
        // TODO — must not skip onboarding
    }

    func test_triageComplete_fromIdle_isIgnored() {
        // TODO — cannot triage without ACTIVE_TRIAGE state
    }
}
