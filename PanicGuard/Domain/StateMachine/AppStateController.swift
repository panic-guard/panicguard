import Foundation
import Combine

/// Owns the current AppState and drives all legal transitions.
@MainActor
final class AppStateController: ObservableObject {
    @Published private(set) var state: AppState = .onboarding

    func send(_ event: AppStateEvent) {
        // TODO: implement transition table
    }

    // Returns false if the transition is illegal from the current state.
    func canSend(_ event: AppStateEvent) -> Bool {
        // TODO: implement guard logic
        return false
    }
}
