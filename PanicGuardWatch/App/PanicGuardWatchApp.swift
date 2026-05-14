import SwiftUI

@main
struct PanicGuardWatchApp: App {
    @StateObject private var appStateController = AppStateController()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(appStateController)
        }
    }
}
