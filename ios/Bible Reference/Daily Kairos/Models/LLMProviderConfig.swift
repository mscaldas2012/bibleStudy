/// LLMProviderConfig.swift
/// Codable configuration for each saved LLM provider.

import Foundation

enum ProviderType: String, Codable, CaseIterable, Identifiable {
    case appleFoundation = "apple"
    case anthropic       = "anthropic"
    case openAI          = "openai"
    case googleGemini    = "google"
    case custom          = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleFoundation: return "On-Device AI (Apple)"
        case .anthropic:       return "Anthropic Claude"
        case .openAI:          return "OpenAI"
        case .googleGemini:    return "Google Gemini"
        case .custom:          return "Custom / Advanced"
        }
    }

    var systemIconName: String {
        switch self {
        case .appleFoundation: return "iphone"
        case .anthropic:       return "sparkles"
        case .openAI:          return "brain"
        case .googleGemini:    return "circle.hexagongrid"
        case .custom:          return "server.rack"
        }
    }

    var accentColorName: String {
        switch self {
        case .appleFoundation: return "blue"
        case .anthropic:       return "orange"
        case .openAI:          return "green"
        case .googleGemini:    return "blue"
        case .custom:          return "purple"
        }
    }
}

enum CustomProtocol: String, Codable, CaseIterable, Identifiable {
    case openAICompatible       = "openai"
    case anthropicCompatible    = "anthropic"
    case googleCompatible       = "google"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible:    return "OpenAI-compatible"
        case .anthropicCompatible: return "Anthropic-compatible"
        case .googleCompatible:    return "Google-compatible"
        }
    }

    var detail: String {
        switch self {
        case .openAICompatible:
            return "Most common — Groq, Together AI, Mistral, local LLMs, etc."
        case .anthropicCompatible:
            return "Providers that implement the Anthropic Messages API."
        case .googleCompatible:
            return "Providers that implement the Google Generative Language API."
        }
    }
}

struct LLMProviderConfig: Codable, Identifiable, Equatable {
    var id: UUID              = UUID()
    var type: ProviderType
    var displayName: String
    var model: String
    // OpenAI
    var orgId: String         = ""
    // Custom
    var baseURL: String       = ""
    var authHeaderName: String = "Authorization"   // used for custom providers
    var customProtocol: CustomProtocol = .openAICompatible
    var additionalModels: [String] = []
}
