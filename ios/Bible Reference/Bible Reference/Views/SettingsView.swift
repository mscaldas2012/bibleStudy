/// SettingsView.swift
/// Settings sheet — currently hosts ESV API key management.

import SwiftUI

private let parchment  = Color(red: 0xFA / 255.0, green: 0xF6 / 255.0, blue: 0xEF / 255.0)
private let warmBrown  = Color(red: 0.45, green: 0.28, blue: 0.08)

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            Form {
                Section {
                    Button {
                        showProviderSettings = true
                    } label: {
                        HStack {
                            Label("AI Provider", systemImage: "brain")
                            Spacer()
                            Text(LLMProviderStore.shared.activeDisplayName)
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
                            .foregroundStyle(warmBrown)
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
                            .foregroundStyle(warmBrown)
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
            .scrollContentBackground(.hidden)
            .background(parchment.ignoresSafeArea())
            .tint(warmBrown)
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
    }
}
