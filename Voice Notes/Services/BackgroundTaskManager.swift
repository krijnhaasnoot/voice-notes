import Foundation
import UIKit

@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private let backgroundTaskIdentifier = "com.kinder.Voice-Notes.refresh"
    private var processingTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var isRegistered = false
    
    private init() {}
    
    func registerBackgroundTasks() {
        // No BGTaskScheduler registration needed for basic background tasks
        isRegistered = true
        print("📱 BackgroundTaskManager: Background task support enabled")
    }
    
    func scheduleBackgroundProcessing() {
        // For audio apps, processing continues while audio is active
        print("📱 BackgroundTaskManager: Background processing available during audio sessions")
    }
    
    func beginBackgroundTask(name: String = "Processing") -> UIBackgroundTaskIdentifier {
        let taskId = UIApplication.shared.beginBackgroundTask(withName: name) {
            // Called when time is about to expire
            self.endBackgroundTask()
        }
        
        if taskId != .invalid {
            print("📱 BackgroundTaskManager: Started background task \(taskId) for \(name)")
            processingTaskIdentifier = taskId
        }
        
        return taskId
    }
    
    func endBackgroundTask() {
        if processingTaskIdentifier != .invalid {
            print("📱 BackgroundTaskManager: Ending background task \(processingTaskIdentifier)")
            UIApplication.shared.endBackgroundTask(processingTaskIdentifier)
            processingTaskIdentifier = .invalid
        }
    }
    
    func processPendingRecordings() async {
        print("📱 BackgroundTaskManager: Processing pending recordings in background")
        
        let recordingsManager = RecordingsManager.shared
        let processingManager = ProcessingManager()
        
        // Find recordings that need processing
        let pendingRecordings = await recordingsManager.recordings.filter { recording in
            // Need transcription
            if recording.transcript == nil || recording.transcript?.isEmpty == true {
                return true
            }
            // Need summary but have transcript
            if recording.summary == nil || recording.summary?.isEmpty == true,
               let transcript = recording.transcript, !transcript.isEmpty {
                return true
            }
            return false
        }
        
        print("📱 BackgroundTaskManager: Found \(pendingRecordings.count) recordings needing processing")
        
        // Process up to 3 recordings to avoid taking too much background time
        for recording in pendingRecordings.prefix(3) {
            if recording.transcript == nil || recording.transcript?.isEmpty == true {
                // Start transcription using resolved file URL
                let _ = processingManager.startTranscription(for: recording.id, audioURL: recording.resolvedFileURL)
                print("📱 BackgroundTaskManager: Started transcription for recording \(recording.id)")
            } else if recording.summary == nil || recording.summary?.isEmpty == true,
                      let transcript = recording.transcript, !transcript.isEmpty {
                // Start summarization
                let _ = processingManager.startSummarization(for: recording.id, transcript: transcript)
                print("📱 BackgroundTaskManager: Started summarization for recording \(recording.id)")
            }
            
            // Add small delay between processing requests
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
}