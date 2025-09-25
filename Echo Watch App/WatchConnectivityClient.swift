#if os(watchOS)
import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityClient: NSObject, ObservableObject {
    static let shared = WatchConnectivityClient()

    @Published var isReachable = false
    @Published var isActivated = false
    // `isPaired` is not available on watchOS; keep our own flag derived from activation state
    @Published var isPaired = true
    @Published var isCompanionAppInstalled = false

    @Published var lastPingTime: Date?
    @Published var lastPongTime: Date?
    @Published var latencyMs: Int = 0

    private let session = WCSession.default

    private override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("⌚ WC: WCSession NOT supported on watchOS")
            return
        }
        
        print("⌚ WC: Setting up WatchConnectivity...")
        print("⌚ WC: Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("⌚ WC: Current session state BEFORE activation:")
        print("⌚ WC: - activationState: \(activationStateString(session.activationState))")
        print("⌚ WC: - isReachable: \(session.isReachable)")
        print("⌚ WC: - isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
        
        if session.delegate == nil {
            print("⌚ WC: Setting delegate...")
            session.delegate = self
        } else {
            print("⌚ WC: Delegate already set")
        }
        
        if session.activationState == .notActivated {
            print("⌚ WC: Activating session...")
            session.activate()
        } else {
            print("⌚ WC: Session already activated with state: \(activationStateString(session.activationState))")
            // Still log current status even if already activated
            logStatus()
        }
    }

    // MARK: - Commands

    func sendCommand(_ command: String) {
        let message: [String: Any] = [
            "type": "command",
            "cmd": command,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable && session.activationState == .activated {
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                DispatchQueue.main.async {
                    if let wcError = error as? WCError, wcError.code == .notReachable {
                        self?.sendCommandViaTransferUserInfo(command)
                    } else if error != nil {
                        self?.sendCommandViaTransferUserInfo(command)
                    }
                }
            }
        } else {
            sendCommandViaTransferUserInfo(command)
        }
    }

    private func sendCommandViaTransferUserInfo(_ command: String) {
        let message: [String: Any] = [
            "type": "command",
            "cmd": command,
            "timestamp": Date().timeIntervalSince1970
        ]
        session.transferUserInfo(message)
        print("⌚ WC: 📤 transferUserInfo(\(command))")
    }

    // MARK: - Ping / Pong

    func sendPing() {
        let pingTime = Date()
        lastPingTime = pingTime
        let message: [String: Any] = [
            "type": "ping",
            "timestamp": pingTime.timeIntervalSince1970
        ]

        if session.isReachable && session.activationState == .activated {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                DispatchQueue.main.async { self?.handlePongMessage(reply, pingTime: pingTime) }
            }, errorHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.session.transferUserInfo(message)
                    print("⌚ WC: 📤 ping via transferUserInfo (fallback)")
                }
            })
        } else {
            session.transferUserInfo(message)
            print("⌚ WC: 📤 ping via transferUserInfo (not reachable)")
        }
    }

    private func handlePongMessage(_ message: [String: Any], pingTime: Date) {
        lastPongTime = Date()
        let latency = lastPongTime!.timeIntervalSince(pingTime) * 1000
        latencyMs = Int(latency)
        print("⌚ WC: 🏓 pong latency \(latencyMs)ms")
    }

    func retryConnection() {
        print("⌚ WC: retryConnection()")
        setupWatchConnectivity()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.sendCommand("requestStatus")
        }
    }
    
    func diagnoseConnectionIssue() {
        print("⌚ WC: === CONNECTION DIAGNOSIS ===")
        
        print("⌚ WC: Basic Checks:")
        print("⌚ WC: - WCSession supported: \(WCSession.isSupported())")
        print("⌚ WC: - Activation state: \(activationStateString(session.activationState))")
        print("⌚ WC: - Is reachable: \(session.isReachable)")
        print("⌚ WC: - Is companion app installed: \(session.isCompanionAppInstalled)")
        
        if !WCSession.isSupported() {
            print("⌚ WC: ❌ WCSession not supported on watchOS")
        }
        
        if session.activationState != .activated {
            print("⌚ WC: ❌ Session not activated - state: \(activationStateString(session.activationState))")
        }
        
        if !session.isCompanionAppInstalled {
            print("⌚ WC: ❌ iPhone companion app not installed")
            print("⌚ WC: ACTION: Install Voice Notes app on iPhone")
        }
        
        if session.isCompanionAppInstalled && !session.isReachable {
            print("⌚ WC: ❌ iPhone app installed but not reachable")
            print("⌚ WC: ACTION: Make sure iPhone app is running and iPhone is connected")
        }
        
        print("⌚ WC: Bundle Info:")
        print("⌚ WC: - Watch Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        print("⌚ WC: === END DIAGNOSIS ===")
    }

    // MARK: - Helpers

    private func handleStatusMessage(_ msg: [String: Any]) {
        guard let isRecording = msg["status"] as? Bool,
              let duration = msg["duration"] as? TimeInterval else { return }
        print("⌚ WC: status isRecording=\(isRecording) duration=\(duration)")
        WatchRecorderViewModel.shared.updateStatus(isRecording: isRecording, duration: duration)
    }

    private func activationStateString(_ s: WCSessionActivationState) -> String {
        switch s { case .notActivated: return "notActivated"; case .inactive: return "inactive"; case .activated: return "activated"; @unknown default: return "unknown" }
    }

    private func logStatus() {
        print("⌚ WC: isReachable=\(self.isReachable) isPaired=\(self.isPaired) isCompanion=\(self.isCompanionAppInstalled) state=\(activationStateString(session.activationState))")
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isActivated = (activationState == .activated)
            self.isReachable = session.isReachable
            // WCSession.isPaired is unavailable on watchOS; assume paired when activated
            self.isPaired = (activationState == .activated)
            self.isCompanionAppInstalled = session.isCompanionAppInstalled
            if let error { print("⌚ WC: Activation error: \(error.localizedDescription)") }
            self.logStatus()
            if self.isActivated { self.sendCommand("requestStatus") }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.logStatus()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if message["type"] as? String == "status" { self.handleStatusMessage(message) }
            else if message["type"] as? String == "pong", let ping = self.lastPingTime { self.handlePongMessage(message, pingTime: ping) }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        DispatchQueue.main.async {
            if userInfo["type"] as? String == "status" { self.handleStatusMessage(userInfo) }
            else if userInfo["type"] as? String == "pong", let ping = self.lastPingTime { self.handlePongMessage(userInfo, pingTime: ping) }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            if applicationContext["type"] as? String == "status" { self.handleStatusMessage(applicationContext) }
            else if applicationContext["type"] as? String == "pong", let ping = self.lastPingTime { self.handlePongMessage(applicationContext, pingTime: ping) }
        }
    }
}
#endif
