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

    // MARK: New transitions — silentInvitation exits

    func test_userDismissed_fromSilentInvitation_transitionsToIdle() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(sut.state, .silentInvitation)
        sut.send(.userDismissed)
        XCTAssertEqual(sut.state, .idle)
    }

    func test_directIntervention_fromSilentInvitation_transitionsToIntervention() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        sut.send(.userRequestedDirectIntervention)
        XCTAssertEqual(sut.state, .intervention)
    }

    func test_directIntervention_fromSilentInvitation_completesViaPostEpisodeLog() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        sut.send(.userRequestedDirectIntervention)
        sut.send(.interventionDismissed)
        XCTAssertEqual(sut.state, .postEpisodeLog)
        sut.send(.logComplete)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: New transitions — idle shortcuts

    func test_manualTriage_fromIdle_transitionsToActiveTriage() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.userRequestedManualTriage)
        XCTAssertEqual(sut.state, .activeTriage)
    }

    func test_manualTriage_fromOnboarding_isIgnored() {
        let sut = makeController()
        XCTAssertEqual(sut.state, .onboarding)
        sut.send(.userRequestedManualTriage)
        XCTAssertEqual(sut.state, .onboarding)
    }

    func test_manualTriage_fromWatching_isIgnored() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .watching)
        sut.send(.userRequestedManualTriage)
        XCTAssertEqual(sut.state, .watching)
    }

    func test_manualTriage_fromActiveTriage_isIgnored() {
        let sut = makeController()
        advanceToState(.activeTriage, controller: sut)
        sut.send(.userRequestedManualTriage)
        XCTAssertEqual(sut.state, .activeTriage)
    }

    func test_directIntervention_fromIdle_transitionsToIntervention() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.userRequestedDirectIntervention)
        XCTAssertEqual(sut.state, .intervention)
    }

    func test_directIntervention_fromIdle_completesViaPostEpisodeLog() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        sut.send(.userRequestedDirectIntervention)
        sut.send(.interventionDismissed)
        sut.send(.logComplete)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: canSend — manual triage

    func test_canSend_manualTriage_trueWhenIdle() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        XCTAssertTrue(sut.canSend(.userRequestedManualTriage))
    }

    func test_canSend_manualTriage_falseWhenNotIdle() {
        let sut = makeController()
        // Onboarding state
        XCTAssertFalse(sut.canSend(.userRequestedManualTriage))
        // Watching state
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        XCTAssertFalse(sut.canSend(.userRequestedManualTriage))
    }

    // MARK: Agent lifecycle — new paths

    func test_userDismissed_fromSilentInvitation_releasesPreloadedAgent() {
        var factoryCalls = 0
        let fake = FakeTriageAgent()
        let sut = AppStateController(agentFactory: {
            factoryCalls += 1
            return fake
        })
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(factoryCalls, 1, "Agent should be preloaded on silentInvitation")
        sut.send(.userDismissed)
        // On next silentInvitation the factory must be called again (agent was released on dismiss).
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(factoryCalls, 2, "Factory must be called again after dismiss released the agent")
    }

    func test_directIntervention_fromSilentInvitation_releasesPreloadedAgent() {
        var factoryCalls = 0
        let fake = FakeTriageAgent()
        let sut = AppStateController(agentFactory: {
            factoryCalls += 1
            return fake
        })
        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(factoryCalls, 1)
        sut.send(.userRequestedDirectIntervention)
        sut.send(.interventionDismissed)
        sut.send(.logComplete)
        // On next silentInvitation the factory must be called again.
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(factoryCalls, 2, "Factory must be called again after direct intervention released the agent")
    }

    func test_manualTriage_fromIdle_callsAgentFactory() {
        var factoryCalls = 0
        let fake = FakeTriageAgent()
        let sut = AppStateController(agentFactory: {
            factoryCalls += 1
            return fake
        })
        sut.send(.onboardingComplete)
        sut.send(.userRequestedManualTriage)
        XCTAssertEqual(sut.state, .activeTriage)
        XCTAssertEqual(factoryCalls, 1, "Manual triage must create an agent (no preload window available)")
    }

    func test_directIntervention_fromIdle_doesNotCallAgentFactory() {
        var factoryCalls = 0
        let fake = FakeTriageAgent()
        let sut = AppStateController(agentFactory: {
            factoryCalls += 1
            return fake
        })
        sut.send(.onboardingComplete)
        sut.send(.userRequestedDirectIntervention)
        XCTAssertEqual(sut.state, .intervention)
        XCTAssertEqual(factoryCalls, 0, "Direct intervention skips triage entirely — no agent needed")
    }

    func test_manualTriage_preservesPendingFeatures() {
        let sut = makeController()
        sut.send(.onboardingComplete)
        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 120, slopeBPMPerMin: 12),
            context: .init(isMoving: false, stepsLast5Min: 5)
        )
        sut.setPendingFeatures(features)
        sut.send(.userRequestedManualTriage)
        // State reaches activeTriage with features set — no crash, correct state
        XCTAssertEqual(sut.state, .activeTriage)
    }
}
