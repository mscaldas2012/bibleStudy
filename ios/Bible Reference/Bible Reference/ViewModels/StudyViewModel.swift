/// StudyViewModel.swift
/// Orchestrates parsing, ESV fetch, and AI generation.
/// Cards appear progressively: context → historical background → cross-references.

import Foundation
import Observation
import Speech

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
    private let tskService = TSKService()

    // MARK: - History helpers (cleared at start of each submit)
    private var pendingHistoryQuery: String = ""
    private var pendingHistoryTitle: String = ""

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

        let historyQuery = pendingHistoryQuery.isEmpty ? trimmed : pendingHistoryQuery
        pendingHistoryQuery = ""
        pendingHistoryTitle = ""

        error = nil
        isLoading = true
        currentNote = nil
        topicCandidates = []

        do {
            // 1. Parse reference — if it fails, resolve as a topic name via AI
            loadingPhase = .parsingReference
            let ref: BibleReference
            do {
                ref = try parseBibleReference(trimmed)
            } catch {
                loadingPhase = .resolvingTopic
                let resolution = try await bibleAI.resolvePassage(topic: trimmed)
                let valid = resolution.references.filter { (try? parseBibleReference($0)) != nil }
                if valid.isEmpty {
                    throw AppError.parseFailure("Could not find a passage for \"\(trimmed)\". Try a direct reference like \"Luke 15:11-32\".")
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
                esvKeyMissing: esvKeyMissing
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
            } catch {
                currentNote?.contextError = error.localizedDescription
            }

            // 4b. Historical background
            do {
                let result = try await bibleAI.analyzeHistory(reference: ref, verseText: verseText)
                currentNote?.historicalBackground = result.historicalBackground
            } catch {
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
                } catch {
                    currentNote?.crossRefError = error.localizedDescription
                }
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
        topicCandidates = []
        referenceInput = referenceString
        await submit()
    }

    func submitHistory(_ entry: HistoryEntry) async {
        pendingHistoryQuery = entry.query
        referenceInput = entry.displayTitle
        await submit()
    }
}
