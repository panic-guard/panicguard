import SwiftUI

struct WatchIdleView: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var didRequestAuth = false 

    // MARK: Real Stream, Mock Stream
    #if targetEnvironment(simulator)
    private let sampler = HRSampler(mode: .mock(.panic))
    #else
    private let sampler = HRSampler(mode: .real)
    #endif
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.18))
                        .frame(width: 88, height: 88)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                            value: pulseScale
                        )

                    Image(systemName: "heart.fill")
                        .font(.system(size: 30, weight: .ultraLight))
                        .foregroundColor(.teal)
                }

                Text("Monitoring")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.7))
            }
        }
        .onAppear { pulseScale = 1.25 
        }
        .task {
            guard !didRequestAuth else { return }
            didRequestAuth = true

            do {
                try await sampler.requestAuthorization()
                print("HealthKit authorization success")
                
                // Start sampling after successful authorization    
                sampler.startSampling { bpm, stepCount in
                    print("HR:", bpm, "Steps:", stepCount)
                }
            } catch {
                print("HealthKit auth failed:", error)
            }
        }



    }
}
