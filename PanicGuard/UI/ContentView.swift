import SwiftUI

struct ContentView: View {
    @EnvironmentObject var controller: AppStateController

    var body: some View {
        ZStack {
            switch controller.state {
            case .onboarding:
                OnboardingView()
            case .idle:
                IdleView()
            case .watching:
                SilentInvitationView()
            case .silentInvitation:
                SilentInvitationView()
            case .activeTriage:
                ActiveTriageView()
            case .intervention:
                InterventionView()
            case .postEpisodeLog:
                PostEpisodeView()
            }

        }
        .ignoresSafeArea()
    }
}
