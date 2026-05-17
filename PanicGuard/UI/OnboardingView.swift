import SwiftUI
import HealthKit

struct OnboardingView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var step: OnboardingStep = .welcome
    @State private var age: Int = 25
    @State private var ecEnabled = false
    @State private var ecPhone = ""

    private enum OnboardingStep { case welcome, profile, vocalCalibration }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch step {
            case .welcome:
                WelcomeStepView { step = .profile }
            case .profile:
                ProfileStepView(age: $age, ecEnabled: $ecEnabled, ecPhone: $ecPhone) {
                    step = .vocalCalibration
                }
            case .vocalCalibration:
                VocalCalibrationView(
                    age: age,
                    emergencyContactEnabled: ecEnabled,
                    emergencyContactPhone: ecEnabled && !ecPhone.isEmpty ? ecPhone : nil
                ) {
                    controller.send(.onboardingComplete)
                }
            }
        }
        .task { age = (await fetchAgeFromHealthKit()) ?? 25 }
    }

    private func fetchAgeFromHealthKit() async -> Int? {
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let dobType = HKCharacteristicType(.dateOfBirth)
        try? await store.requestAuthorization(toShare: [], read: [dobType])
        guard let components = try? store.dateOfBirthComponents(),
              let year = components.year else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        let calculated = currentYear - year
        return (10...99).contains(calculated) ? calculated : nil
    }
}

// MARK: - Welcome Step

private struct WelcomeStepView: View {
    let onContinue: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.10))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 3).repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                Circle()
                    .fill(Color.teal.opacity(0.25))
                    .frame(width: 80, height: 80)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.teal)
            }

            Spacer().frame(height: 48)

            VStack(spacing: 12) {
                Text("PanicGuard")
                    .font(.largeTitle)
                    .fontWeight(.thin)
                    .foregroundColor(.white)
                    .tracking(1)

                Text("Quiet support,\nwhen you need it most.")
                    .font(.body)
                    .fontWeight(.light)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get started")
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
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) { opacity = 1 }
            pulseScale = 1.28
        }
    }
}

// MARK: - Profile Step (age + emergency contact)

private struct ProfileStepView: View {
    @Binding var age: Int
    @Binding var ecEnabled: Bool
    @Binding var ecPhone: String
    let onContinue: () -> Void

    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("A few things about you")
                    .font(.title2)
                    .fontWeight(.light)
                    .foregroundColor(.white)

                Text("Helps personalize your experience")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer().frame(height: 32)

            VStack(spacing: 0) {
                // Age row
                HStack {
                    Text("Age")
                        .font(.body)
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 20) {
                        Button { if age > 10 { age -= 1 } } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.teal)
                        }

                        Text("\(age)")
                            .font(.system(size: 28, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 44)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.15), value: age)

                        Button { if age < 99 { age += 1 } } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.teal)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider().background(Color.white.opacity(0.08))

                // Emergency contact toggle
                Toggle(isOn: $ecEnabled.animation()) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Emergency contact")
                            .font(.body)
                            .foregroundColor(.white)
                        Text("Send an SMS if you need help")
                            .font(.caption)
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .teal))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if ecEnabled {
                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        Text("Phone")
                            .font(.body)
                            .foregroundColor(.white)
                        Spacer()
                        TextField("", text: $ecPhone,
                                  prompt: Text("+1 000 000 0000")
                                    .foregroundColor(Color.gray.opacity(0.4)))
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.teal)
                            .frame(maxWidth: 160)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 16)

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
        .opacity(opacity)
        .onAppear { withAnimation(.easeIn(duration: 0.4)) { opacity = 1 } }
    }
}

// MARK: - Vocal Calibration Step

private struct VocalCalibrationView: View {
    let age: Int
    let emergencyContactEnabled: Bool
    let emergencyContactPhone: String?
    let onComplete: () -> Void

    private static let calibrationPhrase = "The sky is clear\nand the air is still."

    private let store = UserProfileStore()
    private let vocalAnchorManager = VocalAnchorManager()
    private let hrFetcher = iPhoneHRFetcher()

    private enum CalibrationPhase { case idle, recording, done }

    @State private var phase: CalibrationPhase = .idle
    @State private var opacity: Double = 0
    @State private var ringScale: CGFloat = 1.0
    @State private var dotPhase: Int = 0
    @State private var calibrationTask: Task<Void, Never>?

    private var captionText: String {
        switch phase {
        case .idle:      return "Take your time"
        case .recording: return "Keep going"
        case .done:      return "Baseline saved"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("Voice Baseline")
                    .font(.title2)
                    .fontWeight(.light)
                    .foregroundColor(.white)

                Text(captionText)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: captionText)

                if phase != .done {
                    Text(Self.calibrationPhrase.replacingOccurrences(of: "\n", with: " "))
                        .font(.title3)
                        .fontWeight(.light)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }
            }

            Spacer()

            if phase != .done {
                recordButton.padding(.bottom, 16)

                Text(phase == .recording ? String(repeating: "•", count: dotPhase + 1) : " ")
                    .font(.caption2)
                    .foregroundColor(Color.teal.opacity(0.4))
                    .animation(.easeInOut(duration: 0.3), value: dotPhase)
                    .frame(height: 16)
            }

            Spacer().frame(height: 56)
        }
        .opacity(opacity)
        .onAppear { withAnimation(.easeIn(duration: 0.6)) { opacity = 1 } }
        .task(id: phase == .recording) {
            guard phase == .recording else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }

    @ViewBuilder
    private var recordButton: some View {
        switch phase {
        case .idle:
            Button(action: startCalibration) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.plain)

        case .recording:
            Button(action: stopCalibration) {
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .scaleEffect(ringScale)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: ringScale
                        )
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 26, height: 26)
                }
            }
            .buttonStyle(.plain)
            .onAppear { ringScale = 1.12 }

        case .done:
            EmptyView()
        }
    }

    private func startCalibration() {
        phase = .recording
        calibrationTask = Task {
            async let anchorResult = vocalAnchorManager.captureAnchor(
                phrase: Self.calibrationPhrase,
                timeout: 12
            )
            async let hrPayload = hrFetcher.fetch()

            let anchor = try? await anchorResult
            let hr = await hrPayload
            guard !Task.isCancelled else { return }

            saveProfile(anchor: anchor, hr: hr)
            await MainActor.run { withAnimation { phase = .done } }
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }

    private func stopCalibration() {
        calibrationTask?.cancel()
        calibrationTask = nil
        saveProfile(anchor: nil, hr: nil)
        withAnimation { phase = .done }
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            onComplete()
        }
    }

    private func saveProfile(anchor: VocalAnchorResult?, hr: HRFeaturePayload?) {
        let profile = UserProfile(
            age: age,
            baselineHR: hr?.currentHRMetrics.meanBPM ?? 72.0,
            baselineVocalMetrics: anchor?.vocalMetrics,
            emergencyContactEnabled: emergencyContactEnabled,
            emergencyContactPhone: emergencyContactPhone
        )
        try? store.save(profile)
    }
}
