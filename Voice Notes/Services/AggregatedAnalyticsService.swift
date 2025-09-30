import Foundation

// MARK: - Aggregated Analytics Models

struct AggregatedMetrics: Codable {
    let totalUsers: Int
    let activeUsers: Int           // Active in last 30 days
    let totalRecordings: Int
    let totalDurationHours: Double
    let averageSessionLength: Double
    let totalSessions: Int
    let retentionRate: Double      // Users active in last 7 days vs last 30 days
    let timestamp: Date
    
    // Usage patterns
    let topSummaryModes: [String: Int]
    let recordingLengthDistribution: [String: Int]
    let peakUsageHours: [Int: Int] // Hour of day -> usage count
    let platformDistribution: [String: Int]
    
    // Feature adoption
    let summaryFeedbackRate: Double
    let documentListUsage: Int
    let tagUsage: Int
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
    
    private let mockDataEnabled = true // Enable for development/demo
    
    private init() {}
    
    // MARK: - Public API
    
    func fetchAggregatedMetrics() async {
        isLoading = true
        defer { isLoading = false }
        
        if mockDataEnabled {
            await loadMockData()
        } else {
            await fetchFromBackend()
        }
        
        lastUpdated = Date()
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
    
    // MARK: - Backend Integration (Future Implementation)
    
    private func fetchFromBackend() async {
        // TODO: Replace with actual API calls when backend is ready
        // Example implementation:
        
        /*
        guard let url = URL(string: "https://api.voicenotes.app/admin/aggregated-metrics") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let metrics = try JSONDecoder().decode(AggregatedMetrics.self, from: data)
            
            await MainActor.run {
                self.aggregatedMetrics = metrics
            }
        } catch {
            print("❌ Failed to fetch aggregated metrics: \(error)")
        }
        */
        
        // For now, use mock data
        await loadMockData()
    }
    
    private func fetchUserSegmentsFromBackend() async {
        // TODO: Replace with actual API calls when backend is ready
        await loadMockUserSegments()
    }
    
    // MARK: - Helper Methods
    
    func getActiveUserGrowthRate() -> Double {
        guard let metrics = aggregatedMetrics else { return 0.0 }
        // Mock calculation - in real implementation, compare with previous period
        return 0.23 // 23% growth
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