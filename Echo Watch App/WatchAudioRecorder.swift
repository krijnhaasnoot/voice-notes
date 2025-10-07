#if os(watchOS)
import Foundation
import AVFoundation
import WatchKit

@MainActor
final class WatchAudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    private var recordingURL: URL?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var timer: Timer?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession?.setCategory(.record, mode: .default)
            try recordingSession?.setActive(true)
            print("⌚ WatchAudioRecorder: Audio session configured successfully")
        } catch {
            print("⌚ WatchAudioRecorder: ❌ Failed to setup audio session: \(error)")
        }
    }

    func startRecording() {
        guard !isRecording else {
            print("⌚ WatchAudioRecorder: Already recording")
            return
        }

        // Request microphone permission
        recordingSession?.requestRecordPermission { [weak self] allowed in
            Task { @MainActor in
                guard let self = self else { return }

                if allowed {
                    self.beginRecording()
                } else {
                    print("⌚ WatchAudioRecorder: ❌ Microphone permission denied")
                }
            }
        }
    }

    private func beginRecording() {
        // Create unique filename with timestamp
        let timestamp = Date().timeIntervalSince1970
        let filename = "watch_recording_\(Int(timestamp)).m4a"

        // Use documents directory for recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent(filename)

        guard let url = recordingURL else {
            print("⌚ WatchAudioRecorder: ❌ Failed to create recording URL")
            return
        }

        // Configure audio settings for optimal quality
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            let success = audioRecorder?.record() ?? false

            if success {
                isRecording = true
                startTime = Date()
                pausedDuration = 0
                startTimer()

                // Haptic feedback
                WKInterfaceDevice.current().play(.start)

                print("⌚ WatchAudioRecorder: ✅ Recording started at \(url.lastPathComponent)")
            } else {
                print("⌚ WatchAudioRecorder: ❌ Failed to start recording")
            }
        } catch {
            print("⌚ WatchAudioRecorder: ❌ Failed to create audio recorder: \(error)")
        }
    }

    func pauseRecording() {
        guard isRecording, !isPaused, let recorder = audioRecorder else { return }

        recorder.pause()
        isPaused = true
        stopTimer()

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)

        print("⌚ WatchAudioRecorder: Recording paused")
    }

    func resumeRecording() {
        guard isRecording, isPaused, let recorder = audioRecorder else { return }

        recorder.record()
        isPaused = false
        startTimer()

        // Haptic feedback
        WKInterfaceDevice.current().play(.click)

        print("⌚ WatchAudioRecorder: Recording resumed")
    }

    func stopRecording() -> (fileURL: URL?, duration: TimeInterval) {
        guard isRecording, let recorder = audioRecorder else {
            print("⌚ WatchAudioRecorder: Not recording")
            return (nil, 0)
        }

        stopTimer()
        recorder.stop()

        let finalDuration = recordingDuration
        let finalURL = recordingURL

        isRecording = false
        isPaused = false
        recordingDuration = 0
        pausedDuration = 0

        // Haptic feedback
        WKInterfaceDevice.current().play(.stop)

        print("⌚ WatchAudioRecorder: ✅ Recording stopped - Duration: \(finalDuration)s")

        if let url = finalURL {
            print("⌚ WatchAudioRecorder: File saved at: \(url.path)")

            // Check file size
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 {
                let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0
                print("⌚ WatchAudioRecorder: File size: \(String(format: "%.2f", fileSizeMB)) MB")
            }
        }

        return (finalURL, finalDuration)
    }

    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }

            Task { @MainActor in
                if !self.isPaused {
                    self.recordingDuration = Date().timeIntervalSince(start) - self.pausedDuration
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("⌚ WatchAudioRecorder: Deleted recording at \(url.lastPathComponent)")
        } catch {
            print("⌚ WatchAudioRecorder: ❌ Failed to delete recording: \(error)")
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension WatchAudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                print("⌚ WatchAudioRecorder: Recording finished successfully")
            } else {
                print("⌚ WatchAudioRecorder: ❌ Recording finished with error")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("⌚ WatchAudioRecorder: ❌ Encoding error: \(error.localizedDescription)")
            }
        }
    }
}
#endif
