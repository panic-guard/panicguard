import XCTest
@testable import PanicGuard

final class VocalAnchorManagerTests: XCTestCase {

    // MARK: - Protocol conformance

    func test_protocol_conformance() {
        let _: any VocalAnchorManaging = VocalAnchorManager()
    }

    // MARK: - Mock captureAnchor contract

    func test_mock_captureAnchor_preservesTargetPhrase() async throws {
        let result = try await MockVocalAnchorManager(transcript: "hello").captureAnchor(phrase: "The morning light", timeout: 5)
        XCTAssertEqual(result.targetPhrase, "The morning light")
    }

    func test_mock_captureAnchor_returnsConfiguredTranscript() async throws {
        let result = try await MockVocalAnchorManager(transcript: "soft breath soft sky").captureAnchor(phrase: "Soft breath", timeout: 5)
        XCTAssertEqual(result.transcript, "soft breath soft sky")
    }

    func test_mock_captureAnchor_returnsNilTranscript_whenConfiguredWithNil() async throws {
        let result = try await MockVocalAnchorManager(transcript: nil).captureAnchor(phrase: "Test", timeout: 5)
        XCTAssertNil(result.transcript)
    }

    func test_mock_captureAnchor_preservesVocalMetrics() async throws {
        let metrics = VocalMetrics(
            speakingRateWPM: 138, maxPauseSeconds: 0.28,
            meanPauseSeconds: 0.11, totalPauseSeconds: 0, durationSeconds: 5.2
        )
        let result = try await MockVocalAnchorManager(transcript: "calm reading", metrics: metrics)
            .captureAnchor(phrase: "Test", timeout: 5)
        XCTAssertEqual(result.vocalMetrics, metrics)
    }

    func test_mock_captureAnchor_returnsNilMetrics_whenConfiguredWithNil() async throws {
        let result = try await MockVocalAnchorManager(transcript: "hello", metrics: nil)
            .captureAnchor(phrase: "Test", timeout: 5)
        XCTAssertNil(result.vocalMetrics)
    }

    // MARK: - Mock recognize contract

    func test_mock_recognize_preservesTargetPhrase() async {
        let result = await MockVocalAnchorManager(transcript: "still").recognize(phrase: "The water is still", url: URL(fileURLWithPath: "/dummy.m4a"))
        XCTAssertEqual(result.targetPhrase, "The water is still")
    }

    func test_mock_recognize_returnsConfiguredTranscript() async {
        let result = await MockVocalAnchorManager(transcript: "this moment is enough").recognize(phrase: "This moment", url: URL(fileURLWithPath: "/dummy.m4a"))
        XCTAssertEqual(result.transcript, "this moment is enough")
    }

    func test_mock_recognize_preservesVocalMetrics() async {
        let metrics = VocalMetrics(
            speakingRateWPM: 55, maxPauseSeconds: 2.8,
            meanPauseSeconds: 1.2, totalPauseSeconds: 5.1, durationSeconds: 14.3
        )
        let result = await MockVocalAnchorManager(transcript: "slow speech", metrics: metrics)
            .recognize(phrase: "Test", url: URL(fileURLWithPath: "/dummy.m4a"))
        XCTAssertEqual(result.vocalMetrics, metrics)
    }

    // MARK: - Scenario: calm baseline vs panic state

    func test_calmBaselineMetrics_hasNormalWPMAndLowPauses() {
        // Represents expected output from onboarding calibration in a relaxed state.
        let calm = VocalMetrics(
            speakingRateWPM: 138, maxPauseSeconds: 0.28,
            meanPauseSeconds: 0.11, totalPauseSeconds: 0.0, durationSeconds: 5.2
        )
        XCTAssertTrue((100..<170).contains(Int(calm.speakingRateWPM)), "Calm WPM should be in the normal range (100–170)")
        XCTAssertLessThan(calm.maxPauseSeconds, 0.5, "Calm reading should have no significant pauses")
        XCTAssertEqual(calm.totalPauseSeconds, 0.0, "Calm reading should have zero hesitation time")
    }

    func test_panicStateMetrics_hasVerySlowWPMAndLongPauses() {
        // Represents expected output during a panic episode — difficulty speaking.
        let panic = VocalMetrics(
            speakingRateWPM: 55, maxPauseSeconds: 2.8,
            meanPauseSeconds: 1.2, totalPauseSeconds: 5.1, durationSeconds: 14.3
        )
        XCTAssertLessThan(panic.speakingRateWPM, 60, "Panic WPM should be very slow (< 60)")
        XCTAssertGreaterThan(panic.maxPauseSeconds, 1.5, "Panic state should show long hesitation pauses")
        XCTAssertGreaterThan(panic.totalPauseSeconds, 3.0, "Panic state should accumulate significant hesitation time")
    }

    func test_mildAnxietyMetrics_hasSlowWPMAndModeratePauses() {
        // Mild anxiety: slightly slower than normal, occasional notable pauses.
        let mild = VocalMetrics(
            speakingRateWPM: 88, maxPauseSeconds: 0.9,
            meanPauseSeconds: 0.35, totalPauseSeconds: 1.2, durationSeconds: 7.8
        )
        XCTAssertTrue((60..<100).contains(Int(mild.speakingRateWPM)), "Mild anxiety WPM should be in the slow range (60–100)")
        XCTAssertTrue(mild.maxPauseSeconds >= 0.5 && mild.maxPauseSeconds < 1.5, "Mild anxiety should show moderate pauses")
    }

    func test_rushingMetrics_hasFastWPMAndTinyPauses() {
        // Anxious rushing: speaking very fast with minimal pauses.
        let rushing = VocalMetrics(
            speakingRateWPM: 185, maxPauseSeconds: 0.08,
            meanPauseSeconds: 0.04, totalPauseSeconds: 0.0, durationSeconds: 3.1
        )
        XCTAssertGreaterThan(rushing.speakingRateWPM, 170, "Rushing WPM should exceed the normal ceiling (170)")
        XCTAssertLessThan(rushing.maxPauseSeconds, 0.5, "Rushing speech has no significant pauses")
    }

    // MARK: - recognize() with pre-recorded file
    //
    // Drop a recording named "test_anchor.m4a" into PanicGuardTests/ and add it to the
    // PanicGuardTests target in Xcode. Tests are skipped automatically when the file is absent.

    func test_recognize_withBundledFile_preservesPhrase() async throws {
        guard let url = Bundle(for: VocalAnchorManagerTests.self).url(forResource: "test_anchor", withExtension: "m4a") else {
            throw XCTSkip("test_anchor.m4a not in test bundle")
        }
        let result = await VocalAnchorManager().recognize(phrase: "The morning light", url: url)
        XCTAssertEqual(result.targetPhrase, "The morning light")
    }

    func test_recognize_withBundledFile_returnsNonNilTranscript() async throws {
        guard let url = Bundle(for: VocalAnchorManagerTests.self).url(forResource: "test_anchor", withExtension: "m4a") else {
            throw XCTSkip("test_anchor.m4a not in test bundle")
        }
        let result = await VocalAnchorManager().recognize(phrase: "The morning light", url: url)
        XCTAssertNotNil(result.transcript, "Pre-recorded file should produce a non-nil transcript")
    }

    func test_recognize_withBundledFile_hasVocalMetricsWhenSpeechDetected() async throws {
        guard let url = Bundle(for: VocalAnchorManagerTests.self).url(forResource: "test_anchor", withExtension: "m4a") else {
            throw XCTSkip("test_anchor.m4a not in test bundle")
        }
        let result = await VocalAnchorManager().recognize(phrase: "The morning light", url: url)
        if result.transcript != nil {
            XCTAssertNotNil(result.vocalMetrics, "Successful speech recognition should produce vocal metrics")
        }
    }

    // MARK: - recognize() with invalid URL

    func test_recognize_withInvalidURL_returnsNilTranscript() async {
        let result = await VocalAnchorManager().recognize(phrase: "Test", url: URL(fileURLWithPath: "/nonexistent/audio.m4a"))
        XCTAssertNil(result.transcript)
    }

    func test_recognize_withInvalidURL_preservesPhrase() async {
        let result = await VocalAnchorManager().recognize(phrase: "Soft breath", url: URL(fileURLWithPath: "/nonexistent/audio.m4a"))
        XCTAssertEqual(result.targetPhrase, "Soft breath")
    }

    func test_recognize_withInvalidURL_returnsNilMetrics() async {
        let result = await VocalAnchorManager().recognize(phrase: "Test", url: URL(fileURLWithPath: "/nonexistent/audio.m4a"))
        XCTAssertNil(result.vocalMetrics)
    }

    // MARK: - VocalAnchorResult equality

    func test_vocalAnchorResult_equalWhenAllFieldsMatch() {
        let metrics = VocalMetrics(speakingRateWPM: 138, maxPauseSeconds: 0.28, meanPauseSeconds: 0.11, totalPauseSeconds: 0, durationSeconds: 5.2)
        let a = VocalAnchorResult(targetPhrase: "Hello", transcript: "hello", vocalMetrics: metrics)
        let b = VocalAnchorResult(targetPhrase: "Hello", transcript: "hello", vocalMetrics: metrics)
        XCTAssertEqual(a, b)
    }

    func test_vocalAnchorResult_notEqual_whenMetricsDiffer() {
        let calm = VocalMetrics(speakingRateWPM: 138, maxPauseSeconds: 0.28, meanPauseSeconds: 0.11, totalPauseSeconds: 0, durationSeconds: 5.2)
        let panic = VocalMetrics(speakingRateWPM: 55, maxPauseSeconds: 2.8, meanPauseSeconds: 1.2, totalPauseSeconds: 5.1, durationSeconds: 14.3)
        let a = VocalAnchorResult(targetPhrase: "A", transcript: "a", vocalMetrics: calm)
        let b = VocalAnchorResult(targetPhrase: "A", transcript: "a", vocalMetrics: panic)
        XCTAssertNotEqual(a, b)
    }

    func test_vocalAnchorResult_nilTranscript_notEqualToEmpty() {
        XCTAssertNotEqual(
            VocalAnchorResult(targetPhrase: "A", transcript: nil),
            VocalAnchorResult(targetPhrase: "A", transcript: "")
        )
    }

    // MARK: - Real manager on simulator (no mic → nil transcript, nil metrics)

    func test_captureAnchor_onSimulator_returnsNilTranscriptAndNilMetrics() async throws {
        #if targetEnvironment(simulator)
        let result = try await VocalAnchorManager().captureAnchor(phrase: "Test", timeout: 1)
        XCTAssertEqual(result.targetPhrase, "Test")
        XCTAssertNil(result.transcript)
        XCTAssertNil(result.vocalMetrics)
        #endif
    }
}

// MARK: - MockVocalAnchorManager

private final class MockVocalAnchorManager: VocalAnchorManaging {
    private let fixedTranscript: String?
    private let fixedMetrics: VocalMetrics?

    init(transcript: String?, metrics: VocalMetrics? = nil) {
        fixedTranscript = transcript
        fixedMetrics = metrics
    }

    func captureAnchor(phrase: String, timeout: TimeInterval) async throws -> VocalAnchorResult {
        VocalAnchorResult(targetPhrase: phrase, transcript: fixedTranscript, vocalMetrics: fixedMetrics)
    }

    func recognize(phrase: String, url: URL) async -> VocalAnchorResult {
        VocalAnchorResult(targetPhrase: phrase, transcript: fixedTranscript, vocalMetrics: fixedMetrics)
    }
}
