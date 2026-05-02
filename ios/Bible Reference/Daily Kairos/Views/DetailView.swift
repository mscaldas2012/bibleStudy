/// DetailView.swift
/// Right panel: displays the study note or placeholder states.

import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

struct DetailView: View {
    @Environment(StudyViewModel.self) private var viewModel
    @Environment(\.appColors) private var colors
    @ObservedObject private var fontSizeStore = FontSizeStore.shared
    @State private var showFontSize = false
    @State private var showShare = false
    @State private var copyConfirmed = false

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
            ToolbarItemGroup(placement: .primaryAction) {
                if let note = viewModel.currentNote {
                    #if targetEnvironment(macCatalyst)
                    Button {
                        UIPasteboard.general.string = note.fullShareText
                        copyConfirmed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copyConfirmed = false }
                    } label: {
                        Image(systemName: copyConfirmed ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copyConfirmed ? .green : .primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .help(copyConfirmed ? "Copied!" : "Copy study note to clipboard")
                    #else
                    Button { showShare.toggle() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .popover(isPresented: $showShare, arrowEdge: .top) {
                        ShareOptionsPopover(note: note)
                    }
                    #endif
                }
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

// MARK: - Share options popover

private struct ShareOptionsPopover: View {
    let note: StudyNote
    @Environment(\.appColors) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var includeVerse = true
    @State private var includeContext = true
    @State private var includeApplications = true
    @State private var includeHistory = true
    @State private var includeCrossRefs = false
    @State private var copyConfirmed = false

    private var shareText: String {
        var sections: [String] = []
        let divider = String(repeating: "─", count: 32)

        sections.append("📖  \(note.reference.displayTitle)")
        sections.append(divider)

        if includeVerse, let verseText = note.verseText {
            sections.append(verseText)
            sections.append(divider)
        }

        if includeContext, !note.context.isEmpty {
            sections.append("CONTEXT\n\n\(note.context)")
        }

        if includeApplications, !note.applications.isEmpty {
            let numbered = note.applications.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n\n")
            sections.append("APPLICATIONS\n\n\(numbered)")
        }

        if includeHistory, !note.historicalBackground.isEmpty {
            sections.append("HISTORICAL BACKGROUND\n\n\(note.historicalBackground)")
        }

        if includeCrossRefs, !note.crossReferences.isEmpty {
            let refs = note.crossReferences.map { ref in
                ref.explanation.isEmpty
                    ? "• \(ref.reference)"
                    : "• \(ref.reference) — \(ref.explanation)"
            }.joined(separator: "\n")
            sections.append("CROSS-REFERENCES\n\n\(refs)")
        }

        sections.append(divider)
        sections.append("Shared from Daily Kairos")
        return sections.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Share Study Note")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Divider()

            VStack(spacing: 0) {
                if note.verseText != nil {
                    ShareToggleRow(label: "Verse Text", icon: "text.quote", isOn: $includeVerse)
                    Divider().padding(.leading, 48)
                }
                ShareToggleRow(label: "Context", icon: "scroll", isOn: $includeContext)
                Divider().padding(.leading, 48)
                ShareToggleRow(label: "Applications", icon: "lightbulb", isOn: $includeApplications)
                Divider().padding(.leading, 48)
                ShareToggleRow(label: "Historical Background", icon: "building.columns", isOn: $includeHistory)
                Divider().padding(.leading, 48)
                ShareToggleRow(label: "Cross-References", icon: "link", isOn: $includeCrossRefs)
            }

            Divider()
                .padding(.top, 4)

            #if targetEnvironment(macCatalyst)
            Button {
                UIPasteboard.general.string = shareText
                copyConfirmed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
            } label: {
                Label(copyConfirmed ? "Copied!" : "Copy to Clipboard",
                      systemImage: copyConfirmed ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(copyConfirmed ? .green : colors.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            #else
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(colors.accent)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            #endif
        }
        .frame(minWidth: 300)
        .presentationCompactAdaptation(.popover)
    }
}

private struct ShareToggleRow: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    @Environment(\.appColors) private var colors

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack {
                Label(label, systemImage: icon)
                    .font(.body)
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? colors.accent : Color(.tertiaryLabel))
                    .animation(.spring(duration: 0.2), value: isOn)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
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
