import SwiftUI
import WatchKit

struct WatchInterventionView: View {
    @State private var breathScale: CGFloat = 0.62
    @State private var phaseText: String = "Breathe in"
    @State private var hapticTimer: Timer?

    private let phases: [(String, Double)] = [
        ("Breathe in", 4),
        ("Hold", 2),
        ("Breathe out", 4),
        ("Hold", 1)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.teal.opacity(0.60),
                                Color.cyan.opacity(0.10)
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(breathScale)
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: breathScale
                    )

                Text(phaseText)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .animation(.easeOut(duration: 0.35), value: phaseText)
            }
        }
        .onAppear {
            breathScale = 1.0
            startCycle()
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                WKInterfaceDevice.current().play(.click)
            }
        }
        .onDisappear {
            hapticTimer?.invalidate()
            hapticTimer = nil
        }
    }

    private func startCycle() {
        Task {
            var i = 0
            while !Task.isCancelled {
                let (label, duration) = phases[i % phases.count]
                withAnimation(.easeOut(duration: 0.35)) { phaseText = label }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                i += 1
            }
        }
    }
}
