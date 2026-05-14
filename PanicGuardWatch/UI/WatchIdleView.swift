import SwiftUI

struct WatchIdleView: View {
    @State private var pulseScale: CGFloat = 1.0

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
        .onAppear { pulseScale = 1.25 }
    }
}
