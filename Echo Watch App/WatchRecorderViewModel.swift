#if os(watchOS)
import Foundation
import Combine

@MainActor
final class WatchRecorderViewModel: ObservableObject {
    static let shared = WatchRecorderViewModel()

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var duration: TimeInterval = 0
    @Published var isReachable = false
    @Published var isSending = false
    @Published var statusText = "Tap to record"

    // Read-only proxies for UI consumption
    var isConnectivityActivated: Bool { connectivityClient.isActivated }
    var isConnectivityReachable: Bool { connectivityClient.isReachable }

    func retryConnection() { connectivityClient.retryConnection() }
    func requestInitialStatus() { /* No-op for standalone recording */ }

    private let audioRecorder = WatchAudioRecorder()
    private let connectivityClient = WatchConnectivityClient.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupConnectivityObservers()
        setupAudioRecorderObservers()
    }

    private func setupConnectivityObservers() {
        connectivityClient.$isReachable
            .receive(on: DispatchQueue.main)
            .assign(to: \.isReachable, on: self)
            .store(in: &cancellables)
    }

    private func setupAudioRecorderObservers() {
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
                self?.updateStatusText()
            }
            .store(in: &cancellables)

        audioRecorder.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPaused in
                self?.isPaused = isPaused
                self?.updateStatusText()
            }
            .store(in: &cancellables)

        audioRecorder.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: \.duration, on: self)
            .store(in: &cancellables)
    }

    private func updateStatusText() {
        if isSending {
            statusText = "Transferring..."
        } else if isRecording && !isPaused {
            statusText = "Recording..."
        } else if isRecording && isPaused {
            statusText = "Paused"
        } else if !isReachable {
            statusText = "iPhone not reachable"
        } else {
            statusText = "Tap to record"
        }
    }

    func start() {
        guard !isRecording else { return }

        statusText = "Starting..."
        audioRecorder.startRecording()
        updateStatusText()
    }

    func stop() {
        guard isRecording else { return }

        let result = audioRecorder.stopRecording()

        guard let fileURL = result.fileURL else {
            statusText = "Recording failed"
            print("⌚ ViewModel: ❌ No file URL from recorder")
            return
        }

        // Transfer file to iPhone
        transferRecordingToiPhone(fileURL: fileURL, duration: result.duration)
    }

    func pause() {
        guard isRecording && !isPaused else { return }
        audioRecorder.pauseRecording()
    }

    func resume() {
        guard isRecording && isPaused else { return }
        audioRecorder.resumeRecording()
    }

    private func transferRecordingToiPhone(fileURL: URL, duration: TimeInterval) {
        isSending = true
        updateStatusText()

        print("⌚ ViewModel: Transferring recording to iPhone...")

        connectivityClient.transferRecording(fileURL: fileURL, duration: duration) { [weak self] success, error in
            Task { @MainActor in
                guard let self = self else { return }

                self.isSending = false

                if success {
                    self.statusText = "Sent to iPhone!"
                    print("⌚ ViewModel: ✅ Recording transferred successfully")

                    // Delete local file after successful transfer
                    self.audioRecorder.deleteRecording(at: fileURL)

                    // Reset status after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.updateStatusText()
                    }
                } else {
                    self.statusText = "Transfer failed"
                    print("⌚ ViewModel: ❌ Transfer failed: \(error?.localizedDescription ?? "unknown")")

                    // Reset status after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.updateStatusText()
                    }
                }
            }
        }
    }
}
#endif
