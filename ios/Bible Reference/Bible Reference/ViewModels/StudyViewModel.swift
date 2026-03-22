/// StudyViewModel.swift
/// Orchestrates parsing, ESV fetch, and Foundation Model generation.
/// Cards appear progressively: context → historical background → cross-references.

import Foundation
import Observation
import Speech

@Observable
final class StudyViewModel {

    // MARK: - Input
    var referenceInput: String = ""

    // MARK: - Output
    var currentNote: StudyNote?

    // MARK: - State
    var isLoading: Bool = false
    var loadingPhase: LoadingPhase = .idle
    var error: AppError?

    // MARK: - Services
    private let speechService = SpeechService()
    private var esvService: ESVService?
    private let modelService = FoundationModelService()
    private let tskService = TSKService()

    enum LoadingPhase {
        case idle, parsingReference, fetchingText, generatingInsights

        var label: String {
            switch self {
            case .idle: return ""
            case .parsingReference: return "Parsing reference…"
            case .fetchingText: return "Fetching ESV text…"
            case .generatingInsights: return "Generating insights…"
            }
        }
    }

    init() {
        esvService = try? ESVService(apiKey: SecretsLoader.esvAPIKey())
    }

    // MARK: - Study

    func submit() async {
        let trimmed = referenceInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        error = nil
        isLoading = true
        currentNote = nil

        do {
            // 1. Parse reference
            loadingPhase = .parsingReference
            let ref: BibleReference
            do {
                ref = try parseBibleReference(trimmed)
            } catch let e as ParseError {
                throw AppError.parseFailure(e.errorDescription ?? e.localizedDescription)
            }

            // 2. Fetch cross-references from TSK (offline, instant)
            let crossRefs = await tskService.fetchRefs(for: ref)

            // 3. Fetch ESV text if applicable
            var verseText: String? = nil
            if ref.shouldShowText {
                loadingPhase = .fetchingText
                guard let svc = esvService else { throw AppError.esvMissingKey }
                verseText = try await svc.fetchPassage(for: ref)
            }

            // Show all cards immediately with spinners — content fills in as each call completes
            loadingPhase = .generatingInsights
            currentNote = StudyNote(
                reference: ref,
                verseText: verseText,
                context: "",
                applications: [],
                historicalBackground: "",
                crossReferences: []
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

    // MARK: - Speech passthrough

    var isSpeechRecording: Bool { speechService.isRecording }
    var isSpeechSupported: Bool { speechService.isSupported }
    var speechPermission: SFSpeechRecognizerAuthorizationStatus { speechService.permissionStatus }
    var speechError: String? { speechService.error }

    func requestSpeechPermission() async {
        await speechService.requestPermission()
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

    /// Live transcript while recording — bind to show real-time feedback.
    var liveTranscript: String { speechService.transcript }
}
