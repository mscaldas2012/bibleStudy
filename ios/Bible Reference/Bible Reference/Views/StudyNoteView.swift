/// StudyNoteView.swift
/// Scrollable study note layout. Cards appear progressively as each
/// section's AI generation completes.

import SwiftUI

struct StudyNoteView: View {
    let note: StudyNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Verse text (short passages only)
                if let text = note.verseText {
                    VerseTextCard(text: text)
                } else if note.esvKeyMissing {
                    ESVKeyPromptCard()
                }

                // Context
                StudyCard(
                    icon: "scroll",
                    title: "Context",
                    accentColor: .blue,
                    aiGenerated: true
                ) {
                    if note.context.isEmpty {
                        SectionLoadingView()
                    } else {
                        Text(note.context)
                            .font(.body)
                            .lineSpacing(5)
                            .transition(.opacity)
                    }
                }
                .animation(.easeIn(duration: 0.4), value: note.context.isEmpty)

                // Applications
                StudyCard(
                    icon: "lightbulb",
                    title: "Applications",
                    accentColor: .orange,
                    aiGenerated: true
                ) {
                    if note.applications.isEmpty {
                        SectionLoadingView()
                    } else {
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
                        .transition(.opacity)
                    }
                }
                .animation(.easeIn(duration: 0.4), value: note.applications.isEmpty)

                // Historical background — shows spinner until content arrives
                HistoricalBackgroundCard(text: note.historicalBackground)

                // Cross-references — shows spinner until cross-ref phase finishes
                CrossReferencesCard(refs: note.crossReferences, loaded: note.crossRefsLoaded)

                // Disclaimer
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("AI-generated content may contain errors. Always verify with trusted sources.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
            .padding()
            .textSelection(.enabled)
        }
    }
}

// MARK: - Verse text card

private struct VerseTextCard: View {
    let text: String

    var body: some View {
        GroupBox {
            ScrollView {
                Text(text)
                    .font(.body)
                    .italic()
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .frame(maxHeight: 400)
        } label: {
            Label("ESV", systemImage: "text.book.closed")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - ESV key prompt card

private struct ESVKeyPromptCard: View {
    @State private var showSettings = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add your free ESV API key to view passage text.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Open Settings") { showSettings = true }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("ESV", systemImage: "text.book.closed")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

// MARK: - Generic study card

private struct StudyCard<Content: View>: View {
    let icon: String
    let title: String
    let accentColor: Color
    var aiGenerated: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(spacing: 4) {
                if aiGenerated {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(accentColor)
            }
        }
    }
}

// MARK: - Historical background card

private struct HistoricalBackgroundCard: View {
    let text: String

    var body: some View {
        StudyCard(
            icon: "building.columns",
            title: "Historical Background",
            accentColor: Color(red: 0.6, green: 0.35, blue: 0.1),
            aiGenerated: true
        ) {
            if text.isEmpty {
                SectionLoadingView()
            } else {
                Text(text)
                    .font(.body)
                    .lineSpacing(5)
                    .transition(.opacity)
            }
        }
        .animation(.easeIn(duration: 0.4), value: text.isEmpty)
    }
}

// MARK: - Cross-references card

private struct CrossReferencesCard: View {
    let refs: [CrossRef]
    let loaded: Bool    // true once the cross-ref phase is done (refs may still be empty)

    var body: some View {
        // Hide only after loading finishes and TSK found nothing
        if !loaded || !refs.isEmpty {
            StudyCard(icon: "link", title: "Cross-References", accentColor: .green, aiGenerated: true) {
                if !loaded {
                    SectionLoadingView()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(refs.enumerated()), id: \.element.id) { idx, ref in
                            NavigationLink(value: ref.reference) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(ref.reference)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    if !ref.explanation.isEmpty {
                                        Text(ref.explanation)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .lineSpacing(4)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if idx < refs.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeIn(duration: 0.4), value: loaded)
        }
    }
}

// MARK: - Inline loading placeholder

private struct SectionLoadingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Generating…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
