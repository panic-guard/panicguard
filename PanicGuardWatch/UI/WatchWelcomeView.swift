import SwiftUI

struct WatchWelcomeView: View {
    let onContinue: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 72, height: 72)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.teal)
            }

            Spacer().frame(height: 16)

            VStack(spacing: 6) {
                Text("PanicGuard")
                    .font(.system(size: 18, weight: .thin))
                    .foregroundColor(.white)
                    .tracking(0.5)

                Text("Quiet support,\nwhen you need it most.")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get started")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.teal)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .background(Color.black.ignoresSafeArea())
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) { opacity = 1 }
            pulseScale = 1.22
        }
    }
}
