import Foundation

/// PanicGuard state machine. Multiple entry paths exist — see CLAUDE.md for the full transition table.
/// Transitions are driven by AppStateController. All paths through intervention exit via postEpisodeLog.
enum AppState: String, Equatable, CaseIterable {
    case onboarding
    case idle
    case watching
    case silentInvitation
    case activeTriage
    case intervention
    case postEpisodeLog
}

enum AppStateEvent {
    case onboardingComplete
    case hrElevationDetected
    case elevationSustained                  // 2 min unexplained elevation → haptic
    case userAcknowledged                    // silentInvitation → activeTriage (vocal anchor chosen)
    case userDismissed                       // silentInvitation → idle (false alarm)
    case userRequestedDirectIntervention     // {silentInvitation, idle} → intervention (skip triage)
    case userRequestedManualTriage           // idle → activeTriage (no HR elevation)
    case triageComplete(TriageResult)
    case interventionDismissed
    case logComplete
    case resetToIdle
}
