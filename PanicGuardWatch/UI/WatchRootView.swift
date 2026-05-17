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

                // Demo overlay — top-left to avoid overlapping view buttons
                VStack {
                    HStack {
                        Button {
                            controller.nextStateForDemo()
                        } label: {
                            HStack(spacing: 3) {
                                Text(demoLabel)
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.45))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(.teal.opacity(0.6))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .padding(.leading, 4)
                        .padding(.top, 4)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    private var demoLabel: String {
        if controller.state == .intervention {
            return "\(controller.state.rawValue) · \(controller.lastInterventionAction.rawValue)"
        }
        return controller.state.rawValue
    }
}
