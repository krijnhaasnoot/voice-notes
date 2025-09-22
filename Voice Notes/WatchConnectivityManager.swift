#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

enum WatchMessageKey: String {
    case command
    case status
    case duration
}

enum WatchCommand: String {
    case startRecording
    case stopRecording
    case pauseRecording
    case resumeRecording
}

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private weak var audioRecorder: AudioRecorder?
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func setAudioRecorder(_ recorder: AudioRecorder) {
        self.audioRecorder = recorder
    }
    
    func sendStatus(isRecording: Bool, duration: TimeInterval) {
        let session = WCSession.default
        let message: [String: Any] = [
            WatchMessageKey.status.rawValue: isRecording,
            WatchMessageKey.duration.rawValue: duration
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            do {
                try session.updateApplicationContext(message)
            } catch {
                // Handle error if needed
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation completion if needed
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        // Handle reachability change if needed
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive if needed
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Handle session deactivation if needed
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let commandRaw = message[WatchMessageKey.command.rawValue] as? String,
              let command = WatchCommand(rawValue: commandRaw) else {
            return
        }
        
        Task { @MainActor in
            guard let recorder = self.audioRecorder else { return }
            switch command {
            case .startRecording:
                recorder.startRecording()
            case .stopRecording:
                recorder.stopRecording()
            case .pauseRecording:
                recorder.pauseRecording()
            case .resumeRecording:
                recorder.resumeRecording()
            }
        }
    }
}

// Future counterpart for watchOS to handle sending commands to iOS device.
#endif
