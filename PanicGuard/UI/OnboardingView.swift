import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var step: OnboardingStep = .age
    @State private var age: Int = 25

    private enum OnboardingStep { case age, vocalCalibration }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch step {
            case .age:
                AgeStepView(age: $age) { step = .vocalCalibration }
            case .vocalCalibration:
                VocalCalibrationView(age: age) {
                    controller.send(.onboardingComplete)
                }
            }
        }
    }
}

// MARK: - Age Step

private struct AgeStepView: View {
    @Binding var age: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("How old are you?")
                    .font(.title2)
                    .fontWeight(.light)
                    .foregroundColor(.white)

                Text("Helps calibrate your baseline heart rate")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer().frame(height: 52)

            HStack(spacing: 36) {
                Button { if age > 10 { age -= 1 } } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.teal)
                }

                Text("\(age)")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 110)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: age)

                Button { if age < 99 { age += 1 } } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.teal)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.teal)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 56)
        }
    }
}

// MARK: - Vocal Calibration Step

private struct VocalCalibrationView: View {
    let age: Int
    let onComplete: () -> Void

    // A short, neutral phrase used only for baseline calibration — not shown during triage.
    private static let calibrationPhrase = "The sky is clear\nand the air is still."

    private let store = UserProfileStore()
    private let vocalAnchorManager = VocalAnchorManager()
    private let hrFetcher = iPhoneHRFetcher()

    @State private var phase: CalibrationPhase = .instruction
    @State private var opacity: Double = 0

    private enum CalibrationPhase { case instruction, recording, done }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: phase == .recording ? "mic.fill" : "mic")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundColor(phase == .recording ? .teal : Color.teal.opacity(0.6))
                    .animation(.easeInOut(duration: 0.4), value: phase)

                VStack(spacing: 10) {
                    Text("Voice Baseline")
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundColor(.white)

                    Text(phase == .instruction
                         ? "Read the phrase below at your normal,\ncalm pace when you tap Start."
                         : phase == .recording
                           ? "Reading now…"
                           : "Baseline saved.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: phase)
                }

                Text(Self.calibrationPhrase.replacingOccurrences(of: "\n", with: " "))
                    .font(.title3)
                    .fontWeight(.light)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Group {
                switch phase {
                case .instruction:
                    Button {
                        phase = .recording
                        Task { await runCalibration() }
                    } label: {
                        Text("Start Recording")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.teal)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)

                case .recording:
                    ProgressView()
                        .tint(.teal)
                        .scaleEffect(1.2)

                case .done:
                    EmptyView()
                }
            }
            .padding(.bottom, 56)
        }
        .opacity(opacity)
        .onAppear { withAnimation(.easeIn(duration: 0.6)) { opacity = 1 } }
    }

    private func runCalibration() async {
        async let anchorResult = vocalAnchorManager.captureAnchor(
            phrase: Self.calibrationPhrase,
            timeout: 12
        )
        async let hrPayload = hrFetcher.fetch()

        let anchor = try? await anchorResult
        let hr = await hrPayload

        // Fall back to 72 BPM if Watch HR data isn't available yet.
        let baselineHR = hr?.currentHRMetrics.meanBPM ?? 72.0

        let profile = UserProfile(
            age: age,
            baselineHR: baselineHR,
            baselineVocalMetrics: anchor?.vocalMetrics
        )
        try? store.save(profile)
        phase = .done
        try? await Task.sleep(nanoseconds: 800_000_000)
        onComplete()
    }
}
