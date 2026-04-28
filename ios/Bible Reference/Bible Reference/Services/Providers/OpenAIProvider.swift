/// OpenAIProvider.swift
/// OpenAI (and OpenAI-compatible) chat completions.

import Foundation

struct OpenAIProvider: LLMProvider {
    let id: String
    let displayName: String
    let config: LLMProviderConfig
    private let apiKey: String

    init(config: LLMProviderConfig, apiKey: String) {
        self.config      = config
        self.apiKey      = apiKey
        self.id          = config.id.uuidString
        self.displayName = config.displayName
    }

    private var baseURL: String {
        config.baseURL.isEmpty ? "https://api.openai.com" : config.baseURL
    }

    func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        if !config.orgId.isEmpty {
            req.setValue(config.orgId, forHTTPHeaderField: "OpenAI-Organization")
        }

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 1024,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw mapOpenAIError(statusCode: http.statusCode, body: bodyStr)
        }

        struct Resp: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    func verify() async throws -> String {
        // Real generation test — confirms key, model, and billing are all working
        let response = try await chat(
            systemPrompt: "You are a helpful assistant.",
            userPrompt: "Reply with exactly one word: hello"
        )
        guard !response.isEmpty else {
            throw LLMError.httpError(200, "Model returned an empty response.")
        }
        return "Connected — \(config.model) is working."
    }

    // MARK: - Available models

    func fetchAvailableModels() async throws -> [String] {
        let url = URL(string: "\(baseURL)/v1/models")!
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if !config.orgId.isEmpty {
            req.setValue(config.orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        let (data, resp) = try await URLSession.shared.safeData(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        struct ModelList: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        let decoded = try JSONDecoder().decode(ModelList.self, from: data)
        // Keep only chat-completion-capable models
        return decoded.data
            .map(\.id)
            .filter { id in
                id.hasPrefix("gpt-") || id.hasPrefix("o1") ||
                id.hasPrefix("o3") || id.hasPrefix("chatgpt-")
            }
            .sorted()
    }

    // MARK: - OpenAI-specific error parsing

    /// OpenAI encodes the real reason in the error body — insufficient_quota looks
    /// like a 429 but is a billing issue, not a rate limit.
    private func mapOpenAIError(statusCode: Int, body: String) -> LLMError {
        struct OAIError: Decodable {
            struct Inner: Decodable { let code: String?; let message: String? }
            let error: Inner
        }
        if let data = body.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(OAIError.self, from: data) {
            switch parsed.error.code {
            case "insufficient_quota":
                return .httpError(statusCode, "Your OpenAI account has no credits. Add funds at platform.openai.com/settings/billing.")
            case "invalid_api_key":
                return .invalidKey
            case "model_not_found":
                return .modelNotFound(config.model)
            default:
                break
            }
        }
        return mapHTTPError(statusCode: statusCode, body: body, model: config.model)
    }
}
