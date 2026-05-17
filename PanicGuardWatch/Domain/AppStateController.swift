import Foundation
import Combine

/// Watch-target state owner. In production this will mirror state pushed from the iPhone via WatchConnectivity.
/// For demo, nextStateForDemo() cycles through all states and intervention actions locally.
@MainActor
final class AppStateController: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var lastInterventionAction: InterventionAction = .none
    /// Set via WatchConnectivity when the phone syncs the user profile.
    @Published var emergencyContactPhone: String? = nil

    private var demoActionIndex = 0
    private static let demoActions: [InterventionAction] = [
        .groundingExercise, .breathingGuide, .emergencyContact, .medicalAlert
    ]

    func send(_ event: AppStateEvent) {
        switch (state, event) {
        case (.silentInvitation, .userDismissed):
            state = .idle
        case (.idle, .userRequestedDirectIntervention),
             (.silentInvitation, .userRequestedDirectIntervention):
            lastInterventionAction = .none
            state = .intervention
        case (.intervention, .interventionDismissed):
            state = .postEpisodeLog
        case (.postEpisodeLog, .logComplete):
            state = .idle
        case (_, .resetToIdle):
            state = .idle
        default:
            break
        }
    }

    func nextStateForDemo() {
        switch state {
        case .onboarding:       state = .idle
        case .idle:             state = .watching
        case .watching:         state = .silentInvitation
        case .silentInvitation: state = .activeTriage
        case .activeTriage:
            lastInterventionAction = Self.demoActions[demoActionIndex % Self.demoActions.count]
            demoActionIndex += 1
            state = .intervention
        case .intervention:     state = .postEpisodeLog
        case .postEpisodeLog:   state = .idle
        }
    }
}
