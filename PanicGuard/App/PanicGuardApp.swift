import SwiftUI

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
}
