/// SpeechService.swift
/// Wraps SFSpeechRecognizer for live transcription of Bible references.

import Foundation
import Speech
import AVFoundation
import Observation

@Observable
final class SpeechService {
    var transcript: String = ""
    var isRecording: Bool = false
    var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var error: String? = nil

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Permissions

    func requestPermission() async {
        permissionStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Recording

    /// True when speech input is supported on this platform.
    var isSupported: Bool {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return false
        #else
        return true
        #endif
    }

    func startRecording() throws {
        #if targetEnvironment(macCatalyst) || os(macOS)
        error = "Speech input is not available when running on Mac. Use the text field to type your reference, then press Return."
        return
        #endif

        guard permissionStatus == .authorized else {
            error = "Speech recognition permission denied. Enable it in Settings."
            return
        }
        guard recognizer?.isAvailable == true else {
            error = "Speech recognizer is not available right now."
            return
        }

        stopRecording()
        error = nil
        transcript = ""

        #if !targetEnvironment(macCatalyst) && !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        // On-device recognition preferred but not required — fall back to server if unavailable
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode
        // Pass nil format so AVAudio picks the native format — required on macOS
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, err in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if err != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        #if !targetEnvironment(macCatalyst) && !os(macOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
