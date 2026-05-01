/// StudyViewModel.swift
/// Orchestrates parsing, ESV fetch, and AI generation.
/// Cards appear progressively: context → historical background → cross-references.

import Foundation
import Observation
import OSLog
import Speech

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BibleReference", category: "StudyViewModel")

@Observable
final class StudyViewModel {

    // MARK: - Input
    var referenceInput: String = ""

    // MARK: - Speech
    private let speechService = SpeechService()

    var isSpeechRecording: Bool { speechService.isRecording }
    var liveTranscript: String { speechService.transcript }
    var speechPermission: SFSpeechRecognizerAuthorizationStatus { speechService.permissionStatus }
    var isSpeechSupported: Bool { speechService.isSupported }

    func requestSpeechPermission() async {
        await speechService.requestPermission()
        await speechService.prepareLanguageModel()
    }

    func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
            if !speechService.transcript.isEmpty {
                referenceInput = speechService.transcript
            }
        } else {
            try? speechService.startRecording()
        }
    }

    // MARK: - Output
    var currentNote: StudyNote?
    var topicCandidates: [String] = []   // non-empty = show passage picker

    // MARK: - State
    var isLoading: Bool = false
    var loadingPhase: LoadingPhase = .idle
    var error: AppError?

    // MARK: - Services
    /// App-layer adapter that translates Bible study tasks to the active LLMProvider.
    /// Swap providers in Settings — this always reads the current one.
    private let bibleAI = BibleLLMAdapter()
    private let tskService = TSKService.shared

    // MARK: - History helpers (cleared at start of each submit)
    private var pendingHistoryQuery: String = ""
    private var pendingHistoryTitle: String = ""
    private var lastLookedUpQuery: String = ""

    enum LoadingPhase {
        case idle, parsingReference, resolvingTopic, fetchingText, generatingInsights

        var label: String {
            switch self {
            case .idle:               return ""
            case .parsingReference:   return "Parsing reference…"
            case .resolvingTopic:     return "Finding passage…"
            case .fetchingText:       return "Fetching ESV text…"
            case .generatingInsights: return "Generating insights…"
            }
        }
    }

    // MARK: - Study

    func submit() async {
        let trimmed = referenceInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Strip control characters (newlines, tabs, null bytes) — never valid in a
        // Bible reference or topic name, and could embed extra instructions in LLM prompts.
        let sanitized = trimmed.components(separatedBy: .controlCharacters).joined()
        guard sanitized.count <= 200 else {
            error = .parseFailure("Input too long — please keep it under 200 characters.")
            return
        }
        guard sanitized.lowercased() != lastLookedUpQuery else { return }

        let historyQuery = pendingHistoryQuery.isEmpty ? sanitized : pendingHistoryQuery
        pendingHistoryQuery = ""
        pendingHistoryTitle = ""

        error = nil
        isLoading = true
        currentNote = nil
        topicCandidates = []
        lastLookedUpQuery = sanitized.lowercased()

        do {
            // 1. Parse reference — if it fails, resolve as a topic name via AI
            loadingPhase = .parsingReference
            let ref: BibleReference
            do {
                ref = try parseBibleReference(sanitized)
            } catch {
                loadingPhase = .resolvingTopic
                let resolution = try await bibleAI.resolvePassage(topic: sanitized)
                let valid = resolution.references.filter { (try? parseBibleReference($0)) != nil }
                if valid.isEmpty {
                    throw AppError.parseFailure("Could not find a passage for \"\(sanitized)\". Try a direct reference like \"Luke 15:11-32\".")
                } else if valid.count == 1 {
                    ref = try parseBibleReference(valid[0])
                } else {
                    isLoading = false
                    loadingPhase = .idle
                    pendingHistoryQuery = historyQuery
                    topicCandidates = valid
                    return
                }
            }

            // 2. Fetch cross-references from TSK (offline, instant)
            let crossRefs = await tskService.fetchRefs(for: ref)

            // 3. Fetch ESV text (always attempted; multi-chapter refs query first chapter only)
            var verseText: String? = nil
            var esvKeyMissing = false
            var esvError: String? = nil
            if let key = KeychainService.loadESVKey(), !key.isEmpty {
                loadingPhase = .fetchingText
                let svc = ESVService(apiKey: key)
                do {
                    verseText = try await svc.fetchPassage(for: ref)
                } catch {
                    esvError = error.localizedDescription
                }
            } else {
                esvKeyMissing = true
            }

            // Record history and streak
            HistoryStore.shared.add(query: historyQuery, displayTitle: ref.displayTitle)
            StreakStore.shared.recordLookup()

            // Show all cards immediately with spinners — content fills in as each call completes
            loadingPhase = .generatingInsights
            currentNote = StudyNote(
                reference: ref,
                verseText: verseText,
                context: "",
                applications: [],
                historicalBackground: "",
                crossReferences: [],
                esvKeyMissing: esvKeyMissing,
                esvError: esvError
            )
            isLoading = false
            loadingPhase = .idle

            // Yield so SwiftUI renders the empty cards before AI calls begin
            await Task.yield()

            // 4a. Context + applications
            do {
                let result = try await bibleAI.analyzeContext(reference: ref, verseText: verseText)
                currentNote?.context = result.context
                currentNote?.applications = result.applications
                logger.info("Context+Applications loaded for \(ref.displayTitle)")
            } catch {
                logger.error("Context+Applications failed for \(ref.displayTitle): \(error)")
                currentNote?.contextError = error.localizedDescription
            }

            // 4b. Historical background
            do {
                let result = try await bibleAI.analyzeHistory(reference: ref, verseText: verseText)
                currentNote?.historicalBackground = result.historicalBackground
                logger.info("Historical background loaded for \(ref.displayTitle)")
            } catch {
                logger.error("Historical background failed for \(ref.displayTitle): \(error)")
                currentNote?.historyError = error.localizedDescription
            }

            // 4c. Cross-reference explanations
            // Always set refs from TSK so the card appears; AI explanations layer in on top
            if !crossRefs.isEmpty {
                currentNote?.crossReferences = crossRefs
                await Task.yield()
                do {
                    let result = try await bibleAI.analyzeCrossRefs(reference: ref, crossRefs: crossRefs)
                    var refs = crossRefs
                    for i in refs.indices where i < result.crossRefExplanations.count {
                        refs[i].explanation = result.crossRefExplanations[i]
                    }
                    currentNote?.crossReferences = refs
                    logger.info("Cross-references loaded for \(ref.displayTitle)")
                } catch {
                    logger.error("Cross-references failed for \(ref.displayTitle): \(error)")
                    currentNote?.crossRefError = error.localizedDescription
                }
            }
            currentNote?.crossRefsLoaded = true

        } catch let e as AppError {
            isLoading = false
            loadingPhase = .idle
            lastLookedUpQuery = ""
            error = e
        } catch {
            isLoading = false
            loadingPhase = .idle
            lastLookedUpQuery = ""
            self.error = .modelGenerationFailed(error.localizedDescription)
        }
    }

    func selectCandidate(_ referenceString: String) async {
        topicCandidates = []
        referenceInput = referenceString
        await submit()
    }

    func submitHistory(_ entry: HistoryEntry) async {
        pendingHistoryQuery = entry.query
        referenceInput = entry.displayTitle
        await submit()
    }

    // MARK: - Per-section retries

    func retryContext() async {
        guard let note = currentNote else { return }
        currentNote?.contextError = nil
        currentNote?.context = ""
        currentNote?.applications = []
        do {
            let result = try await bibleAI.analyzeContext(reference: note.reference, verseText: note.verseText)
            currentNote?.context = result.context
            currentNote?.applications = result.applications
        } catch {
            currentNote?.contextError = error.localizedDescription
        }
    }

    func retryHistory() async {
        guard let note = currentNote else { return }
        currentNote?.historyError = nil
        currentNote?.historicalBackground = ""
        do {
            let result = try await bibleAI.analyzeHistory(reference: note.reference, verseText: note.verseText)
            currentNote?.historicalBackground = result.historicalBackground
        } catch {
            currentNote?.historyError = error.localizedDescription
        }
    }

    func retryCrossRefs() async {
        guard let note = currentNote else { return }
        currentNote?.crossRefError = nil
        currentNote?.crossRefsLoaded = false
        let crossRefs = note.crossReferences.isEmpty
            ? await tskService.fetchRefs(for: note.reference)
            : note.crossReferences
        guard !crossRefs.isEmpty else {
            currentNote?.crossRefsLoaded = true
            return
        }
        if currentNote?.crossReferences.isEmpty == true {
            currentNote?.crossReferences = crossRefs
        }
        do {
            let result = try await bibleAI.analyzeCrossRefs(reference: note.reference, crossRefs: crossRefs)
            var refs = crossRefs
            for i in refs.indices where i < result.crossRefExplanations.count {
                refs[i].explanation = result.crossRefExplanations[i]
            }
            currentNote?.crossReferences = refs
        } catch {
            currentNote?.crossRefError = error.localizedDescription
        }
        currentNote?.crossRefsLoaded = true
    }
}
