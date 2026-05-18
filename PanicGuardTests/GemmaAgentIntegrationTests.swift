import XCTest
@testable import PanicGuard

// MARK: - Real-model integration tests
//
// These tests load the actual Gemma 4 E2B model and call the LLM.
// They are SKIPPED automatically unless the model is present in Bundle.main.
//ㅎ
// To run: xcodegen generate → Clean Build Folder (⇧⌘K) → Build (⌘B) → Test (⌘U).
// Expected runtime: 15–30 s per test (single-turn prompt — no multi-turn tool calling).

final class GemmaAgentIntegrationTests: XCTestCase {

    private var modelPath: String!
    private var store: MockUserProfileStoreForIntegration!
    private var storeWithVocalBaseline: MockProfileStoreWithVocalBaseline!

    override func setUp() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("LiteRTLM requires real Metal GPU — run on a physical device (iPhone 13 Pro+)")
        #endif

        guard let bundled = Bundle.main.path(forResource: "gemma-4-E2B-it", ofType: "litertlm") else {
            throw XCTSkip("Gemma model not found in app bundle — add gemma-4-E2B-it.litertlm to project resources")
        }
        modelPath = bundled
        store = MockUserProfileStoreForIntegration()
        storeWithVocalBaseline = MockProfileStoreWithVocalBaseline()
    }

    // MARK: - Strong panic signal: high HR + stationary + failed anchor

    func test_highHR_stationary_failedAnchor_returnsHighPanic() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: store)

        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 148, slopeBPMPerMin: 32),
            context: .init(isMoving: false, stepsLast5Min: 8)
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: nil   // recognition failed → strong panic signal
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "highHR_stationary_failedAnchor")

        XCTAssertGreaterThan(result.likelihoodPanic, 0.5,
            "High HR + stationary + failed vocal anchor should produce panic likelihood > 0.5")
        XCTAssertLessThanOrEqual(result.likelihoodPanic, 1.0)
    }

    // MARK: - Exercise signal: moderate HR + active movement + successful anchor

    func test_moderateHR_moving_successfulAnchor_returnsLowPanic() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: store)

        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 110, slopeBPMPerMin: 5),
            context: .init(isMoving: true, stepsLast5Min: 420)  // ~84 steps/min — jogging pace
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: "I am safe and this will pass"
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "moderateHR_moving_successfulAnchor")

        XCTAssertLessThan(result.likelihoodPanic, 0.5,
            "Moderate HR + active movement (84 steps/min) + successful anchor = exercise, not panic")
    }

    // MARK: - Ambiguous: high HR + stationary + successful anchor

    func test_highHR_stationary_successfulAnchor_returnsModerateSignal() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: store)

        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 140, slopeBPMPerMin: 25),
            context: .init(isMoving: false, stepsLast5Min: 10)
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: "I am safe and this will pass"  // user can speak — mixed signal
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "highHR_stationary_successfulAnchor")

        // HR and slope are alarming but anchor success tempers it.
        // Expect meaningful panic signal but not as high as failed anchor case.
        XCTAssertGreaterThan(result.likelihoodPanic, 0.2,
            "High HR + no movement should still register meaningful panic likelihood even with successful anchor")
        XCTAssertLessThan(result.likelihoodPanic, 0.9,
            "Successful anchor should temper panic likelihood below maximum")
    }

    // MARK: - Ambiguous: high HR + active movement + failed anchor

    func test_highHR_moving_failedAnchor_returnsElevatedSignal() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: store)

        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 155, slopeBPMPerMin: 28),
            context: .init(isMoving: true, stepsLast5Min: 180)  // ~36 steps/min — slow walk
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: nil  // failed despite some movement — concerning
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "highHR_moving_failedAnchor")

        // Very high HR + steep slope + failed anchor outweighs modest movement.
        XCTAssertGreaterThan(result.likelihoodPanic, 0.4,
            "Very high HR + steep slope + failed anchor should produce elevated panic signal even with some movement")
    }

    // MARK: - Near-baseline: low HR elevation + stationary + successful anchor

    func test_nearBaseline_stationary_successfulAnchor_returnsLowPanic() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: store)

        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 78, slopeBPMPerMin: 2),
            context: .init(isMoving: false, stepsLast5Min: 15)
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: "I am safe and this will pass"
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "nearBaseline_stationary_successfulAnchor")

        XCTAssertLessThan(result.likelihoodPanic, 0.4,
            "Near-baseline HR + flat slope + successful anchor should produce very low panic likelihood")
    }

    // MARK: - Cross-case: HR normal + vocal failed (new rule)
    //
    // New reasoning guide rule:
    //   "within expected range" + sedentary + recognition_failed: true → MODERATE (0.45–0.60)
    // At minimum this must clear the groundingExercise threshold (0.40) in RuleEngine.

    func test_normalHR_sedentary_failedAnchor_returnsModerateSignal() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: store)

        // HR 75 vs baseline 65, sedentary (2 steps/min) → within expected range (75 ≤ 65+25)
        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 75, slopeBPMPerMin: 2.0),
            context: .init(isMoving: false, stepsLast5Min: 10)
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: nil  // recognition_failed: true
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "normalHR_sedentary_failedAnchor")

        XCTAssertGreaterThanOrEqual(result.likelihoodPanic, 0.40,
            "Normal HR + failed vocal anchor should reach at least groundingExercise tier — new rule targets 0.45–0.60")
        XCTAssertLessThan(result.likelihoodPanic, 0.75,
            "Normal HR should not reach breathingGuide tier (reserved for HIGHER THAN EXPECTED HR cases)")
    }

    // MARK: - Cross-case: HR normal + significant WPM disruption (new rule)
    //
    // New reasoning guide rule:
    //   "within expected range" + sedentary + speaking rate ≥40% slower → LOW-MODERATE (0.35–0.50)
    // Uses a profile with baseline vocal metrics so the WPM comparison appears in the prompt.

    func test_normalHR_sedentary_significantWPMDisruption_returnsModerateSignal() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: storeWithVocalBaseline)

        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 75, slopeBPMPerMin: 2.0),
            context: .init(isMoving: false, stepsLast5Min: 10)
        )
        // WPM 70 vs baseline 140 → 50% of baseline (50% slower → significant disruption label)
        let vocalMetrics = VocalMetrics(
            speakingRateWPM: 70, maxPauseSeconds: 0.9,
            meanPauseSeconds: 0.4, totalPauseSeconds: 2.5, durationSeconds: 18.0
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: "i am safe and this will pass",
            vocalMetrics: vocalMetrics
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "normalHR_sedentary_significantWPMDisruption")

        XCTAssertGreaterThanOrEqual(result.likelihoodPanic, 0.30,
            "Normal HR + WPM 50% of baseline (significant disruption) should register meaningful signal — new rule targets 0.35–0.50")
        XCTAssertLessThan(result.likelihoodPanic, 0.70,
            "Vocal disruption alone with normal HR should not reach breathingGuide tier")
    }

    // MARK: - Regression: HR normal + clean vocal must stay low

    func test_normalHR_sedentary_cleanVocal_remainsLow() async throws {
        let agent = try GemmaAgent(modelPath: modelPath, userProfileStore: storeWithVocalBaseline)

        let features = HRFeaturePayload(
            currentHRMetrics: .init(meanBPM: 75, slopeBPMPerMin: 2.0),
            context: .init(isMoving: false, stepsLast5Min: 10)
        )
        // WPM 138 vs baseline 140 → 98% of baseline (similar to baseline label)
        let vocalMetrics = VocalMetrics(
            speakingRateWPM: 138, maxPauseSeconds: 0.22,
            meanPauseSeconds: 0.11, totalPauseSeconds: 0.4, durationSeconds: 6.5
        )
        let anchor = VocalAnchorResult(
            targetPhrase: "I am safe and this will pass",
            transcript: "I am safe and this will pass",
            vocalMetrics: vocalMetrics
        )

        let result = try await agent.runTriage(features: features, vocalAnchor: anchor)
        printResult(result, label: "normalHR_sedentary_cleanVocal")

        // New rules must not fire — calm scenario stays calm.
        XCTAssertLessThan(result.likelihoodPanic, 0.40,
            "Normal HR + clean vocal (similar WPM to baseline) must not trigger any intervention")
    }
}

// MARK: - Helpers

private extension GemmaAgentIntegrationTests {
    func printResult(_ result: TriageResult, label: String) {
        print("=== \(label) ===")
        print("  likelihoodPanic:           \(result.likelihoodPanic)")
        print("  likelihoodPhysicalAnomaly: \(result.likelihoodPhysicalAnomaly)")
        print("  confidence:                \(result.confidence)")
        print("  reasoning:                 \(result.reasoningSummary)")
    }
}

private final class MockUserProfileStoreForIntegration: UserProfileStoring {
    func save(_ profile: UserProfile) throws {}
    func load() throws -> UserProfile {
        UserProfile(age: 28, baselineHR: 65, emergencyContactEnabled: false)
    }
}

/// Profile store that includes a calm-state vocal baseline (WPM 140, short pauses).
/// Required for tests that verify "speaking rate vs baseline" comparison appears in the prompt.
private final class MockProfileStoreWithVocalBaseline: UserProfileStoring {
    func save(_ profile: UserProfile) throws {}
    func load() throws -> UserProfile {
        let vocalBaseline = VocalMetrics(
            speakingRateWPM: 140, maxPauseSeconds: 0.25,
            meanPauseSeconds: 0.12, totalPauseSeconds: 0.5, durationSeconds: 6.0
        )
        return UserProfile(age: 28, baselineHR: 65,
                           baselineVocalMetrics: vocalBaseline,
                           emergencyContactEnabled: false)
    }
}
