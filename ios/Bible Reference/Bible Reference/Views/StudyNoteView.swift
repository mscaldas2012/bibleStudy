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
                    VerseTextCard(text: text, reference: note.reference)
                } else if note.esvKeyMissing {
                    ESVKeyPromptCard()
                }

                // Context
                StudyCard(
                    icon: "scroll",
                    title: "Context",
                    accentColor: warmBrown,
                    aiGenerated: true
                ) {
                    if let err = note.contextError {
                        AIErrorView(message: err)
                    } else if note.context.isEmpty {
                        SectionLoadingView()
                    } else {
                        SelectableText(text: note.context)
                            .transition(.opacity)
                    }
                }
                .animation(.easeIn(duration: 0.4), value: note.context.isEmpty)

                // Applications
                StudyCard(
                    icon: "sparkles",
                    title: "Applications",
                    accentColor: warmBrown,
                    aiGenerated: false
                ) {
                    if note.contextError != nil {
                        EmptyView() // error already shown in Context card above
                    } else if note.applications.isEmpty {
                        SectionLoadingView()
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(note.applications.enumerated()), id: \.offset) { idx, app in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(idx + 1)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(warmBrown)
                                        .frame(width: 26, height: 26)
                                        .overlay(Circle().stroke(warmBrown.opacity(0.5), lineWidth: 1.5))
                                    SelectableText(text: app, lineSpacing: 4)
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeIn(duration: 0.4), value: note.applications.isEmpty)

                // Historical background — shows spinner until content arrives
                HistoricalBackgroundCard(text: note.historicalBackground, error: note.historyError)

                // Cross-references — shows spinner until cross-ref phase finishes
                CrossReferencesCard(refs: note.crossReferences, loaded: note.crossRefsLoaded, error: note.crossRefError)

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
        }
        .scrollContentBackground(.hidden)
        .background(parchment.ignoresSafeArea())
    }
}

// MARK: - Verse text card

private let parchment = Color(red: 0xFA / 255.0, green: 0xF6 / 255.0, blue: 0xEF / 255.0)
private let warmBrown = Color(red: 0.45, green: 0.28, blue: 0.08)

private struct VerseTextCard: View {
    let text: String
    let reference: BibleReference

    private static let verseFont: UIFont =
        UIFont(name: "Georgia-Italic", size: 17) ?? .preferredFont(forTextStyle: .body)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            warmBrown
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("ESV · \(reference.displayTitle.uppercased())")
                    .font(.caption.bold())
                    .foregroundStyle(warmBrown.opacity(0.75))
                    .tracking(0.8)

                ScrollView {
                    SelectableText(text: text, font: Self.verseFont, lineSpacing: 7,
                                   color: UIColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                }
                .frame(maxHeight: 400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(parchment)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(warmBrown.opacity(0.15), lineWidth: 1))
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(accentColor)
                if aiGenerated {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(accentColor.opacity(0.5))
                }
            }
            Divider()
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Historical background card

private struct HistoricalBackgroundCard: View {
    let text: String
    var error: String? = nil

    var body: some View {
        StudyCard(
            icon: "building.columns",
            title: "Historical Background",
            accentColor: Color(red: 0.6, green: 0.35, blue: 0.1),
            aiGenerated: true
        ) {
            if let err = error {
                AIErrorView(message: err)
            } else if text.isEmpty {
                SectionLoadingView()
            } else {
                SelectableText(text: text)
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
    var error: String? = nil

    var body: some View {
        // Hide only after loading finishes and TSK found nothing
        if !loaded || !refs.isEmpty {
            StudyCard(icon: "link", title: "Cross-References", accentColor: .green, aiGenerated: true) {
                if !loaded {
                    SectionLoadingView()
                } else if let err = error, refs.allSatisfy({ $0.explanation.isEmpty }) {
                    // Show error only if we have no explanations at all
                    AIErrorView(message: err)
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
                                        SelectableText(text: ref.explanation, lineSpacing: 4, color: .secondaryLabel)
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

// MARK: - Inline AI error

private struct AIErrorView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
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
