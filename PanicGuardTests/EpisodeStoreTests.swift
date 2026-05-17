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

    private func makeTriage(
        panic: Double = 0.8,
        physical: Double = 0.1,
        confidence: TriageResult.Confidence = .high
    ) -> TriageResult {
        TriageResult(
            likelihoodPanic: panic,
            likelihoodPhysicalAnomaly: physical,
            confidence: confidence,
            reasoningSummary: "test"
        )
    }

    private func makeEpisode(
        date: Date = .now,
        triage: TriageResult? = nil,
        intervention: InterventionAction = .breathingGuide,
        rating: Int? = nil
    ) -> Episode {
        Episode(id: UUID(), date: date, triage: triage ?? makeTriage(), intervention: intervention, rating: rating)
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
        let triage = makeTriage(panic: 0.92, physical: 0.05, confidence: .medium)
        let episode = Episode(date: .now, triage: triage, intervention: .breathingGuide)
        try sut.save(episode)

        let fetched = try XCTUnwrap(try sut.fetchAll()[0].triage)
        XCTAssertEqual(fetched.likelihoodPanic, 0.92, accuracy: 0.001)
        XCTAssertEqual(fetched.likelihoodPhysicalAnomaly, 0.05, accuracy: 0.001)
        XCTAssertEqual(fetched.confidence, .medium)
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
            let triage = makeTriage(confidence: confidence)
            try sut.save(Episode(date: .now, triage: triage, intervention: .none))
        }
        let fetched = try sut.fetchAll()
        let fetchedConfidences = Set(fetched.compactMap(\.triage?.confidence))
        XCTAssertEqual(fetchedConfidences, Set(variants))
    }

    func test_twoInMemoryInstances_areIsolated() throws {
        let store2 = EpisodeStore(inMemory: true)
        try sut.save(makeEpisode())
        XCTAssertTrue(try store2.fetchAll().isEmpty)
    }

    // MARK: - Rating round-trip

    func test_save_preservesRating() throws {
        let ep = makeEpisode(rating: 4)
        try sut.save(ep)
        XCTAssertEqual(try sut.fetchAll()[0].rating, 4)
    }

    func test_save_preservesNilRating() throws {
        let ep = makeEpisode(rating: nil)
        try sut.save(ep)
        XCTAssertNil(try sut.fetchAll()[0].rating)
    }

    func test_save_preservesAllRatingValues() throws {
        for rating in 1...5 {
            try sut.save(makeEpisode(rating: rating))
        }
        let fetched = try sut.fetchAll()
        let ratings = Set(fetched.compactMap(\.rating))
        XCTAssertEqual(ratings, Set(1...5))
    }

    // MARK: - delete

    func test_delete_removesEpisodeFromStore() throws {
        let ep = makeEpisode()
        try sut.save(ep)
        try sut.delete(ep)
        XCTAssertTrue(try sut.fetchAll().isEmpty)
    }

    func test_delete_removesOnlyTargetEpisode() throws {
        let older = makeEpisode(date: Date(timeIntervalSinceNow: -100))
        let newer = makeEpisode(date: Date(timeIntervalSinceNow: -10))
        try sut.save(older)
        try sut.save(newer)
        try sut.delete(older)
        let remaining = try sut.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0].id, newer.id)
    }

    func test_delete_nonExistentEpisode_doesNotThrow() {
        let ep = makeEpisode()
        XCTAssertNoThrow(try sut.delete(ep))
    }

    // MARK: - Nil triage (direct intervention path)

    func test_save_nilTriage_roundTrip() throws {
        let ep = Episode(date: .now, triage: nil, intervention: .groundingExercise, rating: 3)
        try sut.save(ep)
        let fetched = try sut.fetchAll()[0]
        XCTAssertNil(fetched.triage)
        XCTAssertEqual(fetched.intervention, .groundingExercise)
        XCTAssertEqual(fetched.rating, 3)
    }

    func test_save_mixedTriagePresence_bothRetrievable() throws {
        let withTriage = Episode(date: Date(timeIntervalSinceNow: -10), triage: makeTriage(), intervention: .breathingGuide)
        let withoutTriage = Episode(date: .now, triage: nil, intervention: .none)
        try sut.save(withTriage)
        try sut.save(withoutTriage)

        let fetched = try sut.fetchAll()
        XCTAssertEqual(fetched.count, 2)
        XCTAssertNotNil(fetched[1].triage)
        XCTAssertNil(fetched[0].triage)
    }
}
