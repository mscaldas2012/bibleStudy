/// TopicCandidateView.swift
/// Shown when a topic lookup resolves to multiple passages (e.g. synoptic parallels).
/// User taps a passage to proceed to the study note.

import SwiftUI

struct TopicCandidateView: View {
    @Environment(StudyViewModel.self) private var viewModel
    let topic: String
    let candidates: [String]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("\"\(topic)\"")
                    .font(.title2.bold())
                Text("Found in multiple passages — choose one to study")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 36)

            // Candidate list
            List(candidates, id: \.self) { ref in
                Button {
                    Task { await viewModel.selectCandidate(ref) }
                } label: {
                    HStack {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text(ref)
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Select Passage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
