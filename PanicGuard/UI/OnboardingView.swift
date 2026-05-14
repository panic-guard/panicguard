import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var controller: AppStateController
    @State private var age: Int = 25

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("How old are you?")
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundColor(.white)

                    Text("Helps calibrate your baseline heart rate")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer().frame(height: 52)

                HStack(spacing: 36) {
                    Button {
                        if age > 10 { age -= 1 }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.teal)
                    }

                    Text("\(age)")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 110)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: age)

                    Button {
                        if age < 99 { age += 1 }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.teal)
                    }
                }

                Spacer()

                Button {
                    controller.nextStateForDemo()
                } label: {
                    Text("Continue")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.teal)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 56)
            }
        }
    }
}
