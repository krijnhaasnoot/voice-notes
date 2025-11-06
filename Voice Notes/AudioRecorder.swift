import AVFoundation
import SwiftUI
import UIKit
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// Notification for when recording is auto-stopped due to background task expiration
extension Notification.Name {
    static let recordingAutoStopped = Notification.Name("recordingAutoStopped")
}

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()   // <-- singleton

    private var audioRecorder: AVAudioRecorder?
    private let audioSession = AVAudioSession.sharedInstance()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let maxRecordingDuration: TimeInterval = 3600  // 60 minutes - reasonable limit for transcription quality
    private let telemetryService = EnhancedTelemetryService.shared
    private var hasShownMaxDurationWarning = false

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    @Published var lastError: String?
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseTime: Date?
    private var currentRecordingURL: URL?
    
#if canImport(WatchConnectivity)
    private var wcManager: WatchConnectivityManager?
#endif

    private override init() {             // <-- private init
        super.init()
        if #available(iOS 17.0, *) {
            // Map AVAudioApplication permission to AVAudioSession.RecordPermission for published state
            let appPerm = AVAudioApplication.shared.recordPermission
            switch appPerm {
            case .undetermined: self.permissionStatus = .undetermined
            case .denied: self.permissionStatus = .denied
            case .granted: self.permissionStatus = .granted
            @unknown default: self.permissionStatus = .denied
            }
        } else {
            self.permissionStatus = audioSession.recordPermission
        }
        setupNotifications()
#if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            // Initialize WatchConnectivity manager if publicly initializable
            if let manager = (WatchConnectivityManager.self as AnyObject) as? Any {
                // Attempt to use a shared or default instance if available; otherwise skip
                // NOTE: If WatchConnectivityManager provides a shared instance, replace the next line with it.
                // wcManager = WatchConnectivityManager.shared
            }
            wcManager?.setAudioRecorder(self)
        }
#endif
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
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

            // Invalidate the UI update timer to reduce background activity
            // The recording will continue but we don't need UI updates
            recordingTimer?.invalidate()
            recordingTimer = nil

            Task { @MainActor in
                startBackgroundTask()
            }
        }
    }

    @objc private func handleAppWillEnterForeground() {
        if isRecording {
            print("🎵 App entering foreground, recording still active")

            // Update duration immediately to reflect time spent in background
            if let startTime = recordingStartTime {
                let totalElapsed = Date().timeIntervalSince(startTime)
                let activeDuration = totalElapsed - pausedDuration
                recordingDuration = activeDuration
                print("🎵 Recording duration after background: \(String(format: "%.1f", activeDuration))s")
            }

            // Restart the timer for UI updates now that we're in foreground
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if let startTime = self.recordingStartTime {
                    let totalElapsed = Date().timeIntervalSince(startTime)
                    let activeDuration = totalElapsed - self.pausedDuration
                    self.recordingDuration = activeDuration

                    // Warn user when approaching max duration (55 minutes)
                    if activeDuration >= 3300 && !self.hasShownMaxDurationWarning {
                        print("🎵 ⚠️ Approaching maximum recording duration (55 minutes)")
                        self.hasShownMaxDurationWarning = true
                        Task { @MainActor in
                            self.lastError = "Recording will automatically stop at 60 minutes"
                        }
                    }

                    // Stop recording if max duration reached (60 minutes)
                    if activeDuration >= self.maxRecordingDuration {
                        print("🎵 ⏱️ Maximum recording duration (60 minutes) reached - auto-saving recording")
                        Task { @MainActor in
                            let _ = self.stopRecording()
                        }
                    }
                }
            }
        }
    }

    @objc private func handleAppWillTerminate() {
        if isRecording {
            print("🎵 ⚠️ App terminating while recording - saving recording")
            // Force save the recording before app terminates
            let _ = stopRecording()
        }
    }
    
    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        self.permissionStatus = granted ? .granted : .denied
                        continuation.resume(returning: granted)
                    }
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    Task { @MainActor in
                        self.permissionStatus = granted ? AVAudioSession.RecordPermission.granted : AVAudioSession.RecordPermission.denied
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    func ensureMicReady() async -> Bool {
        // Check permission first
        let currentPermission: AVAudioSession.RecordPermission
        if #available(iOS 17.0, *) {
            let appPerm = AVAudioApplication.shared.recordPermission
            switch appPerm {
            case .undetermined: currentPermission = .undetermined
            case .denied: currentPermission = .denied
            case .granted: currentPermission = .granted
            @unknown default: currentPermission = .denied
            }
        } else {
            currentPermission = audioSession.recordPermission
        }
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
            print("🎵 Setting up audio session for background recording...")
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )

            print("🎵 Activating audio session...")
            try audioSession.setActive(true)

            print("🎵 ✅ Audio session ready with background audio support")
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
            pausedDuration = 0
            lastPauseTime = nil
            lastError = nil
            hasShownMaxDurationWarning = false  // Reset warning for new recording

            // Track recording start
            telemetryService.logRecordingStart()

            // Analytics: recording started
            let selectedMode = UserDefaults.standard.string(forKey: "defaultMode") ?? "personal"
            Analytics.track("recording_started", props: [
                "source": "ios",
                "mode": selectedMode
            ])

            // Start background task for potential background recording
            startBackgroundTask()
            
            // Start timer for duration updates
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let startTime = self.recordingStartTime {
                    let totalElapsed = Date().timeIntervalSince(startTime)
                    let activeDuration = totalElapsed - self.pausedDuration
                    self.recordingDuration = activeDuration

                    // Warn user when approaching max duration (55 minutes)
                    if activeDuration >= 3300 && !self.hasShownMaxDurationWarning {
                        print("🎵 ⚠️ Approaching maximum recording duration (55 minutes)")
                        self.hasShownMaxDurationWarning = true
                        Task { @MainActor in
                            self.lastError = "Recording will automatically stop at 60 minutes"
                        }
                    }

                    // Stop recording if max duration reached (60 minutes)
                    if activeDuration >= self.maxRecordingDuration {
                        print("🎵 ⏱️ Maximum recording duration (60 minutes) reached - auto-saving recording")
                        Task { @MainActor in
                            let _ = self.stopRecording()
                        }
                    }
                }
            }
            
            notifyWatch()
            
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
        
        notifyWatch()
        
        let finalDuration = recordingDuration
        recordingDuration = 0
        recordingStartTime = nil
        pausedDuration = 0
        lastPauseTime = nil
        
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
            
            // Track successful recording stop
            telemetryService.logRecordingStop(
                duration: finalDuration,
                hasTranscript: false, // Will be updated later when processing completes
                hasSummary: false,
                provider: UserDefaults.standard.string(forKey: "selectedProvider"),
                mode: UserDefaults.standard.string(forKey: "defaultMode"),
                length: UserDefaults.standard.string(forKey: "defaultSummaryLength")
            )
            
            // Analytics: recording stopped
            Analytics.track("recording_stopped", props: [
                "duration_s": Int(finalDuration)
            ])
            
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
        lastPauseTime = Date()
        
        print("🎵 Recording paused at duration: \(String(format: "%.1f", recordingDuration))s")
        print("🎵 File: \(currentRecordingURL?.lastPathComponent ?? "unknown")")
        
        notifyWatch()
    }
    
    func resumeRecording() {
        guard isRecording, let recorder = audioRecorder else { return }
        
        print("🎵 Resuming recording...")
        
        // Add the pause duration to our total paused time
        if let pauseTime = lastPauseTime {
            let pauseDuration = Date().timeIntervalSince(pauseTime)
            pausedDuration += pauseDuration
            print("🎵 Pause duration: \(String(format: "%.1f", pauseDuration))s, total paused: \(String(format: "%.1f", pausedDuration))s")
        }
        lastPauseTime = nil
        
        guard recorder.record() else {
            print("🎵 ❌ Failed to resume recording")
            lastError = "Failed to resume recording"
            return
        }
        
        // Restart timer for duration updates
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = self.recordingStartTime {
                let totalElapsed = Date().timeIntervalSince(startTime)
                let activeDuration = totalElapsed - self.pausedDuration
                self.recordingDuration = activeDuration
                
                // Stop recording if max duration reached (1 hour)
                if activeDuration >= self.maxRecordingDuration {
                    print("🎵 Maximum recording duration reached, stopping recording")
                    Task { @MainActor in
                        let _ = self.stopRecording()
                    }
                }
            }
        }
        
        print("🎵 Recording resumed at duration: \(String(format: "%.1f", recordingDuration))s")
        print("🎵 File: \(currentRecordingURL?.lastPathComponent ?? "unknown")")
        
        notifyWatch()
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
            print("🎵 ⚠️ Background task expiring - saving recording before termination")

            // CRITICAL: Use DispatchQueue.main.sync to ensure we complete before expiration
            // This is one of the few cases where sync is necessary to prevent data loss
            guard let strongSelf = self else {
                UIApplication.shared.endBackgroundTask(self?.backgroundTaskID ?? .invalid)
                return
            }

            // Check if we're on main thread already, if not dispatch sync
            if Thread.isMainThread {
                strongSelf.handleBackgroundTaskExpiration()
            } else {
                DispatchQueue.main.sync {
                    strongSelf.handleBackgroundTaskExpiration()
                }
            }
        }

        if backgroundTaskID == .invalid {
            print("🎵 ❌ Failed to start background task")
        } else {
            print("🎵 ✅ Background task started with ID: \(backgroundTaskID.rawValue)")
        }
    }

    @MainActor
    private func handleBackgroundTaskExpiration() {
        guard isRecording else {
            endBackgroundTask()
            return
        }

        print("🎵 🔴 Auto-stopping recording due to background task expiration")
        let result = stopRecording()

        // Set error message for user to see when they return
        lastError = "Recording was automatically saved when app went to background"

        // Post notification so the UI can handle saving the recording
        if let fileURL = result.fileURL, let fileSize = result.fileSize, fileSize > 0 {
            NotificationCenter.default.post(
                name: .recordingAutoStopped,
                object: nil,
                userInfo: [
                    "fileName": fileURL.lastPathComponent,
                    "duration": result.duration,
                    "fileURL": fileURL,
                    "fileSize": fileSize
                ]
            )
        }

        endBackgroundTask()
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
    
    @MainActor
    private func notifyWatch() {
#if canImport(WatchConnectivity)
        wcManager?.sendStatus(isRecording: self.isRecording, duration: self.recordingDuration)
#endif
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
                self.notifyWatch()
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
            self.notifyWatch()
        }
    }
}
