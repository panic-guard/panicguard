import Foundation

/// Step 2: wraps the on-device LLM to run a single-turn Gemma 4 triage.
/// All context (baseline, vocal anchor, risk ratio) is injected into one prompt by Swift;
/// the LLM produces one <answer> block — no multi-turn tool calling needed.
/// LiteRT-specific code lives in GemmaAgentLiteRTLM.swift.
final class GemmaAgent: PanicTriageAgentProtocol {

    // MARK: - Configuration

    struct Configuration {
        var maxTokens: Int = 4096
    }

    // MARK: - Error

    enum AgentError: LocalizedError {
        case modelNotFound(path: String)
        case engineInit(Error)
        case malformedResponse(String)

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let p):         return "Model file not found at: \(p)"
            case .engineInit(let e):            return "LLM engine init failed: \(e.localizedDescription)"
            case .malformedResponse(let r):     return "Malformed LLM response: \(r)"
            }
        }
    }

    // MARK: - Private state

    private let userProfileStore: UserProfileStoring
    private let sessionFactory: () async throws -> any LLMSessionProtocol
    /// Background task started by preload(); runTriage reuses its result.
    private var preloadTask: Task<(any LLMSessionProtocol)?, Never>?

    // MARK: - Init

    convenience init(
        modelPath: String,
        configuration: Configuration = .init(),
        userProfileStore: UserProfileStoring
    ) throws {
        let factory = try LiteRTLMSessionFactory(modelPath: modelPath, configuration: configuration)
        self.init(userProfileStore: userProfileStore, sessionFactory: factory.makeSession)
    }

    init(
        userProfileStore: UserProfileStoring,
        sessionFactory: @escaping () async throws -> any LLMSessionProtocol
    ) {
        self.userProfileStore = userProfileStore
        self.sessionFactory = sessionFactory
    }

    // MARK: - PanicTriageAgentProtocol

    /// Starts loading the LLM session in the background so runTriage can skip the ~5s engine load.
    /// Safe to call multiple times — subsequent calls are no-ops.
    func preload() async {
        guard preloadTask == nil else { return }
        let task = Task<(any LLMSessionProtocol)?, Never> { [sessionFactory] in
            try? await sessionFactory()
        }
        preloadTask = task
        _ = await task.value   // Block until session is ready so callers can rely on it.
    }

    func runTriage(
        features: HRFeaturePayload,
        vocalAnchor: VocalAnchorResult
    ) async throws -> TriageResult {
        let session = try await resolveSession()

        let profile = try? userProfileStore.load()
        let riskRatio: Double? = profile.flatMap { p in
            guard p.baselineHR > 0 else { return nil }
            return (features.currentHRMetrics.meanBPM / p.baselineHR * 100).rounded() / 100
        }

        let prompt = GemmaAgentPrompts.triagePrompt(context: .init(
            features: features,
            anchor: vocalAnchor,
            profile: profile,
            riskRatio: riskRatio
        ))

        print("[GemmaAgent] Prompt:\n\(prompt)")
        let response = try await session.sendMessage(prompt)
        print("[GemmaAgent] Raw response:\n\(response)")

        guard let answerJSON = parseAnswer(from: response) else {
            throw AgentError.malformedResponse(response)
        }
        guard let result = try? JSONDecoder().decode(TriageResult.self, from: Data(answerJSON.utf8)) else {
            throw AgentError.malformedResponse("Cannot decode TriageResult from: \(answerJSON)")
        }
        return result
    }

    // MARK: - Helpers

    private func resolveSession() async throws -> any LLMSessionProtocol {
        if let task = preloadTask {
            preloadTask = nil
            if let preloaded = await task.value {
                return preloaded
            }
            // Preload failed — fall through and try again.
        }
        return try await sessionFactory()
    }

    private func parseAnswer(from response: String) -> String? {
        let pattern = #"<answer>([\s\S]*?)</answer>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range(at: 1), in: response) else { return nil }
        return String(response[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
