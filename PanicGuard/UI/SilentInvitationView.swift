import SwiftUI

struct SilentInvitationView: View {
    @EnvironmentObject var controller: AppStateController

    @State private var breathScale: CGFloat = 0.85
    @State private var fillOpacity: Double = 0.35
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Breathing circle
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(fillOpacity))
                        .frame(width: 160, height: 160)
                        .scaleEffect(breathScale)
                        .animation(
                            .easeInOut(duration: 4).repeatForever(autoreverses: true),
                            value: breathScale
                        )
                        .animation(
                            .easeInOut(duration: 4).repeatForever(autoreverses: true),
                            value: fillOpacity
                        )

                    Text("Breathe")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer().frame(height: 48)

                VStack(spacing: 6) {
                    Text("Your heart rate is elevated")
                        .font(.title3)
                        .fontWeight(.light)
                        .foregroundColor(.white)

                    Text("How are you feeling?")
                        .font(.subheadline)
                        .foregroundColor(Color.gray.opacity(0.6))
                }

                Spacer().frame(height: 48)

                VStack(spacing: 12) {
                    // Vocal triage — full 3-step pipeline
                    Button {
                        controller.send(.userAcknowledged)
                    } label: {
                        Text("Check my state")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.teal)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)

                    // Direct intervention — skip triage
                    Button {
                        controller.send(.userRequestedDirectIntervention)
                    } label: {
                        Text("I need help now")
                            .font(.subheadline)
                            .foregroundColor(Color.teal.opacity(0.75))
                    }

                    // Dismiss
                    Button {
                        controller.send(.userDismissed)
                    } label: {
                        Text("I'm fine, dismiss")
                            .font(.subheadline)
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                }

                Spacer().frame(height: 56)
            }
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) { contentOpacity = 1 }
            breathScale = 1.0
            fillOpacity = 0.12
        }
    }
}
