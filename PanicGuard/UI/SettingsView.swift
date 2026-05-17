import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let store = UserProfileStore()

    // Profile
    @State private var age = 25
    @State private var ageText = "25"
    @State private var baselineHR = 72.0

    // Emergency contact
    @State private var emergencyContactEnabled = false
    @State private var emergencyContactPhone = ""
    @FocusState private var phoneFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Profile section
                        sectionHeader("PROFILE")

                        settingsCard {
                            // Age row
                            HStack {
                                Text("Age")
                                    .font(.body)
                                    .foregroundColor(.white)
                                Spacer()
                                TextField("", text: $ageText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(.teal)
                                    .frame(maxWidth: 60)
                                    .onChange(of: ageText) { _, newVal in
                                        let digits = String(newVal.filter(\.isNumber).prefix(2))
                                        if digits != newVal { ageText = digits }
                                        if let val = Int(digits), (10...99).contains(val) { age = val }
                                    }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                            divider()

                            // Baseline HR row (read-only — set during onboarding calibration)
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Baseline Heart Rate")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Text("Measured during onboarding")
                                        .font(.caption)
                                        .foregroundColor(Color.gray.opacity(0.5))
                                }
                                Spacer()
                                Text("\(Int(baselineHR)) BPM")
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(Color.gray.opacity(0.55))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }

                        // MARK: Emergency contact section
                        sectionHeader("EMERGENCY CONTACT")

                        settingsCard {
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
                                divider()

                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Phone number")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        if emergencyContactPhone.trimmingCharacters(in: .whitespaces).isEmpty {
                                            Text("Required")
                                                .font(.caption2)
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                    }
                                    Spacer()
                                    TextField("", text: $emergencyContactPhone)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.teal)
                                        .frame(maxWidth: 160)
                                        .focused($phoneFieldFocused)
                                        .onChange(of: emergencyContactPhone) { _, newVal in
                                            let digits = newVal.filter(\.isNumber)
                                            if digits != newVal { emergencyContactPhone = digits }
                                        }
                                        .placeholder(when: emergencyContactPhone.isEmpty) {
                                            Text("01012345678")
                                                .foregroundColor(Color.gray.opacity(0.4))
                                                .multilineTextAlignment(.trailing)
                                        }
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button("Done") { phoneFieldFocused = false }
                                                    .foregroundColor(.teal)
                                            }
                                        }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                        }

                        Spacer().frame(height: 40)

                        // MARK: Save button
                        let saveBlocked = emergencyContactEnabled && emergencyContactPhone.trimmingCharacters(in: .whitespaces).isEmpty
                        Button(action: saveAndDismiss) {
                            Text("Save")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(saveBlocked ? Color.gray.opacity(0.4) : Color.teal)
                                .cornerRadius(16)
                        }
                        .disabled(saveBlocked)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 56)
                    }
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

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .foregroundColor(Color.gray.opacity(0.6))
            .tracking(1.2)
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 8)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            .padding(.horizontal, 16)
    }

    private func divider() -> some View {
        Divider().background(Color.white.opacity(0.08))
    }

    // MARK: - Data

    private func loadProfile() {
        guard let profile = try? store.load() else { return }
        age = profile.age
        ageText = "\(profile.age)"
        baselineHR = profile.baselineHR
        emergencyContactEnabled = profile.emergencyContactEnabled
        emergencyContactPhone = profile.emergencyContactPhone ?? ""
    }

    private func saveAndDismiss() {
        guard let current = try? store.load() else { dismiss(); return }
        let phone = emergencyContactPhone.isEmpty ? nil : emergencyContactPhone
        let updated = UserProfile(
            age: age,
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
