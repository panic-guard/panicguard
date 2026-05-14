import SwiftUI

struct IdleView: View {
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
            }
        }
        .onAppear { pulseScale = 1.3 }
    }
}
