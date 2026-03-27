/// CustomProvider.swift
/// Custom / advanced provider — delegates to the appropriate REST protocol implementation.

import Foundation

struct CustomProvider: LLMProvider {
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
        switch config.customProtocol {
        case .openAICompatible:
            return try await openAIChat(systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .anthropicCompatible:
            return try await anthropicChat(systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .googleCompatible:
            return try await googleChat(systemPrompt: systemPrompt, userPrompt: userPrompt)
        }
    }

    func verify() async throws -> String {
        // Quick 1-token completion to verify connectivity
        _ = try await chat(systemPrompt: "Respond with exactly the word OK.", userPrompt: "hi")
        return "Connected to \(config.displayName). Model: \(config.model)"
    }

    // MARK: - OpenAI-compatible

    private func openAIChat(systemPrompt: String, userPrompt: String) async throws -> String {
        let base = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        let url = URL(string: "\(base)/chat/completions")!
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        applyAuth(&req)

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
            throw mapHTTPError(statusCode: http.statusCode,
                               body: String(data: data, encoding: .utf8) ?? "",
                               model: config.model)
        }
        struct Resp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }
            let choices: [Choice]
        }
        return (try JSONDecoder().decode(Resp.self, from: data)).choices.first?.message.content ?? ""
    }

    // MARK: - Anthropic-compatible

    private func anthropicChat(systemPrompt: String, userPrompt: String) async throws -> String {
        let base = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        let url = URL(string: "\(base)/v1/messages")!
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        applyAuth(&req)

        let body: [String: Any] = [
            "model": config.model, "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userPrompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw mapHTTPError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "", model: config.model)
        }
        struct Resp: Decodable { struct Block: Decodable { let type: String; let text: String }; let content: [Block] }
        return (try JSONDecoder().decode(Resp.self, from: data)).content.first(where: { $0.type == "text" })?.text ?? ""
    }

    // MARK: - Google-compatible

    private func googleChat(systemPrompt: String, userPrompt: String) async throws -> String {
        let base = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        let urlStr = "\(base)/v1beta/models/\(config.model):generateContent"
        let url = URL(string: urlStr)!
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        applyAuth(&req)

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": [["text": userPrompt]]]],
            "generationConfig": ["maxOutputTokens": 1024]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            throw mapHTTPError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "", model: config.model)
        }
        struct Resp: Decodable {
            struct Cand: Decodable { struct Con: Decodable { struct Part: Decodable { let text: String }; let parts: [Part] }; let content: Con }
            let candidates: [Cand]
        }
        return (try JSONDecoder().decode(Resp.self, from: data)).candidates.first?.content.parts.first?.text ?? ""
    }

    // MARK: - Auth injection

    private func applyAuth(_ req: inout URLRequest) {
        guard !apiKey.isEmpty else { return }
        let header = config.authHeaderName.isEmpty ? "Authorization" : config.authHeaderName
        if header == "Authorization" {
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: header)
        } else {
            req.setValue(apiKey, forHTTPHeaderField: header)
        }
    }
}
