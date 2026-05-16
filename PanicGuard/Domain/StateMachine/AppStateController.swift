import Foundation
import Combine

/// Owns the current AppState and drives all legal transitions.
/// GemmaAgent (Step 2) is created on entry to activeTriage and released on exit,
/// so the ~2 GB model only occupies memory during the triage window.
@MainActor
final class AppStateController: ObservableObject {
    @Published private(set) var state: AppState = .onboarding
    @Published private(set) var lastTriageResult: TriageResult?
    @Published private(set) var lastInterventionAction: InterventionAction = .none

    // MARK: - Dependencies

    private let agentFactory: () throws -> any PanicTriageAgentProtocol
    private let ruleEngine: RuleEngineProtocol

    // MARK: - Triage state (activeTriage window only)

    private var triageAgent: (any PanicTriageAgentProtocol)?
    private var triageTask: Task<Void, Never>?
    private var pendingFeatures: HRFeaturePayload?

    // MARK: - Init

    init(
        agentFactory: @escaping () throws -> any PanicTriageAgentProtocol,
        ruleEngine: RuleEngineProtocol = RuleEngine()
    ) {
        self.agentFactory = agentFactory
        self.ruleEngine = ruleEngine
    }

    // MARK: - State machine

    func send(_ event: AppStateEvent) {
        switch (state, event) {

        case (.onboarding, .onboardingComplete):
            state = .idle

        case (.idle, .hrElevationDetected):
            state = .watching

        case (.watching, .elevationSustained):
            state = .silentInvitation
            beginPreload()

        case (.silentInvitation, .userAcknowledged):
            state = .activeTriage
            beginTriage()

        case (.silentInvitation, .userDismissed):
            endTriage()
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
    private func beginTriage() {
        guard triageAgent == nil else { return }
        do {
            triageAgent = try agentFactory()
        } catch {
            state = .idle
        }
    }

    /// Starts the async triage task once the vocal anchor is available.
    private func launchTriageTask(anchor: VocalAnchorResult) {
        guard let agent = triageAgent else { return }
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
    }

    // MARK: - Demo helper

    /// Demo-only: cycles through states without real sensors.
    func nextStateForDemo() {
        switch state {
        case .onboarding:       state = .idle
        case .idle:             state = .watching
        case .watching:         state = .silentInvitation
        case .silentInvitation: state = .activeTriage
        case .activeTriage:     state = .intervention
        case .intervention:     state = .postEpisodeLog
        case .postEpisodeLog:   state = .idle
        }
    }
}
