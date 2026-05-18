import SwiftUI
import HealthKit
import AVFoundation
#if canImport(Speech)
import Speech
#endif

struct OnboardingView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var step: OnboardingStep = .welcome
    @State private var age: Int = 25
    @State private var ecEnabled = false
    @State private var ecPhone = ""
    @State private var isRequestingPermissions = false
    @State private var showDemoSheet = false

    private enum OnboardingStep { case welcome, profile, vocalCalibration }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch step {
            case .welcome:
                WelcomeStepView(isLoading: isRequestingPermissions) {
                    isRequestingPermissions = true
                    Task {
                        await requestAllPermissions()
                        await MainActor.run {
                            isRequestingPermissions = false
                            step = .profile
                        }
                    }
                } onDemo: {
                    showDemoSheet = true
                }
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
        .sheet(isPresented: $showDemoSheet) {
            DemoScenarioPickerView()
        }
    }

    // Requests all required permissions upfront in one pass:
    // 1 HealthKit sheet (DOB + HR + steps + energy + workout + restingHR)
    // then Speech recognition, then microphone — each their own system dialog.
    private func requestAllPermissions() async {
        if HKHealthStore.isHealthDataAvailable() {
            let store = HKHealthStore()
            var readTypes: Set<HKObjectType> = [
                HKCharacteristicType(.dateOfBirth),
                HKWorkoutType.workoutType(),
                HKQuantityType(.restingHeartRate)
            ]
            if let t = HKQuantityType.quantityType(forIdentifier: .heartRate) { readTypes.insert(t) }
            if let t = HKQuantityType.quantityType(forIdentifier: .stepCount) { readTypes.insert(t) }
            if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { readTypes.insert(t) }
            try? await store.requestAuthorization(toShare: [], read: readTypes)

            if let components = try? store.dateOfBirthComponents(), let year = components.year {
                let calculated = Calendar.current.component(.year, from: Date()) - year
                if (10...99).contains(calculated) {
                    await MainActor.run { age = calculated }
                }
            }
        }

        #if canImport(Speech)
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
            }
        }
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
        #endif
    }
}

// MARK: - Welcome Step

private struct WelcomeStepView: View {
    let isLoading: Bool
    let onContinue: () -> Void
    let onDemo: () -> Void

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
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                    } else {
                        Text("Get started")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.teal)
                .cornerRadius(16)
            }
            .disabled(isLoading)
            .padding(.horizontal, 40)

            Button(action: onDemo) {
                Text("Try Demo Mode")
                    .font(.subheadline)
                    .foregroundColor(Color.teal.opacity(0.75))
            }
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
    @State private var ageText: String = ""
    @FocusState private var ageFieldFocused: Bool
    @FocusState private var phoneFieldFocused: Bool

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
                // Age row — -/+ buttons with tappable number for direct input
                HStack {
                    Text("Age")
                        .font(.body)
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 20) {
                        Button {
                            if age > 10 { age -= 1; ageText = "\(age)" }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(age > 10 ? .teal : Color.gray.opacity(0.3))
                        }

                        TextField("", text: $ageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 28, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 52)
                            .focused($ageFieldFocused)
                            .onChange(of: ageText) { _, newVal in
                                let digits = String(newVal.filter(\.isNumber).prefix(2))
                                if digits != newVal { ageText = digits }
                                if let val = Int(digits), (10...99).contains(val) { age = val }
                            }

                        Button {
                            if age < 99 { age += 1; ageText = "\(age)" }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(age < 99 ? .teal : Color.gray.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .onAppear { ageText = "\(age)" }
                .onChange(of: age) { _, newAge in
                    // Sync when HealthKit updates age externally
                    if !ageFieldFocused { ageText = "\(newAge)" }
                }

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

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phone")
                                .font(.body)
                                .foregroundColor(.white)
                            if ecPhone.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text("Required")
                                    .font(.caption2)
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        Spacer()
                        TextField("", text: $ecPhone,
                                  prompt: Text("01012345678")
                                    .foregroundColor(Color.gray.opacity(0.4)))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.teal)
                            .frame(maxWidth: 160)
                            .focused($phoneFieldFocused)
                            .onChange(of: ecPhone) { _, newVal in
                                let digits = newVal.filter(\.isNumber)
                                if digits != newVal { ecPhone = digits }
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { phoneFieldFocused = false }
                                        .foregroundColor(.teal)
                                }
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 16)

            Spacer()

            let continueBlocked = ecEnabled && ecPhone.trimmingCharacters(in: .whitespaces).isEmpty
            Button(action: onContinue) {
                Text("Continue")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(continueBlocked ? Color.gray.opacity(0.4) : Color.teal)
                    .cornerRadius(16)
            }
            .disabled(continueBlocked)
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

            // Prefer real-time HR mean; fall back to Apple Watch 30-day resting HR avg before hardcoding 72.
            let baselineHR: Double
            if let mean = hr?.currentHRMetrics.meanBPM {
                baselineHR = mean
            } else {
                baselineHR = await hrFetcher.fetchRestingHR() ?? 72.0
            }

            saveProfile(anchor: anchor, baselineHR: baselineHR)
            await MainActor.run { withAnimation { phase = .done } }
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }

    private func stopCalibration() {
        // Stop recorder early — calibrationTask continues, recognizes partial audio, then calls onComplete.
        vocalAnchorManager.stopRecordingEarly()
        withAnimation { phase = .done }
    }

    private func saveProfile(anchor: VocalAnchorResult?, baselineHR: Double) {
        let profile = UserProfile(
            age: age,
            baselineHR: baselineHR,
            baselineVocalMetrics: anchor?.vocalMetrics,
            emergencyContactEnabled: emergencyContactEnabled,
            emergencyContactPhone: emergencyContactPhone
        )
        try? store.save(profile)
    }
}

// MARK: - Demo Scenario Picker

private struct DemoScenarioPickerView: View {
    @EnvironmentObject var controller: AppStateController
    @Environment(\.dismiss) private var dismiss

    @State private var showCustomSetup = false
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Demo Mode")
                            .font(.title2).fontWeight(.light).foregroundColor(.white)
                        Text("Select a scenario to experience the full flow")
                            .font(.caption).foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 32)

                    // Fixed scenarios
                    VStack(spacing: 12) {
                        ForEach(FixedScenario.all) { scenario in
                            FixedScenarioCard(scenario: scenario) {
                                dismiss()
                                controller.startDemo(scenario)
                            }
                        }

                        // Custom scenario card
                        CustomScenarioCard {
                            showCustomSetup = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .opacity(opacity)
        .onAppear { withAnimation(.easeIn(duration: 0.4)) { opacity = 1 } }
        .sheet(isPresented: $showCustomSetup) {
            CustomScenarioSetupView()
        }
    }
}

private struct FixedScenarioCard: View {
    let scenario: FixedScenario
    let onTap: () -> Void

    private var outcomePillColor: Color {
        switch scenario.id {
        case "acutePanic":      return .red.opacity(0.8)
        case "moderatePanic":   return .orange.opacity(0.8)
        case "mildAnxiety":     return .yellow.opacity(0.7)
        case "physicalAnomaly": return .purple.opacity(0.8)
        default:                return .teal
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scenario.title)
                        .font(.body).fontWeight(.medium).foregroundColor(.white)
                    Text(scenario.description)
                        .font(.caption).foregroundColor(.gray)
                }

                Spacer()

                Text(scenario.outcomeLabel)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(outcomePillColor)
                    .cornerRadius(6)
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct CustomScenarioCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Try Your Own")
                        .font(.body).fontWeight(.medium).foregroundColor(.white)
                    Text("Enter BPM · Record your voice · Real AI inference")
                        .font(.caption).foregroundColor(.gray)
                }

                Spacer()

                Text("Custom")
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.teal)
                    .cornerRadius(6)
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Scenario Setup (BPM input + calibration + triage)

private struct CustomScenarioSetupView: View {
    @EnvironmentObject var controller: AppStateController
    @Environment(\.dismiss) private var dismiss

    private enum SetupStep { case input, calibrating, done }

    @State private var step: SetupStep = .input
    @State private var bpm: Double = 120
    @State private var activity: DemoActivity = .resting
    @State private var opacity: Double = 0

    private let store = UserProfileStore()
    private let vocalAnchorManager = VocalAnchorManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch step {
            case .input:   inputView
            case .calibrating: calibrationView
            case .done:    EmptyView()
            }
        }
        .opacity(opacity)
        .onAppear { withAnimation(.easeIn(duration: 0.4)) { opacity = 1 } }
    }

    // MARK: BPM + Activity input

    private var inputView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("Your Scenario")
                    .font(.title2).fontWeight(.light).foregroundColor(.white)
                Text("Set the heart rate context")
                    .font(.caption).foregroundColor(.gray)
            }

            Spacer().frame(height: 40)

            VStack(spacing: 0) {
                // BPM slider
                VStack(spacing: 10) {
                    HStack {
                        Text("Heart Rate")
                            .font(.body).foregroundColor(.white)
                        Spacer()
                        Text("\(Int(bpm)) BPM")
                            .font(.system(size: 28, weight: .thin, design: .rounded))
                            .foregroundColor(.teal)
                    }
                    Slider(value: $bpm, in: 60...180, step: 1)
                        .tint(.teal)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)

                Divider().background(Color.white.opacity(0.08))

                // Activity picker
                HStack {
                    Text("Activity")
                        .font(.body).foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $activity) {
                        ForEach(DemoActivity.allCases, id: \.self) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.teal)
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 16)

            Spacer()

            Button {
                step = .calibrating
            } label: {
                Text("Next — Voice Baseline")
                    .font(.body).fontWeight(.medium).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Color.teal).cornerRadius(16)
            }
            .padding(.horizontal, 40).padding(.bottom, 56)
        }
    }

    // MARK: Calibration (15-second real recording for baseline)

    @State private var calibPhase: CalibPhase = .idle
    @State private var ringScale: CGFloat = 1.0
    @State private var dotPhase: Int = 0
    @State private var calibTask: Task<Void, Never>?

    private enum CalibPhase { case idle, recording, done }
    private static let calibPhrase = "The sky is wide and open."

    private var calibrationView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("Voice Baseline")
                    .font(.title2).fontWeight(.light).foregroundColor(.white)

                Text(calibPhase == .done ? "Baseline saved" : "Read this calmly")
                    .font(.caption).foregroundColor(.gray)
                    .animation(.easeInOut(duration: 0.3), value: calibPhase)

                if calibPhase != .done {
                    Text(Self.calibPhrase)
                        .font(.title3).fontWeight(.light).foregroundColor(.white)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            }

            Spacer()

            if calibPhase != .done {
                calibButton.padding(.bottom, 16)

                Text(calibPhase == .recording ? String(repeating: "•", count: dotPhase + 1) : " ")
                    .font(.caption2).foregroundColor(Color.teal.opacity(0.4))
                    .animation(.easeInOut(duration: 0.3), value: dotPhase)
                    .frame(height: 16)
            }

            Spacer().frame(height: 56)
        }
        .task(id: calibPhase == .recording) {
            guard calibPhase == .recording else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }

    @ViewBuilder private var calibButton: some View {
        switch calibPhase {
        case .idle:
            Button(action: startCalibration) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 3).frame(width: 80, height: 80)
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 62, height: 62)
                }
            }.buttonStyle(.plain)

        case .recording:
            Button(action: stopCalibration) {
                ZStack {
                    Circle().stroke(Color.red.opacity(0.5), lineWidth: 3).frame(width: 80, height: 80)
                        .scaleEffect(ringScale)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: ringScale)
                    RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.85)).frame(width: 26, height: 26)
                }
            }.buttonStyle(.plain).onAppear { ringScale = 1.12 }

        case .done:
            EmptyView()
        }
    }

    private func startCalibration() {
        calibPhase = .recording
        calibTask = Task {
            let anchor = try? await vocalAnchorManager.captureAnchor(phrase: Self.calibPhrase, timeout: 15)
            guard !Task.isCancelled else { return }
            let profile = UserProfile(
                age: 28,
                baselineHR: 70,
                baselineVocalMetrics: anchor?.vocalMetrics
            )
            try? store.save(profile)
            await MainActor.run { withAnimation { calibPhase = .done } }
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismiss()
                controller.startCustomDemo(hrFeatures: activity.hrFeatures(bpm: bpm))
            }
        }
    }

    private func stopCalibration() {
        vocalAnchorManager.stopRecordingEarly()
        withAnimation { calibPhase = .done }
    }
}
