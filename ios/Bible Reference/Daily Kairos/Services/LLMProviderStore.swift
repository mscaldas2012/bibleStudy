/// LLMProviderStore.swift
/// Observable singleton that manages saved LLM provider configs and the active provider.

import Foundation
import Observation

@Observable
final class LLMProviderStore {
    static let shared = LLMProviderStore()

    private let configsKey  = "llm_provider_configs_v1"
    private let activeIdKey = "llm_active_provider_id_v1"

    private(set) var configs:  [LLMProviderConfig] = []
    private(set) var activeId: UUID? = nil

    // MARK: - Derived

    var activeConfig: LLMProviderConfig? {
        configs.first { $0.id == activeId }
    }

    var activeProvider: any LLMProvider {
        guard let config = activeConfig else {
            return AppleFoundationProvider()
        }
        return makeProvider(for: config)
    }

    var activeDisplayName: String {
        activeConfig?.displayName ?? "On-Device AI (Default)"
    }

    // MARK: - Mutations

    func save(config: LLMProviderConfig, apiKey: String) {
        if !apiKey.isEmpty {
            KeychainService.saveKey(apiKey, forProvider: config.id.uuidString)
        }
        if let idx = configs.firstIndex(where: { $0.id == config.id }) {
            configs[idx] = config
        } else {
            configs.append(config)
        }
        persist()
    }

    func activate(_ id: UUID) {
        activeId = id
        persist()
    }

    func deactivate() {
        activeId = nil
        persist()
    }

    func remove(_ config: LLMProviderConfig) {
        KeychainService.deleteKey(forProvider: config.id.uuidString)
        configs.removeAll { $0.id == config.id }
        if activeId == config.id { activeId = nil }
        persist()
    }

    func loadKey(for config: LLMProviderConfig) -> String {
        KeychainService.loadKey(forProvider: config.id.uuidString) ?? ""
    }

    // MARK: - Factory

    func makeProvider(for config: LLMProviderConfig) -> any LLMProvider {
        let key = KeychainService.loadKey(forProvider: config.id.uuidString) ?? ""
        switch config.type {
        case .appleFoundation: return AppleFoundationProvider()
        case .anthropic:       return AnthropicProvider(config: config, apiKey: key)
        case .openAI:          return OpenAIProvider(config: config, apiKey: key)
        case .googleGemini:    return GoogleGeminiProvider(config: config, apiKey: key)
        case .custom:          return CustomProvider(config: config, apiKey: key)
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
        UserDefaults.standard.set(activeId?.uuidString, forKey: activeIdKey)
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let decoded = try? JSONDecoder().decode([LLMProviderConfig].self, from: data) {
            configs = decoded
        }
        if let str = UserDefaults.standard.string(forKey: activeIdKey) {
            activeId = UUID(uuidString: str)
        }
    }
}
