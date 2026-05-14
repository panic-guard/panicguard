import Foundation
import CoreData

struct Episode: Identifiable, Codable {
    let id: UUID
    let date: Date
    let triage: TriageResult
    let intervention: InterventionAction
    let userNote: String?

    init(id: UUID = UUID(), date: Date = .now, triage: TriageResult, intervention: InterventionAction, userNote: String? = nil) {
        self.id = id
        self.date = date
        self.triage = triage
        self.intervention = intervention
        self.userNote = userNote
    }
}

protocol EpisodeStoring {
    func save(_ episode: Episode) throws
    func fetchAll() throws -> [Episode]
}

final class EpisodeStore: EpisodeStoring {
    func save(_ episode: Episode) throws {
        // TODO: persist to Core Data
        fatalError("not implemented")
    }

    func fetchAll() throws -> [Episode] {
        // TODO: fetch from Core Data
        fatalError("not implemented")
    }
}
