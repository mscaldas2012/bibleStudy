/// WelcomeView.swift
/// Onboarding sheet shown on every launch until the user opts out.
/// Can always be reopened from Settings → About Daily Kairos.

import SwiftUI
import FoundationModels

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("has_seen_welcome_v1") private var hasSeenWelcome = false
    @State private var store = LLMProviderStore.shared

    private var colors: AppColors {
        switch ThemeStore.shared.mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return AppColors.resolved(for: colorScheme)
        }
    }

    private var esvKeyIsSet: Bool {
        if let key = KeychainService.loadESVKey(), !key.isEmpty { return true }
        return false
    }

    private var needsAIProviderSetup: Bool {
        #if targetEnvironment(simulator)
        return store.activeConfig == nil
        #else
        return !SystemLanguageModel.default.isAvailable && store.activeConfig == nil
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {

                    // ── Hero ──────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome to\nDaily Kairos")
                            .font(.largeTitle.bold())
                            .lineSpacing(2)

                        Text("Daily Kairos is your personal Bible study companion. Type any reference — like *John 3:16* or *The Prodigal Son* — and get the passage text, context, historical background, and cross-references in seconds.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }

                    Divider()

                    // ── Cards section ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What You'll See")
                            .font(.title3.bold())

                        Text("Each lookup fills in a set of study cards, one by one as they're ready.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        if needsAIProviderSetup {
                            AIProviderSetupCard()
                        }

                        if esvKeyIsSet {
                            WelcomeCardRow(
                                icon: "text.book.closed",
                                title: "ESV — Verse Text",
                                description: "The actual Bible text for shorter passages, straight from the English Standard Version.",
                                isAI: false
                            )
                        } else {
                            ESVSetupCard()
                        }

                        WelcomeCardRow(
                            icon: "scroll",
                            title: "Context",
                            description: "What's happening around this passage — who's speaking, what led up to it, and why it matters within the bigger story of Scripture.",
                            isAI: true
                        )

                        WelcomeCardRow(
                            icon: "sparkles",
                            title: "Applications",
                            description: "Practical ways to bring this passage into your daily life — things to reflect on, pray about, or act on.",
                            isAI: true
                        )

                        WelcomeCardRow(
                            icon: "building.columns",
                            title: "Historical Background",
                            description: "The world behind the text — culture, geography, and customs that shaped what was written and how it was understood.",
                            isAI: true
                        )

                        WelcomeCardRow(
                            icon: "link",
                            title: "Cross-References",
                            description: "Related passages from across the Bible that echo the same theme or teaching. Tap any entry to study it on its own.",
                            isAI: true
                        )
                    }

                    Divider()

                    // ── AI note ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(colors.accent)
                            Text("A Note on AI")
                                .font(.title3.bold())
                        }

                        Text("Cards marked with a sparkle (✦) are generated by AI. They're a helpful starting point — thoughtful and usually reliable, but not infallible. Always weigh what you read against trusted sources and your own study.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }

                    Divider()

                    // ── Streak note ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("🔥")
                            Text("Daily Streaks")
                                .font(.title3.bold())
                        }

                        Text("Daily Kairos tracks how many days in a row you study. Miss a day? You'll earn Freeze Tokens over time that automatically protect your streak — so one busy day doesn't erase your progress.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }

                    Divider()

                    // ── Do not show again ─────────────────────────────────
                    Toggle(isOn: Binding(
                        get: { hasSeenWelcome },
                        set: { newValue in
                            hasSeenWelcome = newValue
                            if newValue { dismiss() }
                        }
                    )) {
                        Text("Don't show this on startup")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 4)

                    // ── CTA ───────────────────────────────────────────────
                    Button {
                        dismiss()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(colors.background.ignoresSafeArea())
            .navigationTitle("Daily Kairos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .environment(\.appColors, colors)
        .tint(colors.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - AI provider setup card

private struct AIProviderSetupCard: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colors.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Features")
                        .font(.subheadline.bold())
                    Text("One-time setup required")
                        .font(.caption)
                        .foregroundStyle(colors.accent.opacity(0.8))
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("This device doesn't support Apple Intelligence. To use AI-generated study cards, connect an external AI provider:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Tap Settings (⚙️ top right)", systemImage: "1.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Label("Tap \"AI Provider\"", systemImage: "2.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Label("Add Anthropic, OpenAI, Gemini, or a custom provider", systemImage: "3.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(colors.accent)
            }
        }
        .padding(14)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.accent.opacity(0.35), lineWidth: 1.5))
        .shadow(color: colors.accent.opacity(0.12), radius: 6, x: 0, y: 2)
    }
}

// MARK: - ESV setup card

private let esvSignupURL = URL(string: "https://api.esv.org/login/?next=/account/create-application/")!

private struct ESVSetupCard: View {
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colors.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ESV — Verse Text")
                        .font(.subheadline.bold())
                    Text("One-time setup required")
                        .font(.caption)
                        .foregroundStyle(colors.accent.opacity(0.8))
                }
                Spacer()
            }

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("To display actual Bible text you need a free ESV API key (takes about a minute to create):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Create a free account at api.esv.org", systemImage: "1.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Label("Copy your API key", systemImage: "2.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Label("Paste it in Settings (⚙️ top right)", systemImage: "3.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(colors.accent)

                Link(destination: esvSignupURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Get your free ESV API key")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(colors.accent, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(colors.accent.opacity(0.35), lineWidth: 1.5))
        .shadow(color: colors.accent.opacity(0.12), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Card row

private struct WelcomeCardRow: View {
    let icon: String
    let title: String
    let description: String
    let isAI: Bool
    @Environment(\.appColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(colors.accent.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(colors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.bold())
                    if isAI {
                        Label("AI", systemImage: "sparkles")
                            .font(.caption2.bold())
                            .foregroundStyle(colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colors.accent.opacity(0.10), in: Capsule())
                    }
                    Spacer()
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}
