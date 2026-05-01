/// BibleLLMAdapter.swift
/// APP LAYER — Bible study-specific adapter around any LLMProvider.
///
/// This is the only file that knows about BibleReference, CrossRef, and the
/// @Generable output types. It translates high-level Bible study requests into
/// plain chat prompts, dispatches them through whichever LLMProvider is active,
/// and parses the JSON responses back into the app's domain types.
///
/// When the LLM provider layer is extracted as a library, this file stays in the app.

import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BibleReference", category: "BibleLLMAdapter")

// MARK: - Private Codable mirrors of @Generable output types (for JSON decoding)
// These are intentionally private — callers receive the app's @Generable types directly.

private struct TopicResolutionJSON: Codable { let references: [String] }
private struct ContextJSON:          Codable { let context: String; let applications: [String] }
private struct HistoryJSON:          Codable { let historicalBackground: String }
private struct CrossRefJSON:         Codable { let crossRefExplanations: [String] }

// MARK: - Adapter

/// Translates Bible study tasks into `LLMProvider.chat()` calls.
/// `StudyViewModel` owns an instance of this and never touches `LLMProvider` directly.
final class BibleLLMAdapter {

    // Always reads the current active provider — swapping providers in settings
    // takes effect immediately on the next call.
    private var provider: any LLMProvider { LLMProviderStore.shared.activeProvider }

    // MARK: - Public interface (mirrors FoundationModelService signatures)

    func resolvePassage(topic: String) async throws -> TopicResolution {
        let prompt = Prompts.resolvePassage(topic: topic)
        let text = try await provider.chat(systemPrompt: Prompts.system, userPrompt: prompt)
        let json = try parseProviderJSON(text, as: TopicResolutionJSON.self)
        return TopicResolution(references: json.references)
    }

    func analyzeContext(
        reference: BibleReference,
        verseText: String?
    ) async throws -> ContextAndApplications {
        let prompt = buildPrompt(reference: reference, verseText: verseText, instruction: Prompts.contextInstruction(for: reference))
        logger.debug("analyzeContext prompt length: \(prompt.count) chars for \(reference.displayTitle)")
        let text = try await provider.chat(systemPrompt: Prompts.system, userPrompt: prompt)
        logger.debug("analyzeContext raw response (\(text.count) chars): \(text.prefix(300))")
        let json = try parseProviderJSON(text, as: ContextJSON.self)
        guard !json.context.isEmpty else {
            logger.error("analyzeContext: parsed JSON has empty context for \(reference.displayTitle)")
            throw LLMError.parseError
        }
        return ContextAndApplications(context: json.context, applications: json.applications)
    }

    func analyzeHistory(
        reference: BibleReference,
        verseText: String?
    ) async throws -> HistoricalAnalysis {
        let prompt = buildPrompt(reference: reference, verseText: verseText, instruction: Prompts.historyInstruction)
        logger.debug("analyzeHistory prompt length: \(prompt.count) chars for \(reference.displayTitle)")
        let text = try await provider.chat(systemPrompt: Prompts.system, userPrompt: prompt)
        logger.debug("analyzeHistory raw response (\(text.count) chars): \(text.prefix(300))")
        let json = try parseProviderJSON(text, as: HistoryJSON.self)
        guard !json.historicalBackground.isEmpty else {
            logger.error("analyzeHistory: parsed JSON has empty historicalBackground for \(reference.displayTitle)")
            throw LLMError.parseError
        }
        return HistoricalAnalysis(historicalBackground: json.historicalBackground)
    }

    func analyzeCrossRefs(
        reference: BibleReference,
        crossRefs: [CrossRef]
    ) async throws -> CrossRefAnalysis {
        guard !crossRefs.isEmpty else { return CrossRefAnalysis(crossRefExplanations: []) }
        // Cap at 8 to keep output tokens predictable across all providers
        let limited = Array(crossRefs.prefix(8))
        let refList = limited.enumerated()
            .map { "\($0.offset + 1). \($0.element.reference)" }
            .joined(separator: "\n")
        let prompt = Prompts.crossRefExplanations(
            mainPassage: reference.displayTitle,
            refList: refList,
            count: limited.count
        )
        logger.debug("analyzeCrossRefs prompt length: \(prompt.count) chars for \(reference.displayTitle)")
        let text = try await provider.chat(systemPrompt: Prompts.system, userPrompt: prompt)
        logger.debug("analyzeCrossRefs raw response (\(text.count) chars): \(text.prefix(300))")
        let json = try parseProviderJSON(text, as: CrossRefJSON.self)
        return CrossRefAnalysis(crossRefExplanations: json.crossRefExplanations)
    }

    // MARK: - Private helpers

    // ~3 000 chars keeps the full prompt well inside Apple's ~4-6 k token window
    // while still giving REST providers plenty of context. Long passages like
    // Psalm 119 exceed this; the model knows the text from training data.
    private static let verseTextCharLimit = 3_000

    private func buildPrompt(
        reference: BibleReference,
        verseText: String?,
        instruction: String
    ) -> String {
        var parts = ["Passage: \(reference.displayTitle)"]
        if let t = verseText {
            if t.count > Self.verseTextCharLimit {
                let truncated = String(t.prefix(Self.verseTextCharLimit))
                logger.warning("verseText truncated from \(t.count) to \(Self.verseTextCharLimit) chars for \(reference.displayTitle)")
                parts.append("Text (excerpt — passage is too long to include in full): \(truncated)…")
            } else {
                parts.append("Text: \(t)")
            }
        }
        parts.append(instruction)
        return parts.joined(separator: "\n\n")
    }
}
