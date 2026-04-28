/// OpenAISetupView.swift
/// Guided onboarding for OpenAI.

import SwiftUI

struct OpenAISetupView: View {
    @Environment(\.dismiss) private var dismiss
    let editing: LLMProviderConfig?

    @State private var apiKey      = ""
    @State private var orgId       = ""
    @State private var model       = OpenAIModels.defaultModel
    @State private var showOrgTip  = false
    @State private var verifyState: VerifyState = .idle
    @State private var configID    = UUID()

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
                        Text("Connects Daily Kairos to your OpenAI account. Usage is billed to your account.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Link("Get a key at platform.openai.com/api-keys →",
                             destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    SecureField("sk-…", text: $apiKey)
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
                    HStack {
                        TextField("Optional", text: $orgId)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        Button { showOrgTip.toggle() } label: {
                            Image(systemName: "info.circle").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if showOrgTip {
                        Text("Only needed if you belong to multiple OpenAI organizations.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: { Text("Organization ID (optional)") }

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

                verifyResultSection
            }
            .navigationTitle(editing == nil ? "Add OpenAI" : "Edit OpenAI")
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

    @ViewBuilder private var verifyResultSection: some View {
        if case .success(let msg) = verifyState {
            Section { Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
        }
        if case .failure(let msg) = verifyState {
            Section { Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(.red) }
        }
    }

    private func fetchModels(key: String) async {
        isFetchingModels = true
        let tempCfg = LLMProviderConfig(type: .openAI, displayName: "", model: model)
        let provider = OpenAIProvider(config: tempCfg, apiKey: key)
        let models = (try? await provider.fetchAvailableModels()) ?? []
        isFetchingModels = false
        guard !models.isEmpty else { return }
        fetchedModels = models
        if !models.contains(model) {
            model = OpenAIModels.preferredModel(from: models)
        }
    }

    private func prefill() {
        guard let cfg = editing else { return }
        configID = cfg.id
        model    = cfg.model
        orgId    = cfg.orgId
        apiKey   = LLMProviderStore.shared.loadKey(for: cfg)
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty { Task { await fetchModels(key: key) } }
    }

    private func verifyAndSave() async {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        verifyState = .verifying
        var cfg = LLMProviderConfig(type: .openAI, displayName: "OpenAI", model: model)
        cfg.id    = configID
        cfg.orgId = orgId.trimmingCharacters(in: .whitespaces)
        let provider = OpenAIProvider(config: cfg, apiKey: key)
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
