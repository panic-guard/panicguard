import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        dateSection
                        interventionSection
                        if let triage = episode.triage { triageSection(triage) }
                        ratingSection
                        deleteSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Episode Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.teal)
                }
            }
        }
    }

    // MARK: - Sections

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Date & Time")
            HStack(spacing: 12) {
                Text(episode.date, style: .date)
                    .font(.body)
                    .foregroundColor(.white)
                Text(episode.date, style: .time)
                    .font(.body)
                    .foregroundColor(Color.gray.opacity(0.6))
            }
        }
    }

    private var interventionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Intervention")
            HStack(spacing: 10) {
                InterventionBadgeLarge(action: episode.intervention)
                Text(interventionDescription(episode.intervention))
                    .font(.subheadline)
                    .foregroundColor(Color.gray.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func triageSection(_ triage: TriageResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("AI Analysis")

            HStack(spacing: 16) {
                LikelihoodGauge(
                    label: "Panic",
                    value: triage.likelihoodPanic,
                    color: panicColor(triage.likelihoodPanic)
                )
                LikelihoodGauge(
                    label: "Physical",
                    value: triage.likelihoodPhysicalAnomaly,
                    color: .orange
                )
                VStack(spacing: 4) {
                    Text(triage.confidence.rawValue.capitalized)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("confidence")
                        .font(.caption2)
                        .foregroundColor(Color.gray.opacity(0.5))
                }
            }

            if !triage.reasoningSummary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Reasoning")
                    Text(triage.reasoningSummary)
                        .font(.subheadline)
                        .foregroundColor(Color.gray.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("How you felt")
            if let rating = episode.rating {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { i in
                        Circle()
                            .fill(i <= rating ? Color.teal : Color.white.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("\(i)")
                                    .font(.caption.bold())
                                    .foregroundColor(i <= rating ? .black : Color.gray.opacity(0.4))
                            )
                    }
                }
            } else {
                Text("Not recorded")
                    .font(.subheadline)
                    .foregroundColor(Color.gray.opacity(0.4))
            }
        }
    }

    private var deleteSection: some View {
        Button {
            onDelete()
            dismiss()
        } label: {
            HStack {
                Spacer()
                Label("Delete Episode", systemImage: "trash")
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(Color.gray.opacity(0.45))
            .kerning(1.2)
    }

    private func interventionDescription(_ action: InterventionAction) -> String {
        switch action {
        case .breathingGuide:    return "Guided breathing + grounding exercise"
        case .groundingExercise: return "5-4-3-2-1 grounding exercise"
        case .emergencyContact:  return "Emergency contact notified"
        case .medicalAlert:      return "Medical attention suggested"
        case .none:              return "Direct intervention without triage"
        }
    }

    private func panicColor(_ value: Double) -> Color {
        value >= 0.75 ? .red : value >= 0.40 ? .orange : .teal
    }
}

// MARK: - Sub-components

private struct InterventionBadgeLarge: View {
    let action: InterventionAction

    private var label: String {
        switch action {
        case .breathingGuide:    return "Breathing"
        case .groundingExercise: return "Grounding"
        case .emergencyContact:  return "Emergency"
        case .medicalAlert:      return "Medical"
        case .none:              return "Direct"
        }
    }

    private var color: Color {
        switch action {
        case .breathingGuide:    return .teal
        case .groundingExercise: return .cyan
        case .emergencyContact:  return .orange
        case .medicalAlert:      return .red
        case .none:              return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct LikelihoodGauge: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .frame(width: 64, height: 64)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.gray.opacity(0.5))
        }
    }
}
