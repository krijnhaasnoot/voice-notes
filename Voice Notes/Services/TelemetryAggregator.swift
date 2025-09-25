import Foundation

// MARK: - Telemetry Analytics Models

struct TelemetryAnalytics {
    let analysisRange: AnalysisRange
    
    // Sessions & Users
    let totalSessions: Int
    let averageSessionDuration: TimeInterval
    let activeDays: Int
    let appOpensPerDay: Double
    let uniqueUsers: Int // Always 1 for single device, but keeping for future
    
    // Recording Usage
    let totalRecordings: Int
    let totalRecordingTime: TimeInterval
    let averageRecordingLength: TimeInterval
    let recordingBuckets: [RecordingBucket: Int]
    
    // Settings Distribution
    let providerDistribution: [String: Int]
    let modeDistribution: [String: Int]
    let lengthDistribution: [String: Int]
    let settingsToggles: SettingsToggles
    
    // Action Metrics
    let retryTaps: RetryMetrics
    let summaryEdits: Int
    let summaryEditRate: Double // % of recordings that were edited
    
    // Lists Usage
    let listsUsers: Int // Users who visited Lists (0 or 1)
    let listsCreated: Int
    let listItemsCreated: Int
    let listItemsChecked: Int
    let recordingToListsConversion: Double // % conversion
    
    // Time in App
    let totalTimeInApp: TimeInterval
    let averageTimePerSession: TimeInterval
    let sessionsPerDay: Double
}

struct AnalysisRange: Equatable, Hashable {
    let days: Int
    let startDate: Date
    let endDate: Date
    
    init(days: Int) {
        self.days = days
        self.endDate = Date()
        self.startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? Date.distantPast
    }
    
    var displayName: String {
        switch days {
        case 1: return "Today"
        case 7: return "7 Days"
        case 30: return "30 Days"
        default: return "\(days) Days"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(days)
    }
    
    static func == (lhs: AnalysisRange, rhs: AnalysisRange) -> Bool {
        return lhs.days == rhs.days
    }
}

struct RetryMetrics {
    let transcriptionRetries: Int
    let summaryRetries: Int
    let total: Int
    let ratePerHundredRecordings: Double
    
    init(transcriptionRetries: Int, summaryRetries: Int, totalRecordings: Int) {
        self.transcriptionRetries = transcriptionRetries
        self.summaryRetries = summaryRetries
        self.total = transcriptionRetries + summaryRetries
        self.ratePerHundredRecordings = totalRecordings > 0 ? (Double(total) / Double(totalRecordings)) * 100 : 0
    }
}

struct SettingsToggles {
    let autoDetectEnabled: Double // % of time enabled
    let autoSaveEnabled: Double
    let compactViewEnabled: Double
}

// MARK: - Telemetry Aggregator

@MainActor
class TelemetryAggregator {
    private let telemetryService = EnhancedTelemetryService.shared
    
    func generateAnalytics(for range: AnalysisRange) -> TelemetryAnalytics {
        let events = telemetryService.getEvents(in: range.days)
        let sessions = telemetryService.getSessions(in: range.days)
        
        return TelemetryAnalytics(
            analysisRange: range,
            totalSessions: calculateTotalSessions(sessions),
            averageSessionDuration: calculateAverageSessionDuration(sessions),
            activeDays: calculateActiveDays(events, sessions, in: range),
            appOpensPerDay: calculateAppOpensPerDay(events, range: range),
            uniqueUsers: 1, // Always 1 for single device
            totalRecordings: calculateTotalRecordings(events),
            totalRecordingTime: calculateTotalRecordingTime(events),
            averageRecordingLength: calculateAverageRecordingLength(events),
            recordingBuckets: calculateRecordingBuckets(events),
            providerDistribution: calculateProviderDistribution(events),
            modeDistribution: calculateModeDistribution(events),
            lengthDistribution: calculateLengthDistribution(events),
            settingsToggles: calculateSettingsToggles(events),
            retryTaps: calculateRetryMetrics(events),
            summaryEdits: calculateSummaryEdits(events),
            summaryEditRate: calculateSummaryEditRate(events),
            listsUsers: calculateListsUsers(events),
            listsCreated: calculateListsCreated(events),
            listItemsCreated: calculateListItemsCreated(events),
            listItemsChecked: calculateListItemsChecked(events),
            recordingToListsConversion: calculateRecordingToListsConversion(events),
            totalTimeInApp: calculateTotalTimeInApp(sessions),
            averageTimePerSession: calculateAverageTimePerSession(sessions),
            sessionsPerDay: calculateSessionsPerDay(sessions, range: range)
        )
    }
    
    // MARK: - Session Calculations
    
    private func calculateTotalSessions(_ sessions: [TelemetrySession]) -> Int {
        return sessions.count
    }
    
    private func calculateAverageSessionDuration(_ sessions: [TelemetrySession]) -> TimeInterval {
        let completedSessions = sessions.compactMap { $0.durationSeconds }
        guard !completedSessions.isEmpty else { return 0 }
        return completedSessions.reduce(0, +) / Double(completedSessions.count)
    }
    
    private func calculateActiveDays(_ events: [TelemetryEvent], _ sessions: [TelemetrySession], in range: AnalysisRange) -> Int {
        var activeDates = Set<String>()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Add dates from events
        for event in events {
            activeDates.insert(formatter.string(from: event.time))
        }
        
        // Add dates from sessions
        for session in sessions {
            activeDates.insert(formatter.string(from: session.startTime))
        }
        
        return activeDates.count
    }
    
    private func calculateAppOpensPerDay(_ events: [TelemetryEvent], range: AnalysisRange) -> Double {
        let appOpenEvents = events.filter { $0.name == TelemetryEvents.appOpen }
        return range.days > 0 ? Double(appOpenEvents.count) / Double(range.days) : 0
    }
    
    private func calculateTotalTimeInApp(_ sessions: [TelemetrySession]) -> TimeInterval {
        return sessions.compactMap { $0.durationSeconds }.reduce(0, +)
    }
    
    private func calculateAverageTimePerSession(_ sessions: [TelemetrySession]) -> TimeInterval {
        return calculateAverageSessionDuration(sessions)
    }
    
    private func calculateSessionsPerDay(_ sessions: [TelemetrySession], range: AnalysisRange) -> Double {
        return range.days > 0 ? Double(sessions.count) / Double(range.days) : 0
    }
    
    // MARK: - Recording Calculations
    
    private func calculateTotalRecordings(_ events: [TelemetryEvent]) -> Int {
        return events.filter { $0.name == TelemetryEvents.recordingStop }.count
    }
    
    private func calculateTotalRecordingTime(_ events: [TelemetryEvent]) -> TimeInterval {
        let recordingStopEvents = events.filter { $0.name == TelemetryEvents.recordingStop }
        return recordingStopEvents.compactMap { event in
            event.props["duration_sec"]?.value as? Int
        }.map { TimeInterval($0) }.reduce(0, +)
    }
    
    private func calculateAverageRecordingLength(_ events: [TelemetryEvent]) -> TimeInterval {
        let recordingStopEvents = events.filter { $0.name == TelemetryEvents.recordingStop }
        let durations = recordingStopEvents.compactMap { event in
            event.props["duration_sec"]?.value as? Int
        }.map { TimeInterval($0) }
        
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }
    
    private func calculateRecordingBuckets(_ events: [TelemetryEvent]) -> [RecordingBucket: Int] {
        let recordingStopEvents = events.filter { $0.name == TelemetryEvents.recordingStop }
        var buckets: [RecordingBucket: Int] = [:]
        
        // Initialize all buckets to 0
        for bucket in RecordingBucket.allCases {
            buckets[bucket] = 0
        }
        
        for event in recordingStopEvents {
            if let bucketString = event.props["bucket"]?.value as? String,
               let bucket = RecordingBucket(rawValue: bucketString) {
                buckets[bucket, default: 0] += 1
            } else if let durationSec = event.props["duration_sec"]?.value as? Int {
                // Fallback: calculate bucket from duration
                let bucket = RecordingBucket.bucket(for: TimeInterval(durationSec))
                buckets[bucket, default: 0] += 1
            }
        }
        
        return buckets
    }
    
    // MARK: - Settings Calculations
    
    private func calculateProviderDistribution(_ events: [TelemetryEvent]) -> [String: Int] {
        let recordingEvents = events.filter { $0.name == TelemetryEvents.recordingStop }
        var distribution: [String: Int] = [:]
        
        for event in recordingEvents {
            if let provider = event.props["provider"]?.value as? String {
                distribution[provider, default: 0] += 1
            }
        }
        
        return distribution
    }
    
    private func calculateModeDistribution(_ events: [TelemetryEvent]) -> [String: Int] {
        let recordingEvents = events.filter { $0.name == TelemetryEvents.recordingStop }
        var distribution: [String: Int] = [:]
        
        for event in recordingEvents {
            if let mode = event.props["mode"]?.value as? String {
                distribution[mode, default: 0] += 1
            }
        }
        
        return distribution
    }
    
    private func calculateLengthDistribution(_ events: [TelemetryEvent]) -> [String: Int] {
        let recordingEvents = events.filter { $0.name == TelemetryEvents.recordingStop }
        var distribution: [String: Int] = [:]
        
        for event in recordingEvents {
            if let length = event.props["length"]?.value as? String {
                distribution[length, default: 0] += 1
            }
        }
        
        return distribution
    }
    
    private func calculateSettingsToggles(_ events: [TelemetryEvent]) -> SettingsToggles {
        // This is simplified - in a real implementation, you'd track settings changes over time
        // For now, we'll estimate based on current settings
        let defaults = UserDefaults.standard
        
        return SettingsToggles(
            autoDetectEnabled: defaults.bool(forKey: "autoDetectMode") ? 100.0 : 0.0,
            autoSaveEnabled: defaults.bool(forKey: "autoSaveToDocuments") ? 100.0 : 0.0,
            compactViewEnabled: defaults.bool(forKey: "useCompactView") ? 100.0 : 0.0
        )
    }
    
    // MARK: - Action Calculations
    
    private func calculateRetryMetrics(_ events: [TelemetryEvent]) -> RetryMetrics {
        let retryEvents = events.filter { $0.name == TelemetryEvents.retryTap }
        let totalRecordings = calculateTotalRecordings(events)
        
        let transcriptionRetries = retryEvents.filter { 
            $0.props["kind"]?.value as? String == "transcribe" 
        }.count
        
        let summaryRetries = retryEvents.filter { 
            $0.props["kind"]?.value as? String == "summarize" 
        }.count
        
        return RetryMetrics(
            transcriptionRetries: transcriptionRetries,
            summaryRetries: summaryRetries,
            totalRecordings: totalRecordings
        )
    }
    
    private func calculateSummaryEdits(_ events: [TelemetryEvent]) -> Int {
        return events.filter { $0.name == TelemetryEvents.summaryEditTap }.count
    }
    
    private func calculateSummaryEditRate(_ events: [TelemetryEvent]) -> Double {
        let totalRecordings = calculateTotalRecordings(events)
        let summaryEdits = calculateSummaryEdits(events)
        
        return totalRecordings > 0 ? (Double(summaryEdits) / Double(totalRecordings)) * 100 : 0
    }
    
    // MARK: - Lists Calculations
    
    private func calculateListsUsers(_ events: [TelemetryEvent]) -> Int {
        let hasListsEvents = events.contains { event in
            [TelemetryEvents.listsOpen, TelemetryEvents.listCreated, 
             TelemetryEvents.listItemCreated, TelemetryEvents.listItemChecked].contains(event.name)
        }
        return hasListsEvents ? 1 : 0
    }
    
    private func calculateListsCreated(_ events: [TelemetryEvent]) -> Int {
        return events.filter { $0.name == TelemetryEvents.listCreated }.count
    }
    
    private func calculateListItemsCreated(_ events: [TelemetryEvent]) -> Int {
        return events.filter { $0.name == TelemetryEvents.listItemCreated }.count
    }
    
    private func calculateListItemsChecked(_ events: [TelemetryEvent]) -> Int {
        return events.filter { $0.name == TelemetryEvents.listItemChecked }.count
    }
    
    private func calculateRecordingToListsConversion(_ events: [TelemetryEvent]) -> Double {
        // Group events by session
        let eventsBySession = Dictionary(grouping: events) { $0.sessionId }
        
        var conversions = 0
        var recordingSessions = 0
        
        for (_, sessionEvents) in eventsBySession {
            let hasRecording = sessionEvents.contains { $0.name == TelemetryEvents.recordingStop }
            let hasListsActivity = sessionEvents.contains { event in
                [TelemetryEvents.listsOpen, TelemetryEvents.listCreated].contains(event.name)
            }
            
            if hasRecording {
                recordingSessions += 1
                if hasListsActivity {
                    conversions += 1
                }
            }
        }
        
        return recordingSessions > 0 ? (Double(conversions) / Double(recordingSessions)) * 100 : 0
    }
}

// MARK: - Extensions for Formatting

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var formattedSessionTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension Double {
    var formattedPercentage: String {
        return String(format: "%.1f%%", self)
    }
    
    var formattedOneDecimal: String {
        return String(format: "%.1f", self)
    }
}