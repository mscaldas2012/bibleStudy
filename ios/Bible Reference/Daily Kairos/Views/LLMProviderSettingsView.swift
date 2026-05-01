/// LLMProviderSettingsView.swift
/// Main screen for managing LLM provider configurations.

import SwiftUI
import FoundationModels

struct LLMProviderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = LLMProviderStore.shared
    @State private var showAddSheet: ProviderType? = nil
    @State private var editConfig: LLMProviderConfig? = nil

    private var appleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Active section
                Section {
                    HStack {
                        Image(systemName: activeIconName)
                            .foregroundStyle(store.activeConfig == nil && !appleIntelligenceAvailable ? Color.secondary : Color.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading) {
                            if let cfg = store.activeConfig {
                                Text(cfg.displayName)
                                    .fontWeight(.semibold)
                                Text(cfg.model)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if appleIntelligenceAvailable {
                                Text("On-Device AI (Default)")
                                    .fontWeight(.semibold)
                                Text("Runs entirely on your device — no API key required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("None")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Text("Add a provider below to enable AI features")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if store.activeConfig != nil {
                            Button("Reset") { store.deactivate() }
                                .font(.caption)
                                .buttonStyle(.bordered)
                        }
                    }
                } header: { Text("Active Provider") }

                // MARK: Saved providers
                if !store.configs.isEmpty {
                    Section {
                        ForEach(store.configs) { cfg in
                            ProviderRow(cfg: cfg,
                                        isActive: cfg.id == store.activeId,
                                        onActivate: { store.activate(cfg.id) },
                                        onEdit: { editConfig = cfg },
                                        onDelete: { store.remove(cfg) })
                        }
                    } header: { Text("Saved Providers") }
                      footer: { Text("Tap to set active. Swipe for actions.") }
                }

                // MARK: Add provider
                Section {
                    Menu {
                        Button {
                            showAddSheet = .anthropic
                        } label: {
                            Label("Anthropic Claude", systemImage: "sparkles")
                        }
                        Button {
                            showAddSheet = .openAI
                        } label: {
                            Label("OpenAI", systemImage: "brain")
                        }
                        Button {
                            showAddSheet = .googleGemini
                        } label: {
                            Label("Google Gemini", systemImage: "circle.hexagongrid")
                        }
                        Divider()
                        Button {
                            showAddSheet = .custom
                        } label: {
                            Label("Custom / Advanced", systemImage: "server.rack")
                        }
                    } label: {
                        Label("Add Provider", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("AI Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Link(destination: URL(string: "https://simplifylife2026.github.io/dailykairos/setup-apple-intelligence.html")!) {
                        Image(systemName: "questionmark.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $showAddSheet) { type in
                providerSetupView(for: type)
            }
            .sheet(item: $editConfig) { cfg in
                providerSetupView(for: cfg.type, editing: cfg)
            }
        }
    }

    @ViewBuilder
    private func providerSetupView(for type: ProviderType, editing cfg: LLMProviderConfig? = nil) -> some View {
        switch type {
        case .anthropic:       AnthropicSetupView(editing: cfg)
        case .openAI:          OpenAISetupView(editing: cfg)
        case .googleGemini:    GoogleGeminiSetupView(editing: cfg)
        case .custom:          CustomProviderSetupView(editing: cfg)
        case .appleFoundation: EmptyView()
        }
    }

    private var activeIconName: String {
        if let config = store.activeConfig { return config.type.systemIconName }
        return appleIntelligenceAvailable ? "iphone" : "slash.circle"
    }
}

// MARK: - Provider row

private struct ProviderRow: View {
    let cfg: LLMProviderConfig
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: cfg.type.systemIconName)
                .foregroundStyle(isActive ? .blue : .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(cfg.displayName)
                    .fontWeight(isActive ? .semibold : .regular)
                Text(cfg.model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("Edit") { onEdit() }.tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// ProviderType already conforms to Identifiable via its `id` property in LLMProviderConfig.swift
