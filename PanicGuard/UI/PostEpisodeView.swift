import SwiftUI

struct PostEpisodeView: View {
    @EnvironmentObject var controller: AppStateController
    @State private var selectedRating: Int? = nil
    @State private var contentOpacity: Double = 0

    private let episodeStore = EpisodeStore()

    private let ratingLabels = ["1", "2", "3", "4", "5"]
    private let scaleLabels = ("Not great", "Much better")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("How do you feel?")
                    .font(.title2)
                    .fontWeight(.light)
                    .foregroundColor(.white)

                Spacer().frame(height: 44)

                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        ForEach(1...5, id: \.self) { i in
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedRating = i
                                }
                            } label: {
                                Circle()
                                    .fill(selectedRating == i
                                          ? Color.teal
                                          : Color.gray.opacity(0.22))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Text("\(i)")
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .foregroundColor(
                                                selectedRating == i ? .black : .white.opacity(0.6)
                                            )
                                    )
                                    .animation(.easeOut(duration: 0.2), value: selectedRating)
                            }
                        }
                    }

                    HStack {
                        Text(scaleLabels.0)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(scaleLabels.1)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 6)
                    .frame(width: 296)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        saveEpisode()
                        controller.send(.logComplete)
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(Color.gray.opacity(0.55))
                    }

                    Button {
                        saveEpisode()
                        controller.send(.logComplete)
                    } label: {
                        Text("Save & Close")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(selectedRating == nil ? .gray : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(selectedRating == nil
                                        ? Color.gray.opacity(0.18)
                                        : Color.teal)
                            .cornerRadius(16)
                            .animation(.easeOut(duration: 0.25), value: selectedRating)
                    }
                    .disabled(selectedRating == nil)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 56)
            }
            .opacity(contentOpacity)
            .animation(.easeIn(duration: 0.6), value: contentOpacity)
        }
        .onAppear { contentOpacity = 1 }
    }

    private func saveEpisode() {
        let episode = Episode(
            triage: controller.lastTriageResult,
            intervention: controller.lastInterventionAction,
            rating: selectedRating
        )
        try? episodeStore.save(episode)
    }
}
