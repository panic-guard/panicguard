import SwiftUI

struct IdleView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var pulseScale: CGFloat = 1.0
    @State private var isFetching = false
    @State private var showNoWatchAlert = false

    private let fetcher = iPhoneHRFetcher()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                            value: pulseScale
                        )

                    Circle()
                        .fill(Color.teal.opacity(0.35))
                        .frame(width: 90, height: 90)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(.teal)
                }

                VStack(spacing: 6) {
                    Text("Monitoring Active")
                        .font(.title3)
                        .fontWeight(.light)
                        .foregroundColor(.white)

                    Text("Resting quietly")
                        .font(.caption)
                        .foregroundColor(Color.gray.opacity(0.7))
                }

                Spacer().frame(height: 20)

                Button {
                    guard !isFetching else { return }
                    isFetching = true
                    Task {
                        guard let payload = await fetcher.fetch() else {
                            // No Watch HR data — block to prevent 0 BPM from misleading GemmaAgent
                            showNoWatchAlert = true
                            isFetching = false
                            return
                        }
                        controller.setPendingFeatures(payload)
                        controller.send(.userRequestedManualTriage)
                        isFetching = false
                    }
                } label: {
                    if isFetching {
                        ProgressView().tint(.teal)
                    } else {
                        Text("Check my state")
                            .font(.caption)
                            .foregroundColor(.teal)
                    }
                }
            }
        }
        .onAppear { pulseScale = 1.3 }
        .alert("Apple Watch Required", isPresented: $showNoWatchAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No recent heart rate data found. Please wear your Apple Watch and try again.")
        }
    }
}
