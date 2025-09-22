import Foundation

// MARK: - Enhanced Telemetry Service

class TelemetryService: TelemetryTracker {
    static let shared = TelemetryService()
    
    private let maxTelemetryEntries = 1000
    private var telemetryEntries: [SummaryTelemetry] = []
    private let telemetryQueue = DispatchQueue(label: "telemetry.queue", qos: .utility)
    
    private init() {
        loadStoredTelemetry()
    }
    
    // MARK: - Telemetry Tracking
    
    func track(_ telemetry: SummaryTelemetry) {
        telemetryQueue.async {
            self.telemetryEntries.append(telemetry)
            
            // Keep only the most recent entries
            if self.telemetryEntries.count > self.maxTelemetryEntries {
                self.telemetryEntries.removeFirst(self.telemetryEntries.count - self.maxTelemetryEntries)
            }
            
            self.persistTelemetry()
            
            // Console logging for development
            print("📊 Summary Telemetry: provider=\(telemetry.providerId), success=\(telemetry.success), fallback=\(telemetry.fallbackUsed), time=\(telemetry.processingTimeMs)ms")
        }
    }
    
    // MARK: - Analytics and Insights
    
    func getUsageStats(for provider: AIProviderType? = nil, days: Int = 30) -> UsageStats {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        
        let filteredEntries = telemetryEntries.filter { entry in
            entry.timestamp >= cutoffDate &&
            (provider == nil || entry.providerId == provider?.rawValue)
        }
        
        let totalRequests = filteredEntries.count
        let successfulRequests = filteredEntries.filter(\.success).count
        let fallbacksUsed = filteredEntries.filter(\.fallbackUsed).count
        
        let avgProcessingTime = filteredEntries.isEmpty ? 0 : 
            filteredEntries.map(\.processingTimeMs).reduce(0, +) / filteredEntries.count
        
        let avgTranscriptLength = filteredEntries.isEmpty ? 0 :
            filteredEntries.map(\.transcriptLength).reduce(0, +) / filteredEntries.count
        
        let avgSummaryLength = filteredEntries.isEmpty ? 0 :
            filteredEntries.map(\.summaryLength).reduce(0, +) / filteredEntries.count
        
        return UsageStats(
            totalRequests: totalRequests,
            successfulRequests: successfulRequests,
            fallbacksUsed: fallbacksUsed,
            averageProcessingTimeMs: avgProcessingTime,
            averageTranscriptLength: avgTranscriptLength,
            averageSummaryLength: avgSummaryLength,
            successRate: totalRequests > 0 ? Double(successfulRequests) / Double(totalRequests) : 0.0,
            fallbackRate: totalRequests > 0 ? Double(fallbacksUsed) / Double(totalRequests) : 0.0
        )
    }
    
    func getProviderBreakdown(days: Int = 30) -> [String: UsageStats] {
        var breakdown: [String: UsageStats] = [:]
        
        for provider in AIProviderType.allCases {
            breakdown[provider.displayName] = getUsageStats(for: provider, days: days)
        }
        
        return breakdown
    }
    
    func exportTelemetryData() -> Data? {
        let sanitizedEntries = telemetryEntries.map { entry in
            SanitizedTelemetryEntry(
                providerId: entry.providerId,
                success: entry.success,
                fallbackUsed: entry.fallbackUsed,
                processingTimeMs: entry.processingTimeMs,
                transcriptLength: entry.transcriptLength,
                summaryLength: entry.summaryLength,
                timestamp: entry.timestamp
            )
        }
        
        return try? JSONEncoder().encode(sanitizedEntries)
    }
    
    // MARK: - Data Management
    
    private func persistTelemetry() {
        guard let data = try? JSONEncoder().encode(telemetryEntries) else { return }
        
        let url = getStorageURL()
        try? data.write(to: url)
    }
    
    private func loadStoredTelemetry() {
        let url = getStorageURL()
        
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SummaryTelemetry].self, from: data) else {
            return
        }
        
        telemetryEntries = entries
    }
    
    private func getStorageURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("telemetry.json")
    }
    
    func clearTelemetryData() {
        telemetryQueue.async {
            self.telemetryEntries.removeAll()
            self.persistTelemetry()
            print("📊 Telemetry data cleared")
        }
    }
}

// MARK: - Usage Statistics

struct UsageStats: Codable {
    let totalRequests: Int
    let successfulRequests: Int
    let fallbacksUsed: Int
    let averageProcessingTimeMs: Int
    let averageTranscriptLength: Int
    let averageSummaryLength: Int
    let successRate: Double
    let fallbackRate: Double
    
    var formattedSuccessRate: String {
        String(format: "%.1f%%", successRate * 100)
    }
    
    var formattedFallbackRate: String {
        String(format: "%.1f%%", fallbackRate * 100)
    }
    
    var formattedProcessingTime: String {
        if averageProcessingTimeMs < 1000 {
            return "\(averageProcessingTimeMs)ms"
        } else {
            return String(format: "%.1fs", Double(averageProcessingTimeMs) / 1000.0)
        }
    }
}

// MARK: - Sanitized Telemetry Entry (for export)

struct SanitizedTelemetryEntry: Codable {
    let providerId: String
    let success: Bool
    let fallbackUsed: Bool
    let processingTimeMs: Int
    let transcriptLength: Int
    let summaryLength: Int
    let timestamp: Date
}

// MARK: - Telemetry Extensions

extension SummaryTelemetry: Codable {
    enum CodingKeys: String, CodingKey {
        case providerId, success, fallbackUsed, processingTimeMs
        case transcriptLength, summaryLength, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerId = try container.decode(String.self, forKey: .providerId)
        success = try container.decode(Bool.self, forKey: .success)
        fallbackUsed = try container.decode(Bool.self, forKey: .fallbackUsed)
        processingTimeMs = try container.decode(Int.self, forKey: .processingTimeMs)
        transcriptLength = try container.decode(Int.self, forKey: .transcriptLength)
        summaryLength = try container.decode(Int.self, forKey: .summaryLength)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providerId, forKey: .providerId)
        try container.encode(success, forKey: .success)
        try container.encode(fallbackUsed, forKey: .fallbackUsed)
        try container.encode(processingTimeMs, forKey: .processingTimeMs)
        try container.encode(transcriptLength, forKey: .transcriptLength)
        try container.encode(summaryLength, forKey: .summaryLength)
        try container.encode(timestamp, forKey: .timestamp)
    }
}