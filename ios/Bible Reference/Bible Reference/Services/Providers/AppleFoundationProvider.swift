/// AppleFoundationProvider.swift
/// Apple on-device AI via FoundationModels, wrapped as a plain LLMProvider.
///
/// Uses raw text generation (not @Generable structured output) so the interface
/// stays identical to REST providers — JSON is returned as text and parsed
/// by BibleLLMAdapter just like any other backend.

import Foundation
import FoundationModels

struct AppleFoundationProvider: LLMProvider {
    let id          = "apple.foundation"
    let displayName = "On-Device AI (Apple)"

    func chat(systemPrompt: String, userPrompt: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelUnavailable
        }
        let session = LanguageModelSession(instructions: systemPrompt)
        do {
            let response = try await session.respond(to: userPrompt)
            return response.content
        } catch let err as LanguageModelSession.GenerationError {
            if case .guardrailViolation = err {
                // Retry once with more neutral wording
                let neutral = LanguageModelSession(instructions: systemPrompt)
                do {
                    let retry = try await neutral.respond(to: userPrompt)
                    return retry.content
                } catch {
                    throw AppError.modelGenerationFailed(
                        "The on-device model blocked this content. Try again — it usually succeeds on a second attempt."
                    )
                }
            }
            throw AppError.modelGenerationFailed(err.localizedDescription)
        } catch {
            throw AppError.modelGenerationFailed(error.localizedDescription)
        }
    }

    func verify() async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelUnavailable
        }
        return "Apple Intelligence is available on this device."
    }
}
