/// AppError.swift
/// Typed errors for the Bible Study app.

import Foundation

enum AppError: LocalizedError {
    case parseFailure(String)
    case esvMissingKey
    case esvNetworkError(String)
    case esvAuthError
    case esvNoPassage
    case modelUnavailable
    case modelGenerationFailed(String)
    case modelSafetyTriggered

    var errorDescription: String? {
        switch self {
        case .parseFailure(let msg):
            return msg
        case .esvMissingKey:
            return "ESV API key not configured. Add your key to Secrets.plist."
        case .esvNetworkError(let msg):
            return "Network error: \(msg)"
        case .esvAuthError:
            return "Invalid ESV API key. Check the value in Secrets.plist."
        case .esvNoPassage:
            return "The ESV API returned no text for that reference."
        case .modelUnavailable:
            return "Apple Intelligence is not available. Make sure it is enabled in Settings > Apple Intelligence & Siri, and that your iPad has an M1 or later chip."
        case .modelSafetyTriggered:
            return "The on-device model flagged this content — this is likely a beta issue with religious text. Please try again or file feedback at feedbackassistant.apple.com."
        case .modelGenerationFailed(let msg):
            return "Could not generate study notes: \(msg)"
        }
    }
}
