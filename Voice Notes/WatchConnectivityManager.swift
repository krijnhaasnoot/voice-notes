#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

enum WatchMessageKey: String {
    case command
    case status
    case duration
    case type
    case timestamp
    case timestampReceived
    case timestampReply
}

enum WatchCommand: String {
    case startRecording
    case stopRecording
    case pauseRecording
    case resumeRecording
    case requestStatus
    case ping
    case pong
}

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var hasNewFromWatch: Bool = false
    private weak var audioRecorder: AudioRecorder?
    private weak var recordingsManager: RecordingsManager?
    
    private override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("📱 WC: WCSession NOT supported on this device")
            return
        }
        
        let session = WCSession.default
        print("📱 WC: Setting up WatchConnectivity...")
        print("📱 WC: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("📱 WC: Current session state BEFORE activation:")
        print("📱 WC: - activationState: \(activationStateString(session.activationState))")
        print("📱 WC: - isReachable: \(session.isReachable)")
        print("📱 WC: - isPaired: \(session.isPaired)")
        print("📱 WC: - isWatchAppInstalled: \(session.isWatchAppInstalled)")
        
        if session.delegate == nil {
            print("📱 WC: Setting delegate...")
            session.delegate = self
        } else {
            print("📱 WC: Delegate already set")
        }
        
        if session.activationState == .notActivated {
            print("📱 WC: Activating session...")
            session.activate()
        } else {
            print("📱 WC: Session already activated with state: \(activationStateString(session.activationState))")
            // Still log current status even if already activated
            logCurrentStatus()
        }
    }
    
    func setAudioRecorder(_ recorder: AudioRecorder) {
        self.audioRecorder = recorder
    }
    
    func setRecordingsManager(_ manager: RecordingsManager) {
        self.recordingsManager = manager
    }
    
    func forceReconnect() {
        print("📱 WC: Force reconnect requested")
        setupWatchConnectivity()
    }
    
    func diagnoseConnectionIssue() {
        print("📱 WC: === CONNECTION DIAGNOSIS ===")
        let session = WCSession.default
        
        print("📱 WC: Basic Checks:")
        print("📱 WC: - WCSession supported: \(WCSession.isSupported())")
        print("📱 WC: - Activation state: \(activationStateString(session.activationState))")
        print("📱 WC: - Is paired: \(session.isPaired)")
        print("📱 WC: - Is reachable: \(session.isReachable)")
        print("📱 WC: - Watch app installed: \(session.isWatchAppInstalled)")
        
        if !WCSession.isSupported() {
            print("📱 WC: ❌ WCSession not supported on this device")
        }
        
        if session.activationState != .activated {
            print("📱 WC: ❌ Session not activated - state: \(activationStateString(session.activationState))")
        }
        
        if !session.isPaired {
            print("📱 WC: ❌ Watch not paired to this iPhone")
            print("📱 WC: ACTION: Pair your Apple Watch with this iPhone in the Watch app")
        }
        
        if !session.isWatchAppInstalled {
            print("📱 WC: ❌ Watch app not installed")
            print("📱 WC: ACTION: Install the watch app from the iPhone Watch app")
        }
        
        if session.isPaired && session.isWatchAppInstalled && !session.isReachable {
            print("📱 WC: ❌ Watch app installed but not reachable")
            print("📱 WC: ACTION: Make sure watch app is running and watch is connected")
        }
        
        print("📱 WC: Bundle Info:")
        print("📱 WC: - iPhone Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        print("📱 WC: Dependencies:")
        print("📱 WC: - AudioRecorder set: \(audioRecorder != nil)")
        print("📱 WC: - RecordingsManager set: \(recordingsManager != nil)")
        
        print("📱 WC: === END DIAGNOSIS ===")
    }
    
    private func handleIncomingCommand(_ cmd: String) {
        Task { @MainActor in
            guard let recorder = self.audioRecorder else {
                print("⚠️ AudioRecorder not set on WatchConnectivityManager"); return
            }
            switch WatchCommand(rawValue: cmd) {
            case .startRecording:
                print("🎵 WC: startRecording")
                await recorder.startRecording()
                self.sendStatus(isRecording: recorder.isRecording, duration: recorder.recordingDuration)

            case .stopRecording:
                let result = recorder.stopRecording()
                print("🎵 WC: stopRecording -> \(result.fileURL?.lastPathComponent ?? "nil") (dur \(result.duration))")
                if let fileURL = result.fileURL {
                    let recording = Recording(
                        fileName: fileURL.lastPathComponent,
                        date: Date(),
                        duration: result.duration,
                        title: ""
                    )
                    self.recordingsManager?.addRecording(recording)
                    self.hasNewFromWatch = true
                    NotificationCenter.default.post(name: Notification.Name("newRecordingFromWatch"), object: nil)
                }
                self.sendStatus(isRecording: recorder.isRecording, duration: recorder.recordingDuration)

            case .pauseRecording:
                recorder.pauseRecording()
                self.sendStatus(isRecording: recorder.isRecording, duration: recorder.recordingDuration)

            case .resumeRecording:
                recorder.resumeRecording()
                self.sendStatus(isRecording: recorder.isRecording, duration: recorder.recordingDuration)

            case .requestStatus:
                self.sendStatus(isRecording: recorder.isRecording, duration: recorder.recordingDuration)

            case .ping:
                print("🏓 WC: Received ping command, sending pong response")
                let pongMessage: [String: Any] = [
                    WatchMessageKey.type.rawValue: "pong",
                    WatchMessageKey.timestampReply.rawValue: Date().timeIntervalSince1970
                ]
                sendPong(pongMessage)
                
            case .pong:
                print("🏓 WC: Received pong command")
                // Handle pong response - could be used for latency measurement
                
            case .none:
                print("⚠️ WC: Unknown command received")
                break
            }
        }
    }
    
    func sendStatus(isRecording: Bool, duration: TimeInterval) {
        let session = WCSession.default
        let message: [String: Any] = [
            "type": "status",
            WatchMessageKey.status.rawValue: isRecording,
            WatchMessageKey.duration.rawValue: duration
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            do { try session.updateApplicationContext(message) } catch { }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            let stateStr = self.activationStateString(activationState)
            print("📱 WC: activationDidCompleteWith state=\(stateStr)")
            
            if let error = error {
                print("📱 WC: ❌ Activation error: \(error.localizedDescription)")
            } else {
                print("📱 WC: ✅ Activation completed successfully")
                self.logCurrentStatus()
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("📱 WC: reachabilityDidChange - isReachable=\(session.isReachable)")
            self.logCurrentStatus()
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            print("📱 WC: sessionDidBecomeInactive")
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            print("📱 WC: sessionDidDeactivate - reactivating...")
            session.activate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            print("📱 WC: didReceiveMessage: \(message)")
            self.handleIncomingMessage(message, source: "sendMessage")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            print("📱 WC: didReceiveMessage (with reply): \(message)")
            let reply = self.handleIncomingMessage(message, source: "sendMessage+reply")
            replyHandler(reply)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            print("📱 WC: didReceiveUserInfo: \(userInfo)")
            let _ = self.handleIncomingMessage(userInfo, source: "transferUserInfo")
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("📱 WC: didReceiveApplicationContext: \(applicationContext)")
            let _ = self.handleIncomingMessage(applicationContext, source: "updateApplicationContext")
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        DispatchQueue.main.async {
            print("📱 WC: didReceiveFile: \(file.fileURL.lastPathComponent)")
            print("📱 WC: Metadata: \(file.metadata ?? [:])")

            self.handleReceivedFile(file)
        }
    }

    private func handleReceivedFile(_ file: WCSessionFile) {
        guard let metadata = file.metadata,
              let type = metadata["type"] as? String,
              type == "recording" else {
            print("📱 WC: ❌ Received file with invalid metadata")
            return
        }

        let duration = metadata["duration"] as? TimeInterval ?? 0
        let originalFilename = metadata["filename"] as? String ?? file.fileURL.lastPathComponent

        // Move file to app's documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(originalFilename)

        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Move the received file
            try FileManager.default.moveItem(at: file.fileURL, to: destinationURL)

            print("📱 WC: ✅ File saved to: \(destinationURL.lastPathComponent)")

            // Create recording object
            let recording = Recording(
                fileName: originalFilename,
                date: Date(),
                duration: duration,
                title: ""
            )

            // Add to recordings manager
            self.recordingsManager?.addRecording(recording)
            self.hasNewFromWatch = true

            // Post notification
            NotificationCenter.default.post(name: Notification.Name("newRecordingFromWatch"), object: nil)

            print("📱 WC: ✅ Recording added to library")
        } catch {
            print("📱 WC: ❌ Failed to save received file: \(error)")
        }
    }

    // MARK: - Helper Methods
    
    private func activationStateString(_ state: WCSessionActivationState) -> String {
        switch state {
        case .notActivated: return "notActivated"
        case .inactive: return "inactive"
        case .activated: return "activated"
        @unknown default: return "unknown"
        }
    }
    
    private func logCurrentStatus() {
        let session = WCSession.default
        print("📱 WC: === Current Status ===")
        print("📱 WC: isSupported: \(WCSession.isSupported())")
        print("📱 WC: activationState: \(activationStateString(session.activationState))")
        print("📱 WC: isReachable: \(session.isReachable)")
        print("📱 WC: isPaired: \(session.isPaired)")
        print("📱 WC: isWatchAppInstalled: \(session.isWatchAppInstalled)")
        print("📱 WC: ===================")
    }
    
    private func handleIncomingMessage(_ message: [String: Any], source: String) -> [String: Any] {
        guard let type = message[WatchMessageKey.type.rawValue] as? String else {
            print("📱 WC: ❌ No type in message from \(source)")
            return [:]
        }
        
        switch type {
        case "command":
            if let cmd = message["cmd"] as? String {
                print("📱 WC: Handling command '\(cmd)' from \(source)")
                handleIncomingCommand(cmd)
            }
            return [:]
            
        case "ping":
            // Handle ping from Watch
            let timestampReceived = Date().timeIntervalSince1970
            let timestampReply = Date().timeIntervalSince1970
            
            print("📱 WC: 🏓 Received ping from \(source), sending pong")
            
            let pongMessage: [String: Any] = [
                WatchMessageKey.type.rawValue: "pong",
                WatchMessageKey.timestampReceived.rawValue: timestampReceived,
                WatchMessageKey.timestampReply.rawValue: timestampReply
            ]
            
            // If this came from sendMessage with reply, return the pong
            if source.contains("reply") {
                return pongMessage
            } else {
                // Send pong back via sendMessage if possible
                sendPong(pongMessage)
                return [:]
            }
            
        default:
            print("📱 WC: Unknown message type '\(type)' from \(source)")
            return [:]
        }
    }
    
    private func sendPong(_ pongMessage: [String: Any]) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(pongMessage, replyHandler: nil) { error in
                print("📱 WC: ❌ Failed to send pong: \(error.localizedDescription)")
            }
        } else {
            // Use transferUserInfo as fallback
            session.transferUserInfo(pongMessage)
            print("📱 WC: 📤 Sent pong via transferUserInfo (not reachable)")
        }
    }
}

// Future counterpart for watchOS to handle sending commands to iOS device.
#endif

