import Foundation
import Speech
import Combine

@MainActor
final class RecordingsManager: ObservableObject {
    static let shared = RecordingsManager()

    @Published var recordings: [Recording] = []
    
    // MARK: - Bulk Summary Regeneration
    @Published var isRegeneratingSummaries: Bool = false
    @Published var regenerateSummariesProgress: Double = 0
    @Published var regenerateSummariesStatusText: String = ""
    @Published var regenerateSummariesProcessedCount: Int = 0
    @Published var regenerateSummariesTotalCount: Int = 0
    @Published var regenerateSummariesLastError: String?
    private var regenerateSummariesTask: Task<Void, Never>?

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
            print("🎯 RecordingsManager: ⚠️ Recording not found for operation \(operation.id)")
            return 
        }
        
        let currentRecording = recordings[index]
        var newStatus = currentRecording.status
        var newTranscript = currentRecording.transcript
        var newSummary = currentRecording.summary
        var newRawSummary = currentRecording.rawSummary
        var newTranscriptDate = currentRecording.transcriptLastUpdated
        var newSummaryDate = currentRecording.summaryLastUpdated
        var newTranscriptionModel = currentRecording.transcriptionModel

        switch operation.status {
        case .running(let progress):
            switch operation.type {
            case .transcription:
                newStatus = .transcribing(progress: progress)
                print("🎯 RecordingsManager: Transcription progress: \(Int(progress * 100))%")
            case .summarization:
                newStatus = .summarizing(progress: progress)
                print("🎯 RecordingsManager: Summarization progress: \(Int(progress * 100))%")
            }

        case .completed(let result):
            switch result {
            case .transcript(let transcript):
                print("🎯 RecordingsManager: ✅ Transcription completed (\(transcript.count) chars)")
                
                newTranscript = TranscriptPostProcessor.format(transcript)
                newTranscriptDate = Date()
                newStatus = .idle

                // Record which model was used (ProcessingManager currently uses WhisperKit on-device)
                newTranscriptionModel = "WhisperKit \(WhisperModelManager.shared.selectedModel.displayName)"

                // Notify user of transcription completion
                NotificationManager.shared.notifyTranscriptionComplete(
                    recordingTitle: currentRecording.title.isEmpty ? "Recording" : currentRecording.title,
                    duration: currentRecording.duration
                )

                // Analytics: transcription completed
                Analytics.track("transcription_completed", props: [
                    "engine": "whisper",
                    "duration_s": Int(currentRecording.duration)
                ])

                // Note: Auto-summarization now happens directly in startTranscription()
                // No need to trigger it here anymore - keeping this logic simple!

            case .summary(let clean, let raw):
                print("🎯 RecordingsManager: ✅ Summarization completed (\(clean.count) chars)")
                if let rawLength = raw?.count {
                    print("    Raw summary: \(rawLength) chars")
                }
                
                newSummary = clean
                newRawSummary = raw ?? clean
                newSummaryDate = Date()
                newStatus = .idle

                // Notify user of summary completion
                NotificationManager.shared.notifySummaryComplete(
                    recordingTitle: currentRecording.title.isEmpty ? "Recording" : currentRecording.title
                )

                // Analytics: summary completed
                let activeProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "app_default"
                Analytics.track("summary_generated", provider: activeProvider, props: [:])
            }

        case .failed(let error):
            print("🎯 RecordingsManager: ❌ Operation failed: \(error.localizedDescription)")
            newStatus = .failed(reason: error.localizedDescription)
            
            // Analytics: track failure
            switch operation.type {
            case .transcription:
                Analytics.track("transcription_failed", props: [
                    "reason": error.localizedDescription
                ])
            case .summarization:
                let activeProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "app_default"
                Analytics.track("summary_failed", provider: activeProvider, props: [
                    "reason": error.localizedDescription
                ])
            }

        case .cancelled:
            print("🎯 RecordingsManager: Operation cancelled")
            newStatus = .idle
        }

        let updatedRecording = Recording(
            fileName: currentRecording.fileName,
            date: currentRecording.date,
            duration: currentRecording.duration,
            transcript: newTranscript,
            summary: newSummary,
            rawSummary: newRawSummary,
            status: newStatus,
            languageHint: currentRecording.languageHint,
            transcriptLastUpdated: newTranscriptDate,
            summaryLastUpdated: newSummaryDate,
            title: currentRecording.title,
            detectedMode: currentRecording.detectedMode,
            preferredSummaryProvider: currentRecording.preferredSummaryProvider,
            tags: currentRecording.tags,
            transcriptionModel: newTranscriptionModel,
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
        
        // Start transcription immediately using the unified method
        // Note: Don't call startTranscription here - let the caller decide when to start
        // This prevents double-initiation when called from ContentView
        
        // End background task after a delay to ensure processing can start
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            BackgroundTaskManager.shared.endBackgroundTask(taskId)
        }
    }
    
    func updateRecording(_ recordingId: UUID, status: Recording.Status? = nil, transcript: String? = nil, summary: String? = nil, rawSummary: String? = nil, languageHint: String? = nil, title: String? = nil, transcriptionModel: String? = nil) {
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
                transcriptionModel: transcriptionModel ?? currentRecording.transcriptionModel,
                id: currentRecording.id
            )
            
            // Debug log for transcription model
            if let model = transcriptionModel {
                print("📝 updateRecording: Setting transcriptionModel to '\(model)'")
            }

            recordings[index] = updatedRecording
            saveRecordings()
            
            // Additional debug after save
            if transcriptionModel != nil {
                print("📝 updateRecording: Recording saved, transcriptionModel = '\(updatedRecording.transcriptionModel ?? "nil")'")
            }
            
            // Notify observers on main thread to ensure UI updates
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
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
                transcriptionModel: currentRecording.transcriptionModel,
                id: currentRecording.id
            )
            
            recordings[index] = updatedRecording
            saveRecordings()
            
            // Notify observers on main thread to ensure UI updates
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
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

        // Verify file exists and has content
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("🎯 RecordingsManager: ❌ Audio file not found at path: \(audioURL.path)")
            updateRecording(recording.id, status: .failed(reason: "Audio file not found"))
            return
        }

        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            if fileSize == 0 {
                print("🎯 RecordingsManager: ❌ Audio file is empty (0 bytes)")
                updateRecording(recording.id, status: .failed(reason: "Audio file is empty"))
                return
            }
            
            print("🎯 RecordingsManager: ✅ File verified - size: \(fileSize) bytes")
        } catch {
            print("🎯 RecordingsManager: ❌ Error checking file: \(error)")
            updateRecording(recording.id, status: .failed(reason: "Error accessing audio file"))
            return
        }

        updateRecording(recording.id, status: .transcribing(progress: 0.1))

        // 🚀 Use WhisperKit on-device transcription (fast, private, no internet needed)
        startWhisperKitTranscription(for: recording, audioURL: audioURL, languageHint: languageHint)
    }
    
    // MARK: - WhisperKit On-Device Transcription
    
    private func startWhisperKitTranscription(for recording: Recording, audioURL: URL, languageHint: String?) {
        Task { @MainActor in
            do {
                let modelName = WhisperModelManager.shared.selectedModel
                let speedInfo = switch modelName {
                case .tiny: "~10x faster than real-time"
                case .base: "~5x faster than real-time"
                case .small: "~2x faster than real-time"
                case .medium: "~1x real-time"
                case .large: "~0.5x real-time"
                }
                
                print("🚀 WHISPERKIT: Starting on-device transcription...")
                print("   Model: \(modelName.displayName)")
                print("   Expected speed: \(speedInfo)")
                
                // Use shared instance to avoid multiple model loads
                let whisperKitService = WhisperKitTranscriptionService.shared()
                let cancelToken = CancellationToken()
                
                self.updateRecording(recording.id, status: .transcribing(progress: 0.1))
                self.objectWillChange.send()
                
                let transcript = try await whisperKitService.transcribe(
                    url: audioURL,
                    languageHint: languageHint,
                    onDevicePreferred: true,
                    progress: { [weak self] progress in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.updateRecording(recording.id, status: .transcribing(progress: 0.1 + progress * 0.8))
                            self.objectWillChange.send()
                        }
                    },
                    cancelToken: cancelToken
                )
                
                // Store the model name that was used
                let transcriptionModelName = "WhisperKit \(modelName.displayName)"
                let formattedTranscript = TranscriptPostProcessor.format(transcript)
                print("✅ WHISPERKIT: Success! \(formattedTranscript.count) chars using \(transcriptionModelName)")
                print("📝 Saving transcription model: \(transcriptionModelName)")
                self.updateRecording(recording.id, status: .done, transcript: formattedTranscript, transcriptionModel: transcriptionModelName)
                print("📝 Recording updated with model info")
                self.objectWillChange.send()
                
                // Auto-start summary if transcript is not empty
                if !formattedTranscript.isEmpty {
                    print("🔄 WHISPERKIT: Starting summary...")
                    self.startSummarization(for: recording.id, transcript: formattedTranscript)
                }
                
            } catch {
                print("❌ WHISPERKIT: Failed - \(error.localizedDescription)")
                self.updateRecording(recording.id, status: .failed(reason: "Transcription failed: \(error.localizedDescription)"))
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - OpenAI Whisper (Cloud) Transcription
    
    func retryTranscription(for recording: Recording) {
        telemetryService.logRetryTap(kind: "transcribe")
        Analytics.track("retry_tapped", props: ["type": "transcription"])
        
        // Make retry visible + meaningful:
        // Clear existing transcript/summary so UI shows "transcribing" and the user doesn't think nothing happened.
        let modelName = "WhisperKit \(WhisperModelManager.shared.selectedModel.displayName)"
        updateRecording(
            recording.id,
            status: .transcribing(progress: 0.01),
            transcript: nil,
            summary: nil,
            rawSummary: nil,
            transcriptionModel: modelName
        )
        objectWillChange.send()
        
        startTranscription(for: recording, languageHint: recording.languageHint)
    }

    // DIRECT SIMPLE SUMMARIZATION - Using EnhancedSummaryService
    func startSummarization(for recordingId: UUID, transcript: String) {
        print("📝 Starting summarization using EnhancedSummaryService...")
        updateRecording(recordingId, status: .summarizing(progress: 0.1))
        
        Task { @MainActor in
            do {
                // Use EnhancedSummaryService which handles API key management
                let summaryService = EnhancedSummaryService.shared
                
                self.updateRecording(recordingId, status: .summarizing(progress: 0.3))
                
                // Get selected summary length
                let selectedLength: SummaryLength = {
                    let lengthString = UserDefaults.standard.string(forKey: "defaultSummaryLength") ?? SummaryLength.standard.rawValue
                    return SummaryLength(rawValue: lengthString) ?? .standard
                }()
                
                print("📝 Calling EnhancedSummaryService with length: \(selectedLength.rawValue)...")
                
                let result = try await summaryService.summarize(
                    transcript: transcript,
                    length: selectedLength,
                    progress: { progress in
                        Task { @MainActor in
                            self.updateRecording(recordingId, status: .summarizing(progress: 0.3 + progress * 0.6))
                            self.objectWillChange.send()
                        }
                    },
                    cancelToken: CancellationToken()
                )
                
                print("✅ EnhancedSummaryService: Summary done! \(result.clean.count) chars")
                self.updateRecording(recordingId, status: .done, summary: result.clean, rawSummary: result.raw)
                self.objectWillChange.send()
                
            } catch {
                print("❌ EnhancedSummaryService: Summary failed - \(error.localizedDescription)")
                self.updateRecording(recordingId, status: .failed(reason: "Summary generation failed: \(error.localizedDescription)"))
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Bulk Summary Regeneration
    
    /// Regenerate summaries in bulk.
    /// - Parameter onlyFixLocalFallback: If true, only targets summaries that look like the local fallback (or missing summaries).
    func regenerateSummariesInBulk(onlyFixLocalFallback: Bool) {
        guard !isRegeneratingSummaries else { return }
        
        let candidates: [Recording] = recordings.filter { r in
            guard let transcript = r.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !transcript.isEmpty else { return false }
            
            // If summary is missing, always include
            if r.summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                return true
            }
            
            guard onlyFixLocalFallback else { return true }
            
            let s = (r.summary ?? "")
            return s.contains("Local Summary")
                || s.contains("Local Extract")
                || s.contains("simplified local extract")
                || s.contains("Summary (Local Extract)")
        }
        
        isRegeneratingSummaries = true
        regenerateSummariesProgress = 0
        regenerateSummariesProcessedCount = 0
        regenerateSummariesTotalCount = candidates.count
        regenerateSummariesLastError = nil
        regenerateSummariesStatusText = candidates.isEmpty ? "No recordings to update" : "Preparing…"
        
        // Cancel any previous task just in case
        regenerateSummariesTask?.cancel()
        
        regenerateSummariesTask = Task { @MainActor in
            defer {
                isRegeneratingSummaries = false
                if regenerateSummariesTotalCount > 0 && regenerateSummariesProcessedCount == regenerateSummariesTotalCount {
                    regenerateSummariesStatusText = "Done"
                    regenerateSummariesProgress = 1.0
                }
            }
            
            guard !candidates.isEmpty else { return }
            
            let summaryService = EnhancedSummaryService.shared
            let selectedLength: SummaryLength = {
                let lengthString = UserDefaults.standard.string(forKey: "defaultSummaryLength") ?? SummaryLength.standard.rawValue
                return SummaryLength(rawValue: lengthString) ?? .standard
            }()
            
            for (idx, rec) in candidates.enumerated() {
                if Task.isCancelled { break }
                
                let title = rec.title.isEmpty ? "Recording" : rec.title
                regenerateSummariesStatusText = "Summarizing \(idx + 1) / \(candidates.count): \(title)"
                
                // Mark this recording as summarizing for UI feedback
                updateRecording(rec.id, status: .summarizing(progress: 0.05))
                
                do {
                    let result = try await summaryService.summarize(
                        transcript: rec.transcript ?? "",
                        length: selectedLength,
                        progress: { [weak self] p in
                            Task { @MainActor in
                                guard let self else { return }
                                // Recording-level progress (0.05 .. 0.95)
                                self.updateRecording(rec.id, status: .summarizing(progress: 0.05 + p * 0.90))
                                
                                // Bulk-level progress
                                let base = Double(idx) / Double(max(candidates.count, 1))
                                let step = 1.0 / Double(max(candidates.count, 1))
                                self.regenerateSummariesProgress = min(1.0, base + p * step)
                            }
                        },
                        cancelToken: CancellationToken { Task.isCancelled }
                    )
                    
                    updateRecording(rec.id, status: .done, summary: result.clean, rawSummary: result.raw)
                } catch {
                    regenerateSummariesLastError = error.localizedDescription
                    updateRecording(rec.id, status: .failed(reason: "Summary generation failed: \(error.localizedDescription)"))
                }
                
                regenerateSummariesProcessedCount = idx + 1
                regenerateSummariesProgress = Double(regenerateSummariesProcessedCount) / Double(max(candidates.count, 1))
            }
        }
    }
    
    func cancelRegenerateSummariesInBulk() {
        regenerateSummariesTask?.cancel()
        regenerateSummariesTask = nil
        isRegeneratingSummaries = false
        regenerateSummariesStatusText = "Cancelled"
    }
    
    func retrySummarization(for recording: Recording) {
        guard let transcript = recording.transcript, !transcript.isEmpty else {
            print("❌ Cannot retry summarization - no transcript")
            return
        }
        
        telemetryService.logRetryTap(kind: "summarize")
        Analytics.track("retry_tapped", props: ["type": "summary"])
        
        // Use direct simple summarization
        startSummarization(for: recording.id, transcript: transcript)
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
        
        // Notify observers on main thread to ensure UI updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
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
            
            // Notify observers on main thread to ensure UI updates
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func removeTagFromRecording(recordingId: UUID, tag: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recordingId }) else { return }
        var currentTags = recordings[index].tags
        currentTags.removeAll { $0.lowercased() == tag.lowercased() }
        
        recordings[index] = recordings[index].withTags(currentTags)
        saveRecordings()
        
        // Notify observers on main thread to ensure UI updates
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
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
            transcriptionModel: currentRecording.transcriptionModel,
            id: currentRecording.id
        )
        
        recordings[index] = updatedRecording
        saveRecordings()
        objectWillChange.send()
    }
}

