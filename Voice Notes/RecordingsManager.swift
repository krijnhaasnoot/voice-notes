import Foundation
import Speech
import Combine

@MainActor
class RecordingsManager: ObservableObject {
    @Published var recordings: [Recording] = []
    private let userDefaults = UserDefaults.standard
    private let recordingsKey = "SavedRecordings"
    private let processingManager = ProcessingManager()
    
    init() {
        loadRecordings()
        setupProcessingObserver()
    }
    
    private func loadRecordings() {
        if let data = userDefaults.data(forKey: recordingsKey),
           let decodedRecordings = try? JSONDecoder().decode([Recording].self, from: data) {
            recordings = decodedRecordings.sorted { $0.date > $1.date }
        }
    }
    
    private func saveRecordings() {
        if let encoded = try? JSONEncoder().encode(recordings) {
            userDefaults.set(encoded, forKey: recordingsKey)
        }
    }
    
    private func setupProcessingObserver() {
        processingManager.objectWillChange.sink { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleProcessingUpdates()
            }
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func handleProcessingUpdates() {
        // Clean up completed operations first to prevent buildup
        processingManager.cleanupCompletedOperations()
        
        // Reduced logging for better performance
        if processingManager.activeOperations.count > 5 {
            print("📱 RecordingsManager: handleProcessingUpdates - \(processingManager.activeOperations.count) operations")
        }
        for (_, operation) in processingManager.activeOperations {
            updateRecordingFromOperation(operation)
        }
    }
    
    @MainActor
    private func updateRecordingFromOperation(_ operation: ProcessingOperation) {
        guard let index = recordings.firstIndex(where: { $0.id == operation.recordingId }) else { 
            return 
        }
        
        let currentRecording = recordings[index]
        var newStatus = currentRecording.status
        var newTranscript = currentRecording.transcript
        var newSummary = currentRecording.summary
        var newTranscriptDate = currentRecording.transcriptLastUpdated
        var newSummaryDate = currentRecording.summaryLastUpdated
        
        switch operation.status {
        case .running(let progress):
            switch operation.type {
            case .transcription:
                newStatus = .transcribing(progress: progress)
            case .summarization:
                newStatus = .summarizing(progress: progress)
            }
            
        case .completed(let result):
            switch result {
            case .transcript(let transcript):
                newTranscript = transcript
                newTranscriptDate = Date()
                newStatus = .idle
                
                if !transcript.isEmpty {
                    let _ = processingManager.startSummarization(for: operation.recordingId, transcript: transcript)
                }
                
            case .summary(let summary):
                newSummary = summary
                newSummaryDate = Date()
                newStatus = .idle
            }
            
        case .failed(let error):
            newStatus = .failed(reason: error.localizedDescription)
            
        case .cancelled:
            newStatus = .idle
        }
        
        let updatedRecording = Recording(
            fileName: currentRecording.fileName,
            date: currentRecording.date,
            duration: currentRecording.duration,
            transcript: newTranscript,
            summary: newSummary,
            rawSummary: currentRecording.rawSummary,
            status: newStatus,
            languageHint: currentRecording.languageHint,
            transcriptLastUpdated: newTranscriptDate,
            summaryLastUpdated: newSummaryDate,
            title: currentRecording.title.isEmpty && newTranscript != nil && !newTranscript!.isEmpty ? newTranscript!.smartTitle() : currentRecording.title,
            detectedMode: currentRecording.detectedMode,
            id: currentRecording.id
        )
        
        recordings[index] = updatedRecording
        saveRecordings()
        
        // Force UI update
        objectWillChange.send()
    }
    
    func addRecording(_ recording: Recording) {
        recordings.insert(recording, at: 0)
        saveRecordings()
    }
    
    func updateRecording(_ recordingId: UUID, status: Recording.Status? = nil, transcript: String? = nil, summary: String? = nil, rawSummary: String? = nil, languageHint: String? = nil, title: String? = nil) {
        if let index = recordings.firstIndex(where: { $0.id == recordingId }) {
            let currentRecording = recordings[index]
            
            let finalTitle = title ?? (transcript != nil && currentRecording.title.isEmpty ? transcript!.smartTitle() : currentRecording.title)
            
            let updatedRecording = Recording(
                fileName: currentRecording.fileName,
                date: currentRecording.date,
                duration: currentRecording.duration,
                transcript: transcript ?? currentRecording.transcript,
                summary: summary ?? currentRecording.summary,
                rawSummary: rawSummary ?? currentRecording.rawSummary,
                status: status ?? currentRecording.status,
                languageHint: languageHint ?? currentRecording.languageHint,
                transcriptLastUpdated: transcript != nil ? Date() : currentRecording.transcriptLastUpdated,
                summaryLastUpdated: summary != nil ? Date() : currentRecording.summaryLastUpdated,
                title: finalTitle,
                detectedMode: currentRecording.detectedMode,
                id: currentRecording.id
            )
            
            recordings[index] = updatedRecording
            saveRecordings()
        }
    }
    
    func updateRecordingDetectedMode(_ recordingId: UUID, detectedMode: String) {
        if let index = recordings.firstIndex(where: { $0.id == recordingId }) {
            let currentRecording = recordings[index]
            
            let updatedRecording = Recording(
                fileName: currentRecording.fileName,
                date: currentRecording.date,
                duration: currentRecording.duration,
                transcript: currentRecording.transcript,
                summary: currentRecording.summary,
                rawSummary: currentRecording.rawSummary,
                status: currentRecording.status,
                languageHint: currentRecording.languageHint,
                transcriptLastUpdated: currentRecording.transcriptLastUpdated,
                summaryLastUpdated: currentRecording.summaryLastUpdated,
                title: currentRecording.title,
                detectedMode: detectedMode,
                id: currentRecording.id
            )
            
            recordings[index] = updatedRecording
            saveRecordings()
        }
    }
    
    func deleteRecording(_ recording: Recording) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(recording.fileName)
        
        // Cancel any active operations for this recording
        cancelActiveOperations(for: recording.id)
        
        // Remove from recordings array
        recordings.removeAll { $0.id == recording.id }
        
        // Delete audio file from disk (ignore errors if file doesn't exist)
        do {
            try FileManager.default.removeItem(at: audioURL)
        } catch {
            // Silently ignore file deletion errors
        }
        
        // Save updated recordings list
        saveRecordings()
        
        // Force UI update
        objectWillChange.send()
    }
    
    func delete(id: UUID) {
        guard let recording = recordings.first(where: { $0.id == id }) else { 
            return 
        }
        deleteRecording(recording)
    }
    
    func startTranscription(for recording: Recording, languageHint: String? = nil) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(recording.fileName)
        
        print("🎯 RecordingsManager: Starting transcription for recording \(recording.id)")
        print("    File: \(recording.fileName)")
        print("    AudioURL: \(audioURL.path)")
        print("    File exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
        
        updateRecording(recording.id, status: .transcribing(progress: 0.0), languageHint: languageHint)
        
        // Use direct service call like RecordingViewModel does (bypassing ProcessingManager for now)
        Task {
            await performDirectTranscription(recordingId: recording.id, audioURL: audioURL, languageHint: languageHint)
        }
    }
    
    private func performDirectTranscription(recordingId: UUID, audioURL: URL, languageHint: String?) async {
        // Create transcription service directly like RecordingViewModel does
        guard let service = OpenAITranscriptionService.createFromInfoPlist() else {
            await MainActor.run {
                updateRecording(recordingId, status: .failed(reason: "API key not configured"))
            }
            return
        }
        
        do {
            print("🎯 RecordingsManager: Calling transcription service directly")
            let transcript = try await service.transcribe(
                fileURL: audioURL,
                languageHint: languageHint,
                progress: { progress in
                    Task { @MainActor in
                        self.updateRecording(recordingId, status: .transcribing(progress: progress))
                    }
                },
                cancelToken: CancellationToken()
            )
            
            await MainActor.run {
                print("🎯 RecordingsManager: ✅ Transcription completed (\(transcript.count) chars)")
                updateRecording(recordingId, status: .idle, transcript: transcript)
                
                // Start summarization
                if !transcript.isEmpty {
                    performDirectSummarization(recordingId: recordingId, transcript: transcript)
                }
            }
            
        } catch {
            await MainActor.run {
                print("🎯 RecordingsManager: ❌ Transcription failed: \(error)")
                updateRecording(recordingId, status: .failed(reason: error.localizedDescription))
            }
        }
    }
    
    private func performDirectSummarization(recordingId: UUID, transcript: String) {
        updateRecording(recordingId, status: .summarizing(progress: 0.0))
        
        Task {
            let summaryService = SummaryService()
            
            do {
                // Get user settings
                let defaultModeString = UserDefaults.standard.string(forKey: "defaultMode") ?? SummaryMode.personal.rawValue
                let autoDetectMode = UserDefaults.standard.bool(forKey: "autoDetectMode")
                let defaultMode = SummaryMode(rawValue: defaultModeString) ?? .personal
                
                var selectedMode = defaultMode
                
                // Auto-detect mode if enabled
                if autoDetectMode {
                    do {
                        print("🎯 RecordingsManager: Auto-detecting mode...")
                        selectedMode = try await summaryService.detectMode(
                            transcript: transcript,
                            cancelToken: CancellationToken()
                        )
                        print("🎯 RecordingsManager: Detected mode: \(selectedMode.rawValue)")
                        
                        // Update recording with detected mode info
                        await MainActor.run {
                            updateRecordingDetectedMode(recordingId, detectedMode: selectedMode.rawValue)
                            updateRecording(recordingId, status: .summarizing(progress: 0.1))
                        }
                    } catch {
                        print("🎯 RecordingsManager: Mode detection failed, using default: \(error)")
                        selectedMode = defaultMode
                    }
                } else {
                    print("🎯 RecordingsManager: Using default mode: \(selectedMode.rawValue)")
                }
                
                // Get selected summary length
                let selectedLength: SummaryLength = {
                    let lengthString = UserDefaults.standard.string(forKey: "defaultSummaryLength") ?? SummaryLength.standard.rawValue
                    return SummaryLength(rawValue: lengthString) ?? .standard
                }()
                
                print("🎯 RecordingsManager: Starting summarization with mode: \(selectedMode.rawValue), length: \(selectedLength.rawValue)")
                let result = try await summaryService.summarize(
                    transcript: transcript,
                    mode: selectedMode,
                    length: selectedLength,
                    progress: { progress in
                        Task { @MainActor in
                            self.updateRecording(recordingId, status: .summarizing(progress: progress))
                        }
                    },
                    cancelToken: CancellationToken()
                )
                
                await MainActor.run {
                    print("🎯 RecordingsManager: ✅ Summary completed (\(result.clean.count) chars)")
                    updateRecordingWithBothSummaries(recordingId: recordingId, cleanSummary: result.clean, rawSummary: result.raw)
                }
                
            } catch {
                await MainActor.run {
                    print("🎯 RecordingsManager: ❌ Summarization failed: \(error)")
                    updateRecording(recordingId, status: .failed(reason: error.localizedDescription))
                }
            }
        }
    }
    
    func retryTranscription(for recording: Recording) {
        startTranscription(for: recording, languageHint: recording.languageHint)
    }
    
    func retrySummarization(for recording: Recording) {
        guard let transcript = recording.transcript, !transcript.isEmpty else { return }
        
        updateRecording(recording.id, status: .summarizing(progress: 0.0))
        
        // Use direct summarization like the main flow
        performDirectSummarization(recordingId: recording.id, transcript: transcript)
    }
    
    func cancelProcessing(for recordingId: UUID) {
        cancelActiveOperations(for: recordingId)
        updateRecording(recordingId, status: .idle)
    }
    
    private func cancelActiveOperations(for recordingId: UUID) {
        for (operationId, operation) in processingManager.activeOperations {
            if operation.recordingId == recordingId {
                processingManager.cancelOperation(operationId)
            }
        }
    }
    
    func getProcessingProgress(for recordingId: UUID) -> Double? {
        for (_, operation) in processingManager.activeOperations {
            if operation.recordingId == recordingId {
                switch operation.status {
                case .running(let progress):
                    return progress
                default:
                    break
                }
            }
        }
        return nil
    }
    
    func cleanupOldOperations() {
        processingManager.cleanupCompletedOperations()
    }
    
    func update(id: UUID, mutate: (inout Recording) -> Void) {
        guard let index = recordings.firstIndex(where: { $0.id == id }) else { return }
        var recording = recordings[index]
        mutate(&recording)
        recordings[index] = recording
        saveRecordings()
        objectWillChange.send()
    }
    
    private func updateRecordingWithBothSummaries(recordingId: UUID, cleanSummary: String, rawSummary: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recordingId }) else { return }
        let currentRecording = recordings[index]
        
        let updatedRecording = Recording(
            fileName: currentRecording.fileName,
            date: currentRecording.date,
            duration: currentRecording.duration,
            transcript: currentRecording.transcript,
            summary: cleanSummary,
            rawSummary: rawSummary,
            status: .idle,
            languageHint: currentRecording.languageHint,
            transcriptLastUpdated: currentRecording.transcriptLastUpdated,
            summaryLastUpdated: Date(),
            title: currentRecording.title,
            detectedMode: currentRecording.detectedMode,
            id: currentRecording.id
        )
        
        recordings[index] = updatedRecording
        saveRecordings()
        objectWillChange.send()
    }
}
