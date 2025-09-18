import Foundation

@MainActor
class ProcessingManager: ObservableObject {
    @Published var activeOperations: [UUID: ProcessingOperation] = [:]
    
    private let transcriptionService: OpenAITranscriptionService?
    private let summaryService: SummaryService
    
    init() {
        // Load API key from Info.plist instead of UserDefaults
        self.transcriptionService = OpenAITranscriptionService.createFromInfoPlist()
        self.summaryService = SummaryService()
        
        if transcriptionService == nil {
            print("⚠️ ProcessingManager: TranscriptionService not available - check OpenAI API key in Info.plist")
        }
    }
    
    func startTranscription(for recordingId: UUID, audioURL: URL, languageHint: String? = nil) -> ProcessingOperation {
        print("🎯 ProcessingManager: Starting transcription operation for recording \(recordingId)")
        print("    AudioURL: \(audioURL.path)")
        print("    Service available: \(transcriptionService != nil)")
        
        let operation = ProcessingOperation(
            id: UUID(),
            recordingId: recordingId,
            type: .transcription,
            status: .running(progress: 0.0)
        )
        
        activeOperations[operation.id] = operation
        print("🎯 ProcessingManager: Created operation \(operation.id), active operations: \(activeOperations.count)")
        
        Task {
            await performTranscription(operation: operation, audioURL: audioURL, languageHint: languageHint)
        }
        
        return operation
    }
    
    func startSummarization(for recordingId: UUID, transcript: String) -> ProcessingOperation {
        // Check if there's already an active summarization for this recording
        for (operationId, existingOperation) in activeOperations {
            if existingOperation.recordingId == recordingId && existingOperation.type == .summarization {
                switch existingOperation.status {
                case .running:
                    print("🔄 ProcessingManager: Summarization already running for recording \(recordingId), skipping")
                    return existingOperation
                case .completed, .failed, .cancelled:
                    // Clean up completed operation
                    activeOperations.removeValue(forKey: operationId)
                    break
                }
            }
        }
        
        let operation = ProcessingOperation(
            id: UUID(),
            recordingId: recordingId,
            type: .summarization,
            status: .running(progress: 0.0)
        )
        
        activeOperations[operation.id] = operation
        print("🔄 ProcessingManager: Starting new summarization for recording \(recordingId)")
        
        Task {
            await performSummarization(operation: operation, transcript: transcript)
        }
        
        return operation
    }
    
    func cancelOperation(_ operationId: UUID) {
        guard var operation = activeOperations[operationId] else { return }
        operation.status = .cancelled
        operation.cancelToken = CancellationToken { true }
        activeOperations[operationId] = operation
    }
    
    private func performTranscription(operation: ProcessingOperation, audioURL: URL, languageHint: String?) async {
        print("🎯 ProcessingManager: performTranscription called for operation \(operation.id)")
        
        guard let service = transcriptionService else {
            print("🎯 ProcessingManager: ❌ No transcription service available")
            await MainActor.run {
                if var op = activeOperations[operation.id] {
                    op.status = .failed(error: TranscriptionError.apiKeyMissing)
                    activeOperations[operation.id] = op
                    print("🎯 ProcessingManager: Set operation to failed - API key missing")
                }
            }
            return
        }
        
        print("🎯 ProcessingManager: Starting actual transcription call to service")
        
        do {
            let transcript = try await service.transcribe(
                fileURL: audioURL,
                languageHint: languageHint,
                progress: { progress in
                    Task { @MainActor in
                        self.updateOperationProgress(operation.id, progress: progress)
                    }
                },
                cancelToken: operation.cancelToken
            )
            
            await MainActor.run {
                if var op = activeOperations[operation.id] {
                    op.status = .completed(result: .transcript(transcript))
                    activeOperations[operation.id] = op
                    print("🔄 ProcessingManager: Transcription completed for recording \(op.recordingId)")
                    print("    Transcript length: \(transcript.count) chars")
                    
                    // Clean up completed operation after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.activeOperations.removeValue(forKey: operation.id)
                        self.objectWillChange.send()
                    }
                    
                    // Manually trigger objectWillChange to ensure observers are notified
                    objectWillChange.send()
                }
            }
            
        } catch {
            await MainActor.run {
                if var op = activeOperations[operation.id] {
                    op.status = .failed(error: error)
                    activeOperations[operation.id] = op
                }
            }
        }
    }
    
    private func performSummarization(operation: ProcessingOperation, transcript: String) async {
        do {
            // Get selected summary length
            let selectedLength: SummaryLength = {
                let lengthString = UserDefaults.standard.string(forKey: "defaultSummaryLength") ?? SummaryLength.standard.rawValue
                return SummaryLength(rawValue: lengthString) ?? .standard
            }()
            
            let result = try await summaryService.summarize(
                transcript: transcript,
                length: selectedLength,
                progress: { progress in
                    Task { @MainActor in
                        self.updateOperationProgress(operation.id, progress: progress)
                    }
                },
                cancelToken: operation.cancelToken
            )
            
            await MainActor.run {
                if var op = activeOperations[operation.id] {
                    op.status = .completed(result: .summary(result.clean))
                    activeOperations[operation.id] = op
                    print("🔄 ProcessingManager: Summary completed for recording \(op.recordingId)")
                    print("    Summary length: \(result.clean.count) chars")
                    
                    // Clean up completed operation after a brief delay to allow UI update
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.activeOperations.removeValue(forKey: operation.id)
                        self.objectWillChange.send()
                    }
                    
                    // Manually trigger objectWillChange
                    objectWillChange.send()
                }
            }
            
        } catch {
            await MainActor.run {
                if var op = activeOperations[operation.id] {
                    op.status = .failed(error: error)
                    activeOperations[operation.id] = op
                }
            }
        }
    }
    
    private func updateOperationProgress(_ operationId: UUID, progress: Double) {
        guard var operation = activeOperations[operationId] else { return }
        operation.status = .running(progress: progress)
        activeOperations[operationId] = operation
        
        // Manually trigger objectWillChange for progress updates
        objectWillChange.send()
    }
    
    func cleanupCompletedOperations() {
        let countBefore = activeOperations.count
        activeOperations = activeOperations.filter { _, operation in
            switch operation.status {
            case .completed, .failed, .cancelled:
                return false
            default:
                return true
            }
        }
        let countAfter = activeOperations.count
        if countBefore != countAfter {
            print("🧹 ProcessingManager: Cleaned up \(countBefore - countAfter) completed operations")
            objectWillChange.send()
        }
    }
}

struct ProcessingOperation {
    let id: UUID
    let recordingId: UUID
    let type: OperationType
    var status: OperationStatus
    var cancelToken: CancellationToken
    
    init(id: UUID, recordingId: UUID, type: OperationType, status: OperationStatus) {
        self.id = id
        self.recordingId = recordingId
        self.type = type
        self.status = status
        self.cancelToken = CancellationToken()
    }
    
    enum OperationType {
        case transcription
        case summarization
    }
    
    enum OperationStatus {
        case running(progress: Double)
        case completed(result: OperationResult)
        case failed(error: Error)
        case cancelled
    }
    
    enum OperationResult {
        case transcript(String)
        case summary(String)
    }
}

class ProcessingPreferences: ObservableObject {
    @Published var preferOnDeviceTranscription: Bool {
        didSet {
            UserDefaults.standard.set(preferOnDeviceTranscription, forKey: "prefer_on_device_transcription")
        }
    }
    
    @Published var preferredSummarizationModel: SummarizationModel {
        didSet {
            UserDefaults.standard.set(preferredSummarizationModel.rawValue, forKey: "preferred_summarization_model")
        }
    }
    
    init() {
        self.preferOnDeviceTranscription = UserDefaults.standard.bool(forKey: "prefer_on_device_transcription")
        
        let modelString = UserDefaults.standard.string(forKey: "preferred_summarization_model") ?? SummarizationModel.anthropicClaude35Sonnet.rawValue
        self.preferredSummarizationModel = SummarizationModel(rawValue: modelString) ?? .anthropicClaude35Sonnet
    }
}

extension UserDefaults {
    func string(forKey defaultName: String, defaultValue: String) -> String {
        return string(forKey: defaultName) ?? defaultValue
    }
}