/// StudyNoteView.swift
/// Scrollable study note layout with verse text, context, and application cards.

import SwiftUI

struct StudyNoteView: View {
    let note: StudyNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Verse text (short passages only)
                if let text = note.verseText {
                    VerseTextCard(text: text)
                }

                // Context
                StudyCard(
                    icon: "scroll",
                    title: "Context",
                    accentColor: .blue
                ) {
                    Text(note.context)
                        .font(.body)
                        .lineSpacing(5)
                }

                // Applications
                StudyCard(
                    icon: "lightbulb",
                    title: "Applications",
                    accentColor: .orange
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(note.applications.enumerated()), id: \.offset) { idx, app in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(idx + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(.orange, in: .circle)
                                Text(app)
                                    .font(.body)
                                    .lineSpacing(4)
                            }
                        }
                    }
                }

                // Phase 2 placeholder — historical background & cross-references
                Phase2PlaceholderCard()
            }
            .padding()
        }
    }
}

// MARK: - Verse text card

private struct VerseTextCard: View {
    let text: String

    var body: some View {
        GroupBox {
            Text(text)
                .font(.body)
                .italic()
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("ESV", systemImage: "text.book.closed")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Generic study card

private struct StudyCard<Content: View>: View {
    let icon: String
    let title: String
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(accentColor)
        }
    }
}

// MARK: - Phase 2 placeholder

private struct Phase2PlaceholderCard: View {
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Historical background and cross-references will appear here in a future update.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Coming Soon", systemImage: "clock.badge.questionmark")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}
