/// AnthropicSetupView.swift
/// Guided onboarding for Anthropic Claude.

import SwiftUI

struct AnthropicSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let editing: LLMProviderConfig?

    @State private var apiKey    = ""
    @State private var model     = AnthropicModels.defaultModel
    @State private var customModel = ""
    @State private var useCustom = false
    @State private var verifyState: VerifyState = .idle
    @State private var configID  = UUID()

    enum VerifyState { case idle, verifying, success(String), failure(String) }

    private var selectedModel: String { useCustom ? customModel : model }

    var body: some View {
        NavigationStack {
            Form {
                // Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("An API key gives Daily Kairos access to Claude models on your Anthropic account. Usage is billed to your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link("Get a key at console.anthropic.com →",
                             destination: URL(string: "https://console.anthropic.com")!)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                // API Key
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: { Text("API Key") }

                // Model
                Section {
                    Picker("Model", selection: $model) {
                        ForEach(AnthropicModels.curated, id: \.id) { m in
                            Text(m.label).tag(m.id)
                        }
                    }
                    Toggle("Use custom model ID", isOn: $useCustom)
                    if useCustom {
                        TextField("claude-…", text: $customModel)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: { Text("Model") }

                // Verify result
                if case .success(let msg) = verifyState {
                    Section {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                if case .failure(let msg) = verifyState {
                    Section {
                        Label(msg, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Anthropic" : "Edit Anthropic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .verifying = verifyState {
                        ProgressView()
                    } else {
                        Button("Verify & Save") { Task { await verifyAndSave() } }
                            .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty ||
                                      (useCustom && customModel.trimmingCharacters(in: .whitespaces).isEmpty))
                    }
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard let cfg = editing else { return }
        configID  = cfg.id
        model     = AnthropicModels.curated.contains(where: { $0.id == cfg.model }) ? cfg.model : AnthropicModels.defaultModel
        useCustom = !AnthropicModels.curated.contains(where: { $0.id == cfg.model })
        customModel = useCustom ? cfg.model : ""
        apiKey = LLMProviderStore.shared.loadKey(for: cfg)
    }

    private func verifyAndSave() async {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        verifyState = .verifying

        var cfg = LLMProviderConfig(type: .anthropic,
                                    displayName: "Anthropic Claude",
                                    model: selectedModel)
        cfg.id = configID

        let provider = AnthropicProvider(config: cfg, apiKey: key)
        do {
            let msg = try await provider.verify()
            LLMProviderStore.shared.save(config: cfg, apiKey: key)
            LLMProviderStore.shared.activate(cfg.id)
            verifyState = .success(msg)
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch let e as LLMError {
            verifyState = .failure(e.errorDescription ?? "Unknown error")
        } catch {
            verifyState = .failure(error.localizedDescription)
        }
    }
}
