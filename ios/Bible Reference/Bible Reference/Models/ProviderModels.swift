/// ProviderModels.swift
/// Curated model lists for first-class providers.

import Foundation

enum AnthropicModels {
    static let curated: [(id: String, label: String)] = [
        ("claude-opus-4-5",    "Claude Opus 4.5"),
        ("claude-sonnet-4-5",  "Claude Sonnet 4.5"),
        ("claude-haiku-4-5",   "Claude Haiku 4.5"),
        ("claude-opus-3-7",    "Claude Opus 3.7"),
        ("claude-sonnet-3-7",  "Claude Sonnet 3.7"),
        ("claude-haiku-3-5",   "Claude Haiku 3.5"),
    ]
    static let defaultModel = "claude-sonnet-4-5"
}

enum OpenAIModels {
    static let curated: [(id: String, label: String)] = [
        ("gpt-4o",          "GPT-4o"),
        ("gpt-4o-mini",     "GPT-4o mini"),
        ("gpt-4-turbo",     "GPT-4 Turbo"),
        ("gpt-4",           "GPT-4"),
        ("gpt-3.5-turbo",   "GPT-3.5 Turbo"),
        ("o1",              "o1"),
        ("o1-mini",         "o1 mini"),
        ("o3-mini",         "o3 mini"),
    ]
    static let defaultModel = "gpt-4o-mini"
}

enum GoogleModels {
    /// Fallback list shown before the API key is entered
    static let curated: [(id: String, label: String)] = [
        ("gemini-2.5-flash",      "Gemini 2.5 Flash"),
        ("gemini-2.5-pro",        "Gemini 2.5 Pro"),
        ("gemini-2.0-flash",      "Gemini 2.0 Flash"),
        ("gemini-2.0-flash-lite", "Gemini 2.0 Flash Lite"),
        ("gemini-1.5-pro",        "Gemini 1.5 Pro"),
        ("gemini-1.5-flash",      "Gemini 1.5 Flash"),
    ]
    static let defaultModel = "gemini-2.5-flash"

    /// Preferred order for auto-selecting from a live model list
    private static let preference = [
        "gemini-2.5-flash", "gemini-2.5-pro",
        "gemini-2.0-flash", "gemini-2.0-flash-lite",
        "gemini-1.5-flash", "gemini-1.5-pro",
    ]

    /// Pick the best available model from a live list, falling back to the first entry
    static func preferredModel(from available: [String]) -> String {
        for preferred in preference {
            if available.contains(preferred) { return preferred }
        }
        return available.first ?? defaultModel
    }
}
