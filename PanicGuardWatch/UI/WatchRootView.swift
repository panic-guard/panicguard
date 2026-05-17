import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var controller: AppStateController
    @AppStorage("watchWelcomeSeen") private var welcomeSeen = false

    var body: some View {
        if !welcomeSeen {
            WatchWelcomeView { welcomeSeen = true }
        } else {
            ZStack {
                switch controller.state {
                case .onboarding:
                    WatchIdleView()
                case .idle:
                    WatchIdleView()
                case .watching:
                    WatchWatchingView()
                case .silentInvitation:
                    WatchSilentInvitationView()
                case .activeTriage:
                    WatchIdleView()
                case .intervention:
                    WatchInterventionView()
                case .postEpisodeLog:
                    WatchPostEpisodeView()
                }

            }
        }
    }
}
