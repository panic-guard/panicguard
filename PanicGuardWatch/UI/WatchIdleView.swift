import SwiftUI
import WatchKit

struct WatchIdleView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var pulseScale: CGFloat = 1.0
    @State private var didRequestAuth = false

    private let sampler = HRSampler(mode: .real)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 8) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundColor(.teal)
                }

                Text("Monitoring")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(Color.gray.opacity(0.7))

                Spacer()

                Button {
                    WKInterfaceDevice.current().play(.notification)
                    controller.send(.userRequestedDirectIntervention)
                } label: {
                    Text("I need help")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.teal)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color.teal.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .onAppear { pulseScale = 1.22 }
        .task {
            guard !didRequestAuth else { return }
            didRequestAuth = true
            do {
                try await sampler.requestAuthorization()
                sampler.startSampling { bpm, stepCount in
                    print("HR:", bpm, "Steps:", stepCount)
                }
            } catch {
                print("HealthKit auth failed:", error)
            }
        }
    }
}
