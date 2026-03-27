/// GoogleGeminiProvider.swift
/// Google Gemini via the Generative Language API.

import Foundation

struct GoogleGeminiProvider: LLMProvider {
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
        config.baseURL.isEmpty
            ? "https://generativelanguage.googleapis.com"
            : config.baseURL
    }

    func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        let urlStr = "\(baseURL)/v1beta/models/\(config.model):generateContent?key=\(apiKey)"
        let url = URL(string: urlStr)!
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": [["text": userPrompt]]]],
            "generationConfig": ["maxOutputTokens": 1024]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw mapHTTPError(statusCode: http.statusCode, body: bodyStr, model: config.model)
        }

        struct Resp: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        let decoded = try JSONDecoder().decode(Resp.self, from: data)
        return decoded.candidates.first?.content.parts.first?.text ?? ""
    }

    func verify() async throws -> String {
        // GET /v1beta/models?key=<apiKey> — lists models, confirms auth
        let urlStr = "\(baseURL)/v1beta/models?key=\(apiKey)"
        let url = URL(string: urlStr)!
        let req = URLRequest(url: url, timeoutInterval: 20)

        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw mapHTTPError(statusCode: http.statusCode, body: bodyStr, model: config.model)
        }
        return "Connected to Google Gemini. Model: \(config.model)"
    }
}
