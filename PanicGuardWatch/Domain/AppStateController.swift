import Foundation
import Combine

/// Watch-target state owner. In production this will mirror state pushed from the iPhone.
/// For the UI skeleton demo, nextStateForDemo() cycles through all states locally.
@MainActor
final class AppStateController: ObservableObject {
    @Published private(set) var state: AppState = .idle

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
