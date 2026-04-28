/// AnthropicSetupView.swift
/// Guided onboarding for Anthropic Claude.

import SwiftUI

struct AnthropicSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let editing: LLMProviderConfig?

    @State private var apiKey     = ""
    @State private var model      = AnthropicModels.defaultModel
    @State private var verifyState: VerifyState = .idle
    @State private var configID   = UUID()

    @State private var fetchedModels: [String] = []
    @State private var isFetchingModels = false

    enum VerifyState { case idle, verifying, success(String), failure(String) }

    private var pickerModels: [(id: String, label: String)] {
        fetchedModels.map { (id: $0, label: $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
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

                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: apiKey) { _, newKey in
                            let trimmed = newKey.trimmingCharacters(in: .whitespaces)
                            guard trimmed.count > 20 else {
                                fetchedModels = []
                                return
                            }
                            Task { await fetchModels(key: trimmed) }
                        }
                } header: { Text("API Key") }

                Section {
                    if isFetchingModels {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Loading available models…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } else if fetchedModels.isEmpty {
                        Text("Enter your API key above to see available models.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Picker("Model", selection: $model) {
                            ForEach(pickerModels, id: \.id) { m in
                                Text(m.label).tag(m.id)
                            }
                        }
                    }
                } header: { Text("Model") }

                if case .success(let msg) = verifyState {
                    Section { Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                if case .failure(let msg) = verifyState {
                    Section { Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle(editing == nil ? "Add Anthropic" : "Edit Anthropic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if case .verifying = verifyState { ProgressView() }
                    else {
                        Button("Verify & Save") { Task { await verifyAndSave() } }
                            .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear { prefill() }
        }
    }

    private func fetchModels(key: String) async {
        isFetchingModels = true
        let tempCfg = LLMProviderConfig(type: .anthropic, displayName: "", model: model)
        let provider = AnthropicProvider(config: tempCfg, apiKey: key)
        let models = (try? await provider.fetchAvailableModels()) ?? []
        isFetchingModels = false
        guard !models.isEmpty else { return }
        fetchedModels = models
        if !models.contains(model) {
            model = AnthropicModels.preferredModel(from: models)
        }
    }

    private func prefill() {
        guard let cfg = editing else { return }
        configID = cfg.id
        model    = cfg.model
        apiKey   = LLMProviderStore.shared.loadKey(for: cfg)
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty { Task { await fetchModels(key: key) } }
    }

    private func verifyAndSave() async {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        verifyState = .verifying
        var cfg = LLMProviderConfig(type: .anthropic, displayName: "Anthropic Claude", model: model)
        cfg.id = configID
        let provider = AnthropicProvider(config: cfg, apiKey: key)
        do {
            let msg = try await provider.verify()
            LLMProviderStore.shared.save(config: cfg, apiKey: key)
            LLMProviderStore.shared.activate(cfg.id)
            verifyState = .success(msg)
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch let e as LLMError { verifyState = .failure(e.errorDescription ?? "Unknown error") }
          catch { verifyState = .failure(error.localizedDescription) }
    }
}
