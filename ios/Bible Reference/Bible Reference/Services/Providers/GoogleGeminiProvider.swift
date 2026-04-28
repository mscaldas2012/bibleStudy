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

    // Disable all safety filters — Gemini blocks religious/biblical content by default,
    // which causes the `content` field to be absent from the response and silently
    // fails every Bible study call.
    private var safetySettings: [[String: Any]] {
        let categories = [
            "HARM_CATEGORY_HARASSMENT",
            "HARM_CATEGORY_HATE_SPEECH",
            "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "HARM_CATEGORY_DANGEROUS_CONTENT",
            "HARM_CATEGORY_CIVIC_INTEGRITY",
        ]
        return categories.map { ["category": $0, "threshold": "BLOCK_NONE"] }
    }

    func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        let urlStr = "\(baseURL)/v1beta/models/\(config.model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else {
            throw LLMError.httpError(0, "Invalid URL — check the model name and base URL.")
        }
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": [["text": userPrompt]]]],
            "safetySettings": safetySettings,
            "generationConfig": ["maxOutputTokens": 2048]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.safeData(for: req)
        let http = resp as! HTTPURLResponse
        guard http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw mapHTTPError(statusCode: http.statusCode, body: bodyStr, model: config.model)
        }

        // `content` is Optional — Gemini omits it when a safety filter fires.
        struct Resp: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content?       // absent on safety block
                let finishReason: String?
            }
            let candidates: [Candidate]?
            struct PromptFeedback: Decodable { let blockReason: String? }
            let promptFeedback: PromptFeedback?
        }

        let decoded = try JSONDecoder().decode(Resp.self, from: data)

        // Surface prompt-level blocks (e.g. the input itself was refused)
        if let reason = decoded.promptFeedback?.blockReason {
            throw LLMError.httpError(200, "Prompt blocked by Gemini safety filter: \(reason)")
        }

        guard let candidate = decoded.candidates?.first else {
            throw LLMError.httpError(200, "Gemini returned no candidates.")
        }

        // Surface candidate-level blocks
        if candidate.content == nil {
            let reason = candidate.finishReason ?? "unknown"
            throw LLMError.httpError(200, "Gemini content blocked (finishReason: \(reason)).")
        }

        return candidate.content?.parts.first?.text ?? ""
    }

    func verify() async throws -> String {
        // Test the specific model with a minimal real generation — confirms both
        // the key and that the chosen model ID is valid and accessible.
        do {
            let response = try await chat(
                systemPrompt: "You are a helpful assistant.",
                userPrompt: "Reply with exactly one word: hello"
            )
            guard !response.isEmpty else {
                throw LLMError.httpError(200, "Model returned an empty response.")
            }
            return "Connected — \(config.model) is working."
        } catch LLMError.modelNotFound {
            throw LLMError.httpError(404, "\"\(config.model)\" isn't available on your account yet. Try \"Gemini 2.5 Flash\" from the model picker — it works with most paid accounts.")
        }
    }

    func fetchAvailableModels() async throws -> [String] {
        let urlStr = "\(baseURL)/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return [] }
        let (data, resp) = try await URLSession.shared.safeData(for: URLRequest(url: url, timeoutInterval: 20))
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        struct ModelList: Decodable {
            struct Model: Decodable {
                let name: String
                let supportedGenerationMethods: [String]
            }
            let models: [Model]
        }
        let decoded = try JSONDecoder().decode(ModelList.self, from: data)
        return decoded.models
            .filter { $0.supportedGenerationMethods.contains("generateContent") }
            .map { $0.name.replacingOccurrences(of: "models/", with: "") }
            .filter { $0.hasPrefix("gemini") }
            .sorted()
    }
}
