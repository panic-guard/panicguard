import Foundation

/// Linear state machine for PanicGuard.
/// Transitions are driven by AppStateController — no state skipping allowed.
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
    case elevationSustained        // 2 min unexplained elevation → haptic
    case userAcknowledged          // user tapped watch / opened app
    case selfCheckRequested        // user manually initiates triage from idle
    case triageComplete(TriageResult)
    case interventionDismissed
    case logComplete
    case resetToIdle
}
