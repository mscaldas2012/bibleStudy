/// CrossRefPassageView.swift
/// Self-contained study note for a tapped cross-reference.
/// Uses CrossRefLoader (starts with isLoading=true) so the loading view
/// renders on the very first frame — no blank flash before .task fires.
/// CrossReferencesCard inside StudyNoteView pushes further refs recursively.

import SwiftUI

// MARK: - Loader

/// Minimal observable loader for a single cross-reference lookup.
/// Mirrors StudyViewModel's submit() flow but without speech/input state.
@Observable
@MainActor
final class CrossRefLoader {
    var studyNote: StudyNote?
    var isLoading = true    // true at init → loading view shows on first render
    var error: AppError?

    private let tskService   = TSKService()
    private let modelService = FoundationModelService()

    func load(referenceString: String) async {
        isLoading = true
        error = nil
        studyNote = nil

        do {
            let ref = try parseBibleReference(referenceString)
            let crossRefs = await tskService.fetchRefs(for: ref)

            var verseText: String? = nil
            var esvKeyMissing = false
            if ref.shouldShowText {
                if let key = KeychainService.loadESVKey(), !key.isEmpty {
                    let svc = ESVService(apiKey: key)
                    verseText = try? await svc.fetchPassage(for: ref)
                } else {
                    esvKeyMissing = true
                }
            }

            // Show skeleton with spinners in each card
            studyNote = StudyNote(
                reference: ref,
                verseText: verseText,
                context: "",
                applications: [],
                historicalBackground: "",
                crossReferences: [],
                esvKeyMissing: esvKeyMissing
            )
            isLoading = false
            await Task.yield()

            // Fill cards progressively
            if let r = try? await modelService.analyzeContext(reference: ref, verseText: verseText) {
                studyNote?.context = r.context
                studyNote?.applications = r.applications
            }
            if let r = try? await modelService.analyzeHistory(reference: ref, verseText: verseText) {
                studyNote?.historicalBackground = r.historicalBackground
            }
            if !crossRefs.isEmpty,
               let r = try? await modelService.analyzeCrossRefs(reference: ref, crossRefs: crossRefs) {
                var refs = crossRefs
                for i in refs.indices where i < r.crossRefExplanations.count {
                    refs[i].explanation = r.crossRefExplanations[i]
                }
                studyNote?.crossReferences = refs
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
                StudyNoteView(note: note)
            }
        }
        .navigationTitle(loader.studyNote?.reference.displayTitle ?? referenceString)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loader.load(referenceString: referenceString)
        }
    }
}
