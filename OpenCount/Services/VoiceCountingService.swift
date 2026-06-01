import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - VoiceCountingService

/// Enables hands-free counting via voice commands.
///
/// Supported commands (locale-aware):
///   "count" / "add" / "one" / "mark"  → increment selected type
///   "undo" / "remove" / "delete"       → undo last marker
///   "next" / "switch"                  → cycle to next object type
///   "stop" / "done" / "finish"         → stop voice counting
///
/// This feature gives OpenCount a decisive advantage over ZapCount and CountThings,
/// which do not offer voice-driven counting.
///
/// Requirements: Voice Counting (new feature)
@MainActor
final class VoiceCountingService: ObservableObject {

    // MARK: - Published state

    @Published var isListening: Bool = false
    @Published var lastRecognizedCommand: String = ""
    @Published var error: String?
    @Published var isAvailable: Bool = false

    // MARK: - Callbacks

    var onCount: (() -> Void)?
    var onUndo: (() -> Void)?
    var onNextType: (() -> Void)?
    var onStop: (() -> Void)?

    // MARK: - Private

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Command keywords

    private let countKeywords = ["count", "add", "one", "mark", "tap", "plus", "đếm", "thêm"]
    private let undoKeywords  = ["undo", "remove", "delete", "back", "hoàn tác", "xóa"]
    private let nextKeywords  = ["next", "switch", "change", "tiếp theo", "chuyển"]
    private let stopKeywords  = ["stop", "done", "finish", "end", "dừng", "xong"]

    // MARK: - Init

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        checkAvailability()
    }

    // MARK: - Availability

    private func checkAvailability() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                self?.isAvailable = (status == .authorized)
            }
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard isAvailable, !isListening else { return }

        do {
            try startAudioSession()
            try startRecognition()
            isListening = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private helpers

    private func startAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcript = result.bestTranscription.formattedString.lowercased()
                Task { @MainActor [weak self] in
                    self?.processTranscript(transcript)
                }
            }

            if error != nil || result?.isFinal == true {
                Task { @MainActor [weak self] in
                    self?.stopListening()
                }
            }
        }
    }

    private func processTranscript(_ transcript: String) {
        let words = transcript.components(separatedBy: .whitespaces)
        guard let lastWord = words.last else { return }

        if countKeywords.contains(where: { lastWord.contains($0) }) {
            lastRecognizedCommand = "Count ✓"
            onCount?()
        } else if undoKeywords.contains(where: { lastWord.contains($0) }) {
            lastRecognizedCommand = "Undo ↩"
            onUndo?()
        } else if nextKeywords.contains(where: { lastWord.contains($0) }) {
            lastRecognizedCommand = "Next →"
            onNextType?()
        } else if stopKeywords.contains(where: { lastWord.contains($0) }) {
            lastRecognizedCommand = "Stop ■"
            onStop?()
            stopListening()
        }
    }
}
