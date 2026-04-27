/// Prompts.swift
/// Single source of truth for all LLM prompt strings.
///
/// All prompt constants are static lets on the `Prompts` enum — Swift initializes
/// each one at most once (thread-safe) the first time it is accessed.
/// Call `Prompts.preload()` at app startup to warm every string before the first
/// user interaction.

import Foundation

enum Prompts {

    // MARK: - System

    /// Neutral system prompt used for all Bible study analysis calls.
    /// Avoids religious framing that might trigger content guardrails on some providers.
    static let system = """
        You are a knowledgeable assistant specializing in ancient literature, history, and \
        philosophy. Analyze texts by explaining their historical setting, literary context, \
        and timeless wisdom. Return ONLY valid JSON with no markdown, no code blocks, no explanation.
        """

    // MARK: - Topic resolution

    /// User prompt template for resolving a named topic to Bible references.
    /// - Parameter topic: The topic or passage name supplied by the user.
    static func resolvePassage(topic: String) -> String {
        """
        Find the Bible passage reference(s) for this named topic or passage. \
        Return JSON exactly: {"references": ["Book Chapter:Verse-Verse"]}. \
        For synoptic parallels include all occurrences. Only references, no explanations.
        Topic: \(topic)
        """
    }

    // MARK: - Context & applications

    /// Instruction fragment for the context-and-applications analysis call.
    /// Scope adapts based on the reference:
    /// - Verse-level (few verses in one chapter) → main theme of that chapter
    /// - Chapter-level (multiple chapters) → summary of the 1-2 chapters preceding the selection
    static func contextInstruction(for reference: BibleReference) -> String {
        let isVerseLevel = reference.verseStart != nil && reference.chapterStart == reference.chapterEnd
        let isMultiChapter = reference.chapterStart != reference.chapterEnd

        if isVerseLevel {
            return """
                Return JSON exactly: \
                {"context": "2-3 sentences on the main theme of \(reference.book) chapter \(reference.chapterStart) \
                as a whole — what the chapter is about, its key movement, and how verses \(reference.verseStart!)\
                \(reference.verseEnd.map { "-\($0)" } ?? "") fit within that chapter", \
                "applications": ["application 1", "application 2", "application 3"]}. \
                Exactly 3 applications, each 1-2 sentences, drawn directly from the selected verses.
                """
        } else if isMultiChapter && reference.chapterStart > 1 {
            let prevEnd = reference.chapterStart - 1
            let prevStart = max(1, prevEnd - 1)
            let prevRange = prevStart == prevEnd ? "chapter \(prevEnd)" : "chapters \(prevStart)–\(prevEnd)"
            return """
                Return JSON exactly: \
                {"context": "2-3 sentences summarizing \(reference.book) \(prevRange) — \
                the narrative or argument immediately before the selected passage — \
                so the reader understands what leads into \(reference.book) \(reference.chapterStart)–\(reference.chapterEnd)", \
                "applications": ["application 1", "application 2", "application 3"]}. \
                Exactly 3 applications, each 1-2 sentences, drawn from the themes of the selected chapters.
                """
        } else {
            // Single whole chapter or chapter 1 with no preceding context
            return """
                Return JSON exactly: \
                {"context": "2-3 sentences on the main theme of \(reference.book) \
                chapter \(reference.chapterStart) — what it is about, its key movement, \
                and how it fits within the broader book", \
                "applications": ["application 1", "application 2", "application 3"]}. \
                Exactly 3 applications, each 1-2 sentences, directly grounded in the text.
                """
        }
    }

    // MARK: - Historical background

    /// Instruction fragment for the historical analysis call.
    static let historyInstruction = """
        Return JSON exactly: \
        {"historicalBackground": "2-3 sentences on the historical and cultural setting: \
        time period, geography, social or political context, and any customs or language \
        nuances that illuminate this passage"}.
        """

    // MARK: - Cross-reference explanations

    /// User prompt for explaining a list of cross-references.
    /// - Parameters:
    ///   - mainPassage: Display title of the passage being studied.
    ///   - refList: Numbered list of cross-reference strings (one per line).
    ///   - count: Total number of cross-references in `refList`.
    static func crossRefExplanations(mainPassage: String, refList: String, count: Int) -> String {
        """
        Main passage: \(mainPassage)
        Cross-references:
        \(refList)

        For each numbered cross-reference above, write one sentence explaining how it \
        connects to the main passage. Return JSON exactly:
        {"crossRefExplanations": ["sentence for 1", "sentence for 2", ...]}
        The array must have exactly \(count) strings, one per cross-reference, in order.
        """
    }

    // MARK: - Connectivity check

    /// Minimal system prompt used to verify that a custom provider endpoint is reachable.
    static let verifySystem = "Respond with exactly the word OK."

    // MARK: - Preload

    /// Touch every static constant so the Swift runtime initializes them all during
    /// app startup rather than on the first user-facing call.
    static func preload() {
        _ = system
        _ = historyInstruction
        _ = verifySystem
    }
}
