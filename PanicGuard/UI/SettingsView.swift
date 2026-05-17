import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let store = UserProfileStore()

    @State private var emergencyContactEnabled = false
    @State private var emergencyContactPhone = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Text("EMERGENCY CONTACT")
                        .font(.caption2)
                        .foregroundColor(Color.gray.opacity(0.6))
                        .tracking(1.2)
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 8)

                    VStack(spacing: 0) {
                        Toggle(isOn: $emergencyContactEnabled.animation()) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notify someone during a crisis")
                                    .font(.body)
                                    .foregroundColor(.white)
                                Text("A message will be sent via SMS")
                                    .font(.caption)
                                    .foregroundColor(Color.gray.opacity(0.6))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .teal))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                        if emergencyContactEnabled {
                            Divider()
                                .background(Color.white.opacity(0.08))

                            HStack {
                                Text("Phone number")
                                    .font(.body)
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("", text: $emergencyContactPhone)
                                    .keyboardType(.phonePad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.teal)
                                    .frame(maxWidth: 160)
                                    .placeholder(when: emergencyContactPhone.isEmpty) {
                                        Text("+1 000 000 0000")
                                            .foregroundColor(Color.gray.opacity(0.4))
                                            .multilineTextAlignment(.trailing)
                                    }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)

                    Spacer()

                    Button(action: saveAndDismiss) {
                        Text("Save")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.teal)
                }
            }
        }
        .onAppear(perform: loadProfile)
    }

    private func loadProfile() {
        guard let profile = try? store.load() else { return }
        emergencyContactEnabled = profile.emergencyContactEnabled
        emergencyContactPhone = profile.emergencyContactPhone ?? ""
    }

    private func saveAndDismiss() {
        guard let current = try? store.load() else { dismiss(); return }
        let phone = emergencyContactPhone.isEmpty ? nil : emergencyContactPhone
        let updated = UserProfile(
            age: current.age,
            baselineHR: current.baselineHR,
            baselineVocalMetrics: current.baselineVocalMetrics,
            emergencyContactEnabled: emergencyContactEnabled,
            emergencyContactPhone: phone
        )
        try? store.save(updated)
        PhoneConnector.shared.pushProfile(ecPhone: emergencyContactEnabled ? phone : nil)
        dismiss()
    }
}

// MARK: - Placeholder helper

private extension View {
    func placeholder<Content: View>(
        when condition: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .trailing) {
            if condition { placeholder() }
            self
        }
    }
}
