/// StudyViewModel.swift
/// Orchestrates parsing, ESV fetch, and Foundation Model generation.

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
    private let modelService = FoundationModelService.shared

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
        defer { isLoading = false; loadingPhase = .idle }

        do {
            // 1. Parse reference
            loadingPhase = .parsingReference
            let ref: BibleReference
            do {
                ref = try parseBibleReference(trimmed)
            } catch let e as ParseError {
                throw AppError.parseFailure(e.errorDescription ?? e.localizedDescription)
            }

            // 2. Fetch ESV text (short passages only)
            var verseText: String? = nil
            if ref.isShort {
                loadingPhase = .fetchingText
                guard let svc = esvService else { throw AppError.esvMissingKey }
                verseText = try await svc.fetchPassage(for: ref)
            }

            // 3. Generate insights with Apple Foundation Models
            loadingPhase = .generatingInsights
            let analysis = try await modelService.analyze(reference: ref, verseText: verseText)

            currentNote = StudyNote(
                reference: ref,
                verseText: verseText,
                context: analysis.context,
                applications: analysis.applications
            )
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .modelGenerationFailed(error.localizedDescription)
        }
    }

    // MARK: - Speech passthrough

    var isSpeechRecording: Bool { speechService.isRecording }
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
