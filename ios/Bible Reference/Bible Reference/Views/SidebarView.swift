/// SidebarView.swift
/// Left panel: reference input with keyboard, Bible picker, and microphone support.

import SwiftUI
import Speech

struct SidebarView: View {
    @Environment(StudyViewModel.self) private var viewModel
    @Environment(HistoryStore.self) private var history
    @Environment(\.appColors) private var colors
    @ObservedObject private var fontSizeStore = FontSizeStore.shared
    @FocusState private var fieldFocused: Bool
    @State private var showSettings = false
    @State private var showBiblePicker = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Kairos")
                        .font(.largeTitle.bold())
                    Text("Enter a reference or passage name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Input
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reference")
                        .font(.headline)

                    HStack(spacing: 8) {
                        TextField("e.g. John 3:16, Psalm 23", text: $vm.referenceInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .focused($fieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                fieldFocused = false
                                Task { await viewModel.submit() }
                            }

                        // Bible picker button
                        Button {
                            fieldFocused = false
                            showBiblePicker = true
                        } label: {
                            Image(systemName: "book.closed")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(.quaternary, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .help("Browse books, chapters, and verses")

                        // Microphone button (iOS only) — hidden for v1
                        // #if !targetEnvironment(macCatalyst) && !os(macOS)
                        // MicButton()
                        // #endif
                    }

                    // Live transcript preview while recording
                    if viewModel.isSpeechRecording, !viewModel.liveTranscript.isEmpty {
                        Text(viewModel.liveTranscript)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .transition(.opacity)
                    }
                }

                // Submit button
                Button {
                    fieldFocused = false
                    Task { await viewModel.submit() }
                } label: {
                    Label("Look Up", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.accent)
                .controlSize(.large)
                .disabled(
                    viewModel.referenceInput.trimmingCharacters(in: .whitespaces).isEmpty
                    || viewModel.isLoading
                )

                // History or examples
                if history.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ExampleGroup(
                            label: "By reference",
                            examples: ["John 3:16", "Psalm 23", "Romans 8", "Matthew 5:3-12"]
                        )
                        ExampleGroup(
                            label: "By name",
                            examples: [
                                "The Shema",
                                "Prodigal Son",
                                "Sermon on the Mount",
                                "Lord's Prayer",
                            ]
                        )
                    }
                } else {
                    HistoryList()
                }

                Spacer()
            }
            .padding()
        }
        .dynamicTypeSize(fontSizeStore.currentSize)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showBiblePicker) {
            BiblePickerView()
                .presentationDetents([.large])
        }
        #if !targetEnvironment(macCatalyst) && !os(macOS)
        .task { await viewModel.requestSpeechPermission() }
        #endif
    }
}

// MARK: - Mic button (iOS only)

#if !targetEnvironment(macCatalyst) && !os(macOS)
private struct MicButton: View {
    @Environment(StudyViewModel.self) private var viewModel

    var body: some View {
        Button {
            viewModel.toggleRecording()
        } label: {
            Image(systemName: viewModel.isSpeechRecording ? "mic.fill" : "mic")
                .font(.title3)
                .foregroundStyle(viewModel.isSpeechRecording ? .red : .secondary)
                .symbolEffect(.pulse, isActive: viewModel.isSpeechRecording)
                .frame(width: 36, height: 36)
                .background(.quaternary, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.speechPermission == .denied)
        .help(viewModel.speechPermission == .denied
              ? "Speech recognition denied — enable in Settings"
              : "Tap to dictate a reference")
    }
}
#endif

// MARK: - Example group

private struct ExampleGroup: View {
    @Environment(StudyViewModel.self) private var viewModel
    @Environment(\.appColors) private var colors
    let label: String
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(examples, id: \.self) { example in
                Button(example) {
                    viewModel.referenceInput = example
                    Task { await viewModel.submit() }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(colors.accent)
            }
        }
    }
}

// MARK: - History list

private struct HistoryList: View {
    @Environment(StudyViewModel.self) private var viewModel
    @Environment(HistoryStore.self) private var history
    @Environment(\.appColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(history.entries.enumerated()), id: \.element.id) { idx, entry in
                    if idx > 0 {
                        Divider().padding(.leading, 52)
                    }
                    HistoryRow(entry: entry) {
                        Task { await viewModel.submitHistory(entry) }
                    }
                }
            }
            .background(colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let action: () -> Void
    @Environment(\.appColors) private var colors

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(entry.timestamp)     { return "Today" }
        if cal.isDateInYesterday(entry.timestamp) { return "Yesterday" }
        return entry.timestamp.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colors.accent.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: "book.closed")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(colors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(dateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

