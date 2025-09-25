import Foundation
import UIKit

// MARK: - Session Manager

class SessionManager {
    static let shared = SessionManager()
    
    private var sessionId: String {
        get { UserDefaults.standard.string(forKey: "sessionId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "sessionId") }
    }
    
    private var lastSessionTime: Double {
        get { UserDefaults.standard.double(forKey: "lastSessionTime") }
        set { UserDefaults.standard.set(newValue, forKey: "lastSessionTime") }
    }
    
    private init() {}
    
    func getCurrentSessionId() -> String {
        let now = Date().timeIntervalSince1970
        let sessionTimeout: TimeInterval = 4 * 3600 // 4 hours
        
        // Create new session if:
        // 1. No existing session
        // 2. More than 4 hours since last activity
        if sessionId.isEmpty || (now - lastSessionTime) > sessionTimeout {
            sessionId = UUID().uuidString
            print("📊 Analytics: New session created: \(sessionId)")
        }
        
        lastSessionTime = now
        return sessionId
    }
}

// MARK: - Analytics Client

enum Analytics {
    private static var queue = [[String: Any]]()
    private static var isSending = false
    private static let serial = DispatchQueue(label: "analytics.queue")
    private static var timer: Timer?
    private static var sessionIdProvider: (() -> String)?
    private static var retryCount = 0
    private static let maxRetries = 3
    
    private static var endpoint: URL? = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "ANALYTICS_ENDPOINT") as? String,
              !urlString.isEmpty,
              urlString != "REPLACE_ME_FOR_TESTFLIGHT" else {
            return nil
        }
        return URL(string: urlString)
    }()
    
    private static var token: String? = {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "ANALYTICS_TOKEN") as? String,
              !token.isEmpty,
              token != "REPLACE_ME_FOR_TESTFLIGHT" else {
            return nil
        }
        return token
    }()
    
    // Privacy toggle - can be set by user preferences
    private static var isEnabled: Bool {
        // Default to true, but can be disabled via user settings
        return UserDefaults.standard.object(forKey: "shareAnonymousUsage") as? Bool ?? true
    }
    
    static func start(sessionIdProvider: @escaping () -> String) {
        guard endpoint != nil, token != nil else {
            print("📊 Analytics: Configuration missing, analytics disabled")
            return
        }
        
        self.sessionIdProvider = sessionIdProvider
        serial.async {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in 
                flush() 
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
        
        print("📊 Analytics: Started with endpoint configured")
    }
    
    static func track(_ name: String, userId: String? = nil, provider: String? = nil, props: [String: Any] = [:]) {
        guard isEnabled else { return }
        guard endpoint != nil, token != nil else { return }
        
        serial.async {
            var event: [String: Any] = baseEnvelope(name: name, userId: userId, provider: provider)
            event["properties"] = props
            queue.append(event)
            
            print("📊 Analytics: Tracked '\(name)' (queue: \(queue.count))")
            
            // Auto-flush when queue is full
            if queue.count >= 20 { 
                flush() 
            }
            
            // Cap queue size to prevent memory issues
            if queue.count > 200 { 
                queue.removeFirst(queue.count - 200) 
            }
        }
    }
    
    static func flush() {
        guard isEnabled else { return }
        guard let endpoint = endpoint, let token = token else { return }
        
        serial.async {
            guard !isSending, !queue.isEmpty else { return }
            
            isSending = true
            let toSend = Array(queue) // Copy current queue
            
            do {
                let body = try JSONSerialization.data(withJSONObject: toSend, options: [])
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(token, forHTTPHeaderField: "x-analytics-token")
                request.httpBody = body
                request.timeoutInterval = 30
                
                print("📊 Analytics: Flushing \(toSend.count) events")
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    serial.async {
                        defer { isSending = false }
                        
                        if let error = error {
                            print("📊 Analytics: Network error - \(error.localizedDescription)")
                            handleRetry()
                            return
                        }
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            print("📊 Analytics: Invalid response")
                            handleRetry()
                            return
                        }
                        
                        if (200...299).contains(httpResponse.statusCode) {
                            // Success - remove the events we just sent
                            let sentCount = min(queue.count, toSend.count)
                            queue.removeFirst(sentCount)
                            retryCount = 0 // Reset retry counter on success
                            print("📊 Analytics: Successfully sent \(sentCount) events")
                        } else {
                            print("📊 Analytics: Server error - \(httpResponse.statusCode)")
                            handleRetry()
                        }
                    }
                }.resume()
                
            } catch {
                isSending = false
                print("📊 Analytics: JSON serialization error - \(error)")
            }
        }
    }
    
    private static func handleRetry() {
        retryCount += 1
        
        if retryCount <= maxRetries {
            let delay = min(pow(2.0, Double(retryCount)), 10.0) // Exponential backoff: 2s, 4s, 8s, max 10s
            print("📊 Analytics: Retry \(retryCount)/\(maxRetries) in \(delay)s")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                flush()
            }
        } else {
            print("📊 Analytics: Max retries exceeded, dropping \(queue.count) events")
            queue.removeAll() // Drop events after max retries to prevent infinite accumulation
            retryCount = 0
        }
    }
    
    private static func baseEnvelope(name: String, userId: String?, provider: String?) -> [String: Any] {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        let sessionId = sessionIdProvider?() ?? UUID().uuidString
        
        var envelope: [String: Any] = [
            "event_name": name,
            "session_id": sessionId,
            "platform": "ios",
            "app_version": version,
            "build": build
        ]
        
        // Only include non-nil values
        if let userId = userId {
            envelope["user_id"] = userId
        }
        if let provider = provider {
            envelope["provider"] = provider
        }
        
        return envelope
    }
    
    // MARK: - Configuration
    
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "shareAnonymousUsage")
        if !enabled {
            serial.async {
                queue.removeAll()
                print("📊 Analytics: Disabled and cleared queue")
            }
        }
    }
    
    static var analyticsEnabled: Bool {
        return isEnabled
    }
    
    // MARK: - Cleanup
    
    static func stop() {
        serial.async {
            timer?.invalidate()
            timer = nil
            if !queue.isEmpty {
                flush() // Final flush before stopping
            }
        }
    }
}