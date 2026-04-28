/// LLMProvider.swift
/// Core protocol for LLM provider backends.
///
/// LIBRARY BOUNDARY — nothing in this file or the Providers/ folder should
/// import app-specific types (BibleReference, CrossRef, StudyNote, etc.).
/// That coupling lives in BibleLLMAdapter.swift (the app layer).
/// When extracting this as an SPM package, move:
///   Services/LLMProvider.swift
///   Services/LLMProviderStore.swift
///   Services/Providers/
///   Models/LLMProviderConfig.swift
///   Models/ProviderModels.swift
///   Views/LLMProviderSettingsView.swift
///   Views/*SetupView.swift

import Foundation

// MARK: - Error types

enum LLMError: LocalizedError {
    case invalidKey
    case noAccess(model: String)
    case rateLimited
    case networkTimeout
    case modelNotFound(String)
    case httpError(Int, String)
    case parseError
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "API key is invalid. Check the key and try again."
        case .noAccess(let model):
            return "Your account doesn't have access to \"\(model)\". Try a different model."
        case .rateLimited:
            return "Rate limit reached on your account. Wait a moment and try again."
        case .networkTimeout:
            return "Couldn't reach the provider. Check your connection."
        case .modelNotFound(let model):
            return "Model \"\(model)\" not found on this provider. Check the model name."
        case .httpError(_, let body) where !body.isEmpty:
            return body
        case .httpError(let code, _):
            return "Something went wrong (HTTP \(code)). Try again or choose a different model."
        case .parseError:
            return "Couldn't parse the response from the provider."
        case .notConfigured:
            return "No LLM provider is configured."
        }
    }

    var rawBody: String? {
        if case .httpError(_, let body) = self { return body }
        return nil
    }
}

// MARK: - Core protocol (library-safe, no app types)

/// A single LLM backend. All app-specific logic (Bible study prompts,
/// structured output types) belongs in the adapter layer, not here.
protocol LLMProvider: Sendable {
    var id: String { get }
    var displayName: String { get }

    /// Send a single chat turn. `systemPrompt` sets behavior/persona;
    /// `userPrompt` is the task. Returns the raw text response.
    func chat(systemPrompt: String, userPrompt: String) async throws -> String

    /// Perform a lightweight round-trip to confirm the key and model are valid.
    /// Returns a human-readable confirmation string on success.
    func verify() async throws -> String
}

// MARK: - Shared utilities (also library-safe)

/// Parse a JSON string into `T`, stripping markdown fences if present.
func parseProviderJSON<T: Decodable>(_ text: String, as type: T.Type) throws -> T {
    let decoder = JSONDecoder()

    // 1. Direct parse
    if let data = text.data(using: .utf8),
       let result = try? decoder.decode(type, from: data) { return result }

    // 2. Strip ```json … ``` fences
    let stripped = text
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if let data = stripped.data(using: .utf8),
       let result = try? decoder.decode(type, from: data) { return result }

    // 3. Extract first { … } block
    if let start = stripped.firstIndex(of: "{"),
       let end = stripped.lastIndex(of: "}") {
        let jsonStr = String(stripped[start...end])
        if let data = jsonStr.data(using: .utf8) {
            return try decoder.decode(type, from: data)
        }
    }
    throw LLMError.parseError
}

/// Map HTTP status codes to structured errors.
func mapHTTPError(statusCode: Int, body: String, model: String) -> LLMError {
    switch statusCode {
    case 401: return .invalidKey
    case 403: return .noAccess(model: model)
    case 404: return .modelNotFound(model)
    case 429: return .rateLimited
    default:  return .httpError(statusCode, body)
    }
}

// MARK: - URLSession helper

extension URLSession {
    /// Wraps `data(for:)`, converting timeout URLErrors to `LLMError.networkTimeout`.
    func safeData(for request: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await data(for: request) }
        catch let e as URLError where e.code == .timedOut { throw LLMError.networkTimeout }
        catch { throw LLMError.networkTimeout }
    }
}
