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

    // Neutral system prompt avoids triggering content guardrails on religious text.
    private let system = """
        You are a knowledgeable assistant specializing in ancient literature, history, and \
        philosophy. Analyze texts by explaining their historical setting, literary context, \
        and timeless wisdom. Return ONLY valid JSON with no markdown, no code blocks, no explanation.
        """

    // MARK: - Public interface (mirrors FoundationModelService signatures)

    func resolvePassage(topic: String) async throws -> TopicResolution {
        let prompt = """
            Find the Bible passage reference(s) for this named topic or passage. \
            Return JSON exactly: {"references": ["Book Chapter:Verse-Verse"]}. \
            For synoptic parallels include all occurrences. Only references, no explanations.
            Topic: \(topic)
            """
        let text = try await provider.chat(systemPrompt: system, userPrompt: prompt)
        let json = try parseProviderJSON(text, as: TopicResolutionJSON.self)
        return TopicResolution(references: json.references)
    }

    func analyzeContext(
        reference: BibleReference,
        verseText: String?
    ) async throws -> ContextAndApplications {
        let prompt = buildPrompt(reference: reference, verseText: verseText, instruction: """
            Return JSON exactly: \
            {"context": "2-3 sentences describing narrative context: who wrote this, to whom, \
            and what is happening in this specific passage within the broader book", \
            "applications": ["application 1", "application 2", "application 3"]}. \
            Exactly 3 applications, each 1-2 sentences, directly grounded in the text.
            """)
        let text = try await provider.chat(systemPrompt: system, userPrompt: prompt)
        let json = try parseProviderJSON(text, as: ContextJSON.self)
        return ContextAndApplications(context: json.context, applications: json.applications)
    }

    func analyzeHistory(
        reference: BibleReference,
        verseText: String?
    ) async throws -> HistoricalAnalysis {
        let prompt = buildPrompt(reference: reference, verseText: verseText, instruction: """
            Return JSON exactly: \
            {"historicalBackground": "2-3 sentences on the historical and cultural setting: \
            time period, geography, social or political context, and any customs or language \
            nuances that illuminate this passage"}.
            """)
        let text = try await provider.chat(systemPrompt: system, userPrompt: prompt)
        let json = try parseProviderJSON(text, as: HistoryJSON.self)
        return HistoricalAnalysis(historicalBackground: json.historicalBackground)
    }

    func analyzeCrossRefs(
        reference: BibleReference,
        crossRefs: [CrossRef]
    ) async throws -> CrossRefAnalysis {
        guard !crossRefs.isEmpty else { return CrossRefAnalysis(crossRefExplanations: []) }
        let refList = crossRefs.map(\.reference).joined(separator: " | ")
        let prompt = """
            Main passage: \(reference.displayTitle)
            Cross-references (in order): \(refList)
            For each cross-reference write exactly one sentence explaining how it connects \
            to the main passage. Return JSON exactly: \
            {"crossRefExplanations": ["explanation 1", "explanation 2", ...]}. \
            Return the same number of explanations as cross-references provided.
            """
        let text = try await provider.chat(systemPrompt: system, userPrompt: prompt)
        let json = try parseProviderJSON(text, as: CrossRefJSON.self)
        return CrossRefAnalysis(crossRefExplanations: json.crossRefExplanations)
    }

    // MARK: - Private helpers

    private func buildPrompt(
        reference: BibleReference,
        verseText: String?,
        instruction: String
    ) -> String {
        var parts = ["Passage: \(reference.displayTitle)"]
        if let t = verseText { parts.append("Text: \(t)") }
        parts.append(instruction)
        return parts.joined(separator: "\n\n")
    }
}
