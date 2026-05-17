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
    private let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = Self.makeContainer(inMemory: inMemory)
    }

    func save(_ episode: Episode) throws {
        let ctx = container.viewContext
        let entity = container.managedObjectModel.entitiesByName["EpisodeMO"]!
        let mo = NSManagedObject(entity: entity, insertInto: ctx)
        mo.setValue(episode.id, forKey: "id")
        mo.setValue(episode.date, forKey: "date")
        mo.setValue(try JSONEncoder().encode(episode.triage), forKey: "triageData")
        mo.setValue(episode.intervention.rawValue, forKey: "interventionRaw")
        mo.setValue(episode.userNote, forKey: "userNote")
        try ctx.save()
    }

    func fetchAll() throws -> [Episode] {
        let ctx = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "EpisodeMO")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try ctx.fetch(request).map { mo in
            let triageData = mo.value(forKey: "triageData") as! Data
            let triage = try JSONDecoder().decode(TriageResult.self, from: triageData)
            let interventionRaw = mo.value(forKey: "interventionRaw") as! String
            return Episode(
                id: mo.value(forKey: "id") as! UUID,
                date: mo.value(forKey: "date") as! Date,
                triage: triage,
                intervention: InterventionAction(rawValue: interventionRaw) ?? .none,
                userNote: mo.value(forKey: "userNote") as? String
            )
        }
    }

    // MARK: - Private

    private static func makeContainer(inMemory: Bool) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "PanicGuard", managedObjectModel: makeModel())
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("EpisodeStore: CoreData load failed — \(error)") }
        }
        return container
    }

    private static func makeModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "EpisodeMO"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        func attr(_ name: String, _ type: NSAttributeType, isOptional: Bool = false) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = isOptional
            return a
        }

        entity.properties = [
            attr("id", .UUIDAttributeType),
            attr("date", .dateAttributeType),
            attr("triageData", .binaryDataAttributeType),
            attr("interventionRaw", .stringAttributeType),
            attr("userNote", .stringAttributeType, isOptional: true)
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}
