import Foundation
import Combine

/// Owns the current AppState and drives all legal transitions.
/// GemmaAgent (Step 2) is created on entry to activeTriage and released on exit,
/// so the ~2 GB model only occupies memory during the triage window.
@MainActor
final class AppStateController: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var lastTriageResult: TriageResult?
    @Published private(set) var lastInterventionAction: InterventionAction = .none

    // MARK: - Dependencies

    private let agentFactory: () throws -> any PanicTriageAgentProtocol
    private let ruleEngine: RuleEngineProtocol
    private let watchingGuard: WatchingGuardProtocol
    private let hrFetcher: any HRFetching
    private let profileStore: UserProfileStoring

    // MARK: - Triage state (activeTriage window only)

    private var triageAgent: (any PanicTriageAgentProtocol)?
    private var triageTask: Task<Void, Never>?
    private var pendingFeatures: HRFeaturePayload?

    // MARK: - Demo mode state (set by startDemo / startCustomDemo, cleared after use)

    var pendingDemoResult: TriageResult? = nil
    var demoAnchor: VocalAnchorResult? = nil
    var demoPromptText: String? = nil
    var demoHRSummary: (bpm: Double, slope: Double)? = nil

    // MARK: - Watching state (polling only while in .watching)

    private var watchingTask: Task<Void, Never>?

    // MARK: - Init

    init(
        agentFactory: @escaping () throws -> any PanicTriageAgentProtocol,
        ruleEngine: RuleEngineProtocol = RuleEngine(),
        watchingGuard: WatchingGuardProtocol = WatchingGuard(),
        hrFetcher: any HRFetching = iPhoneHRFetcher(),
        profileStore: UserProfileStoring = UserProfileStore()
    ) {
        self.agentFactory = agentFactory
        self.ruleEngine = ruleEngine
        self.watchingGuard = watchingGuard
        self.hrFetcher = hrFetcher
        self.profileStore = profileStore
        // Skip onboarding if the user has already completed it.
        self.state = (try? profileStore.load()) != nil ? .idle : .onboarding
    }

    // MARK: - State machine

    func send(_ event: AppStateEvent) {
        switch (state, event) {

        case (.onboarding, .onboardingComplete):
            state = .idle

        case (.idle, .hrElevationDetected):
            state = .watching
            beginWatchingPoll()

        case (.watching, .elevationSustained):
            stopWatchingPoll()
            state = .silentInvitation
            beginPreload()

        case (.silentInvitation, .userAcknowledged):
            state = .activeTriage
            beginTriage()

        case (.silentInvitation, .userDismissed):
            endTriage()
            stopWatchingPoll()
            state = .idle

        case (.silentInvitation, .userRequestedDirectIntervention):
            endTriage()
            state = .intervention

        case (.idle, .userRequestedManualTriage):
            state = .activeTriage
            beginTriage()

        case (.idle, .userRequestedDirectIntervention):
            state = .intervention

        case (.activeTriage, .triageComplete(let result)):
            endTriage()
            lastTriageResult = result
            lastInterventionAction = ruleEngine.selectIntervention(for: result)
            state = .intervention

        case (.intervention, .interventionDismissed):
            state = .postEpisodeLog

        case (.postEpisodeLog, .logComplete):
            state = .idle

        case (_, .resetToIdle):
            endTriage()
            stopWatchingPoll()
            state = .idle

        default:
            break  // Illegal transitions are silently ignored.
        }
    }

    func canSend(_ event: AppStateEvent) -> Bool {
        switch (state, event) {
        case (.onboarding,       .onboardingComplete):                return true
        case (.idle,             .hrElevationDetected):               return true
        case (.idle,             .userRequestedManualTriage):         return true
        case (.idle,             .userRequestedDirectIntervention):   return true
        case (.watching,         .elevationSustained):                return true
        case (.silentInvitation, .userAcknowledged):                  return true
        case (.silentInvitation, .userDismissed):                     return true
        case (.silentInvitation, .userRequestedDirectIntervention):   return true
        case (.activeTriage,     .triageComplete):                    return true
        case (.intervention,     .interventionDismissed):             return true
        case (.postEpisodeLog,   .logComplete):                       return true
        case (_,                 .resetToIdle):                       return true
        default: return false
        }
    }

    // MARK: - Pending data setters (called by views)

    /// Store HR features from Step 1 before sending .userAcknowledged.
    func setPendingFeatures(_ features: HRFeaturePayload) {
        pendingFeatures = features
    }

    /// Called by ActiveTriageView after VocalAnchorManager captures the anchor.
    /// This is the trigger that actually starts the LLM triage task.
    func setPendingAnchor(_ anchor: VocalAnchorResult) {
        launchTriageTask(anchor: anchor)
    }

    // MARK: - Demo mode entry points

    /// Fixed scenario: all inputs hardcoded, LLM bypassed, prompt shown for 5 s.
    func startDemo(_ scenario: FixedScenario) {
        let profile = UserProfile(
            age: 28,
            baselineHR: scenario.baselineHR,
            baselineVocalMetrics: scenario.baselineVocalMetrics,
            emergencyContactEnabled: true,
            emergencyContactPhone: "01012345678"
        )
        let riskRatio = scenario.hrFeatures.currentHRMetrics.meanBPM / scenario.baselineHR
        demoPromptText = GemmaAgentPrompts.triagePrompt(context: .init(
            features: scenario.hrFeatures,
            anchor: scenario.vocalAnchorResult,
            profile: profile,
            riskRatio: riskRatio
        ))
        pendingDemoResult = scenario.triageResult
        demoAnchor = scenario.vocalAnchorResult
        demoHRSummary = (scenario.hrFeatures.currentHRMetrics.meanBPM,
                         scenario.hrFeatures.currentHRMetrics.slopeBPMPerMin)
        setPendingFeatures(scenario.hrFeatures)
        state = .activeTriage
    }

    /// Custom scenario: real mic + real LLM. Profile must be saved to profileStore before calling.
    func startCustomDemo(hrFeatures: HRFeaturePayload) {
        demoHRSummary = (hrFeatures.currentHRMetrics.meanBPM,
                         hrFeatures.currentHRMetrics.slopeBPMPerMin)
        setPendingFeatures(hrFeatures)
        state = .activeTriage
        beginTriage()
    }

    // MARK: - Triage lifecycle

    /// Creates the agent and starts warming up the LLM session during silentInvitation.
    /// This gives the engine ~2 min to load before the user acknowledges the haptic.
    private func beginPreload() {
        guard triageAgent == nil else { return }
        do {
            triageAgent = try agentFactory()
            Task { await self.triageAgent?.preload() }
        } catch {
            // If factory fails here, beginTriage() will retry and fall back to idle.
        }
    }

    /// Ensures the agent exists when entering activeTriage (fallback if preload wasn't triggered).
    /// Also kicks off preload() so the model starts loading while the user records the vocal anchor.
    private func beginTriage() {
        guard pendingDemoResult == nil else { return }  // Fixed demo: agent not needed.
        guard triageAgent == nil else { return }
        do {
            triageAgent = try agentFactory()
            Task { await self.triageAgent?.preload() }
        } catch {
            state = .idle
        }
    }

    /// Starts the async triage task once the vocal anchor is available.
    private func launchTriageTask(anchor: VocalAnchorResult) {
        // Fixed demo: bypass LLM, display prompt for 5 s then deliver pre-defined result.
        if let demoResult = pendingDemoResult {
            pendingDemoResult = nil
            triageTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.send(.triageComplete(demoResult)) }
            }
            return
        }
        guard let agent = triageAgent else { send(.resetToIdle); return }
        let features = pendingFeatures ?? HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 0, slopeBPMPerMin: 0),
            context: .init(isMoving: false, stepsLast5Min: 0)
        )
        triageTask = Task { [weak self] in
            do {
                let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.send(.triageComplete(result)) }
            } catch {
                await MainActor.run { self?.send(.resetToIdle) }
            }
        }
    }

    /// Cancels the triage task and releases the model from memory.
    private func endTriage() {
        triageTask?.cancel()
        triageTask = nil
        triageAgent = nil  // Releases LlmInference → model memory freed.
        pendingFeatures = nil
        pendingDemoResult = nil
        demoAnchor = nil
        demoPromptText = nil
        demoHRSummary = nil
    }

    /// Polls HealthKit every 30 s while in .watching; transitions to .silentInvitation
    /// when WatchingGuard confirms sustained unexplained elevation.
    private func beginWatchingPoll() {
        watchingTask?.cancel()
        watchingTask = Task { [weak self] in
            guard let self else { return }
            let baseline = (try? self.profileStore.load())?.baselineHR ?? 72.0
            while !Task.isCancelled {
                if let payload = await self.hrFetcher.fetch() {
                    let samples = Array(repeating: payload.currentHRMetrics.meanBPM,
                                       count: max(1, Int(payload.currentHRMetrics.meanBPM / 10)))
                    let elevated = self.watchingGuard.isSustainedElevation(
                        hrSamples: samples,
                        baseline: baseline,
                        stepCount: payload.context.stepsLast5Min,
                        activeEnergyKcal: payload.context.activeEnergyKcal,
                        hasActiveWorkout: payload.context.hasActiveWorkout
                    )
                    if elevated {
                        self.send(.elevationSustained)
                        return
                    }
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    private func stopWatchingPoll() {
        watchingTask?.cancel()
        watchingTask = nil
    }

}
