import SwiftUI
import WatchKit

struct WatchSilentInvitationView: View {
    @State private var breathScale: CGFloat = 0.65
    @State private var fillOpacity: Double = 0.45

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                // Translucent outer breathing ring
                Circle()
                    .fill(Color.teal.opacity(fillOpacity))
                    .frame(width: 180, height: 180)
                    .scaleEffect(breathScale)
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: breathScale
                    )
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: fillOpacity
                    )

                Text("Breathe")
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .onAppear {
            breathScale = 1.0
            fillOpacity = 0.12
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
