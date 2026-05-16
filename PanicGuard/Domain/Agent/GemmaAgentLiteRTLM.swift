// Migrated from MediaPipe LLM Inference API to LiteRTLM-Swift-SDK.
// When the official Google LiteRT LM Swift SDK ships, swap this file for the
// official implementation that satisfies LLMSessionProtocol.
// Track: https://github.com/google-ai-edge/LiteRT-LM (Swift: "Coming Soon")
import Foundation
import LiteRTLM

// MARK: - Session wrapper

/// Wraps LMConversation behind LLMSessionProtocol.
/// Holds the engine to keep it alive for the duration of the triage session.
private final class LiteRTConversationWrapper: LLMSessionProtocol {
    private let engine: LMEngine
    private let conversation: LMConversation

    init(engine: LMEngine, conversation: LMConversation) {
        self.engine = engine
        self.conversation = conversation
    }

    deinit {
        conversation.close()
    }

    func sendMessage(_ text: String) async throws -> String {
        try await conversation.send(text)
    }
}

// MARK: - Session factory

struct LiteRTLMSessionFactory {
    private let modelURL: URL
    private let configuration: GemmaAgent.Configuration

    init(modelPath: String, configuration: GemmaAgent.Configuration) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw GemmaAgent.AgentError.modelNotFound(path: modelPath)
        }
        self.modelURL = URL(fileURLWithPath: modelPath)
        self.configuration = configuration
    }

    func makeSession() async throws -> any LLMSessionProtocol {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("litertlm_cache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let engineConfig = EngineConfiguration(modelPath: modelURL)
            .backend(.cpu)
            .visionBackend(.cpu)
            .audioBackend(.cpu)
            .maxTokens(configuration.maxTokens)
            .cacheDirectory(cacheDir)
            .logLevel(.info)

        print("[LiteRTLM] Loading model from: \(modelURL.path)")
        print("[LiteRTLM] Model file exists: \(FileManager.default.fileExists(atPath: modelURL.path))")
        print("[LiteRTLM] Model file size: \((try? FileManager.default.attributesOfItem(atPath: modelURL.path)[.size] as? Int) ?? 0)")
        let engine = LMEngine(configuration: engineConfig)
        do {
            try await engine.load()
        } catch {
            print("[LiteRTLM] Engine load failed: \(error)")
            throw GemmaAgent.AgentError.engineInit(error)
        }

        let conversationConfig = ConversationConfiguration()
            .sampler(.creative)
            .maxOutputTokens(512)
        let conversation = try await engine.createConversation(configuration: conversationConfig)
        return LiteRTConversationWrapper(engine: engine, conversation: conversation)
    }
}
