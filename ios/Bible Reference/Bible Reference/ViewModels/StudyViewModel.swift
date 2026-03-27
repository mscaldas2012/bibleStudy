/// StudyViewModel.swift
/// Orchestrates parsing, ESV fetch, and Foundation Model generation.
/// Cards appear progressively: context → historical background → cross-references.

import Foundation
import Observation

@Observable
final class StudyViewModel {

    // MARK: - Input
    var referenceInput: String = ""

    // MARK: - Output
    var currentNote: StudyNote?
    var topicCandidates: [String] = []   // non-empty = show passage picker

    // MARK: - State
    var isLoading: Bool = false
    var loadingPhase: LoadingPhase = .idle
    var error: AppError?

    // MARK: - Services
    private let modelService = FoundationModelService()
    private let tskService = TSKService()

    // MARK: - History helpers (cleared at start of each submit)
    private var pendingHistoryQuery: String = ""      // original typed query to show in history
    private var pendingHistoryTitle: String = ""      // canonical display title (set after ref is resolved)

    enum LoadingPhase {
        case idle, parsingReference, resolvingTopic, fetchingText, generatingInsights

        var label: String {
            switch self {
            case .idle: return ""
            case .parsingReference: return "Parsing reference…"
            case .resolvingTopic: return "Finding passage…"
            case .fetchingText: return "Fetching ESV text…"
            case .generatingInsights: return "Generating insights…"
            }
        }
    }

    // MARK: - Study

    func submit() async {
        let trimmed = referenceInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Capture pending history context set by selectCandidate / submitHistory, then clear
        let historyQuery = pendingHistoryQuery.isEmpty ? trimmed : pendingHistoryQuery
        pendingHistoryQuery = ""
        pendingHistoryTitle = ""

        error = nil
        isLoading = true
        currentNote = nil
        topicCandidates = []

        do {
            // 1. Parse reference — if it fails, treat input as a topic and resolve via FM
            loadingPhase = .parsingReference
            let ref: BibleReference
            do {
                ref = try parseBibleReference(trimmed)
            } catch {
                loadingPhase = .resolvingTopic
                let resolution = try await modelService.resolvePassage(topic: trimmed)
                let valid = resolution.references.filter { (try? parseBibleReference($0)) != nil }
                if valid.isEmpty {
                    throw AppError.parseFailure("Could not find a passage for \"\(trimmed)\". Try a direct reference like \"Luke 15:11-32\".")
                } else if valid.count == 1 {
                    ref = try parseBibleReference(valid[0])
                } else {
                    isLoading = false
                    loadingPhase = .idle
                    pendingHistoryQuery = historyQuery // preserve for selectCandidate
                    topicCandidates = valid
                    return
                }
            }

            // 2. Fetch cross-references from TSK (offline, instant)
            let crossRefs = await tskService.fetchRefs(for: ref)

            // 3. Fetch ESV text if applicable
            var verseText: String? = nil
            var esvKeyMissing = false
            if ref.shouldShowText {
                if let key = KeychainService.loadESVKey(), !key.isEmpty {
                    loadingPhase = .fetchingText
                    let svc = ESVService(apiKey: key)
                    verseText = try? await svc.fetchPassage(for: ref)
                } else {
                    esvKeyMissing = true
                }
            }

            // Record history — query is what user typed, displayTitle is the canonical passage
            HistoryStore.shared.add(query: historyQuery, displayTitle: ref.displayTitle)

            // Show all cards immediately with spinners — content fills in as each call completes
            loadingPhase = .generatingInsights
            currentNote = StudyNote(
                reference: ref,
                verseText: verseText,
                context: "",
                applications: [],
                historicalBackground: "",
                crossReferences: [],
                esvKeyMissing: esvKeyMissing
            )
            isLoading = false
            loadingPhase = .idle

            // Yield so SwiftUI renders the empty cards (with spinners) before model calls begin
            await Task.yield()

            // 4a. Context + applications
            if let contextResult = try? await modelService.analyzeContext(reference: ref, verseText: verseText) {
                currentNote?.context = contextResult.context
                currentNote?.applications = contextResult.applications
            }

            // 4b. Historical background
            if let historyResult = try? await modelService.analyzeHistory(reference: ref, verseText: verseText) {
                currentNote?.historicalBackground = historyResult.historicalBackground
            }

            // 4c. Cross-reference explanations
            if !crossRefs.isEmpty,
               let crossRefResult = try? await modelService.analyzeCrossRefs(reference: ref, crossRefs: crossRefs) {
                var refs = crossRefs
                for i in refs.indices where i < crossRefResult.crossRefExplanations.count {
                    refs[i].explanation = crossRefResult.crossRefExplanations[i]
                }
                currentNote?.crossReferences = refs
            }
            currentNote?.crossRefsLoaded = true

        } catch let e as AppError {
            isLoading = false
            loadingPhase = .idle
            error = e
        } catch {
            isLoading = false
            loadingPhase = .idle
            self.error = .modelGenerationFailed(error.localizedDescription)
        }
    }

    func selectCandidate(_ referenceString: String) async {
        // pendingHistoryQuery was preserved from submit() when candidates were set
        // so historyQuery in the next submit() will use the original typed text
        topicCandidates = []
        referenceInput = referenceString
        await submit()
    }

    /// Re-run a history entry: display text stays as-is, lookup uses the canonical title.
    func submitHistory(_ entry: HistoryEntry) async {
        pendingHistoryQuery = entry.query        // preserve original typed text
        referenceInput = entry.displayTitle      // look up the canonical passage directly
        await submit()
    }

}
