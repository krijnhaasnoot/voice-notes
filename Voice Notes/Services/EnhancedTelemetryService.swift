import Foundation
import UIKit
import Security

// MARK: - Telemetry Event Constants

struct TelemetryEvents {
    // App lifecycle
    static let appOpen = "app_open"
    static let appBackground = "app_background"
    
    // Recording flow
    static let recordingStart = "recording_start"
    static let recordingStop = "recording_stop"
    static let retryTap = "retry_tap"
    static let summaryEditTap = "summary_edit_tap"
    
    // Lists usage
    static let listsOpen = "lists_open"
    static let listCreated = "list_created"
    static let listItemCreated = "list_item_created"
    static let listItemChecked = "list_item_checked"
    
    // Navigation
    static let screenView = "screen_view"
    
    // Settings
    static let settingsChanged = "settings_changed"
}

// MARK: - Telemetry Event Model

struct TelemetryEvent: Codable {
    let name: String
    let time: Date
    let props: [String: AnyCodable]
    let sessionId: String
    let anonymousDeviceId: String
}

// MARK: - Session Model

struct TelemetrySession: Codable {
    let sessionId: String
    let startTime: Date
    var endTime: Date?
    var durationSeconds: TimeInterval?
    let anonymousDeviceId: String
    
    mutating func end() {
        endTime = Date()
        if let end = endTime {
            durationSeconds = end.timeIntervalSince(startTime)
        }
    }
}

// MARK: - Recording Buckets

enum RecordingBucket: String, CaseIterable, Codable {
    case short = "0-1min"       // 0-60s
    case medium = "1-5min"      // 61-300s
    case long = "5-15min"       // 301-900s
    case veryLong = "15-60min"  // 901-3600s
    case extraLong = "60min+"   // 3600s+
    
    static func bucket(for duration: TimeInterval) -> RecordingBucket {
        switch duration {
        case 0...60: return .short
        case 61...300: return .medium
        case 301...900: return .long
        case 901...3600: return .veryLong
        default: return .extraLong
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any
    
    init<T: Codable>(_ value: T) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        default:
            try container.encode("")
        }
    }
}

// MARK: - Enhanced Telemetry Service

@MainActor
class EnhancedTelemetryService: ObservableObject {
    static let shared = EnhancedTelemetryService()
    
    @Published private(set) var currentSession: TelemetrySession?
    
    private let maxEvents = 5000
    private var events: [TelemetryEvent] = []
    private var sessions: [TelemetrySession] = []
    private let storage = TelemetryStorage()
    
    // Device ID for privacy-preserving analytics
    private var _anonymousDeviceId: String?
    private var anonymousDeviceId: String {
        if let id = _anonymousDeviceId {
            return id
        }
        let id = UserDefaults.standard.string(forKey: "anonymous_device_id") ?? UUID().uuidString
        if UserDefaults.standard.string(forKey: "anonymous_device_id") == nil {
            UserDefaults.standard.set(id, forKey: "anonymous_device_id")
        }
        _anonymousDeviceId = id
        return id
    }
    
    // Session tracking
    private var sessionStartTime: Date?
    private var lastActiveTime: Date = Date()
    
    private init() {
        loadStoredData()
        setupAppLifecycleObservers()
    }
    
    // MARK: - Session Management
    
    func startSession(reason: String = "cold") {
        let sessionId = UUID().uuidString
        sessionStartTime = Date()
        lastActiveTime = Date()
        
        let session = TelemetrySession(
            sessionId: sessionId,
            startTime: sessionStartTime!,
            endTime: nil,
            durationSeconds: nil,
            anonymousDeviceId: anonymousDeviceId
        )
        
        currentSession = session
        
        // Log app open event
        logEvent(TelemetryEvents.appOpen, properties: [
            "reason": reason,
            "session_id": sessionId
        ])
    }
    
    func endSession() {
        guard var session = currentSession else { return }
        
        session.end()
        sessions.append(session)
        
        // Log app background event
        if let duration = session.durationSeconds {
            logEvent(TelemetryEvents.appBackground, properties: [
                "duration_sec": Int(duration),
                "session_id": session.sessionId
            ])
        }
        
        currentSession = nil
        persistData()
    }
    
    // MARK: - Event Logging
    
    func logEvent(_ name: String, properties: [String: Any] = [:]) {
        let sessionId = currentSession?.sessionId ?? "no-session"
        
        var codableProps: [String: AnyCodable] = [:]
        for (key, value) in properties {
            switch value {
            case let stringValue as String:
                codableProps[key] = AnyCodable(stringValue)
            case let intValue as Int:
                codableProps[key] = AnyCodable(intValue)
            case let doubleValue as Double:
                codableProps[key] = AnyCodable(doubleValue)
            case let boolValue as Bool:
                codableProps[key] = AnyCodable(boolValue)
            default:
                codableProps[key] = AnyCodable(String(describing: value))
            }
        }
        
        let event = TelemetryEvent(
            name: name,
            time: Date(),
            props: codableProps,
            sessionId: sessionId,
            anonymousDeviceId: anonymousDeviceId
        )
        
        events.append(event)
        lastActiveTime = Date()
        
        // Keep only recent events
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        
        // Persist periodically
        if events.count % 10 == 0 {
            persistData()
        }
        
        print("📊 Event: \(name) [\(sessionId[..<sessionId.index(sessionId.startIndex, offsetBy: 8)])] \(properties)")
    }
    
    // MARK: - Recording Events
    
    func logRecordingStart() {
        logEvent(TelemetryEvents.recordingStart)
    }
    
    func logRecordingStop(duration: TimeInterval, hasTranscript: Bool, hasSummary: Bool, provider: String?, mode: String?, length: String?) {
        let wordsEstimate = Int(duration * 150) // ~150 words per minute average
        
        logEvent(TelemetryEvents.recordingStop, properties: [
            "duration_sec": Int(duration),
            "words_est": wordsEstimate,
            "had_transcript": hasTranscript,
            "had_summary": hasSummary,
            "provider": provider ?? "none",
            "mode": mode ?? "none",
            "length": length ?? "none",
            "bucket": RecordingBucket.bucket(for: duration).rawValue
        ])
    }
    
    func logRetryTap(kind: String) {
        logEvent(TelemetryEvents.retryTap, properties: [
            "kind": kind
        ])
    }
    
    func logSummaryEditTap(source: String) {
        logEvent(TelemetryEvents.summaryEditTap, properties: [
            "source": source
        ])
    }
    
    // MARK: - Lists Events
    
    func logListsOpen(from source: String) {
        logEvent(TelemetryEvents.listsOpen, properties: [
            "from": source
        ])
    }
    
    func logListCreated(type: String) {
        logEvent(TelemetryEvents.listCreated, properties: [
            "type": type
        ])
    }
    
    func logListItemCreated(listType: String) {
        logEvent(TelemetryEvents.listItemCreated, properties: [
            "listType": listType
        ])
    }
    
    func logListItemChecked(listType: String) {
        logEvent(TelemetryEvents.listItemChecked, properties: [
            "listType": listType
        ])
    }
    
    // MARK: - Settings Events
    
    func logSettingsChanged(key: String, value: Any) {
        logEvent(TelemetryEvents.settingsChanged, properties: [
            "key": key,
            "value": String(describing: value)
        ])
    }
    
    // MARK: - Screen Tracking
    
    func logScreenView(screen: String) {
        // Prevent duplicate screen views within 2 seconds
        let recentScreenViews = events.filter { event in
            event.name == TelemetryEvents.screenView &&
            Date().timeIntervalSince(event.time) < 2.0 &&
            event.props["screen"]?.value as? String == screen
        }
        
        guard recentScreenViews.isEmpty else { return }
        
        logEvent(TelemetryEvents.screenView, properties: [
            "screen": screen
        ])
    }
    
    // MARK: - Data Access
    
    func getEvents(in days: Int = 30) -> [TelemetryEvent] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        return events.filter { $0.time >= cutoffDate }
    }
    
    func getSessions(in days: Int = 30) -> [TelemetrySession] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        return sessions.filter { $0.startTime >= cutoffDate }
    }
    
    var firstSeenDate: Date? {
        return events.first?.time ?? sessions.first?.startTime
    }
    
    var lastSeenDate: Date? {
        return max(events.last?.time ?? Date.distantPast, sessions.last?.startTime ?? Date.distantPast)
    }
    
    // MARK: - Data Management
    
    private func persistData() {
        Task.detached {
            await self.storage.save(events: self.events, sessions: self.sessions)
        }
    }
    
    private func loadStoredData() {
        Task {
            let (loadedEvents, loadedSessions) = await storage.load()
            self.events = loadedEvents
            self.sessions = loadedSessions
        }
    }
    
    func exportData() -> Data? {
        let export = TelemetryExport(
            anonymousDeviceId: anonymousDeviceId,
            events: events,
            sessions: sessions,
            exportDate: Date(),
            firstSeenDate: firstSeenDate,
            lastSeenDate: lastSeenDate,
            settingsSnapshot: getCurrentSettingsSnapshot()
        )
        
        return try? JSONEncoder().encode(export)
    }
    
    func clearAllData() {
        events.removeAll()
        sessions.removeAll()
        currentSession = nil
        persistData()
        print("📊 All telemetry data cleared")
    }
    
    private func getCurrentSettingsSnapshot() -> [String: String] {
        let defaults = UserDefaults.standard
        return [
            "defaultMode": defaults.string(forKey: "defaultMode") ?? "personal",
            "defaultSummaryLength": defaults.string(forKey: "defaultSummaryLength") ?? "standard",
            "autoDetectMode": String(defaults.bool(forKey: "autoDetectMode")),
            "defaultDocumentType": defaults.string(forKey: "defaultDocumentType") ?? "todo",
            "autoSaveToDocuments": String(defaults.bool(forKey: "autoSaveToDocuments")),
            "useCompactView": String(defaults.bool(forKey: "useCompactView"))
        ]
    }
    
    // MARK: - App Lifecycle
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startSession(reason: "warm")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endSession()
        }
    }
    
    // MARK: - Development/Testing
    
    #if DEBUG
    func addTestData() {
        let testEvents = generateTestEvents()
        let testSessions = generateTestSessions()
        
        events.append(contentsOf: testEvents)
        sessions.append(contentsOf: testSessions)
        
        persistData()
        print("📊 Added \(testEvents.count) test events and \(testSessions.count) test sessions")
    }
    
    private func generateTestEvents() -> [TelemetryEvent] {
        var testEvents: [TelemetryEvent] = []
        let now = Date()
        
        for i in 0..<100 {
            let daysAgo = Int.random(in: 0...29)
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            
            // Mix of different event types
            let eventTypes = [
                (TelemetryEvents.appOpen, ["reason": "cold"]),
                (TelemetryEvents.recordingStart, [:]),
                (TelemetryEvents.recordingStop, [
                    "duration_sec": Int.random(in: 10...600),
                    "words_est": Int.random(in: 50...1500),
                    "had_summary": Bool.random(),
                    "provider": ["openai", "anthropic", "gemini", "app_default"].randomElement() ?? "openai"
                ]),
                (TelemetryEvents.listsOpen, ["from": ["tab", "deeplink", "after_summary"].randomElement() ?? "tab"]),
                (TelemetryEvents.screenView, ["screen": ["Recordings", "Lists", "Settings"].randomElement() ?? "Recordings"])
            ]
            
            let (eventName, props) = eventTypes.randomElement() ?? (TelemetryEvents.appOpen, [:])
            
            var codableProps: [String: AnyCodable] = [:]
            for (key, value) in props {
                switch value {
                case let stringValue as String:
                    codableProps[key] = AnyCodable(stringValue)
                case let intValue as Int:
                    codableProps[key] = AnyCodable(intValue)
                case let doubleValue as Double:
                    codableProps[key] = AnyCodable(doubleValue)
                case let boolValue as Bool:
                    codableProps[key] = AnyCodable(boolValue)
                default:
                    codableProps[key] = AnyCodable(String(describing: value))
                }
            }
            
            let event = TelemetryEvent(
                name: eventName,
                time: date,
                props: codableProps,
                sessionId: UUID().uuidString,
                anonymousDeviceId: anonymousDeviceId
            )
            
            testEvents.append(event)
        }
        
        return testEvents.sorted { $0.time < $1.time }
    }
    
    private func generateTestSessions() -> [TelemetrySession] {
        var testSessions: [TelemetrySession] = []
        let now = Date()
        
        for i in 0..<30 {
            let daysAgo = Int.random(in: 0...29)
            let startTime = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            let duration = TimeInterval.random(in: 60...1800) // 1-30 minutes
            let endTime = startTime.addingTimeInterval(duration)
            
            var session = TelemetrySession(
                sessionId: UUID().uuidString,
                startTime: startTime,
                endTime: endTime,
                durationSeconds: duration,
                anonymousDeviceId: anonymousDeviceId
            )
            
            testSessions.append(session)
        }
        
        return testSessions.sorted { $0.startTime < $1.startTime }
    }
    #endif
}

// MARK: - Storage Helper

private actor TelemetryStorage {
    private let eventsURL: URL
    private let sessionsURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        eventsURL = documentsPath.appendingPathComponent("telemetry_events.json")
        sessionsURL = documentsPath.appendingPathComponent("telemetry_sessions.json")
    }
    
    func save(events: [TelemetryEvent], sessions: [TelemetrySession]) {
        // Save events
        if let eventsData = try? JSONEncoder().encode(events) {
            try? eventsData.write(to: eventsURL)
        }
        
        // Save sessions
        if let sessionsData = try? JSONEncoder().encode(sessions) {
            try? sessionsData.write(to: sessionsURL)
        }
    }
    
    func load() -> ([TelemetryEvent], [TelemetrySession]) {
        // Load events
        let events: [TelemetryEvent]
        if let eventsData = try? Data(contentsOf: eventsURL),
           let decodedEvents = try? JSONDecoder().decode([TelemetryEvent].self, from: eventsData) {
            events = decodedEvents
        } else {
            events = []
        }
        
        // Load sessions
        let sessions: [TelemetrySession]
        if let sessionsData = try? Data(contentsOf: sessionsURL),
           let decodedSessions = try? JSONDecoder().decode([TelemetrySession].self, from: sessionsData) {
            sessions = decodedSessions
        } else {
            sessions = []
        }
        
        return (events, sessions)
    }
    
}

// MARK: - Export Model

struct TelemetryExport: Codable {
    let anonymousDeviceId: String
    let events: [TelemetryEvent]
    let sessions: [TelemetrySession]
    let exportDate: Date
    let firstSeenDate: Date?
    let lastSeenDate: Date?
    let settingsSnapshot: [String: String]
}