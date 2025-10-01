import Foundation

// MARK: - Aggregated Analytics Models

struct AggregatedMetrics: Codable {
    let totalUsers: Int
    let activeUsers: Int           // Active in last 30 days
    let totalRecordings: Int
    let totalDurationHours: Double?
    let averageSessionLength: Double?
    let totalSessions: Int?
    let retentionRate: Double?      // Users active in last 7 days vs last 30 days
    let timestamp: Date

    // Usage patterns
    let topSummaryModes: [String: Int]
    let recordingLengthDistribution: [String: Int]
    let peakUsageHours: [Int: Int] // Hour of day -> usage count
    let platformDistribution: [String: Int]

    // Feature adoption
    let summaryFeedbackRate: Double
    let documentListUsage: Int?
    let tagUsage: Int?
}

struct UserSegment: Codable {
    let segment: String
    let userCount: Int
    let averageRecordings: Double
    let averageDuration: Double
    let churnRate: Double
}

// MARK: - Aggregated Analytics Service

@MainActor
class AggregatedAnalyticsService: ObservableObject {
    static let shared = AggregatedAnalyticsService()

    @Published var aggregatedMetrics: AggregatedMetrics?
    @Published var userSegments: [UserSegment] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    @Published var isUsingFallback: Bool = false

    private let mockDataEnabled = false // Disabled - use real data
    private let supabaseClient = SupabaseAnalyticsClient()

    // Store additional backend data
    var topEvents: [SupabaseAnalyticsClient.GroupCount] = []
    var dailySeries: [SupabaseAnalyticsClient.DailyPoint] = []

    private init() {}
    
    // MARK: - Public API
    
    func fetchAggregatedMetrics(force: Bool = false) async {
        // Skip if data is fresh (less than 5 minutes old) and not forced
        if !force,
           let lastUpdated = lastUpdated,
           Date().timeIntervalSince(lastUpdated) < 300 {
            return
        }

        isLoading = true
        defer { isLoading = false; lastUpdated = Date() }

        if mockDataEnabled {
            await loadMockData()
        } else {
            await fetchFromBackend()
        }
    }
    
    func getUserSegments() async {
        if mockDataEnabled {
            await loadMockUserSegments()
        } else {
            await fetchUserSegmentsFromBackend()
        }
    }
    
    // MARK: - Mock Data (For Development/Demo)
    
    private func loadMockData() async {
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(500))
        
        aggregatedMetrics = AggregatedMetrics(
            totalUsers: 2847,
            activeUsers: 1923,
            totalRecordings: 18394,
            totalDurationHours: 4892.3,
            averageSessionLength: 12.4, // minutes
            totalSessions: 11273,
            retentionRate: 0.67,
            timestamp: Date(),
            topSummaryModes: [
                "personal": 8932,
                "meeting": 3421,
                "interview": 2183,
                "lecture": 1872,
                "planning": 1458,
                "brainstorm": 1234,
                "primaryCare": 987,
                "techTeam": 654
            ],
            recordingLengthDistribution: [
                "0-1min": 7234,
                "1-5min": 6789,
                "5-15min": 3421,
                "15-60min": 834,
                "60min+": 116
            ],
            peakUsageHours: [
                9: 1234,   // 9 AM
                10: 1456,  // 10 AM
                11: 1678,  // 11 AM
                14: 1543,  // 2 PM
                15: 1789,  // 3 PM (peak)
                16: 1432,  // 4 PM
                20: 987,   // 8 PM
                21: 743    // 9 PM
            ],
            platformDistribution: [
                "iPhone": 14512,
                "iPad": 3234,
                "Watch": 648
            ],
            summaryFeedbackRate: 0.34,
            documentListUsage: 5632,
            tagUsage: 3841
        )
    }
    
    private func loadMockUserSegments() async {
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(300))
        
        userSegments = [
            UserSegment(
                segment: "Power Users",
                userCount: 234,
                averageRecordings: 47.2,
                averageDuration: 18.4,
                churnRate: 0.12
            ),
            UserSegment(
                segment: "Regular Users",
                userCount: 1289,
                averageRecordings: 12.7,
                averageDuration: 8.9,
                churnRate: 0.23
            ),
            UserSegment(
                segment: "Casual Users",
                userCount: 892,
                averageRecordings: 3.1,
                averageDuration: 4.2,
                churnRate: 0.45
            ),
            UserSegment(
                segment: "New Users",
                userCount: 432,
                averageRecordings: 1.3,
                averageDuration: 2.8,
                churnRate: 0.67
            )
        ]
    }
    
    // MARK: - Real Data Implementation

    private func fetchFromBackend() async {
        isUsingFallback = false

        do {
            // Fetch from Supabase
            let now = Date()
            guard let since30d = Calendar.current.date(byAdding: .day, value: -30, to: now) else {
                throw NSError(domain: "DateError", code: -1, userInfo: nil)
            }

            // Parallel fetch all metrics
            async let totalEvents = supabaseClient.totalEvents(since: since30d)
            async let distinctUsers = supabaseClient.distinctUsers(since: since30d)
            async let topEventsList = supabaseClient.topEvents(since: since30d, limit: 5)
            async let platformDist = supabaseClient.platformDistribution(since: since30d)
            async let dailyData = supabaseClient.dailySeries(since: 14)
            async let feedbackData = supabaseClient.feedbackSplit(since: since30d)

            // Await all results
            let (te, du, events, platforms, series, feedback) = try await (
                totalEvents,
                distinctUsers,
                topEventsList,
                platformDist,
                dailyData,
                feedbackData
            )

            // Store for UI access
            self.topEvents = events
            self.dailySeries = series

            // Map events to summary modes (if event names match pattern)
            var summaryModes: [String: Int] = [:]
            for event in events {
                // Extract summary mode from event names like "summary_generated_personal"
                if event.key.hasPrefix("summary_generated_") {
                    let mode = event.key.replacingOccurrences(of: "summary_generated_", with: "")
                    summaryModes[mode] = event.count
                }
            }

            // Build platform distribution
            let platformDict = Dictionary(uniqueKeysWithValues: platforms.map { ($0.key, $0.count) })

            // Calculate feedback rate
            let totalFeedback = feedback.thumbsUp + feedback.thumbsDown
            let feedbackRate = te > 0 ? Double(totalFeedback) / Double(te) : 0.0

            // Create aggregated metrics from backend data
            self.aggregatedMetrics = AggregatedMetrics(
                totalUsers: du,
                activeUsers: max(1, du), // Users active in last 30d
                totalRecordings: te,
                totalDurationHours: nil, // Not tracked in current schema
                averageSessionLength: nil, // Not tracked in current schema
                totalSessions: nil, // Not tracked in current schema
                retentionRate: nil, // Would require 7d vs 30d comparison
                timestamp: Date(),
                topSummaryModes: summaryModes,
                recordingLengthDistribution: [:], // Not tracked in current schema
                peakUsageHours: [:], // Could be computed from daily series if needed
                platformDistribution: platformDict,
                summaryFeedbackRate: feedbackRate,
                documentListUsage: nil, // Not tracked in current schema
                tagUsage: nil // Not tracked in current schema
            )

            print("✅ Successfully fetched global analytics from Supabase:")
            print("   Total events: \(te), Users: \(du), Platforms: \(platforms.count)")

        } catch {
            print("❌ Backend analytics failed: \(error.localizedDescription)")
            print("   Falling back to local data...")
            isUsingFallback = true
            await loadRealLocalData()
        }
    }
    
    private func loadRealLocalData() async {
        // Get real data from local services
        let recordingsManager = RecordingsManager.shared
        let telemetryService = EnhancedTelemetryService.shared
        let feedbackService = SummaryFeedbackService.shared
        
        // Simulate brief loading for UX
        try? await Task.sleep(for: .milliseconds(300))
        
        // Calculate real metrics
        let recordings = recordingsManager.recordings
        let totalRecordings = recordings.count
        let totalDurationHours = recordings.reduce(0) { $0 + $1.duration } / 3600.0
        
        // Calculate summary mode distribution
        var summaryModeCount: [String: Int] = [:]
        for recording in recordings {
            if let mode = recording.detectedMode {
                summaryModeCount[mode, default: 0] += 1
            } else {
                summaryModeCount["personal", default: 0] += 1
            }
        }
        
        // Calculate recording length distribution
        var lengthDistribution: [String: Int] = [:]
        for recording in recordings {
            let bucket = RecordingBucket.bucket(for: recording.duration)
            lengthDistribution[bucket.rawValue, default: 0] += 1
        }
        
        // Calculate peak usage hours (simplified - based on recording creation times)
        var peakHours: [Int: Int] = [:]
        for recording in recordings {
            let hour = Calendar.current.component(.hour, from: recording.date)
            peakHours[hour, default: 0] += 1
        }
        
        // Get feedback stats
        let feedbackStats = await feedbackService.getFeedbackStats()
        let feedbackRate = totalRecordings > 0 ? Double(feedbackStats.totalFeedback) / Double(totalRecordings) : 0.0
        
        // Document usage - simplified without direct DocumentStore access
        let documentCount = 0 // Would need to be passed in or accessed differently
        let totalDocumentItems = 0
        
        // Calculate session metrics (simplified)
        let averageSessionLength = totalRecordings > 0 ? (totalDurationHours * 60) / Double(totalRecordings) : 0.0
        let totalSessions = max(totalRecordings, 1) // Simplified - assume 1 session per recording minimum
        
        // Since this is local data, we only have 1 "user" (the current user)
        // But we can provide meaningful local statistics
        aggregatedMetrics = AggregatedMetrics(
            totalUsers: 1, // Local user only
            activeUsers: totalRecordings > 0 ? 1 : 0, // Active if has recordings
            totalRecordings: totalRecordings,
            totalDurationHours: totalDurationHours,
            averageSessionLength: averageSessionLength,
            totalSessions: totalSessions,
            retentionRate: totalRecordings > 0 ? 1.0 : 0.0, // 100% retention for single user
            timestamp: Date(),
            topSummaryModes: summaryModeCount,
            recordingLengthDistribution: lengthDistribution,
            peakUsageHours: peakHours,
            platformDistribution: ["iPhone": totalRecordings], // Assume iPhone for simplicity
            summaryFeedbackRate: feedbackRate,
            documentListUsage: documentCount,
            tagUsage: recordingsManager.recordings.reduce(0) { $0 + $1.tags.count }
        )

        print("ℹ️ Using local fallback analytics: \(totalRecordings) recordings")
    }
    
    private func fetchUserSegmentsFromBackend() async {
        await loadRealUserSegments()
    }
    
    private func loadRealUserSegments() async {
        // For local data, create a single user segment based on actual usage
        let recordingsManager = RecordingsManager.shared
        let recordings = recordingsManager.recordings
        let totalRecordings = recordings.count
        let totalDurationHours = recordings.reduce(0) { $0 + $1.duration } / 3600.0
        
        // Determine user segment based on usage patterns
        let segment: String
        let churnRate: Double
        
        if totalRecordings == 0 {
            segment = "New User"
            churnRate = 1.0 // No usage yet
        } else if totalRecordings >= 50 {
            segment = "Power User"
            churnRate = 0.1 // Very engaged
        } else if totalRecordings >= 10 {
            segment = "Regular User"
            churnRate = 0.2 // Active user
        } else {
            segment = "Casual User"
            churnRate = 0.4 // Light usage
        }
        
        userSegments = [
            UserSegment(
                segment: segment,
                userCount: 1, // Single local user
                averageRecordings: Double(totalRecordings),
                averageDuration: totalDurationHours,
                churnRate: churnRate
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    func getActiveUserGrowthRate() -> Double {
        // For single user, calculate based on recent activity
        guard let metrics = aggregatedMetrics else { return 0.0 }
        
        // Check if user has been active recently (recordings in last 7 days)
        let recordingsManager = RecordingsManager.shared
        let recentRecordings = recordingsManager.recordings.filter {
            Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.contains($0.date) == true
        }
        
        return recentRecordings.count > 0 ? 1.0 : 0.0 // 100% if active, 0% if not
    }
    
    func getChurnRate() -> Double {
        return userSegments.reduce(0) { $0 + $1.churnRate * Double($1.userCount) } 
               / Double(userSegments.reduce(0) { $0 + $1.userCount })
    }
    
    func getPeakUsageTime() -> String {
        guard let metrics = aggregatedMetrics else { return "Unknown" }
        
        let maxHour = metrics.peakUsageHours.max { $0.value < $1.value }?.key ?? 15
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        
        let date = Calendar.current.date(bySettingHour: maxHour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}