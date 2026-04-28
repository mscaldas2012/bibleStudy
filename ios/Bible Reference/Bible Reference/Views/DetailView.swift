/// DetailView.swift
/// Right panel: displays the study note or placeholder states.

import SwiftUI

struct DetailView: View {
    @Environment(StudyViewModel.self) private var viewModel
    @Environment(\.appColors) private var colors
    @ObservedObject private var fontSizeStore = FontSizeStore.shared

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView(phase: viewModel.loadingPhase)
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Could Not Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.submit() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !viewModel.topicCandidates.isEmpty {
                TopicCandidateView(
                    topic: viewModel.referenceInput,
                    candidates: viewModel.topicCandidates
                )
            } else if let note = viewModel.currentNote {
                StudyNoteView(note: note)
            } else {
                ContentUnavailableView {
                    Label("Open a Passage", systemImage: "book.pages")
                } description: {
                    Text("Enter a Bible reference in the sidebar to see context, background, and applications.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background.ignoresSafeArea())
        .dynamicTypeSize(fontSizeStore.currentSize)
        .navigationTitle(viewModel.currentNote?.reference.displayTitle ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { refString in
            CrossRefPassageView(referenceString: refString)
        }
    }
}

// MARK: - Loading indicator

struct LoadingView: View {
    let phase: StudyViewModel.LoadingPhase

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            if !phase.label.isEmpty {
                Text(phase.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .animation(.default, value: phase.label)
            }
        }
    }
}
