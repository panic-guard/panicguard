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
                IdleView()
            case .silentInvitation:
                IdleView()
            case .activeTriage:
                ActiveTriageView()
            case .intervention:
                InterventionView()
            case .postEpisodeLog:
                PostEpisodeView()
            }

            // Demo overlay — tap to advance state, shows current state name
            VStack {
                HStack {
                    Spacer()
                    Button { controller.nextStateForDemo() } label: {
                        HStack(spacing: 5) {
                            Text(demoLabel)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.teal)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.top, 56)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    private var demoLabel: String {
        if controller.state == .intervention {
            return "\(controller.state.rawValue) · \(controller.lastInterventionAction.rawValue)"
        }
        return controller.state.rawValue
    }
}
