import Foundation
import AVFoundation
import Speech

// MARK: - Voice Recorder for Document Items

@MainActor
class DocumentVoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""
    @Published var lastError: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // Completion handler for when transcription is complete
    var onTranscriptionComplete: ((String) -> Void)?
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    // MARK: - Setup
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer()
        
        guard let speechRecognizer = speechRecognizer else {
            lastError = "Speech recognizer not available"
            return
        }
        
        speechRecognizer.delegate = self
    }
    
    // MARK: - Permission Handling
    
    private func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechStatus else {
            await MainActor.run {
                self.lastError = "Speech recognition permission denied"
            }
            return false
        }
        
        // Request microphone permission
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard micStatus else {
            await MainActor.run {
                self.lastError = "Microphone permission denied"
            }
            return false
        }
        
        return true
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        Task {
            await startRecordingAsync()
        }
    }
    
    private func startRecordingAsync() async {
        guard await requestPermissions() else { return }
        
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Start speech recognition
            await startSpeechRecognition()
            
            isRecording = true
            lastError = nil
            
            print("📝 VoiceRecorder: Started recording for item creation")
            
        } catch {
            lastError = "Failed to start recording: \(error.localizedDescription)"
            print("❌ VoiceRecorder: \(lastError ?? "")")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop speech recognition
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Stop audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("❌ VoiceRecorder: Failed to deactivate audio session: \(error)")
        }
        
        isRecording = false
        
        // Call completion handler with final transcription
        let finalText = transcriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            onTranscriptionComplete?(finalText)
            print("📝 VoiceRecorder: Completed transcription: '\(finalText)'")
        }
        
        // Reset for next use
        transcriptionText = ""
        
        print("📝 VoiceRecorder: Stopped recording")
    }
    
    // MARK: - Speech Recognition
    
    private func startSpeechRecognition() async {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            lastError = "Speech recognizer not available"
            return
        }
        
        // Cancel previous task if running
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            lastError = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            lastError = "Failed to start audio engine: \(error.localizedDescription)"
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            Task { @MainActor in
                if let result = result {
                    self.transcriptionText = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    self.lastError = "Speech recognition error: \(error.localizedDescription)"
                    print("❌ VoiceRecorder: Speech recognition error: \(error)")
                }
                
                if result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension DocumentVoiceRecorder: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.lastError = "Speech recognizer became unavailable"
                if self.isRecording {
                    self.stopRecording()
                }
            }
        }
    }
}