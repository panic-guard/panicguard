import SwiftUI

struct InterventionView: View {
    @State private var breathScale: CGFloat = 0.62
    @State private var phaseText: String = "Breathe in"
    @State private var phaseIndex: Int = 0

    // Variable-duration phases: (label, seconds)
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
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.teal.opacity(0.25),
                                Color.cyan.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .scaleEffect(breathScale)
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: breathScale
                    )

                // Core breathing circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.teal.opacity(0.55),
                                Color.cyan.opacity(0.15)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(breathScale)
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: breathScale
                    )

                Text(phaseText)
                    .font(.title3)
                    .fontWeight(.light)
                    .foregroundColor(.white.opacity(0.9))
                    .animation(.easeOut(duration: 0.4), value: phaseText)
            }
        }
        .onAppear {
            breathScale = 1.0
            startCycle()
        }
    }

    private func startCycle() {
        Task {
            var i = 0
            while !Task.isCancelled {
                let (label, duration) = phases[i % phases.count]
                withAnimation(.easeOut(duration: 0.4)) { phaseText = label }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                i += 1
            }
        }
    }
}
