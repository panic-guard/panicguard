import SwiftUI

struct EpisodeHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    private let store = EpisodeStore()
    @State private var episodes: [Episode] = []
    @State private var showExportSheet = false
    @State private var exportURL: URL? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if episodes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 44, weight: .ultraLight))
                            .foregroundColor(Color.gray.opacity(0.4))
                        Text("No episodes recorded yet")
                            .font(.body)
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                } else {
                    List {
                        ForEach(episodes) { episode in
                            EpisodeRowView(episode: episode)
                                .listRowBackground(Color.white.opacity(0.05))
                                .listRowSeparatorTint(Color.white.opacity(0.08))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Episode History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.teal)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !episodes.isEmpty {
                        Button {
                            exportURL = buildCSV(episodes: episodes)
                            showExportSheet = exportURL != nil
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.teal)
                        }
                    }
                }
            }
        }
        .onAppear { episodes = (try? store.fetchAll()) ?? [] }
        .sheet(isPresented: $showExportSheet, onDismiss: { exportURL = nil }) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
}

// MARK: - Row

private struct EpisodeRowView: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(episode.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text(episode.date, style: .time)
                    .font(.subheadline)
                    .foregroundColor(Color.gray.opacity(0.6))
                Spacer()
                if let rating = episode.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.teal)
                        Text("\(rating)/5")
                            .font(.caption)
                            .foregroundColor(.teal)
                    }
                }
            }

            HStack(spacing: 8) {
                InterventionBadge(action: episode.intervention)

                if let triage = episode.triage {
                    Text(String(format: "%.0f%% panic", triage.likelihoodPanic * 100))
                        .font(.caption2)
                        .foregroundColor(Color.gray.opacity(0.55))
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct InterventionBadge: View {
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
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - CSV Export

private func buildCSV(episodes: [Episode]) -> URL? {
    var lines = ["date,time,intervention,panic_likelihood,physical_anomaly_likelihood,confidence,rating"]
    let dateFmt = DateFormatter()
    dateFmt.dateFormat = "yyyy-MM-dd"
    let timeFmt = DateFormatter()
    timeFmt.dateFormat = "HH:mm:ss"

    for e in episodes {
        let date = dateFmt.string(from: e.date)
        let time = timeFmt.string(from: e.date)
        let panic = e.triage.map { String(format: "%.2f", $0.likelihoodPanic) } ?? ""
        let physical = e.triage.map { String(format: "%.2f", $0.likelihoodPhysicalAnomaly) } ?? ""
        let confidence = e.triage?.confidence.rawValue ?? ""
        let rating = e.rating.map { String($0) } ?? ""
        lines.append("\(date),\(time),\(e.intervention.rawValue),\(panic),\(physical),\(confidence),\(rating)")
    }

    let csv = lines.joined(separator: "\n")
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("panicguard_episodes.csv")
    return (try? csv.write(to: url, atomically: true, encoding: .utf8)) == nil ? nil : url
}

// MARK: - UIActivityViewController wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
