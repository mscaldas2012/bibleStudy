/// OpenAISetupView.swift
/// Guided onboarding for OpenAI.

import SwiftUI

struct OpenAISetupView: View {
    @Environment(\.dismiss) private var dismiss
    let editing: LLMProviderConfig?

    @State private var apiKey     = ""
    @State private var orgId      = ""
    @State private var model      = OpenAIModels.defaultModel
    @State private var customModel = ""
    @State private var useCustom  = false
    @State private var showOrgTip = false
    @State private var verifyState: VerifyState = .idle
    @State private var configID   = UUID()

    enum VerifyState { case idle, verifying, success(String), failure(String) }
    private var selectedModel: String { useCustom ? customModel : model }

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
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                } header: { Text("API Key") }

                Section {
                    HStack {
                        TextField("Optional", text: $orgId)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        Button {
                            showOrgTip.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if showOrgTip {
                        Text("Only needed if you belong to multiple OpenAI organizations.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: { Text("Organization ID (optional)") }

                Section {
                    Picker("Model", selection: $model) {
                        ForEach(OpenAIModels.curated, id: \.id) { m in
                            Text(m.label).tag(m.id)
                        }
                    }
                    Toggle("Use custom model ID", isOn: $useCustom)
                    if useCustom {
                        TextField("gpt-…", text: $customModel)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
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
                            .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty ||
                                      (useCustom && customModel.trimmingCharacters(in: .whitespaces).isEmpty))
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

    private func prefill() {
        guard let cfg = editing else { return }
        configID  = cfg.id
        model     = OpenAIModels.curated.contains(where: { $0.id == cfg.model }) ? cfg.model : OpenAIModels.defaultModel
        useCustom = !OpenAIModels.curated.contains(where: { $0.id == cfg.model })
        customModel = useCustom ? cfg.model : ""
        orgId     = cfg.orgId
        apiKey    = LLMProviderStore.shared.loadKey(for: cfg)
    }

    private func verifyAndSave() async {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        verifyState = .verifying
        var cfg = LLMProviderConfig(type: .openAI, displayName: "OpenAI", model: selectedModel)
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
        } catch let e as LLMError { verifyState = .failure(e.errorDescription ?? "Unknown error")
        } catch { verifyState = .failure(error.localizedDescription) }
    }
}
