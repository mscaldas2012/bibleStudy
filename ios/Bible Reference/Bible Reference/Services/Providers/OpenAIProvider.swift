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
            throw mapHTTPError(statusCode: http.statusCode, body: bodyStr, model: config.model)
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
        // GET /v1/models — lightweight auth check
        let url = URL(string: "\(baseURL)/v1/models")!
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if !config.orgId.isEmpty {
            req.setValue(config.orgId, forHTTPHeaderField: "OpenAI-Organization")
        }

        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw mapHTTPError(statusCode: http.statusCode, body: bodyStr, model: config.model)
        }
        return "Connected to OpenAI. Model: \(config.model)"
    }
}
