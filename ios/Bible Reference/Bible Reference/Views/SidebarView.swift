/// SidebarView.swift
/// Left panel: reference input with keyboard and microphone support.

import SwiftUI
import Speech

struct SidebarView: View {
    @Environment(StudyViewModel.self) private var viewModel
    @FocusState private var fieldFocused: Bool
    @State private var showSettings = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bible Study")
                        .font(.largeTitle.bold())
                    Text("Enter a reference to begin")
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

                        MicButton()
                    }

                    // Live transcript while recording
                    if viewModel.isSpeechRecording, !viewModel.liveTranscript.isEmpty {
                        Text(viewModel.liveTranscript)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .transition(.opacity)
                    }

                    // Speech error
                    if let speechError = viewModel.speechError {
                        Text(speechError)
                            .font(.caption)
                            .foregroundStyle(.red)
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
                .controlSize(.large)
                .disabled(
                    viewModel.referenceInput.trimmingCharacters(in: .whitespaces).isEmpty
                    || viewModel.isLoading
                )

                // Tip
                VStack(alignment: .leading, spacing: 6) {
                    Text("Examples")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ForEach(["John 3:16", "Psalm 23", "Matthew 5:3-12", "Romans 8"], id: \.self) { example in
                        Button(example) {
                            vm.referenceInput = example
                            fieldFocused = false
                            Task { await viewModel.submit() }
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .task { await viewModel.requestSpeechPermission() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

// MARK: - Mic button

private struct MicButton: View {
    @Environment(StudyViewModel.self) private var viewModel

    var body: some View {
        // Speech input is only available on physical iPad — not Mac (Designed for iPad)
        if viewModel.isSpeechSupported {
            button
        }
    }

    private var button: some View {
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
