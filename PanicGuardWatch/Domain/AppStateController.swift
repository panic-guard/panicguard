import Foundation
import Combine

@MainActor
final class AppStateController: ObservableObject {
    @Published private(set) var state: AppState = .idle
    @Published private(set) var lastInterventionAction: InterventionAction = .none
    @Published var emergencyContactPhone: String? = nil

    let connector = WatchConnector()

    init() {
        connector.onProfileReceived = { [weak self] ecPhone in
            self?.emergencyContactPhone = ecPhone
        }
        connector.activate()
    }

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
}
