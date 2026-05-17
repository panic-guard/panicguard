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
        connector.onWatchStateReceived = { [weak self] stateName in
            self?.onWatchStateReceived(stateName)
        }
        connector.activate()
    }

    func send(_ event: AppStateEvent) {
        switch (state, event) {
        case (.idle, .hrElevationDetected):
            state = .watching
        case (.watching, .elevationSustained):
            state = .silentInvitation
        case (.silentInvitation, .userDismissed):
            state = .idle
        case (.idle, .userRequestedDirectIntervention),
             (.silentInvitation, .userRequestedDirectIntervention):
            lastInterventionAction = .none
            state = .intervention
        case (.intervention, .interventionDismissed):
            state = .idle  // Watch skips post-episode log; iPhone owns episode saving.
        case (_, .resetToIdle):
            state = .idle
        default:
            break
        }
    }

    /// Receives state name pushed from the iPhone via WatchConnectivity.
    /// Sets state directly to be robust against missed intermediate events
    /// (e.g. Watch missed "watching" but iPhone already advanced to "silentInvitation").
    func onWatchStateReceived(_ stateName: String) {
        switch stateName {
        case "watching":         state = .watching
        case "silentInvitation": state = .silentInvitation
        case "idle":             state = .idle
        default:                 break
        }
    }
}
