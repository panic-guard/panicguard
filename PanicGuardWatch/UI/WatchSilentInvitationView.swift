import SwiftUI
import WatchKit

struct WatchSilentInvitationView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var breathScale: CGFloat = 0.85
    @State private var fillOpacity: Double = 0.35

    var body: some View {
        VStack(spacing: 0) {
            // Breathing circle — upper area
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(fillOpacity))
                    .frame(width: 70, height: 70)
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
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Buttons — fixed height, no clipping
            VStack(spacing: 4) {
                Button {
                    WKInterfaceDevice.current().play(.success)
                    controller.send(.userRequestedDirectIntervention)
                } label: {
                    Text("I need help")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.teal)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    controller.send(.userDismissed)
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            breathScale = 1.0
            fillOpacity = 0.12
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
