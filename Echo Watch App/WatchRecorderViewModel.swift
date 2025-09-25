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
    @Published var statusText = "Idle"
    
    // Read-only proxies for UI consumption
    var isConnectivityActivated: Bool { connectivityClient.isActivated }
    var isConnectivityReachable: Bool { connectivityClient.isReachable }

    func retryConnection() { connectivityClient.retryConnection() }
    func requestInitialStatus() { connectivityClient.sendCommand("requestStatus") }
    
    private var durationTimer: Timer?
    private var lastStatusUpdate = Date()
    private let connectivityClient = WatchConnectivityClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupConnectivityObservers()
        requestInitialStatus()
    }
    
    private func setupConnectivityObservers() {
        connectivityClient.$isReachable
            .receive(on: DispatchQueue.main)
            .assign(to: \.isReachable, on: self)
            .store(in: &cancellables)
        
        connectivityClient.$isReachable
            .receive(on: DispatchQueue.main)
            .assign(to: \.isReachable, on: self)
            .store(in: &cancellables)
    }
    
    func updateStatus(isRecording: Bool, duration: TimeInterval) {
        self.isRecording = isRecording
        self.duration = duration
        self.lastStatusUpdate = Date()
        
        updateStatusText()
        
        if isRecording && !isPaused {
            startDurationTimer()
        } else {
            stopDurationTimer()
        }
    }
    
    private func updateStatusText() {
        if !isReachable {
            statusText = "Phone not reachable"
        } else if isSending {
            statusText = "Sending..."
        } else if isRecording && !isPaused {
            statusText = "Recording..."
        } else if isRecording && isPaused {
            statusText = "Paused"
        } else {
            statusText = "Idle"
        }
    }
    
    private func startDurationTimer() {
        stopDurationTimer()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                let timeSinceLastUpdate = Date().timeIntervalSince(self.lastStatusUpdate)
                if timeSinceLastUpdate < 5.0 {
                    self.duration += 1.0
                }
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    func start() {
        guard isReachable && !isSending else { return }
        
        isSending = true
        updateStatusText()
        
        connectivityClient.sendCommand("startRecording")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSending = false
            self.updateStatusText()
        }
    }
    
    func stop() {
        guard isReachable && !isSending else { return }
        
        isSending = true
        updateStatusText()
        
        connectivityClient.sendCommand("stopRecording")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSending = false
            self.updateStatusText()
        }
    }
    
    func pause() {
        guard isReachable && !isSending && isRecording else { return }
        
        isSending = true
        isPaused = true
        updateStatusText()
        
        connectivityClient.sendCommand("pauseRecording")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSending = false
            self.updateStatusText()
        }
    }
    
    func resume() {
        guard isReachable && !isSending && isRecording && isPaused else { return }
        
        isSending = true
        isPaused = false
        updateStatusText()
        
        connectivityClient.sendCommand("resumeRecording")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSending = false
            self.updateStatusText()
        }
    }
}
#endif
