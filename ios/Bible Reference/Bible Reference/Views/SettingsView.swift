/// SettingsView.swift
/// Settings sheet — currently hosts ESV API key management.

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var isKeyStored = false
    @State private var saveStatus: SaveStatus = .idle

    enum SaveStatus { case idle, saved }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Paste API key here", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("ESV API Key")
                } footer: {
                    Text("Free key available at api.esv.org — required to display verse text.")
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
            }
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
        }
    }
}
