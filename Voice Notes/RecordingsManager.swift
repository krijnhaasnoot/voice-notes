import Foundation
import Speech
import Combine

@MainActor
final class RecordingsManager: ObservableObject {
    static let shared = RecordingsManager()

    @Published var recordings: [Recording] = []
    private let userDefaults = UserDefaults.standard
    private let recordingsKey = "SavedRecordings"
    private let processingManager = ProcessingManager()
    private let telemetryService = EnhancedTelemetryService.shared

    private init() {
        loadRecordings()
        setupProcessingObserver()
        setupTagNotifications()
    }
    
    private func loadRecordings() {
        if let data = userDefaults.data(forKey: recordingsKey),
           let decodedRecordings = try? JSONDecoder().decode([Recording].self, from: data) {
            // Migration: ensure all recordings have tags property
            recordings = decodedRecordings.map { recording in
                // If Recording doesn't have tags property, it will have empty tags from init
                return recording
            }.sorted { $0.date > $1.date }
            
            // Add all existing tags to TagStore
            for recording in recordings {
                for tag in recording.tags {
                    TagStore.shared.add(tag)
                }
            }
        }
    }
    
    private func setupTagNotifications() {
        NotificationCenter.default.addObserver(
            forName: .tagRenamed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let oldTag = userInfo["old"] as? String,
                  let newTag = userInfo["new"] as? String else { return }
            self?.renameTagInAllRecordings(from: oldTag, to: newTag)
        }
        
        NotificationCenter.default.addObserver(
            forName: .tagRemoved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let tag = userInfo["tag"] as? String else { return }
            self?.removeTagFromAllRecordings(tag: tag)
        }
        
        NotificationCenter.default.addObserver(
            forName: .tagMerged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let fromTag = userInfo["from"] as? String,
                  let intoTag = userInfo["into"] as? String else { return }
            self?.mergeTagInAllRecordings(from: fromTag, into: intoTag)
        }
    }
    
    private func renameTagInAllRecordings(from oldTag: String, to newTag: String) {
        for i in recordings.indices {
            if let index = recordings[i].tags.firstIndex(where: { $0.lowercased() == oldTag.lowercased() }) {
                recordings[i].tags[index] = newTag
            }
        }
        saveRecordings()
    }
    
    private func removeTagFromAllRecordings(tag: String) {
        for i in recordings.indices {
            recordings[i].tags.removeAll { $0.lowercased() == tag.lowercased() }
        }
        saveRecordings()
    }
    
    private func mergeTagInAllRecordings(from fromTag: String, into intoTag: String) {
        for i in recordings.indices {
            var tags = recordings[i].tags
            
            // Remove the old tag and add the new one if not already present
            tags.removeAll { $0.lowercased() == fromTag.lowercased() }
            if !tags.contains(where: { $0.lowercased() == intoTag.lowercased() }) {
                tags.append(intoTag)
            }
            
            recordings[i].tags = tags.normalized()
        }
        saveRecordings()
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
            title: currentRecording.title,
            detectedMode: currentRecording.detectedMode,
            preferredSummaryProvider: currentRecording.preferredSummaryProvider,
            tags: currentRecording.tags,
            id: currentRecording.id
        )
        
        recordings[index] = updatedRecording
        saveRecordings()
        
        // Force UI update
        objectWillChange.send()
    }
    
    func addRecording(_ recording: Recording) {
        print("🎵 RecordingsManager: Adding new recording - \(recording.fileName)")
        recordings.insert(recording, at: 0)
        saveRecordings()
        print("🎵 RecordingsManager: Recording added successfully. Total recordings: \(recordings.count)")
        
        // Start background task for processing
        let taskId = BackgroundTaskManager.shared.beginBackgroundTask(name: "RecordingProcessing")
        
        // Schedule background processing
        BackgroundTaskManager.shared.scheduleBackgroundProcessing()
        
        // Start transcription immediately
        Task {
            let _ = processingManager.startTranscription(for: recording.id, audioURL: recording.resolvedFileURL)
            
            // End background task after a delay to ensure processing started
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                BackgroundTaskManager.shared.endBackgroundTask()
            }
        }
    }
    
    func updateRecording(_ recordingId: UUID, status: Recording.Status? = nil, transcript: String? = nil, summary: String? = nil, rawSummary: String? = nil, languageHint: String? = nil, title: String? = nil) {
        if let index = recordings.firstIndex(where: { $0.id == recordingId }) {
            let currentRecording = recordings[index]
            
            // Generate title automatically if not provided and we have content
            let finalTitle: String
            if let providedTitle = title {
                finalTitle = providedTitle
            } else if currentRecording.title.isEmpty && (transcript != nil || summary != nil) {
                // Auto-generate title using transcript or summary
                let mode = SummaryMode(rawValue: currentRecording.detectedMode ?? "") ?? .personal
                finalTitle = TitleGenerator.shared.generateTitle(
                    from: transcript ?? currentRecording.transcript,
                    summary: summary ?? currentRecording.summary,
                    mode: mode,
                    date: currentRecording.date
                )
            } else {
                finalTitle = currentRecording.title
            }
            
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
                preferredSummaryProvider: currentRecording.preferredSummaryProvider,
                tags: currentRecording.tags,
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
                preferredSummaryProvider: currentRecording.preferredSummaryProvider,
                tags: currentRecording.tags,
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
                
                // Analytics: transcription completed
                if let recording = recordings.first(where: { $0.id == recordingId }) {
                    Analytics.track("transcription_completed", props: [
                        "engine": "whisper",
                        "duration_s": Int(recording.duration)
                    ])
                }
                
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
            let summaryService = EnhancedSummaryService.shared
            
            do {
                // Get user settings
                let defaultModeString = UserDefaults.standard.string(forKey: "defaultMode") ?? SummaryMode.personal.rawValue
                let autoDetectMode = UserDefaults.standard.bool(forKey: "autoDetectMode")
                let defaultMode = SummaryMode(rawValue: defaultModeString) ?? .personal
                
                var selectedMode = defaultMode
                
                if autoDetectMode {
                    print("🎯 RecordingsManager: Auto-detecting mode...")
                    // NOTE: EnhancedSummaryService currently has no `detectMode` API.
                    // If a detection API is added (e.g., `detectSummaryMode`), replace this placeholder accordingly.
                    // For now, we fall back to the default mode to avoid compile errors.
                    // selectedMode = try await summaryService.detectSummaryMode(
                    //     transcript: transcript,
                    //     cancelToken: CancellationToken()
                    // )
                    // print("🎯 RecordingsManager: Detected mode: \(selectedMode.rawValue)")
                    print("🎯 RecordingsManager: Mode detection API unavailable, using default: \(selectedMode.rawValue)")
                    await MainActor.run {
                        updateRecordingDetectedMode(recordingId, detectedMode: selectedMode.rawValue)
                        updateRecording(recordingId, status: .summarizing(progress: 0.1))
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
                
                // Analytics: summary requested
                let activeProvider = "app_default" // TODO: Get actual provider from settings
                Analytics.track("summary_requested", provider: activeProvider, props: [
                    "mode": selectedMode.rawValue,
                    "length": selectedLength.rawValue
                ])
                
                let startTime = Date()
                let result = try await summaryService.summarize(
                    transcript: transcript,
                    progress: { progress in
                        Task { @MainActor in
                            self.updateRecording(recordingId, status: .summarizing(progress: progress))
                        }
                    },
                    cancelToken: CancellationToken()
                )
                let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)
                
                await MainActor.run {
                    print("🎯 RecordingsManager: ✅ Summary completed (\(result.clean.count) chars)")
                    updateRecordingWithBothSummaries(recordingId: recordingId, cleanSummary: result.clean, rawSummary: result.raw ?? result.clean)
                    
                    // Analytics: summary completed successfully
                    Analytics.track("summary_generated", provider: activeProvider, props: [
                        "ms": elapsedMs
                    ])
                }
                
            } catch {
                await MainActor.run {
                    print("🎯 RecordingsManager: ❌ Summarization failed: \(error)")
                    updateRecording(recordingId, status: .failed(reason: error.localizedDescription))
                    
                    // Analytics: summary failed
                    let activeProvider = "app_default" // TODO: Get actual provider from settings
                    Analytics.track("summary_failed", provider: activeProvider, props: [
                        "reason": error.localizedDescription
                    ])
                }
            }
        }
    }
    
    func retryTranscription(for recording: Recording) {
        telemetryService.logRetryTap(kind: "transcribe")
        Analytics.track("retry_tapped", props: ["type": "transcription"])
        startTranscription(for: recording, languageHint: recording.languageHint)
    }
    
    func retrySummarization(for recording: Recording) {
        guard let transcript = recording.transcript, !transcript.isEmpty else { return }
        
        telemetryService.logRetryTap(kind: "summarize")
        Analytics.track("retry_tapped", props: ["type": "summary"])
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
    
    // MARK: - Tag Management
    
    func updateRecordingTags(recordingId: UUID, tags: [String]) {
        guard let index = recordings.firstIndex(where: { $0.id == recordingId }) else { return }
        let normalizedTags = tags.normalized()
        
        // Add new tags to global store
        for tag in normalizedTags {
            TagStore.shared.add(tag)
        }
        
        recordings[index] = recordings[index].withTags(normalizedTags)
        saveRecordings()
    }
    
    func addTagToRecording(recordingId: UUID, tag: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recordingId }) else { return }
        var currentTags = recordings[index].tags
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanTag.isEmpty && currentTags.count < 50 else { return }
        
        // Check if tag already exists (case insensitive)
        if !currentTags.contains(where: { $0.lowercased() == cleanTag.lowercased() }) {
            currentTags.append(cleanTag)
            TagStore.shared.add(cleanTag)
            
            recordings[index] = recordings[index].withTags(currentTags.normalized())
            saveRecordings()
        }
    }
    
    func removeTagFromRecording(recordingId: UUID, tag: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recordingId }) else { return }
        var currentTags = recordings[index].tags
        currentTags.removeAll { $0.lowercased() == tag.lowercased() }
        
        recordings[index] = recordings[index].withTags(currentTags)
        saveRecordings()
    }
    
    private func updateRecordingWithBothSummaries(recordingId: UUID, cleanSummary: String, rawSummary: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recordingId }) else { return }
        let currentRecording = recordings[index]
        
        // Generate title if not already set
        let finalTitle: String
        if currentRecording.title.isEmpty {
            let mode = SummaryMode(rawValue: currentRecording.detectedMode ?? "") ?? .personal
            finalTitle = TitleGenerator.shared.generateTitle(
                from: currentRecording.transcript,
                summary: cleanSummary,
                mode: mode,
                date: currentRecording.date
            )
        } else {
            finalTitle = currentRecording.title
        }
        
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
            title: finalTitle,
            detectedMode: currentRecording.detectedMode,
            preferredSummaryProvider: currentRecording.preferredSummaryProvider,
            tags: currentRecording.tags,
            id: currentRecording.id
        )
        
        recordings[index] = updatedRecording
        saveRecordings()
        objectWillChange.send()
    }
}

