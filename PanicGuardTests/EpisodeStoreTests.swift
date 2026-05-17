import XCTest
@testable import PanicGuard

final class EpisodeStoreTests: XCTestCase {

    private var sut: EpisodeStore!

    override func setUp() {
        super.setUp()
        sut = EpisodeStore(inMemory: true)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeEpisode(
        date: Date = .now,
        panicLikelihood: Double = 0.8,
        intervention: InterventionAction = .breathingGuide,
        userNote: String? = nil
    ) -> Episode {
        let triage = TriageResult(
            likelihoodPanic: panicLikelihood,
            likelihoodPhysicalAnomaly: 0.1,
            confidence: .high,
            reasoningSummary: "test"
        )
        return Episode(id: UUID(), date: date, triage: triage, intervention: intervention, userNote: userNote)
    }

    // MARK: - save / fetchAll round-trip

    func test_saveAndFetchAll_roundTrip() throws {
        let episode = makeEpisode()
        try sut.save(episode)
        let fetched = try sut.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, episode.id)
    }

    func test_fetchAll_emptyStore_returnsEmptyArray() throws {
        let result = try sut.fetchAll()
        XCTAssertTrue(result.isEmpty)
    }

    func test_multipleEpisodes_returnedNewestFirst() throws {
        let older = makeEpisode(date: Date(timeIntervalSinceNow: -3600))
        let newer = makeEpisode(date: Date(timeIntervalSinceNow: -60))
        try sut.save(older)
        try sut.save(newer)

        let fetched = try sut.fetchAll()
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched[0].id, newer.id)
        XCTAssertEqual(fetched[1].id, older.id)
    }

    // MARK: - Field accuracy

    func test_save_preservesAllInterventionActions() throws {
        let actions: [InterventionAction] = [.breathingGuide, .groundingExercise, .emergencyContact, .medicalAlert, .none]
        for action in actions {
            let ep = makeEpisode(intervention: action)
            try sut.save(ep)
        }
        let fetched = try sut.fetchAll()
        let fetchedActions = Set(fetched.map(\.intervention))
        XCTAssertEqual(fetchedActions, Set(actions))
    }

    func test_save_preservesTriageResult_allFields() throws {
        let triage = TriageResult(
            likelihoodPanic: 0.92,
            likelihoodPhysicalAnomaly: 0.05,
            confidence: .medium,
            reasoningSummary: "elevated HR, stationary, slow speech"
        )
        let episode = Episode(date: .now, triage: triage, intervention: .breathingGuide)
        try sut.save(episode)

        let fetched = try sut.fetchAll()[0]
        XCTAssertEqual(fetched.triage.likelihoodPanic, 0.92, accuracy: 0.001)
        XCTAssertEqual(fetched.triage.likelihoodPhysicalAnomaly, 0.05, accuracy: 0.001)
        XCTAssertEqual(fetched.triage.confidence, .medium)
        XCTAssertEqual(fetched.triage.reasoningSummary, "elevated HR, stationary, slow speech")
    }

    func test_save_preservesUserNote() throws {
        let ep = makeEpisode(userNote: "felt very anxious at work")
        try sut.save(ep)
        XCTAssertEqual(try sut.fetchAll()[0].userNote, "felt very anxious at work")
    }

    func test_save_preservesNilUserNote() throws {
        let ep = makeEpisode(userNote: nil)
        try sut.save(ep)
        XCTAssertNil(try sut.fetchAll()[0].userNote)
    }

    func test_save_preservesDate() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let ep = makeEpisode(date: fixedDate)
        try sut.save(ep)
        let fetched = try sut.fetchAll()[0]
        XCTAssertEqual(fetched.date.timeIntervalSince1970, fixedDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func test_triageResult_confidence_allVariants() throws {
        let variants: [TriageResult.Confidence] = [.high, .medium, .low]
        for confidence in variants {
            let triage = TriageResult(
                likelihoodPanic: 0.5,
                likelihoodPhysicalAnomaly: 0.1,
                confidence: confidence,
                reasoningSummary: "test"
            )
            try sut.save(Episode(date: .now, triage: triage, intervention: .none))
        }
        let fetched = try sut.fetchAll()
        let fetchedConfidences = Set(fetched.map(\.triage.confidence))
        XCTAssertEqual(fetchedConfidences, Set(variants))
    }

    func test_twoInMemoryInstances_areIsolated() throws {
        let store2 = EpisodeStore(inMemory: true)
        try sut.save(makeEpisode())
        XCTAssertTrue(try store2.fetchAll().isEmpty)
    }
}
