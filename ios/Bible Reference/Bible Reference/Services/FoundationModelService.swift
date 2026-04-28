/// FoundationModelService.swift
/// Generates passage context, applications, historical background, and
/// cross-reference explanations using Apple Foundation Models.
/// Each section is a separate model call so results can appear progressively.
/// Requires iPadOS 26+ with Apple Intelligence enabled on M1+ hardware.

import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BibleReference", category: "FoundationModelService")

// MARK: - Guardrail detection helper

private extension LanguageModelSession.GenerationError {
    /// Returns true when the error is a safety guardrail violation.
    var isGuardrail: Bool {
        if case .guardrailViolation = self { return true }
        return false
    }
}

actor FoundationModelService {

    // Neutral wording avoids triggering beta safety guardrails on religious content.
    private let instructions = """
        You are a knowledgeable assistant specializing in ancient literature, \
        history, and philosophy. Analyze texts by explaining their historical \
        setting, literary context, and timeless wisdom.
        """

    // MARK: - Section 1: Context + Applications

    func analyzeContext(
        reference: BibleReference,
        verseText: String?
    ) async throws -> ContextAndApplications {
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelUnavailable
        }
        let session = LanguageModelSession(instructions: instructions)
        let prompt = basePrompt(reference: reference, verseText: verseText)
        do {
            let result = try await session.respond(to: prompt, generating: ContextAndApplications.self).content
            logger.debug("analyzeContext succeeded for \(reference.displayTitle): context=\(result.context.count) chars, applications=\(result.applications.count)")
            guard !result.context.isEmpty else {
                logger.error("analyzeContext returned empty context for \(reference.displayTitle) — treating as failure")
                throw AppError.modelGenerationFailed("Model returned empty content for \(reference.displayTitle). The passage may be too long for the on-device model.")
            }
            return result
        } catch let error as LanguageModelSession.GenerationError where error.isGuardrail {
            logger.warning("analyzeContext guardrail hit for \(reference.displayTitle), retrying with neutral prompt")
            return try await retry(
                prompt: "Describe the literary context and key lessons of the ancient text \(reference.displayTitle).",
                generating: ContextAndApplications.self
            )
        } catch {
            logger.error("analyzeContext failed for \(reference.displayTitle): \(error)")
            throw AppError.modelGenerationFailed(error.localizedDescription)
        }
    }

    // MARK: - Section 2: Historical Background

    func analyzeHistory(
        reference: BibleReference,
        verseText: String?
    ) async throws -> HistoricalAnalysis {
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelUnavailable
        }
        let session = LanguageModelSession(instructions: instructions)
        let prompt = basePrompt(reference: reference, verseText: verseText)
            + "\n\nDescribe the historical and cultural setting of this text."
        do {
            let result = try await session.respond(to: prompt, generating: HistoricalAnalysis.self).content
            logger.debug("analyzeHistory succeeded for \(reference.displayTitle): \(result.historicalBackground.count) chars")
            guard !result.historicalBackground.isEmpty else {
                logger.error("analyzeHistory returned empty content for \(reference.displayTitle) — treating as failure")
                throw AppError.modelGenerationFailed("Model returned empty content for \(reference.displayTitle).")
            }
            return result
        } catch let error as LanguageModelSession.GenerationError where error.isGuardrail {
            logger.warning("analyzeHistory guardrail hit for \(reference.displayTitle), retrying")
            return try await retry(
                prompt: "Describe the historical and cultural setting of the ancient text \(reference.displayTitle).",
                generating: HistoricalAnalysis.self
            )
        } catch {
            logger.error("analyzeHistory failed for \(reference.displayTitle): \(error)")
            throw AppError.modelGenerationFailed(error.localizedDescription)
        }
    }

    // MARK: - Section 3: Cross-Reference Explanations

    func analyzeCrossRefs(
        reference: BibleReference,
        crossRefs: [CrossRef]
    ) async throws -> CrossRefAnalysis {
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelUnavailable
        }
        guard !crossRefs.isEmpty else {
            return CrossRefAnalysis(crossRefExplanations: [])
        }
        let session = LanguageModelSession(instructions: instructions)
        let refList = crossRefs.map(\.reference).joined(separator: " | ")
        let prompt = "Text: \(reference.displayTitle)\n\nRelated passages to explain (in order): \(refList)"
        do {
            let result = try await session.respond(to: prompt, generating: CrossRefAnalysis.self).content
            logger.debug("analyzeCrossRefs succeeded for \(reference.displayTitle): \(result.crossRefExplanations.count) explanations")
            return result
        } catch let error as LanguageModelSession.GenerationError where error.isGuardrail {
            logger.warning("analyzeCrossRefs guardrail hit for \(reference.displayTitle), retrying")
            return try await retry(
                prompt: "Briefly explain how each of these ancient texts relates to \(reference.displayTitle): \(refList)",
                generating: CrossRefAnalysis.self
            )
        } catch {
            logger.error("analyzeCrossRefs failed for \(reference.displayTitle): \(error)")
            throw AppError.modelGenerationFailed(error.localizedDescription)
        }
    }

    // MARK: - Section 4: Topic Resolution

    func resolvePassage(topic: String) async throws -> TopicResolution {
        guard SystemLanguageModel.default.isAvailable else {
            throw AppError.modelUnavailable
        }
        let session = LanguageModelSession(instructions: instructions)
        let prompt = "Ancient literature topic or named passage: \(topic)"
        do {
            return try await session.respond(to: prompt, generating: TopicResolution.self).content
        } catch let error as LanguageModelSession.GenerationError where error.isGuardrail {
            return try await retry(
                prompt: "List the ancient text references for the passage known as: \(topic)",
                generating: TopicResolution.self
            )
        } catch {
            throw AppError.modelGenerationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    // Conservative limit for the on-device model's small context window
    private static let verseTextCharLimit = 3_000

    private func basePrompt(reference: BibleReference, verseText: String?) -> String {
        var parts = ["Text: \(reference.displayTitle)"]
        if let text = verseText {
            if text.count > Self.verseTextCharLimit {
                let truncated = String(text.prefix(Self.verseTextCharLimit))
                logger.warning("verseText truncated from \(text.count) to \(Self.verseTextCharLimit) chars for \(reference.displayTitle)")
                parts.append("Content (excerpt — passage is too long to include in full): \(truncated)…")
            } else {
                parts.append("Content: \(text)")
            }
        }
        return parts.joined(separator: "\n\n")
    }

    /// Retry with a more neutral prompt after a guardrail hit.
    private func retry<T: Generable>(prompt: String, generating type: T.Type) async throws -> T {
        let session = LanguageModelSession(instructions: instructions)
        do {
            return try await session.respond(to: prompt, generating: type).content
        } catch {
            throw AppError.modelGenerationFailed(
                "The on-device model blocked this content (known beta issue with religious text). " +
                "Try again — it usually succeeds on a second attempt."
            )
        }
    }
}
