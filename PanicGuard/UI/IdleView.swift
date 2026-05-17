import SwiftUI

struct IdleView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var pulseScale: CGFloat = 1.0
    @State private var isFetching = false
    @State private var showNoWatchAlert = false
    @State private var showSettings = false
    @State private var showHistory = false

    private let fetcher = iPhoneHRFetcher()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Settings gear — top right
            VStack {
                HStack {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                    .padding(.top, 60)
                    .padding(.leading, 24)

                    Spacer()

                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                    .padding(.top, 60)
                    .padding(.trailing, 24)
                }
                Spacer()
            }

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

                // Primary CTA: manual triage with HR fetch
                Button {
                    guard !isFetching else { return }
                    isFetching = true
                    Task {
                        guard let payload = await fetcher.fetch() else {
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else {
                        Text("Check my state")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.teal)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 40)
                .disabled(isFetching)

                // Secondary CTA: skip triage, go directly to intervention
                Button {
                    controller.send(.userRequestedDirectIntervention)
                } label: {
                    Text("I need help now")
                        .font(.subheadline)
                        .foregroundColor(Color.teal.opacity(0.75))
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { pulseScale = 1.3 }
        .alert("Apple Watch Required", isPresented: $showNoWatchAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No recent heart rate data found. Please wear your Apple Watch and try again.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            EpisodeHistoryView()
        }
    }
}
