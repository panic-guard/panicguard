import Foundation

/// Mirror of the iOS AppState enum, scoped to the Watch target for UI-layer use.
enum AppState: String, Equatable, CaseIterable {
    case onboarding
    case idle
    case watching
    case silentInvitation
    case activeTriage
    case intervention
    case postEpisodeLog
}

/// Watch-relevant subset of the iPhone AppStateEvent.
enum AppStateEvent {
    case userDismissed
    case userRequestedDirectIntervention
    case interventionDismissed
    case logComplete
    case resetToIdle
}

/// Mirror of iPhone InterventionAction — duplicated here to avoid cross-target dependency.
enum InterventionAction: String {
    case breathingGuide
    case groundingExercise
    case emergencyContact
    case medicalAlert
    case none
}
