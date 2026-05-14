import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var controller: AppStateController

    var body: some View {
        ZStack {
            switch controller.state {
            case .onboarding:
                WatchIdleView()         // phone-only state
            case .idle:
                WatchIdleView()
            case .watching:
                WatchWatchingView()
            case .silentInvitation:
                WatchSilentInvitationView()
            case .activeTriage:
                WatchIdleView()         // phone-only state
            case .intervention:
                WatchInterventionView()
            case .postEpisodeLog:
                WatchIdleView()         // phone-only state
            }

            // Demo overlay — tap to cycle states
            VStack {
                Spacer()
                Button {
                    controller.nextStateForDemo()
                } label: {
                    HStack(spacing: 3) {
                        Text(controller.state.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(.teal.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.bottom, 6)
            }
        }
    }
}
