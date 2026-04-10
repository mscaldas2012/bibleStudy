/// CustomProviderSetupView.swift
/// Multi-step wizard for custom / advanced LLM providers.

import SwiftUI

struct CustomProviderSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let editing: LLMProviderConfig?

    @State private var step = 1
    // Step 1
    @State private var displayName = ""
    @State private var baseURL     = ""
    // Step 2
    @State private var proto: CustomProtocol = .openAICompatible
    // Step 3
    @State private var apiKey         = ""
    @State private var authHeaderName = "Authorization"
    @State private var noAuth         = false
    // Step 4
    @State private var model          = ""
    @State private var additionalModels: [String] = []
    @State private var newModel       = ""
    // Verify
    @State private var verifyState: VerifyState = .idle
    @State private var configID       = UUID()

    enum VerifyState { case idle, verifying, success(String), failure(String) }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case 1: step1
                case 2: step2
                case 3: step3
                case 4: step4
                default: EmptyView()
                }

                if case .success(let msg) = verifyState {
                    Section { Label(msg, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                if case .failure(let msg) = verifyState {
                    Section { Label(msg, systemImage: "xmark.circle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == 1 { Button("Cancel") { dismiss() } }
                    else { Button("Back") { step -= 1 } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step < 4 {
                        Button("Next") { step += 1 }
                            .disabled(!stepValid)
                    } else {
                        if case .verifying = verifyState { ProgressView() }
                        else {
                            Button("Verify & Save") { Task { await verifyAndSave() } }
                                .disabled(model.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - Steps

    @ViewBuilder private var step1: some View {
        Section {
            TextField("e.g. Groq, My Local LLM", text: $displayName)
        } header: { Text("Provider Name") }

        Section {
            TextField("https://api.groq.com/openai/v1", text: $baseURL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
        } header: { Text("Base URL") }
          footer: { Text("The root endpoint without a trailing slash or path segment.") }
    }

    @ViewBuilder private var step2: some View {
        Section {
            ForEach(CustomProtocol.allCases) { p in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.displayName).fontWeight(.semibold)
                        Text(p.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if proto == p {
                        Image(systemName: "checkmark").foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { proto = p }
            }
        } header: { Text("API Protocol") }
    }

    @ViewBuilder private var step3: some View {
        Section {
            Toggle("No authentication required", isOn: $noAuth)
        }
        if !noAuth {
            Section {
                TextField("Header name", text: $authHeaderName)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            } header: { Text("Auth Header") }
              footer: { Text("Use 'Authorization' for Bearer tokens, or 'x-api-key' for key-based auth.") }

            Section {
                SecureField("API key / token", text: $apiKey)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
            } header: { Text("Key / Token") }
        }
    }

    @ViewBuilder private var step4: some View {
        Section {
            TextField("Model ID (required)", text: $model)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
        } header: { Text("Primary Model") }

        Section {
            ForEach(additionalModels, id: \.self) { m in
                Text(m)
            }
            .onDelete { offsets in
                additionalModels.remove(atOffsets: offsets)
            }
            HStack {
                TextField("Add another model ID", text: $newModel)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                Button {
                    let m = newModel.trimmingCharacters(in: .whitespaces)
                    guard !m.isEmpty else { return }
                    additionalModels.append(m)
                    newModel = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newModel.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: { Text("Additional Models (optional)") }
          footer: { Text("Pre-populate a list for easy switching later.") }
    }

    // MARK: - Helpers

    private var stepTitle: String {
        switch step {
        case 1: return "Step 1 of 4 — Name & URL"
        case 2: return "Step 2 of 4 — Protocol"
        case 3: return "Step 3 of 4 — Authentication"
        case 4: return "Step 4 of 4 — Model"
        default: return "Custom Provider"
        }
    }

    private var stepValid: Bool {
        switch step {
        case 1: return !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
                       !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
        case 3: return noAuth || !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func prefill() {
        guard let cfg = editing else { return }
        configID      = cfg.id
        displayName   = cfg.displayName
        baseURL       = cfg.baseURL
        proto         = cfg.customProtocol
        authHeaderName = cfg.authHeaderName
        model         = cfg.model
        additionalModels = cfg.additionalModels
        let stored    = LLMProviderStore.shared.loadKey(for: cfg)
        noAuth        = stored.isEmpty && cfg.authHeaderName.isEmpty
        apiKey        = stored
    }

    private func verifyAndSave() async {
        let key = noAuth ? "" : apiKey.trimmingCharacters(in: .whitespaces)
        verifyState = .verifying
        var cfg = LLMProviderConfig(type: .custom,
                                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                                    model: model.trimmingCharacters(in: .whitespaces))
        cfg.id               = configID
        cfg.baseURL          = baseURL.trimmingCharacters(in: .whitespaces)
        cfg.customProtocol   = proto
        cfg.authHeaderName   = noAuth ? "" : authHeaderName
        cfg.additionalModels = additionalModels
        let provider = CustomProvider(config: cfg, apiKey: key)
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
