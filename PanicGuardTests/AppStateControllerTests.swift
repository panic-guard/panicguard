import XCTest
@testable import PanicGuard

// MARK: - Fake agent (no LLM, returns a canned result)

private final class FakeTriageAgent: PanicTriageAgentProtocol {
    var result: TriageResult = .init(
        likelihoodPanic: 0.8,
        likelihoodPhysicalAnomaly: 0.1,
        confidence: .high,
        reasoningSummary: "Test result."
    )
    var didRunTriage = false

    func runTriage(features: HRFeaturePayload, vocalAnchor: VocalAnchorResult) async throws -> TriageResult {
        didRunTriage = true
        return result
    }
}

// MARK: - Helpers

@MainActor
private func makeController(agent: (any PanicTriageAgentProtocol)? = nil) -> AppStateController {
    let fake = agent ?? FakeTriageAgent()
    return AppStateController(agentFactory: { fake })
}

@MainActor
private func advanceToState(_ target: AppState, controller: AppStateController) {
    let sequence: [(AppState, AppStateEvent)] = [
        (.onboarding,       .onboardingComplete),
        (.idle,             .hrElevationDetected),
        (.watching,         .elevationSustained),
        (.silentInvitation, .userAcknowledged),
    ]
    for (requiredState, event) in sequence {
        if controller.state == target { break }
        if controller.state == requiredState { controller.send(event) }
    }
}

// MARK: - Tests

@MainActor
final class AppStateControllerTests: XCTestCase {

    // MARK: Happy-path transitions

    func test_onboardingComplete_transitionsToIdle() {
        let sut = makeController()
        XCTAssertEqual(sut.state, .onboarding)
        sut.send(.onboardingComplete)
        XCTAssertEqual(sut.state, .idle)
    }

    func test_hrElevationDetected_fromIdle_transitionsToWatching() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .watching)
    }

    func test_elevationSustained_fromWatching_transitionsToSilentInvitation() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(sut.state, .silentInvitation)
    }

    func test_userAcknowledged_fromSilentInvitation_transitionsToActiveTriage() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        sut.send(.userAcknowledged)
        XCTAssertEqual(sut.state, .activeTriage)
    }

    func test_triageComplete_fromActiveTriage_transitionsToIntervention() {
        let sut = makeController()
        advanceToState(.activeTriage, controller: sut)
        let result = TriageResult(
            likelihoodPanic: 0.9,
            likelihoodPhysicalAnomaly: 0.05,
            confidence: .high,
            reasoningSummary: "Panic."
        )
        sut.send(.triageComplete(result))
        XCTAssertEqual(sut.state, .intervention)
        XCTAssertEqual(sut.lastTriageResult, result)
    }

    func test_interventionDismissed_transitionsToPostEpisodeLog() {
        let sut = makeController()
        advanceToState(.activeTriage, controller: sut)
        let result = TriageResult(
            likelihoodPanic: 0.7,
            likelihoodPhysicalAnomaly: 0.1,
            confidence: .medium,
            reasoningSummary: "Likely panic."
        )
        sut.send(.triageComplete(result))
        sut.send(.interventionDismissed)
        XCTAssertEqual(sut.state, .postEpisodeLog)
    }

    func test_logComplete_transitionsBackToIdle() {
        let sut = makeController()
        advanceToState(.activeTriage, controller: sut)
        let result = TriageResult(
            likelihoodPanic: 0.6,
            likelihoodPhysicalAnomaly: 0.15,
            confidence: .medium,
            reasoningSummary: "Borderline."
        )
        sut.send(.triageComplete(result))
        sut.send(.interventionDismissed)
        sut.send(.logComplete)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: Illegal transitions (silently ignored)

    func test_hrElevation_fromOnboarding_isIgnored() {
        let sut = makeController()
        XCTAssertEqual(sut.state, .onboarding)
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .onboarding)  // must not change
    }

    func test_triageComplete_fromIdle_isIgnored() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        XCTAssertEqual(sut.state, .idle)
        let result = TriageResult(
            likelihoodPanic: 0.5,
            likelihoodPhysicalAnomaly: 0.2,
            confidence: .low,
            reasoningSummary: "Should not apply."
        )
        sut.send(.triageComplete(result))
        XCTAssertEqual(sut.state, .idle)  // must not change
    }

    // MARK: GemmaAgent lifecycle

    func test_resetToIdle_fromActiveTriage_nilesTriageAgent() {
        let sut = makeController()
        advanceToState(.activeTriage, controller: sut)
        XCTAssertEqual(sut.state, .activeTriage)
        sut.send(.resetToIdle)
        XCTAssertEqual(sut.state, .idle)
        // Agent memory is released — verified indirectly by confirming state is idle
        // and no triage result was set.
        XCTAssertNil(sut.lastTriageResult)
    }

    func test_agentFactory_isCalledOnSilentInvitation() {
        var factoryCalls = 0
        let fake = FakeTriageAgent()
        let sut = AppStateController(agentFactory: {
            factoryCalls += 1
            return fake
        })
        // Factory is called at silentInvitation (beginPreload) for early engine warm-up.
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(factoryCalls, 1, "Factory must be called exactly once when entering silentInvitation")
        // Advancing to activeTriage must not call the factory again.
        sut.send(.userAcknowledged)
        XCTAssertEqual(factoryCalls, 1, "Factory must not be called a second time on userAcknowledged")
    }

    func test_secondTriage_callsFactoryAgain() {
        var factoryCalls = 0
        let fake = FakeTriageAgent()
        let sut = AppStateController(agentFactory: {
            factoryCalls += 1
            return fake
        })

        // First triage cycle
        advanceToState(.activeTriage, controller: sut)
        sut.send(.triageComplete(TriageResult(likelihoodPanic: 0.8, likelihoodPhysicalAnomaly: 0.1, confidence: .high, reasoningSummary: "First")))
        sut.send(.interventionDismissed)
        sut.send(.logComplete)

        // Second triage cycle
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        sut.send(.userAcknowledged)

        XCTAssertEqual(factoryCalls, 2, "Factory must be called again for the second triage cycle")
    }
}
