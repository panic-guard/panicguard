import SwiftUI
import WatchKit

private let groundingPrompts: [(Int, String)] = [
    (5, "things you\ncan SEE"),
    (4, "things you\ncan TOUCH"),
    (3, "things you\ncan HEAR"),
    (2, "things you\ncan SMELL"),
    (1, "thing you\ncan TASTE"),
]

struct WatchInterventionView: View {
    @EnvironmentObject var controller: AppStateController
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private enum Phase { case ecPrompt, breathing, grounding, medicalAlert }

    @State private var phase: Phase = .breathing
    @State private var breathScale: CGFloat = 0.62
    @State private var phaseText: String = "Breathe in"
    @State private var showContinueButton = false
    @State private var groundingIndex = 0

    private var action: InterventionAction { controller.lastInterventionAction }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea()

            switch phase {
            case .ecPrompt:     ecPromptView
            case .breathing:    breathingView
            case .grounding:    groundingView
            case .medicalAlert: medicalAlertView
            }
        }
        .onAppear {
            switch action {
            case .emergencyContact: phase = .ecPrompt
            case .groundingExercise: phase = .grounding
            case .medicalAlert: phase = .medicalAlert
            default: phase = .breathing
            }
        }
        // Palm cover → back to monitoring via postEpisodeLog
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive {
                controller.send(.interventionDismissed)
            }
        }
    }

    // MARK: - EC Prompt

    private var ecPromptView: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 26))
                .foregroundColor(.teal)
            Text("Notify someone?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 6) {
                Button {
                    WKInterfaceDevice.current().play(.success)
                    sendSMS()
                    phase = .breathing
                } label: {
                    Text("Send message")
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
                    phase = .breathing
                } label: {
                    Text("Not now")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
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
    }

    // MARK: - Breathing
    // breathScale driven step-by-step — no repeatForever, stays in sync with phaseText.

    private var breathingView: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.teal.opacity(0.55), Color.cyan.opacity(0.08)],
                            center: .center, startRadius: 4, endRadius: 70
                        )
                    )
                    .scaleEffect(breathScale)
                    .animation(.easeInOut(duration: 4), value: breathScale)
                    .containerRelativeFrame([.horizontal, .vertical]) { size, _ in size * 0.78 }

                Text(phaseText)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
                    .animation(.easeOut(duration: 0.3), value: phaseText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showContinueButton {
                Button {
                    withAnimation { phase = .grounding }
                } label: {
                    Text("Continue")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.teal)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.teal.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .task {
            let hapticTask = Task {
                while !Task.isCancelled {
                    WKInterfaceDevice.current().play(.click)
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            defer { hapticTask.cancel() }

            var cycleCount = 0
            while !Task.isCancelled {
                phaseText = "Breathe in"
                breathScale = 1.0
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { break }

                phaseText = "Hold"
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }

                phaseText = "Breathe out"
                breathScale = 0.62
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { break }

                phaseText = "Hold"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }

                cycleCount += 1
                if cycleCount == 1 {
                    withAnimation { showContinueButton = true }
                }
            }
        }
    }

    // MARK: - Grounding

    private var groundingView: some View {
        VStack(spacing: 4) {
            Spacer()
            Text("\(groundingPrompts[groundingIndex].0)")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(.teal)
            Text(groundingPrompts[groundingIndex].1)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
            Spacer()
            Group {
                if groundingIndex < groundingPrompts.count - 1 {
                    Button {
                        withAnimation { groundingIndex += 1 }
                    } label: {
                        Text("Next")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.teal)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.teal.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        WKInterfaceDevice.current().play(.success)
                        controller.send(.interventionDismissed)
                    } label: {
                        Text("Done")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color.teal)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.25), value: groundingIndex)
    }

    // MARK: - Medical alert

    private var medicalAlertView: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "heart.circle")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            Text("May not be panic")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Consider seeing a doctor if symptoms persist.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
            Spacer()
            Button {
                WKInterfaceDevice.current().play(.click)
                controller.send(.interventionDismissed)
            } label: {
                Text("OK")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private func sendSMS() {
        let phone = controller.emergencyContactPhone ?? ""
        let urlString = phone.isEmpty ? "sms:" : "sms:\(phone.filter(\.isNumber))"
        if let url = URL(string: urlString) { openURL(url) }
    }
}
