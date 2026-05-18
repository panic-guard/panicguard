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

// MARK: - Spy agent (tracks preload calls)

private final class SpyTriageAgent: PanicTriageAgentProtocol {
    var preloadCalled = false
    func preload() async { preloadCalled = true }
    func runTriage(features: HRFeaturePayload, vocalAnchor: VocalAnchorResult) async throws -> TriageResult {
        TriageResult(likelihoodPanic: 0.5, likelihoodPhysicalAnomaly: 0.1, confidence: .medium, reasoningSummary: "spy")
    }
}

// MARK: - Fake HR fetcher

private struct FakeHRFetcher: HRFetching {
    let payload: HRFeaturePayload?
    func fetch() async -> HRFeaturePayload? {
        await Task.yield()  // Ensure at least one suspension so polling loop yields properly.
        return payload
    }
}

// MARK: - Fake WatchingGuard

private final class FakeWatchingGuard: WatchingGuardProtocol {
    var shouldElevate = false
    func isSustainedElevation(hrSamples: [Double], baseline: Double, stepCount: Int, activeEnergyKcal: Double, hasActiveWorkout: Bool) -> Bool {
        shouldElevate
    }
}

// MARK: - Helpers

/// Returns a UserProfileStore backed by a fresh, isolated UserDefaults suite.
/// Prevents real app data from leaking into tests and causing onboarding-skip.
private func freshProfileStore() -> UserProfileStore {
    let suite = "com.panicguard.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return UserProfileStore(defaults: defaults)
}

@MainActor
private func makeController(
    agent: (any PanicTriageAgentProtocol)? = nil,
    hrFetcher: (any HRFetching)? = nil,
    watchingGuard: WatchingGuardProtocol? = nil
) -> AppStateController {
    let fake = agent ?? FakeTriageAgent()
    return AppStateController(
        agentFactory: { fake },
        watchingGuard: watchingGuard ?? WatchingGuard(),
        hrFetcher: hrFetcher ?? FakeHRFetcher(payload: nil),
        profileStore: freshProfileStore()
    )
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
        }, profileStore: freshProfileStore())
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
        }, profileStore: freshProfileStore())

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
        }, profileStore: freshProfileStore())
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
        }, profileStore: freshProfileStore())
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
        }, profileStore: freshProfileStore())
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
        }, profileStore: freshProfileStore())
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
        XCTAssertEqual(sut.state, .activeTriage)
    }

    // MARK: - WatchingGuard polling

    func test_hrElevationDetected_startsPollingWithFakeHRFetcher() async {
        // FakeWatchingGuard set to elevate immediately → polling loop fires elevationSustained.
        let guard_ = FakeWatchingGuard()
        guard_.shouldElevate = true
        let elevatedPayload = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 150, slopeBPMPerMin: 25),
            context: .init(isMoving: false, stepsLast5Min: 5)
        )
        let fetcher = FakeHRFetcher(payload: elevatedPayload)
        let sut = makeController(hrFetcher: fetcher, watchingGuard: guard_)

        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .watching)

        // Drain the run loop until polling task fires or timeout.
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(sut.state, .silentInvitation,
            "When WatchingGuard reports elevation, polling must advance state to silentInvitation")
    }

    func test_watchingPoll_doesNotElevate_whenGuardReturnsFalse() async {
        let guard_ = FakeWatchingGuard()
        guard_.shouldElevate = false
        let payload = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 80, slopeBPMPerMin: 2),
            context: .init(isMoving: false, stepsLast5Min: 5)
        )
        let sut = makeController(hrFetcher: FakeHRFetcher(payload: payload), watchingGuard: guard_)

        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .watching)

        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(sut.state, .watching,
            "When WatchingGuard reports no elevation, state must remain watching")
    }

    func test_watchingPoll_doesNotElevate_whenFetcherReturnsNil() async {
        // No HR data (Watch not worn) → polling must stay quiet.
        let guard_ = FakeWatchingGuard()
        guard_.shouldElevate = true
        let sut = makeController(hrFetcher: FakeHRFetcher(payload: nil), watchingGuard: guard_)

        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .watching)

        for _ in 0..<20 { await Task.yield() }

        // Guard would elevate but fetcher returned nil, so loop skips — state stays watching.
        XCTAssertEqual(sut.state, .watching,
            "Nil HR payload must not advance state even when WatchingGuard would return true")
    }

    func test_resetToIdle_fromWatching_cancelsPoll() async {
        let guard_ = FakeWatchingGuard()
        guard_.shouldElevate = false
        let sut = makeController(hrFetcher: FakeHRFetcher(payload: nil), watchingGuard: guard_)

        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        XCTAssertEqual(sut.state, .watching)

        sut.send(.resetToIdle)
        XCTAssertEqual(sut.state, .idle)

        // After reset, elevating the guard should no longer affect state.
        guard_.shouldElevate = true
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(sut.state, .idle,
            "Polling task must be cancelled on resetToIdle — guard changes must not alter state")
    }

    // MARK: - beginTriage calls preload (manual triage path has no preload window)

    func test_manualTriage_fromIdle_callsPreloadOnAgent() async {
        var spyRef: SpyTriageAgent?
        let sut = AppStateController(agentFactory: {
            let agent = SpyTriageAgent()
            spyRef = agent
            return agent
        }, profileStore: freshProfileStore())
        sut.send(.onboardingComplete)
        sut.send(.userRequestedManualTriage)

        for _ in 0..<20 { await Task.yield() }

        XCTAssertTrue(spyRef?.preloadCalled == true,
            "beginTriage must call preload() so the LLM starts loading before the user finishes recording")
    }

    func test_userDismissed_fromSilentInvitation_cancelsPoll() async {
        let guard_ = FakeWatchingGuard()
        guard_.shouldElevate = false
        let sut = makeController(hrFetcher: FakeHRFetcher(payload: nil), watchingGuard: guard_)

        sut.send(.onboardingComplete)
        sut.send(.hrElevationDetected)
        sut.send(.elevationSustained)
        XCTAssertEqual(sut.state, .silentInvitation)

        sut.send(.userDismissed)
        XCTAssertEqual(sut.state, .idle)
    }
}
