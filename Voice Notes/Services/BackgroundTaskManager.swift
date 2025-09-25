import Foundation
import UIKit
import BackgroundTasks

@MainActor
class BackgroundTaskManager: ObservableObject {
    static let shared = BackgroundTaskManager()
    
    private let backgroundTaskIdentifier = "com.kinder.Voice-Notes.processing"
    private var processingTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var isRegistered = false
    
    private init() {}
    
    func registerBackgroundTasks() {
        guard !isRegistered else { return }
        
        // Register background app refresh task
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
        
        if success {
            print("📱 BackgroundTaskManager: Successfully registered background task")
            isRegistered = true
        } else {
            print("❌ BackgroundTaskManager: Failed to register background task")
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2) // Start in 2 seconds
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📱 BackgroundTaskManager: Background processing scheduled")
        } catch {
            print("❌ BackgroundTaskManager: Failed to schedule background task: \(error)")
        }
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
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        print("📱 BackgroundTaskManager: Handling background processing task")
        
        // Schedule next background processing
        scheduleBackgroundProcessing()
        
        task.expirationHandler = {
            print("📱 BackgroundTaskManager: Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Start processing any pending recordings
        Task {
            await processePendingRecordings()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func processePendingRecordings() async {
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
                // Start transcription - need audio URL
                if let audioURL = recording.fileURL {
                    let _ = processingManager.startTranscription(for: recording.id, audioURL: audioURL)
                    print("📱 BackgroundTaskManager: Started transcription for recording \(recording.id)")
                }
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