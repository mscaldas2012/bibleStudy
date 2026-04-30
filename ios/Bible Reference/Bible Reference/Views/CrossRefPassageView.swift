/// CrossRefPassageView.swift
/// Self-contained study note for a tapped cross-reference.
/// Uses CrossRefLoader (starts with isLoading=true) so the loading view
/// renders on the very first frame — no blank flash before .task fires.
/// CrossReferencesCard inside StudyNoteView pushes further refs recursively.

import OSLog
import SwiftUI

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BibleReference", category: "CrossRefLoader")

// MARK: - Loader

/// Minimal observable loader for a single cross-reference lookup.
/// Mirrors StudyViewModel's submit() flow but without speech/input state.
@Observable
@MainActor
final class CrossRefLoader {
    var studyNote: StudyNote?
    var isLoading = true    // true at init → loading view shows on first render
    var error: AppError?

    private let tskService   = TSKService.shared
    private let modelService = FoundationModelService.shared

    func load(referenceString: String) async {
        isLoading = true
        error = nil
        studyNote = nil

        do {
            let ref = try parseBibleReference(referenceString)
            let crossRefs = await tskService.fetchRefs(for: ref)

            var verseText: String? = nil
            var esvKeyMissing = false
            var esvError: String? = nil
            if let key = KeychainService.loadESVKey(), !key.isEmpty {
                let svc = ESVService(apiKey: key)
                do {
                    verseText = try await svc.fetchPassage(for: ref)
                } catch {
                    esvError = error.localizedDescription
                }
            } else {
                esvKeyMissing = true
            }

            // Show skeleton with spinners in each card
            studyNote = StudyNote(
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
            await Task.yield()

            // Fill cards progressively
            do {
                let r = try await modelService.analyzeContext(reference: ref, verseText: verseText)
                studyNote?.context = r.context
                studyNote?.applications = r.applications
                logger.info("Context+Applications loaded for \(ref.displayTitle)")
            } catch {
                logger.error("Context+Applications failed for \(ref.displayTitle): \(error)")
                studyNote?.contextError = error.localizedDescription
            }
            do {
                let r = try await modelService.analyzeHistory(reference: ref, verseText: verseText)
                studyNote?.historicalBackground = r.historicalBackground
                logger.info("Historical background loaded for \(ref.displayTitle)")
            } catch {
                logger.error("Historical background failed for \(ref.displayTitle): \(error)")
                studyNote?.historyError = error.localizedDescription
            }
            if !crossRefs.isEmpty {
                do {
                    let r = try await modelService.analyzeCrossRefs(reference: ref, crossRefs: crossRefs)
                    var refs = crossRefs
                    for i in refs.indices where i < r.crossRefExplanations.count {
                        refs[i].explanation = r.crossRefExplanations[i]
                    }
                    studyNote?.crossReferences = refs
                    logger.info("Cross-references loaded for \(ref.displayTitle)")
                } catch {
                    logger.error("Cross-references failed for \(ref.displayTitle): \(error)")
                    studyNote?.crossRefError = error.localizedDescription
                }
            }
            studyNote?.crossRefsLoaded = true

        } catch let e as AppError {
            isLoading = false
            error = e
        } catch {
            isLoading = false
            self.error = .modelGenerationFailed(error.localizedDescription)
        }
    }

    func retryContext() async {
        guard let note = studyNote else { return }
        studyNote?.contextError = nil
        studyNote?.context = ""
        studyNote?.applications = []
        if let r = try? await modelService.analyzeContext(reference: note.reference, verseText: note.verseText) {
            studyNote?.context = r.context
            studyNote?.applications = r.applications
        } else {
            studyNote?.contextError = "retry_failed"
        }
    }

    func retryHistory() async {
        guard let note = studyNote else { return }
        studyNote?.historyError = nil
        studyNote?.historicalBackground = ""
        if let r = try? await modelService.analyzeHistory(reference: note.reference, verseText: note.verseText) {
            studyNote?.historicalBackground = r.historicalBackground
        } else {
            studyNote?.historyError = "retry_failed"
        }
    }

    func retryCrossRefs() async {
        guard let note = studyNote else { return }
        studyNote?.crossRefError = nil
        studyNote?.crossRefsLoaded = false
        let crossRefs = note.crossReferences.isEmpty
            ? await tskService.fetchRefs(for: note.reference)
            : note.crossReferences
        guard !crossRefs.isEmpty else {
            studyNote?.crossRefsLoaded = true
            return
        }
        if studyNote?.crossReferences.isEmpty == true {
            studyNote?.crossReferences = crossRefs
        }
        if let r = try? await modelService.analyzeCrossRefs(reference: note.reference, crossRefs: crossRefs) {
            var refs = crossRefs
            for i in refs.indices where i < r.crossRefExplanations.count {
                refs[i].explanation = r.crossRefExplanations[i]
            }
            studyNote?.crossReferences = refs
        } else {
            studyNote?.crossRefError = "retry_failed"
        }
        studyNote?.crossRefsLoaded = true
    }
}

// MARK: - View

struct CrossRefPassageView: View {
    let referenceString: String
    @State private var loader = CrossRefLoader()

    var body: some View {
        Group {
            if loader.isLoading {
                LoadingView(phase: .generatingInsights)
            } else if let error = loader.error {
                ContentUnavailableView {
                    Label("Could Not Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try Again") {
                        Task { await loader.load(referenceString: referenceString) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let note = loader.studyNote {
                StudyNoteView(
                    note: note,
                    onRetryContext: { await loader.retryContext() },
                    onRetryHistory: { await loader.retryHistory() },
                    onRetryCrossRefs: { await loader.retryCrossRefs() }
                )
            }
        }
        .navigationTitle(loader.studyNote?.reference.displayTitle ?? referenceString)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loader.load(referenceString: referenceString)
        }
    }
}
