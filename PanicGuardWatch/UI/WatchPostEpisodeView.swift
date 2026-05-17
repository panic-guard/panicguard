import SwiftUI
import WatchKit

struct WatchPostEpisodeView: View {
    @EnvironmentObject var controller: AppStateController
    @State private var selectedRating: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("How do you feel?")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white)

            Spacer().frame(height: 14)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedRating = i
                        }
                    } label: {
                        Circle()
                            .fill(selectedRating == i
                                  ? Color.teal
                                  : Color.gray.opacity(0.22))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text("\(i)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(selectedRating == i ? .black : .white.opacity(0.6))
                            )
                            .animation(.easeOut(duration: 0.15), value: selectedRating)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Not great")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Spacer()
                Text("Much better")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            Spacer()

            Button {
                WKInterfaceDevice.current().play(.success)
                controller.send(.logComplete)
            } label: {
                Text("Save")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(selectedRating == nil ? .gray : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(selectedRating == nil ? Color.gray.opacity(0.18) : Color.teal)
                    .cornerRadius(8)
                    .animation(.easeOut(duration: 0.2), value: selectedRating)
            }
            .buttonStyle(.plain)
            .disabled(selectedRating == nil)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
