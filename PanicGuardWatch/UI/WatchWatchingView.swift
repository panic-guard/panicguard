import SwiftUI

struct WatchWatchingView: View {
    @State private var dotOpacities: [Double] = [1.0, 0.3, 0.3]
    @State private var dotIndex: Int = 0

    private let timer = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 26, weight: .ultraLight))
                    .foregroundColor(.teal)

                Text("Analyzing")
                    .font(.caption)
                    .fontWeight(.light)
                    .foregroundColor(.white)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.teal)
                            .frame(width: 7, height: 7)
                            .opacity(dotOpacities[i])
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            dotIndex = (dotIndex + 1) % 3
            withAnimation(.easeInOut(duration: 0.25)) {
                dotOpacities = [0.25, 0.25, 0.25]
                dotOpacities[dotIndex] = 1.0
            }
        }
    }
}
