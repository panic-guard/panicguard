import SwiftUI

@main
struct PanicGuardApp: App {
    @StateObject private var appStateController = AppStateController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appStateController)
        }
    }
}
