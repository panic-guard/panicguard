import XCTest
@testable import PanicGuard

final class UserProfileStoreTests: XCTestCase {

    // Each test gets an isolated UserDefaults suite so tests don't bleed into each other.
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var sut: UserProfileStore!

    override func setUp() {
        super.setUp()
        suiteName = "com.panicguard.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        sut = UserProfileStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - save / load round-trip

    func test_saveAndLoad_roundTrip() throws {
        let profile = UserProfile(age: 28, baselineHR: 62.5)
        try sut.save(profile)
        let loaded = try sut.load()
        XCTAssertEqual(loaded, profile)
    }

    func test_save_overwritesPreviousProfile() throws {
        try sut.save(UserProfile(age: 25, baselineHR: 70.0))
        let updated = UserProfile(age: 26, baselineHR: 68.0)
        try sut.save(updated)
        let loaded = try sut.load()
        XCTAssertEqual(loaded, updated)
    }

    // MARK: - load before save

    func test_load_throwsNotFound_whenNothingSaved() {
        XCTAssertThrowsError(try sut.load()) { error in
            XCTAssertEqual(error as? UserProfileStoreError, .notFound)
        }
    }

    // MARK: - field accuracy

    func test_load_preservesAge() throws {
        try sut.save(UserProfile(age: 40, baselineHR: 55.0))
        XCTAssertEqual(try sut.load().age, 40)
    }

    func test_load_preservesBaselineHR() throws {
        let profile = UserProfile(age: 30, baselineHR: 58.3)
        try sut.save(profile)
        XCTAssertEqual(try sut.load().baselineHR, 58.3, accuracy: 0.001)
    }

    // MARK: - isolation between instances

    // MARK: - baselineVocalMetrics round-trip

    func test_saveAndLoad_withBaselineVocalMetrics_roundTrip() throws {
        let metrics = VocalMetrics(
            speakingRateWPM: 138.0, maxPauseSeconds: 0.28,
            meanPauseSeconds: 0.11, totalPauseSeconds: 0.0, durationSeconds: 5.2
        )
        try sut.save(UserProfile(age: 30, baselineHR: 68.0, baselineVocalMetrics: metrics))
        XCTAssertEqual(try sut.load().baselineVocalMetrics, metrics)
    }

    func test_saveAndLoad_withNilBaselineVocalMetrics_roundTrip() throws {
        try sut.save(UserProfile(age: 28, baselineHR: 70.0, baselineVocalMetrics: nil))
        XCTAssertNil(try sut.load().baselineVocalMetrics)
    }

    func test_saveAndLoad_vocalMetrics_allFieldsPreserved() throws {
        let metrics = VocalMetrics(
            speakingRateWPM: 55.3, maxPauseSeconds: 2.81,
            meanPauseSeconds: 1.23, totalPauseSeconds: 5.14, durationSeconds: 14.32
        )
        try sut.save(UserProfile(age: 25, baselineHR: 72.0, baselineVocalMetrics: metrics))
        let loaded = try sut.load().baselineVocalMetrics!
        XCTAssertEqual(loaded.speakingRateWPM,   metrics.speakingRateWPM,   accuracy: 0.001)
        XCTAssertEqual(loaded.maxPauseSeconds,   metrics.maxPauseSeconds,   accuracy: 0.001)
        XCTAssertEqual(loaded.meanPauseSeconds,  metrics.meanPauseSeconds,  accuracy: 0.001)
        XCTAssertEqual(loaded.totalPauseSeconds, metrics.totalPauseSeconds, accuracy: 0.001)
        XCTAssertEqual(loaded.durationSeconds,   metrics.durationSeconds,   accuracy: 0.001)
    }

    func test_twoInstances_shareSameDefaults_seeEachOthersData() throws {
        let store2 = UserProfileStore(defaults: defaults)
        try sut.save(UserProfile(age: 33, baselineHR: 60.0))
        XCTAssertEqual(try store2.load().age, 33)
    }

    func test_separateDefaultsSuites_areIsolated() throws {
        let otherSuite = UserDefaults(suiteName: "com.panicguard.tests.other.\(UUID().uuidString)")!
        let otherStore = UserProfileStore(defaults: otherSuite)
        try sut.save(UserProfile(age: 22, baselineHR: 75.0))
        XCTAssertThrowsError(try otherStore.load()) { error in
            XCTAssertEqual(error as? UserProfileStoreError, .notFound)
        }
    }

    // MARK: - emergencyContact fields

    func test_saveAndLoad_withEmergencyContactPhone_roundTrip() throws {
        let profile = UserProfile(
            age: 30, baselineHR: 70.0,
            emergencyContactEnabled: true,
            emergencyContactPhone: "+14155550123"
        )
        try sut.save(profile)
        let loaded = try sut.load()
        XCTAssertEqual(loaded.emergencyContactEnabled, true)
        XCTAssertEqual(loaded.emergencyContactPhone, "+14155550123")
    }

    func test_saveAndLoad_nilEmergencyContactPhone_roundTrip() throws {
        let profile = UserProfile(age: 28, baselineHR: 68.0, emergencyContactEnabled: false)
        try sut.save(profile)
        let loaded = try sut.load()
        XCTAssertFalse(loaded.emergencyContactEnabled)
        XCTAssertNil(loaded.emergencyContactPhone)
    }
}
