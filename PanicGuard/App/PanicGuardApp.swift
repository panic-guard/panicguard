import SwiftUI
import Combine

@main
struct PanicGuardApp: App {
    @StateObject private var appStateController = AppStateController(agentFactory: {
        let modelPath = Bundle.main.url(
            forResource: "gemma-4-E2B-it",
            withExtension: "litertlm"
        )?.path ?? ""
        return try GemmaAgent(modelPath: modelPath, userProfileStore: UserProfileStore())
    })

    init() {
        let connector = PhoneConnector.shared
        connector.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStateController)
                .onAppear { wireConnector() }
                .onReceive(appStateController.$state) { state in
                    pushWatchState(for: state)
                }
        }
    }

    private func wireConnector() {
        let connector = PhoneConnector.shared
        connector.onHRBatchReceived = { [weak appStateController] samples, stepCount in
            guard let ctrl = appStateController else { return }
            let extractor = HRFeatureExtractor()
            let payload = extractor.extract(hrSamples: samples, stepCount: stepCount)
            ctrl.setPendingFeatures(payload)
            if ctrl.state == .idle {
                ctrl.send(.hrElevationDetected)
            }
        }
        connector.onSilentInvitation = { [weak appStateController] in
            appStateController?.send(.elevationSustained)
        }
    }

    /// Mirrors key iPhone states to the Watch so it can show the correct UI and haptic.
    private func pushWatchState(for state: AppState) {
        let stateName: String
        switch state {
        case .watching:         stateName = "watching"
        case .silentInvitation: stateName = "silentInvitation"
        case .idle:             stateName = "idle"
        default:                return
        }
        PhoneConnector.shared.pushWatchState(stateName)
    }
}
