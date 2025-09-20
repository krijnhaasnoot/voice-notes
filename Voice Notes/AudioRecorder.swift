import Foundation
import AVFoundation
import UIKit

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    @Published var lastError: String?
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let maxRecordingDuration: TimeInterval = 3600 // 1 hour limit
    
    override init() {
        super.init()
        self.permissionStatus = audioSession.recordPermission
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSceneChange),
            name: UIScene.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIScene.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        print("🎵 Audio interruption: \(type == .began ? "began" : "ended")")
        
        if type == .began && isRecording {
            print("🎵 Stopping recording due to interruption")
            Task { @MainActor in
                let _ = stopRecording()
            }
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🎵 Audio route change: \(reason.rawValue)")
        
        if reason == .oldDeviceUnavailable && isRecording {
            print("🎵 Audio device unavailable, stopping recording")
            Task { @MainActor in
                let _ = stopRecording()
            }
        }
    }
    
    @objc private func handleSceneChange() {
        if isRecording {
            print("🎵 App backgrounded, continuing recording with background task")
            Task { @MainActor in
                startBackgroundTask()
            }
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        if isRecording {
            print("🎵 App entering foreground, recording still active")
            // The background task will automatically end when app becomes active
        }
    }
    
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                Task { @MainActor in
                    self.permissionStatus = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func ensureMicReady() async -> Bool {
        // Check permission first
        let currentPermission = audioSession.recordPermission
        print("🎵 Current permission: \(currentPermission.rawValue)")
        
        switch currentPermission {
        case .undetermined:
            print("🎵 Requesting microphone permission...")
            return await requestPermission()
            
        case .denied:
            await MainActor.run {
                lastError = "Microphone permission denied. Please enable in Settings."
            }
            return false
            
        case .granted:
            break
            
        @unknown default:
            return false
        }
        
        // Set up audio session
        do {
            print("🎵 Setting up audio session...")
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            
            print("🎵 Activating audio session...")
            try audioSession.setActive(true)
            
            print("🎵 ✅ Audio session ready")
            return true
            
        } catch {
            print("🎵 ❌ Failed to setup audio session: \(error)")
            await MainActor.run {
                lastError = "Failed to setup audio: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func startRecording() async -> String? {
        print("🎵 Starting recording...")
        
        // Ensure microphone is ready
        let isReady = await ensureMicReady()
        guard isReady else {
            print("🎵 ❌ Microphone not ready")
            return nil
        }
        
        // Stop any existing recording
        if isRecording {
            let _ = stopRecording()
        }
        
        // Create unique filename and URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let audioURL = documentsPath.appendingPathComponent(fileName)
        currentRecordingURL = audioURL
        
        print("🎵 Recording to: \(audioURL.path)")
        
        // High quality settings for better Whisper results
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,  // Was 12000 - too low!
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create recorder
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            
            // Critical: prepare the recorder
            guard audioRecorder?.prepareToRecord() == true else {
                print("🎵 ❌ Failed to prepare recorder")
                lastError = "Failed to prepare audio recorder"
                return nil
            }
            
            // Start recording
            guard audioRecorder?.record() == true else {
                print("🎵 ❌ Failed to start recording")
                lastError = "Failed to start recording"
                return nil
            }
            
            print("🎵 ✅ Recording started successfully")
            
            // Update UI state
            isRecording = true
            recordingStartTime = Date()
            recordingDuration = 0
            lastError = nil
            
            // Start background task for potential background recording
            startBackgroundTask()
            
            // Start timer for duration updates
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let startTime = self.recordingStartTime {
                    let currentDuration = Date().timeIntervalSince(startTime)
                    self.recordingDuration = currentDuration
                    
                    // Stop recording if max duration reached (1 hour)
                    if currentDuration >= self.maxRecordingDuration {
                        print("🎵 Maximum recording duration reached, stopping recording")
                        Task { @MainActor in
                            let _ = self.stopRecording()
                        }
                    }
                }
            }
            
            return fileName
            
        } catch {
            print("🎵 ❌ Recording setup failed: \(error)")
            lastError = "Recording failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    func stopRecording() -> (duration: TimeInterval, fileURL: URL?, fileSize: Int64?) {
        print("🎵 Stopping recording...")
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // End background task
        endBackgroundTask()
        
        isRecording = false
        
        let finalDuration = recordingDuration
        recordingDuration = 0
        recordingStartTime = nil
        
        // Check file was created and has content
        guard let fileURL = currentRecordingURL else {
            print("🎵 ❌ No recording URL")
            return (finalDuration, nil, nil)
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            print("🎵 ✅ Recording saved:")
            print("    Path: \(fileURL.path)")
            print("    Size: \(fileSize) bytes")
            print("    Duration: \(String(format: "%.1f", finalDuration))s")
            
            if fileSize == 0 {
                print("🎵 ❌ WARNING: Recording file is empty!")
                lastError = "Recording file is empty - please try again"
                return (finalDuration, fileURL, 0)
            }
            
            return (finalDuration, fileURL, fileSize)
            
        } catch {
            print("🎵 ❌ Failed to check recording file: \(error)")
            lastError = "Failed to verify recording file"
            return (finalDuration, fileURL, nil)
        }
    }
    
    func pauseRecording() {
        guard isRecording, let recorder = audioRecorder else { return }
        
        print("🎵 Pausing recording...")
        recorder.pause()
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func resumeRecording() {
        guard isRecording, let recorder = audioRecorder else { return }
        
        print("🎵 Resuming recording...")
        guard recorder.record() else {
            print("🎵 ❌ Failed to resume recording")
            lastError = "Failed to resume recording"
            return
        }
        
        // Restart timer for duration updates
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = self.recordingStartTime {
                let currentDuration = Date().timeIntervalSince(startTime)
                self.recordingDuration = currentDuration
                
                // Stop recording if max duration reached (1 hour)
                if currentDuration >= self.maxRecordingDuration {
                    print("🎵 Maximum recording duration reached, stopping recording")
                    Task { @MainActor in
                        let _ = self.stopRecording()
                    }
                }
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func startBackgroundTask() {
        guard backgroundTaskID == .invalid else {
            print("🎵 Background task already active")
            return
        }
        
        print("🎵 Starting background task for recording")
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
            print("🎵 Background task expiring, ending task")
            self?.endBackgroundTask()
        }
        
        if backgroundTaskID == .invalid {
            print("🎵 ❌ Failed to start background task")
        } else {
            print("🎵 ✅ Background task started with ID: \(backgroundTaskID.rawValue)")
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else {
            return
        }
        
        print("🎵 Ending background task with ID: \(backgroundTaskID.rawValue)")
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    
    nonisolated private func endBackgroundTaskFromDelegate() {
        Task { @MainActor in
            self.endBackgroundTask()
        }
    }
    
    deinit {
        // Clean up background task from deinit (non-MainActor context)
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎵 Recording finished successfully: \(flag)")
        
        endBackgroundTaskFromDelegate()
        
        Task { @MainActor in
            if !flag {
                self.isRecording = false
                self.recordingTimer?.invalidate()
                self.recordingTimer = nil
                self.lastError = "Recording failed to complete properly"
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("🎵 ❌ Recording encode error: \(error?.localizedDescription ?? "unknown")")
        
        endBackgroundTaskFromDelegate()
        
        Task { @MainActor in
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.lastError = "Recording encoding error: \(error?.localizedDescription ?? "unknown")"
        }
    }
}

