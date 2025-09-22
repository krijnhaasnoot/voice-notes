import Foundation
import SwiftUI

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var transcript: String = ""
    @Published var summary: String = ""
    @Published var isTranscribing: Bool = false
    @Published var isSummarizing: Bool = false
    @Published var transcriptionProgress: Double = 0.0
    @Published var summarizationProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var status: RecordingStatus = .idle
    
    private let transcriptionService: OpenAITranscriptionService?
    private let summaryService: EnhancedSummaryService
    private var currentCancelToken = CancellationToken()
    
    enum RecordingStatus {
        case idle
        case transcribing(progress: Double)
        case summarizing(progress: Double)
        case completed
        case failed(String)
    }
    
    init() {
        self.transcriptionService = OpenAITranscriptionService.createFromInfoPlist()
        self.summaryService = EnhancedSummaryService.shared
        
        if transcriptionService == nil {
            print("⚠️ RecordingViewModel: OpenAI API key not configured")
        }
    }
    
    func transcribe(fileURL: URL, languageHint: String? = nil) async {
        guard let service = transcriptionService else {
            await updateError("OpenAI API key not configured. Check Info.plist.")
            return
        }
        
        print("🔤 RecordingViewModel: Starting transcription for \(fileURL.lastPathComponent)")
        
        // Reset state
        transcript = ""
        errorMessage = nil
        isTranscribing = true
        transcriptionProgress = 0.0
        status = .transcribing(progress: 0.0)
        currentCancelToken = CancellationToken()
        
        do {
            let result = try await service.transcribe(
                fileURL: fileURL,
                languageHint: languageHint,
                progress: { progress in
                    Task { @MainActor in
                        self.transcriptionProgress = progress
                        self.status = .transcribing(progress: progress)
                    }
                },
                cancelToken: currentCancelToken
            )
            
            // Success - update UI on main thread
            transcript = result
            isTranscribing = false
            transcriptionProgress = 1.0
            status = .completed
            
            print("🔤 RecordingViewModel: ✅ Transcript updated (\(result.count) chars)")
            
            // Auto-start summarization if transcript is available
            if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await summarize(transcript: result)
            }
            
        } catch {
            await updateError("Transcription failed: \(error.localizedDescription)")
            print("🔤 RecordingViewModel: ❌ Transcription error: \(error)")
        }
    }
    
    func summarize(transcript: String) async {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await updateError("No transcript available for summarization")
            return
        }
        
        print("📝 RecordingViewModel: Starting summarization")
        
        // Update state
        summary = ""
        isSummarizing = true
        summarizationProgress = 0.0
        status = .summarizing(progress: 0.0)
        errorMessage = nil
        
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
                        self.summarizationProgress = progress
                        self.status = .summarizing(progress: progress)
                    }
                },
                cancelToken: currentCancelToken
            )
            
            // Success - use the clean summary for display
            summary = result.clean
            isSummarizing = false
            summarizationProgress = 1.0
            status = .completed
            
            print("📝 RecordingViewModel: ✅ Summary updated (\(result.clean.count) chars)")
            
        } catch {
            await updateError("Summarization failed: \(error.localizedDescription)")
            print("📝 RecordingViewModel: ❌ Summary error: \(error)")
        }
    }
    
    func retryTranscription(fileURL: URL, languageHint: String? = nil) async {
        await transcribe(fileURL: fileURL, languageHint: languageHint)
    }
    
    func retrySummarization() async {
        guard !transcript.isEmpty else {
            await updateError("No transcript available for retry")
            return
        }
        await summarize(transcript: transcript)
    }
    
    func cancelProcessing() {
        currentCancelToken = CancellationToken { true }
        
        isTranscribing = false
        isSummarizing = false
        status = .idle
        
        print("🚫 RecordingViewModel: Processing cancelled")
    }
    
    private func updateError(_ message: String) async {
        errorMessage = message
        isTranscribing = false
        isSummarizing = false
        status = .failed(message)
    }
    
    // For display purposes
    var statusText: String {
        switch status {
        case .idle:
            return "Ready"
        case .transcribing(let progress):
            return "Transcribing... \(Int(progress * 100))%"
        case .summarizing(let progress):
            return "Summarizing... \(Int(progress * 100))%"
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
    
    var hasContent: Bool {
        !transcript.isEmpty || !summary.isEmpty
    }
    
    var isProcessing: Bool {
        isTranscribing || isSummarizing
    }
}