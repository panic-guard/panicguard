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
