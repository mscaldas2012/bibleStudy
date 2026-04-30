/// SettingsView.swift
/// Settings sheet — API key, AI provider, appearance, and streak options.

import SwiftUI
import FoundationModels

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var activeProviderLabel: String {
        if let name = LLMProviderStore.shared.activeConfig?.displayName { return name }
        #if targetEnvironment(simulator)
        return "None"
        #else
        return SystemLanguageModel.default.isAvailable ? "On-Device AI" : "None"
        #endif
    }

    private var colors: AppColors {
        switch ThemeStore.shared.mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return AppColors.resolved(for: colorScheme)
        }
    }
    @State private var apiKey: String = ""
    @State private var isKeyStored = false
    @State private var saveStatus: SaveStatus = .idle
    @State private var showProviderSettings = false
    @State private var showAbout = false

    enum SaveStatus { case idle, saved }

    private var streakStatusRow: some View {
        let streak = StreakStore.shared.data
        return HStack {
            Label("Current streak", systemImage: "calendar")
            Spacer()
            HStack(spacing: 6) {
                Text("\(streak.currentStreak) day\(streak.currentStreak == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                if streak.longestStreak > streak.currentStreak {
                    Text("· best \(streak.longestStreak)")
                        .foregroundStyle(.secondary)
                }
                if streak.freezeTokens > 0 {
                    Label("\(streak.freezeTokens)", systemImage: "snowflake")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
            .font(.caption)
        }
    }

    var body: some View {
        @Bindable var themeStore = ThemeStore.shared

        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("", selection: $themeStore.mode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        showProviderSettings = true
                    } label: {
                        HStack {
                            Label("AI Provider", systemImage: "brain")
                            Spacer()
                            Text(activeProviderLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        showAbout = true
                    } label: {
                        HStack {
                            Label("About Daily Kairos", systemImage: "info.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Link(destination: URL(string: "https://simplifylife2026.github.io/dailykairos")!) {
                        HStack {
                            Label("Help", systemImage: "questionmark.circle")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    SecureField("Paste API key here", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("ESV API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Required to display verse text. Free to create.")
                        Link("Get your key at api.esv.org →",
                             destination: URL(string: "https://api.esv.org/login/?next=/account/create-application/")!)
                            .foregroundStyle(colors.accent)
                    }
                }

                if isKeyStored {
                    Section {
                        Button("Remove Saved Key", role: .destructive) {
                            KeychainService.deleteESVKey()
                            apiKey = ""
                            isKeyStored = false
                            saveStatus = .idle
                        }
                    }
                }

                if saveStatus == .saved {
                    Label("Key saved securely.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scripture quotations are from the ESV® Bible (The Holy Bible, English Standard Version®), copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                        Link("www.esv.org", destination: URL(string: "https://www.esv.org")!)
                            .font(.caption)
                            .foregroundStyle(colors.accent)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Scripture Text")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { !StreakStore.shared.data.suppressCelebrations },
                        set: { StreakStore.shared.setSuppressCelebrations(!$0) }
                    )) {
                        Label("Show Streak Celebrations", systemImage: "flame")
                    }
                    streakStatusRow
                } header: {
                    Text("Streak")
                } footer: {
                    Text("A celebration appears on your first daily lookup once your streak reaches 3 or more days.")
                }
            }
            .scrollContentBackground(colorScheme == .dark ? .visible : .hidden)
            .background(colorScheme == .light ? colors.background.ignoresSafeArea() : nil)
            .tint(colors.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        KeychainService.saveESVKey(trimmed)
                        isKeyStored = true
                        saveStatus = .saved
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let stored = KeychainService.loadESVKey(), !stored.isEmpty {
                    apiKey = stored
                    isKeyStored = true
                }
            }
            .sheet(isPresented: $showProviderSettings) {
                LLMProviderSettingsView()
            }
            .sheet(isPresented: $showAbout) {
                WelcomeView()
            }
        }
        .environment(\.appColors, colors)
    }
}
