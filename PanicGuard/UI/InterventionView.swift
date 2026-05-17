import SwiftUI
import MessageUI

// MARK: - Supporting types

private enum InterventionPhase {
    case breathing
    case grounding
    case medicalAlert
    case calm
}

private struct GroundingPrompt {
    let count: Int
    let title: String
    let hint: String
}

private let groundingPrompts: [GroundingPrompt] = [
    .init(count: 5, title: "5 things you can SEE",   hint: "Look around and name them slowly."),
    .init(count: 4, title: "4 things you can TOUCH",  hint: "Notice the textures around you."),
    .init(count: 3, title: "3 things you can HEAR",   hint: "Listen carefully to each sound."),
    .init(count: 2, title: "2 things you can SMELL",  hint: "Take a slow breath and notice."),
    .init(count: 1, title: "1 thing you can TASTE",   hint: "What do you notice in your mouth?"),
]

// MARK: - Main view

struct InterventionView: View {
    @EnvironmentObject var controller: AppStateController

    private let profileStore = UserProfileStore()
    @State private var emergencyContactEnabled = false
    @State private var emergencyContactPhone: String? = nil

    @State private var phase: InterventionPhase = .breathing
    @State private var showEmergencySheet = false

    // Breathing phase state
    @State private var breathScale: CGFloat = 0.62
    @State private var phaseLabel: String = "Breathe in"
    @State private var showContinueButton = false

    // Grounding phase state
    @State private var groundingIndex = 0

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea()

            switch phase {
            case .breathing:
                breathingPhaseView
            case .grounding:
                groundingPhaseView
            case .medicalAlert:
                medicalAlertView
            case .calm:
                calmView
            }
        }
        .onAppear {
            if let profile = try? profileStore.load() {
                emergencyContactEnabled = profile.emergencyContactEnabled
                emergencyContactPhone = profile.emergencyContactPhone
            }
            let action = controller.lastInterventionAction
            switch action {
            case .calm:
                phase = .calm
            case .groundingExercise:
                phase = .grounding
            case .medicalAlert:
                phase = .medicalAlert
            default:
                // .breathingGuide, .emergencyContact, .none all begin with breathing → grounding.
                phase = .breathing
                if action == .emergencyContact && emergencyContactEnabled {
                    showEmergencySheet = true
                }
            }
        }
        .sheet(isPresented: $showEmergencySheet) {
            EmergencyContactSheet(phone: emergencyContactPhone) {
                controller.send(.interventionDismissed)
            }
        }
    }

    // MARK: - Breathing phase

    private var breathingPhaseView: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.teal.opacity(0.25), Color.cyan.opacity(0.05), Color.clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .scaleEffect(breathScale)
                .animation(.easeInOut(duration: 4), value: breathScale)

            // Core breathing circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.teal.opacity(0.55), Color.cyan.opacity(0.15)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .scaleEffect(breathScale)
                .animation(.easeInOut(duration: 4), value: breathScale)

            Text(phaseLabel)
                .font(.title3)
                .fontWeight(.light)
                .foregroundColor(.white.opacity(0.9))
                .animation(.easeOut(duration: 0.4), value: phaseLabel)

            // Button pinned to bottom, clear of the breathing circle
            VStack {
                Spacer()
                if showContinueButton {
                    Button("Continue to grounding") {
                        phase = .grounding
                    }
                    .font(.subheadline)
                    .foregroundColor(.teal)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(Capsule())
                    .transition(.opacity)
                    .padding(.bottom, 56)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // task{} is automatically cancelled when breathingPhaseView leaves the hierarchy.
        .task {
            var cycleCount = 0
            while !Task.isCancelled {
                // Breathe in — circle expands over 4 s
                phaseLabel = "Breathe in"
                breathScale = 1.0
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }

                // Hold at full expansion for 2 s
                phaseLabel = "Hold"
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }

                // Breathe out — circle contracts over 4 s
                phaseLabel = "Breathe out"
                breathScale = 0.62
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }

                // Hold at resting size for 1 s
                phaseLabel = "Hold"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }

                cycleCount += 1
                if cycleCount == 1 {
                    withAnimation { showContinueButton = true }
                }
            }
        }
    }

    // MARK: - Grounding phase

    private var groundingPhaseView: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("\(groundingPrompts[groundingIndex].count)")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundColor(.teal)

            VStack(spacing: 8) {
                Text(groundingPrompts[groundingIndex].title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(groundingPrompts[groundingIndex].hint)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if groundingIndex < groundingPrompts.count - 1 {
                Button("Next") {
                    withAnimation { groundingIndex += 1 }
                }
                .font(.subheadline)
                .foregroundColor(.teal)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.teal.opacity(0.15))
                .clipShape(Capsule())
            } else {
                Button("I'm feeling better") {
                    controller.send(.interventionDismissed)
                }
                .font(.subheadline)
                .foregroundColor(.teal)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.teal.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 48)
        .animation(.easeInOut, value: groundingIndex)
    }

    // MARK: - Medical alert

    private var medicalAlertView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("This may not be a panic attack")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Your heart rate pattern suggests a possible health issue unrelated to panic. If symptoms persist, please consult a medical professional.")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            Button("Understood") {
                controller.send(.interventionDismissed)
            }
            .font(.subheadline)
            .foregroundColor(.orange)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 48)
    }

    // MARK: - Calm (low-score triage result)

    private var calmView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.teal)

            Text("You seem calm")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Your heart rate and voice patterns don't indicate a panic episode right now. Take a slow breath and carry on.")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            Button("Close") {
                controller.send(.interventionDismissed)
            }
            .font(.subheadline)
            .foregroundColor(.teal)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.teal.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 48)
    }
}

// MARK: - Emergency contact sheet

private struct EmergencyContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    let phone: String?
    let onSend: () -> Void

    @State private var showComposer = false

    private var number: String { phone.map { $0.filter(\.isNumber) } ?? "" }

    private static let messageBody =
        "I'm not feeling well and may be having a panic attack. Please check on me."

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.teal)

                VStack(spacing: 8) {
                    Text("Notify someone?")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text("Would you like to send an SMS to your emergency contact?")
                        .font(.subheadline)
                        .foregroundColor(Color.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Text("Not now")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                    }

                    Button { sendSMS() } label: {
                        Text("Send")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.teal)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .presentationDetents([.fraction(0.42)])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showComposer, onDismiss: {
            dismiss()
            onSend()
        }) {
            MessageComposeView(
                recipients: number.isEmpty ? [] : [number],
                body: Self.messageBody
            )
        }
    }

    private func sendSMS() {
        guard MFMessageComposeViewController.canSendText() else {
            dismiss()
            onSend()
            return
        }
        showComposer = true
    }
}

// MARK: - MFMessageComposeViewController wrapper

private struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            dismiss()
        }
    }
}
