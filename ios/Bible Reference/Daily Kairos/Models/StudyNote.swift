/// StudyNote.swift
/// Data models for study output, including the @Generable types
/// used by Apple's FoundationModels framework.

import Foundation
import FoundationModels

// MARK: - Structured output from the on-device model (one @Generable per section)

@Generable
struct ContextAndApplications {
    @Guide(description: "2-3 sentences describing the narrative context: who wrote this, to whom, and what is happening in this specific passage within the broader story of the book")
    var context: String

    @Guide(description: "Exactly 3 practical applications of this passage for a modern reader. Each application should be 1-2 sentences and directly grounded in the text.")
    var applications: [String]
}

@Generable
struct HistoricalAnalysis {
    @Guide(description: "2-3 sentences on the historical and cultural setting: time period, geography, social or political context, and any customs or language nuances that illuminate this passage")
    var historicalBackground: String
}

@Generable
struct TopicResolution {
    @Guide(description: "Exact Bible references for this named passage or topic. Use format 'Book Chapter:Verse-Verse' (e.g. 'Luke 15:11-32'). If the topic appears in multiple books (synoptic parallels, parallel accounts), include all occurrences. Return only references, no explanations.")
    var references: [String]
}

@Generable
struct CrossRefAnalysis {
    @Guide(description: "For each cross-reference listed in the prompt (in the same order), write exactly one sentence explaining how it connects to the current passage. Return the same number of explanations as cross-references provided.")
    var crossRefExplanations: [String]
}

// MARK: - UI data model

/// The assembled study note shown in the UI.
/// AI-generated fields start empty and are filled in progressively.
struct StudyNote: Identifiable {
    let id = UUID()
    let reference: BibleReference
    let verseText: String?
    var context: String
    var applications: [String]
    var historicalBackground: String        // empty until history call completes
    var crossReferences: [CrossRef]         // empty until cross-ref call completes
    var crossRefsLoaded: Bool = false       // true once cross-ref phase finishes (even if 0 refs)
    var esvKeyMissing: Bool = false
    var esvError: String?
    let createdAt: Date = .now

    // Per-section AI errors — nil while loading or when successful
    var contextError: String?
    var historyError: String?
    var crossRefError: String?
}
