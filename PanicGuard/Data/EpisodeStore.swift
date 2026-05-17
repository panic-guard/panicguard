import Foundation
import CoreData

struct Episode: Identifiable, Codable {
    let id: UUID
    let date: Date
    let triage: TriageResult?
    let intervention: InterventionAction
    let rating: Int?

    init(id: UUID = UUID(), date: Date = .now, triage: TriageResult? = nil, intervention: InterventionAction, rating: Int? = nil) {
        self.id = id
        self.date = date
        self.triage = triage
        self.intervention = intervention
        self.rating = rating
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
        mo.setValue(episode.triage.flatMap { try? JSONEncoder().encode($0) }, forKey: "triageData")
        mo.setValue(episode.intervention.rawValue, forKey: "interventionRaw")
        mo.setValue(episode.rating.map { NSNumber(value: $0) }, forKey: "rating")
        try ctx.save()
    }

    func fetchAll() throws -> [Episode] {
        let ctx = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "EpisodeMO")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try ctx.fetch(request).map { mo in
            let triage: TriageResult? = (mo.value(forKey: "triageData") as? Data)
                .flatMap { try? JSONDecoder().decode(TriageResult.self, from: $0) }
            let interventionRaw = mo.value(forKey: "interventionRaw") as! String
            return Episode(
                id: mo.value(forKey: "id") as! UUID,
                date: mo.value(forKey: "date") as! Date,
                triage: triage,
                intervention: InterventionAction(rawValue: interventionRaw) ?? .none,
                rating: (mo.value(forKey: "rating") as? NSNumber)?.intValue
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
            attr("triageData", .binaryDataAttributeType, isOptional: true),
            attr("interventionRaw", .stringAttributeType),
            attr("rating", .integer16AttributeType, isOptional: true)
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}
