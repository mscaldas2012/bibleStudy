/// StudyNoteView.swift
/// Scrollable study note layout. Cards appear progressively as each
/// section's AI generation completes.

import SwiftUI

struct StudyNoteView: View {
    let note: StudyNote
    @Environment(\.appColors) private var colors
    @ObservedObject private var fontSizeStore = FontSizeStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Verse text — always shown; multi-chapter refs display the first chapter
                if let text = note.verseText {
                    VerseTextCard(text: text, reference: note.reference)
                } else if note.esvKeyMissing {
                    ESVKeyPromptCard()
                } else if let err = note.esvError {
                    ESVErrorCard(message: err)
                }

                // Context
                StudyCard(
                    icon: "scroll",
                    title: "Context",
                    accentColor: colors.accent,
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
                    accentColor: colors.accent,
                    aiGenerated: false
                ) {
                    if note.contextError != nil {
                        EmptyView()
                    } else if note.applications.isEmpty {
                        SectionLoadingView()
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(note.applications.enumerated()), id: \.offset) { idx, app in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(idx + 1)")
                                        .studyFont(15, weight: .bold)
                                        .foregroundStyle(colors.accent)
                                        .frame(width: 26, height: 26)
                                        .overlay(Circle().stroke(colors.accent.opacity(0.5), lineWidth: 1.5))
                                    SelectableText(text: app, lineSpacing: 4)
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeIn(duration: 0.4), value: note.applications.isEmpty)

                // Historical background
                HistoricalBackgroundCard(text: note.historicalBackground, error: note.historyError)

                // Cross-references
                CrossReferencesCard(refs: note.crossReferences, loaded: note.crossRefsLoaded, error: note.crossRefError)

                // Disclaimer
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .studyFont(11)
                        .foregroundStyle(.tertiary)
                    Text("AI-generated content may contain errors. Always verify with trusted sources.")
                        .studyFont(11)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(colors.background.ignoresSafeArea())
        .dynamicTypeSize(fontSizeStore.currentSize)
    }
}

// MARK: - Verse text card

private struct VerseTextCard: View {
    let text: String
    let reference: BibleReference
    @Environment(\.appColors) private var colors
    @ObservedObject private var fontSizeStore = FontSizeStore.shared

    private static let verseFont: UIFont =
        UIFont(name: "Georgia-Italic", size: 17) ?? .preferredFont(forTextStyle: .body)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            colors.accent
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(reference.displayTitle.uppercased())
                        .studyFont(12, weight: .bold)
                        .foregroundStyle(colors.accent.opacity(0.75))
                        .tracking(0.8)
                    Spacer()
                    Link("ESV®", destination: URL(string: "https://www.esv.org")!)
                        .studyFont(12, weight: .bold)
                        .foregroundStyle(colors.accent.opacity(0.75))
                }

                ScrollView {
                    SelectableText(text: text, font: Self.verseFont, lineSpacing: 7,
                                   color: colors.verseTextUIColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                }
                .frame(maxHeight: 400)

                Text("© 2001 Crossway. All rights reserved.")
                    .studyFont(11)
                    .foregroundStyle(colors.accent.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

// MARK: - ESV error card

private struct ESVErrorCard: View {
    let message: String
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            colors.accent.opacity(0.35)
                .frame(width: 4)

            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .studyFont(15)
                    .foregroundStyle(colors.accent.opacity(0.7))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ESV · Could not load passage text")
                        .studyFont(12, weight: .bold)
                        .foregroundStyle(colors.accent.opacity(0.75))
                        .tracking(0.8)
                    Text(message)
                        .studyFont(12)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

// MARK: - ESV key prompt card

private struct ESVKeyPromptCard: View {
    @State private var showSettings = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add your free ESV API key to view passage text.")
                    .studyFont(15)
                    .foregroundStyle(.secondary)
                Button("Open Settings") { showSettings = true }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("ESV", systemImage: "text.book.closed")
                .studyFont(12, weight: .bold)
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
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .studyFont(15, weight: .semibold)
                    .foregroundStyle(accentColor)
                Text(title)
                    .studyFont(17, weight: .semibold)
                    .foregroundStyle(accentColor)
                if aiGenerated {
                    Image(systemName: "sparkles")
                        .studyFont(12)
                        .foregroundStyle(accentColor.opacity(0.5))
                }
            }
            Divider()
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Historical background card

private struct HistoricalBackgroundCard: View {
    let text: String
    var error: String? = nil
    @Environment(\.appColors) private var colors

    var body: some View {
        StudyCard(
            icon: "building.columns",
            title: "Historical Background",
            accentColor: colors.accentSecondary,
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
    let loaded: Bool
    var error: String? = nil

    var body: some View {
        if !loaded || !refs.isEmpty {
            StudyCard(icon: "link", title: "Cross-References", accentColor: .green, aiGenerated: true) {
                if !loaded {
                    SectionLoadingView()
                } else if let err = error, refs.allSatisfy({ $0.explanation.isEmpty }) {
                    AIErrorView(message: err)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(refs.enumerated()), id: \.element.id) { idx, ref in
                            NavigationLink(value: ref.reference) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(ref.reference)
                                            .studyFont(17, weight: .semibold)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .studyFont(11)
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
                .studyFont(15)
            Text(message)
                .studyFont(15)
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
                .studyFont(15)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct StudyScaledFontModifier: ViewModifier {
    @ObservedObject private var fontSizeStore = FontSizeStore.shared

    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(.system(size: fontSizeStore.scaled(size), weight: weight))
    }
}

private extension View {
    func studyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(StudyScaledFontModifier(size: size, weight: weight))
    }
}
