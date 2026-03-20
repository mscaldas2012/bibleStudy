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

    func startRecording() throws {
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

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true   // keep it local

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
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

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
