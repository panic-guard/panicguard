import SwiftUI

struct ActiveTriageView: View {
    @EnvironmentObject var controller: AppStateController

    private static let anchorPhrases = [
        "The morning light\nis calm and still.",
        "Soft breath,\nsoft sky.",
        "The water is still\nand quiet.",
        "Slow and steady,\nI am here.",
        "The sky is wide\nand open.",
        "This moment\nis enough."
    ]
    private let anchorPhrase = anchorPhrases.randomElement()!
    private let vocalAnchorManager = VocalAnchorManager()

    private enum RecordingPhase { case idle, recording, done }

    @State private var recordingPhase: RecordingPhase = .idle
    @State private var contentOpacity: Double = 0
    @State private var ringScale: CGFloat = 1.0
    @State private var dotPhase: Int = 0
    @State private var recordingTask: Task<Void, Never>?
    @State private var anchorSent = false

    // Demo mode state — captured once on appear, never changes mid-session
    @State private var isDemoFixed = false
    @State private var demoBPM: Double = 0
    @State private var demoSlope: Double = 0

    private var captionText: String {
        switch recordingPhase {
        case .idle:      return "Take your time"
        case .recording: return "Keep going"
        case .done:      return "Analyzing..."
        }
    }

    private var dotIndicatorText: String {
        guard recordingPhase != .idle else { return " " }
        return String(repeating: "•", count: dotPhase + 1)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                // Demo badge — fixed scenario only
                if isDemoFixed {
                    HStack(spacing: 8) {
                        Text("DEMO")
                            .font(.caption2).fontWeight(.bold)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.teal).foregroundColor(.black)
                            .cornerRadius(6)
                        Text("\(Int(demoBPM)) BPM · +\(Int(demoSlope))/min")
                            .font(.caption2).foregroundColor(Color.teal.opacity(0.7))
                    }
                    .padding(.top, 60)
                }

                Spacer()

                // Phrase — always visible
                VStack(spacing: 14) {
                    Text(captionText)
                        .font(recordingPhase == .done ? .title2 : .caption)
                        .fontWeight(recordingPhase == .done ? .light : .regular)
                        .foregroundColor(recordingPhase == .done ? .white : .gray)
                        .tracking(recordingPhase == .done ? 0 : 1.2)
                        .animation(.easeInOut(duration: 0.3), value: captionText)

                    if recordingPhase != .done {
                        Text(anchorPhrase)
                            .font(.title2)
                            .fontWeight(.light)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(8)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }
                }

                Spacer()

                // Button area — hidden after done
                if recordingPhase != .done {
                    recordButton
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }

                Text(dotIndicatorText)
                    .font(.caption2)
                    .foregroundColor(Color.teal.opacity(0.4))
                    .animation(.easeInOut(duration: 0.3), value: dotPhase)
                    .frame(height: 16)

                // Fixed demo: show actual Gemma prompt while waiting 5 s
                if isDemoFixed, recordingPhase == .done, let prompt = controller.demoPromptText {
                    ScrollView {
                        Text(prompt)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.teal.opacity(0.65))
                            .padding(12)
                    }
                    .frame(maxHeight: 260)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .transition(.opacity)
                }

                Spacer().frame(height: 48)
            }
            .opacity(contentOpacity)
            .animation(.easeIn(duration: 0.8), value: contentOpacity)
        }
        .onAppear {
            contentOpacity = 1
            // Fixed demo: capture HR summary and auto-deliver anchor after 1.5 s
            if let anchor = controller.demoAnchor,
               let summary = controller.demoHRSummary {
                isDemoFixed = true
                demoBPM = summary.bpm
                demoSlope = summary.slope
                controller.demoAnchor = nil
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.4)) { recordingPhase = .done }
                        deliverAnchor(anchor)
                    }
                }
            }
        }
        .task(id: recordingPhase) {
            guard recordingPhase != .idle else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }

    // MARK: - Record button

    @ViewBuilder
    private var recordButton: some View {
        switch recordingPhase {
        case .idle:
            Button(action: startRecording) {
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
            Button(action: stopRecording) {
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

    // MARK: - Actions

    private func startRecording() {
        recordingPhase = .recording
        recordingTask = Task {
            // System-only 12-second limit — not shown to the user.
            let result = (try? await vocalAnchorManager.captureAnchor(phrase: anchorPhrase, timeout: 12))
                ?? VocalAnchorResult(targetPhrase: anchorPhrase, transcript: nil)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) { recordingPhase = .done }
                deliverAnchor(result)
            }
        }
    }

    private func stopRecording() {
        vocalAnchorManager.stopRecordingEarly()
        withAnimation { recordingPhase = .done }
        // recordingTask recognizes the partial audio and calls deliverAnchor with the result.
    }

    @MainActor
    private func deliverAnchor(_ result: VocalAnchorResult) {
        guard !anchorSent else { return }
        anchorSent = true
        controller.setPendingAnchor(result)
    }
}
