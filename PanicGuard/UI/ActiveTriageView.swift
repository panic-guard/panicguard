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

    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                Image(systemName: "mic.circle")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundColor(Color.teal.opacity(0.75))

                VStack(spacing: 16) {
                    Text("Please read this out loud")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .tracking(1.2)

                    Text(anchorPhrase)
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
            .opacity(contentOpacity)
            .animation(.easeIn(duration: 1.0), value: contentOpacity)
        }
        .onAppear { contentOpacity = 1 }
        .task {
            let result = (try? await vocalAnchorManager.captureAnchor(phrase: anchorPhrase, timeout: 15))
                ?? VocalAnchorResult(targetPhrase: anchorPhrase, transcript: nil)
            controller.setPendingAnchor(result)
        }
    }
}
