import XCTest
@testable import PanicGuard

// MARK: - Mock

final class MockLLMSession: LLMSessionProtocol {
    var responses: [String]
    private(set) var callCount = 0
    private(set) var receivedMessages: [String] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func sendMessage(_ text: String) async throws -> String {
        receivedMessages.append(text)
        defer { callCount += 1 }
        guard callCount < responses.count else {
            throw GemmaAgent.AgentError.malformedResponse("mock exhausted at call \(callCount)")
        }
        return responses[callCount]
    }
}

final class MockUserProfileStore: UserProfileStoring {
    var profile: UserProfile?

    func save(_ profile: UserProfile) throws { self.profile = profile }

    func load() throws -> UserProfile {
        guard let p = profile else { throw NSError(domain: "mock", code: 1) }
        return p
    }
}

// MARK: - Helpers

private func makeAgent(
    responses: [String],
    profile: UserProfile = .init(age: 30, baselineHR: 72, emergencyContactEnabled: false)
) -> (GemmaAgent, MockLLMSession) {
    let store = MockUserProfileStore()
    store.profile = profile
    let session = MockLLMSession(responses: responses)
    let agent = GemmaAgent(userProfileStore: store, sessionFactory: { session })
    return (agent, session)
}

private func makeFeatures(meanBPM: Double = 145, slope: Double = 30, isMoving: Bool = false, stepsLast5Min: Int = 12) -> HRFeaturePayload {
    HRFeaturePayload(
        currentHRMetrics: .init(meanBPM: meanBPM, slopeBPMPerMin: slope),
        context: .init(isMoving: isMoving, stepsLast5Min: stepsLast5Min)
    )
}

private func makeAnchor(transcript: String? = "I am safe right now") -> VocalAnchorResult {
    VocalAnchorResult(targetPhrase: "I am safe right now", transcript: transcript)
}

private func panicAnswer(likelihood: Double = 0.85) -> String {
    "<answer>{\"likelihoodPanic\":\(likelihood),\"likelihoodPhysicalAnomaly\":0.10,\"confidence\":\"high\",\"reasoningSummary\":\"Test.\"}</answer>"
}

private func moderateAnswer(likelihood: Double = 0.50) -> String {
    "<answer>{\"likelihoodPanic\":\(likelihood),\"likelihoodPhysicalAnomaly\":0.05,\"confidence\":\"medium\",\"reasoningSummary\":\"Test.\"}</answer>"
}

// MARK: - Tests

final class GemmaAgentTests: XCTestCase {

    // Single prompt → single LLM call → TriageResult
    func test_singleTurn_returnsTriageResult() async throws {
        let (agent, session) = makeAgent(responses: [panicAnswer(likelihood: 0.85)])

        let result = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor())

        XCTAssertEqual(session.callCount, 1, "Must be exactly one LLM call")
        XCTAssertEqual(result.likelihoodPanic, 0.85, accuracy: 0.001)
        XCTAssertEqual(result.confidence, .high)
    }

    // HR values must appear in the prompt so the LLM can reason about them.
    func test_hrFeatures_appearsInPrompt() async throws {
        let (agent, session) = makeAgent(responses: [panicAnswer()])

        _ = try await agent.runTriage(features: makeFeatures(meanBPM: 148, slope: 32), vocalAnchor: makeAnchor())

        let prompt = session.receivedMessages[0]
        XCTAssertTrue(prompt.contains("148"), "Prompt must contain current mean HR")
        XCTAssertTrue(prompt.contains("32"), "Prompt must contain HR slope")
    }

    // When ASR fails the prompt must signal speech_recognized: false.
    func test_vocalAnchorFailed_promptSignalsRecognitionFailed() async throws {
        let (agent, session) = makeAgent(responses: [panicAnswer(likelihood: 0.92)])

        _ = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor(transcript: nil))

        let prompt = session.receivedMessages[0]
        XCTAssertTrue(prompt.contains("speech_recognized: false"), "Prompt must flag recognition failure")
        // Note: the guide section of the prompt also uses "speech_recognized: true" as explanatory text,
        // so we only assert the presence of the true signal, not the absence of the false string.
    }

    // Successful anchor match must appear in the prompt as speech_recognized: true.
    func test_vocalAnchorSucceeded_promptSignalsRecognitionSucceeded() async throws {
        let (agent, session) = makeAgent(responses: [panicAnswer(likelihood: 0.2)])

        _ = try await agent.runTriage(
            features: makeFeatures(),
            vocalAnchor: makeAnchor(transcript: "I am safe right now")
        )

        let prompt = session.receivedMessages[0]
        XCTAssertTrue(prompt.contains("speech_recognized: true"))
    }

    // Missing user profile → prompt reflects unavailability, result uses low confidence.
    func test_missingProfile_promptReflectsUnavailable() async throws {
        let store = MockUserProfileStore()  // profile = nil
        let session = MockLLMSession(responses: [
            "<answer>{\"likelihoodPanic\":0.5,\"likelihoodPhysicalAnomaly\":0.2,\"confidence\":\"low\",\"reasoningSummary\":\"No baseline.\"}</answer>"
        ])
        let agent = GemmaAgent(userProfileStore: store, sessionFactory: { session })

        let result = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor())

        XCTAssertTrue(session.receivedMessages[0].contains("unavailable"),
                      "Prompt must mention that baseline is unavailable")
        XCTAssertEqual(result.confidence, .low)
    }

    // No <answer> tag → throws malformedResponse.
    func test_noAnswerTag_throwsMalformedResponse() async throws {
        let (agent, _) = makeAgent(responses: ["This response has no answer tag"])

        do {
            _ = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor())
            XCTFail("Expected AgentError.malformedResponse")
        } catch GemmaAgent.AgentError.malformedResponse {
            // expected
        }
    }

    // <answer> contains invalid JSON → throws malformedResponse.
    func test_malformedAnswerJSON_throwsMalformedResponse() async throws {
        let (agent, _) = makeAgent(responses: ["<answer>NOT VALID JSON</answer>"])

        do {
            _ = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor())
            XCTFail("Expected AgentError.malformedResponse")
        } catch GemmaAgent.AgentError.malformedResponse {
            // expected
        }
    }

    // preload() causes sessionFactory to be called early; runTriage reuses the session.
    func test_preload_sessionIsReusedInRunTriage() async throws {
        var factoryCalls = 0
        let store = MockUserProfileStore()
        store.profile = .init(age: 30, baselineHR: 72, emergencyContactEnabled: false)
        let agent = GemmaAgent(
            userProfileStore: store,
            sessionFactory: {
                factoryCalls += 1
                return MockLLMSession(responses: [panicAnswer()])
            }
        )

        await agent.preload()
        XCTAssertEqual(factoryCalls, 1, "preload() must call sessionFactory once")

        _ = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor())
        XCTAssertEqual(factoryCalls, 1, "runTriage must reuse the preloaded session")
    }

    // Without preload, sessionFactory is still called once inside runTriage.
    func test_withoutPreload_sessionFactoryCalledOnce() async throws {
        var factoryCalls = 0
        let store = MockUserProfileStore()
        store.profile = .init(age: 30, baselineHR: 72, emergencyContactEnabled: false)
        let agent = GemmaAgent(
            userProfileStore: store,
            sessionFactory: {
                factoryCalls += 1
                return MockLLMSession(responses: [panicAnswer()])
            }
        )

        _ = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor())
        XCTAssertEqual(factoryCalls, 1)
    }

    // MARK: - Cross-case: HR normal + vocal failed / disrupted

    // When HR is in normal range but vocal anchor fails, the prompt must carry both signals
    // so the LLM can apply the new "within expected range + speech_recognized: false" rule.
    func test_hrNormalVocalFailed_promptContainsBothSignals() async throws {
        let (agent, session) = makeAgent(
            responses: [moderateAnswer(likelihood: 0.50)],
            profile: .init(age: 30, baselineHR: 53, emergencyContactEnabled: false)
        )
        let normalFeatures = makeFeatures(meanBPM: 61, slope: 2.0, stepsLast5Min: 5)

        _ = try await agent.runTriage(features: normalFeatures, vocalAnchor: makeAnchor(transcript: nil))

        let prompt = session.receivedMessages[0]
        XCTAssertTrue(prompt.contains("within expected range"),
                      "HR 61 vs baseline 53 sedentary must be labelled within expected range")
        XCTAssertTrue(prompt.contains("speech_recognized: false"),
                      "Nil transcript must flag recognition failure in the prompt")
    }

    // Moderate panic likelihood (0.50) from mock LLM must decode correctly.
    // Ensures the new target range (0.45–0.60) round-trips through JSON parsing.
    func test_moderatePanicLikelihood_decodesCorrectly() async throws {
        let (agent, _) = makeAgent(responses: [moderateAnswer(likelihood: 0.50)])

        let result = try await agent.runTriage(features: makeFeatures(), vocalAnchor: makeAnchor())

        XCTAssertEqual(result.likelihoodPanic, 0.50, accuracy: 0.001)
        XCTAssertEqual(result.confidence, .medium)
    }
}
