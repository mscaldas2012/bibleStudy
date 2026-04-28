/// DetailView.swift
/// Right panel: displays the study note or placeholder states.

import SwiftUI

struct DetailView: View {
    @Environment(StudyViewModel.self) private var viewModel
    @Environment(\.appColors) private var colors
    @ObservedObject private var fontSizeStore = FontSizeStore.shared
    @State private var showFontSize = false

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
                StudyNoteView(
                    note: note,
                    onRetryContext: { await viewModel.retryContext() },
                    onRetryHistory: { await viewModel.retryHistory() },
                    onRetryCrossRefs: { await viewModel.retryCrossRefs() }
                )
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showFontSize.toggle() } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $showFontSize, arrowEdge: .top) {
                    FontSizePopover()
                }
            }
        }
    }
}

// MARK: - Font size popover

private struct FontSizePopover: View {
    @Environment(\.appColors) private var colors
    @ObservedObject private var store = FontSizeStore.shared

    var body: some View {
        HStack(spacing: 20) {
            Button { store.decrease() } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.title3)
                    .foregroundStyle(store.canDecrease ? colors.accent : colors.accent.opacity(0.25))
            }
            .disabled(!store.canDecrease)

            HStack(spacing: 4) {
                ForEach(0..<FontSizeStore.sizes.count, id: \.self) { i in
                    Capsule()
                        .fill(i == store.sizeIndex ? colors.accent : colors.accent.opacity(0.2))
                        .frame(width: 6, height: i == store.sizeIndex ? 18 : 10)
                        .animation(.spring(duration: 0.2), value: store.sizeIndex)
                }
            }

            Button { store.increase() } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.title3)
                    .foregroundStyle(store.canIncrease ? colors.accent : colors.accent.opacity(0.25))
            }
            .disabled(!store.canIncrease)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .presentationCompactAdaptation(.popover)
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
