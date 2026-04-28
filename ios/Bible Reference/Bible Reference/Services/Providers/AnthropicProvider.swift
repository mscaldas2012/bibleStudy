/// AnthropicProvider.swift
/// Anthropic Claude via the Messages API.

import Foundation

struct AnthropicProvider: LLMProvider {
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

    func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        let baseURL = config.baseURL.isEmpty ? "https://api.anthropic.com" : config.baseURL
        let url = URL(string: "\(baseURL)/v1/messages")!
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue(apiKey,        forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",  forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model":      config.model,
            "max_tokens": 1024,
            "system":     systemPrompt,
            "messages":   [["role": "user", "content": userPrompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw mapHTTPError(statusCode: http.statusCode, body: bodyStr, model: config.model)
        }

        struct Resp: Decodable {
            struct Block: Decodable { let type: String; let text: String }
            let content: [Block]
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }

    func fetchAvailableModels() async throws -> [String] {
        let baseURL = config.baseURL.isEmpty ? "https://api.anthropic.com" : config.baseURL
        guard let url = URL(string: "\(baseURL)/v1/models") else { return [] }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue(apiKey,       forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, resp) = try await URLSession.shared.safeData(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        struct ModelList: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        let decoded = try JSONDecoder().decode(ModelList.self, from: data)
        return decoded.data
            .map(\.id)
            .filter { $0.hasPrefix("claude-") }
            .sorted()
    }

    func verify() async throws -> String {
        let baseURL = config.baseURL.isEmpty ? "https://api.anthropic.com" : config.baseURL
        let url = URL(string: "\(baseURL)/v1/messages")!
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue(apiKey,       forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model":      config.model,
            "max_tokens": 1,
            "messages":   [["role": "user", "content": "hi"]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw mapHTTPError(statusCode: http.statusCode, body: bodyStr, model: config.model)
        }
        return "Connected to Anthropic. Model: \(config.model)"
    }
}
