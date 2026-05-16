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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStateController)
        }
    }
}
