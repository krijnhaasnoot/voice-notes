import Foundation

// MARK: - Summary Feedback Models

enum FeedbackType: String, Codable {
    case thumbsUp = "thumbs_up"
    case thumbsDown = "thumbs_down"
}

struct SummaryFeedback: Codable {
    let id: UUID
    let recordingId: UUID
    let summaryText: String
    let feedbackType: FeedbackType
    let userFeedback: String?
    let summaryMode: String
    let summaryLengthSetting: String
    let aiProvider: String
    let timestamp: Date
    let transcriptLength: Int
    let summaryLength: Int
    
    init(
        recordingId: UUID,
        summaryText: String,
        feedbackType: FeedbackType,
        userFeedback: String? = nil,
        summaryMode: String,
        summaryLengthSetting: String,
        aiProvider: String,
        transcriptLength: Int
    ) {
        self.id = UUID()
        self.recordingId = recordingId
        self.summaryText = summaryText
        self.feedbackType = feedbackType
        self.userFeedback = userFeedback
        self.summaryMode = summaryMode
        self.summaryLengthSetting = summaryLengthSetting
        self.aiProvider = aiProvider
        self.timestamp = Date()
        self.transcriptLength = transcriptLength
        self.summaryLength = summaryText.count
    }
}

// MARK: - Summary Feedback Service

@MainActor
class SummaryFeedbackService: ObservableObject {
    static let shared = SummaryFeedbackService()
    
    @Published var feedbackHistory: [SummaryFeedback] = []
    private let userDefaults = UserDefaults.standard
    private let feedbackKey = "summary_feedback_history"
    
    private init() {
        loadFeedbackHistory()
    }
    
    // MARK: - Feedback Collection
    
    func submitFeedback(
        recordingId: UUID,
        summaryText: String,
        feedbackType: FeedbackType,
        userFeedback: String? = nil,
        recording: Recording
    ) {
        let feedback = SummaryFeedback(
            recordingId: recordingId,
            summaryText: summaryText,
            feedbackType: feedbackType,
            userFeedback: userFeedback,
            summaryMode: recording.detectedMode ?? "personal",
            summaryLengthSetting: UserDefaults.standard.string(forKey: "defaultSummaryLength") ?? "standard",
            aiProvider: recording.preferredSummaryProvider ?? "app_default",
            transcriptLength: recording.transcript?.count ?? 0
        )
        
        // Add to local history
        feedbackHistory.append(feedback)
        saveFeedbackHistory()
        
        // Send to analytics
        sendFeedbackToAnalytics(feedback)
        
        print("📝 SummaryFeedback: Collected \(feedbackType.rawValue) feedback for recording \(recordingId)")
        if let userText = userFeedback {
            print("📝 User feedback: \(userText)")
        }
    }
    
    // MARK: - Analytics Integration
    
    private func sendFeedbackToAnalytics(_ feedback: SummaryFeedback) {
        // Send to enhanced telemetry service
        EnhancedTelemetryService.shared.logSummaryFeedback(
            type: feedback.feedbackType.rawValue,
            mode: feedback.summaryMode,
            length: feedback.summaryLengthSetting,
            provider: feedback.aiProvider,
            hasUserFeedback: feedback.userFeedback != nil,
            transcriptLength: feedback.transcriptLength,
            summaryLength: feedback.summaryLength
        )
        
        // Send to general analytics
        var eventData: [String: Any] = [
            "feedback_type": feedback.feedbackType.rawValue,
            "summary_mode": feedback.summaryMode,
            "summary_length": feedback.summaryLengthSetting,
            "ai_provider": feedback.aiProvider,
            "transcript_length": feedback.transcriptLength,
            "summary_length": feedback.summaryLength,
            "has_user_feedback": feedback.userFeedback != nil
        ]
        
        if let userText = feedback.userFeedback {
            eventData["feedback_text_length"] = userText.count
            // Don't send actual feedback text to general analytics for privacy
        }
        
        Analytics.track("summary_feedback_submitted", props: eventData)
    }
    
    // MARK: - Data Persistence
    
    private func saveFeedbackHistory() {
        do {
            let data = try JSONEncoder().encode(feedbackHistory)
            userDefaults.set(data, forKey: feedbackKey)
        } catch {
            print("❌ SummaryFeedback: Failed to save feedback history: \(error)")
        }
    }
    
    private func loadFeedbackHistory() {
        guard let data = userDefaults.data(forKey: feedbackKey) else { return }
        
        do {
            feedbackHistory = try JSONDecoder().decode([SummaryFeedback].self, from: data)
            print("📝 SummaryFeedback: Loaded \(feedbackHistory.count) feedback entries")
        } catch {
            print("❌ SummaryFeedback: Failed to load feedback history: \(error)")
        }
    }
    
    // MARK: - Analytics Dashboard Data
    
    func getFeedbackStats() -> (totalFeedback: Int, thumbsUp: Int, thumbsDown: Int, feedbackWithComments: Int) {
        let total = feedbackHistory.count
        let thumbsUp = feedbackHistory.filter { $0.feedbackType == .thumbsUp }.count
        let thumbsDown = feedbackHistory.filter { $0.feedbackType == .thumbsDown }.count
        let withComments = feedbackHistory.filter { $0.userFeedback?.isEmpty == false }.count
        
        return (total, thumbsUp, thumbsDown, withComments)
    }
    
    func getRecentNegativeFeedback(limit: Int = 20) -> [SummaryFeedback] {
        return feedbackHistory
            .filter { $0.feedbackType == .thumbsDown }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    func getFeedbackByMode() -> [String: (thumbsUp: Int, thumbsDown: Int)] {
        var modeStats: [String: (Int, Int)] = [:]
        
        for feedback in feedbackHistory {
            let currentStats = modeStats[feedback.summaryMode] ?? (0, 0)
            if feedback.feedbackType == .thumbsUp {
                modeStats[feedback.summaryMode] = (currentStats.0 + 1, currentStats.1)
            } else {
                modeStats[feedback.summaryMode] = (currentStats.0, currentStats.1 + 1)
            }
        }
        
        return modeStats
    }
    
    func getFeedbackByProvider() -> [String: (thumbsUp: Int, thumbsDown: Int)] {
        var providerStats: [String: (Int, Int)] = [:]
        
        for feedback in feedbackHistory {
            let currentStats = providerStats[feedback.aiProvider] ?? (0, 0)
            if feedback.feedbackType == .thumbsUp {
                providerStats[feedback.aiProvider] = (currentStats.0 + 1, currentStats.1)
            } else {
                providerStats[feedback.aiProvider] = (currentStats.0, currentStats.1 + 1)
            }
        }
        
        return providerStats
    }
    
    // MARK: - Cleanup
    
    func clearOldFeedback(olderThan days: Int = 90) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let initialCount = feedbackHistory.count
        
        feedbackHistory = feedbackHistory.filter { $0.timestamp > cutoffDate }
        
        if feedbackHistory.count != initialCount {
            saveFeedbackHistory()
            print("📝 SummaryFeedback: Cleaned up \(initialCount - feedbackHistory.count) old feedback entries")
        }
    }
}

// MARK: - Enhanced Telemetry Extension

extension EnhancedTelemetryService {
    func logSummaryFeedback(
        type: String,
        mode: String,
        length: String,
        provider: String,
        hasUserFeedback: Bool,
        transcriptLength: Int,
        summaryLength: Int
    ) {
        let eventProperties: [String: Any] = [
            "feedback_type": type,
            "summary_mode": mode,
            "summary_length": length,
            "ai_provider": provider,
            "has_user_feedback": hasUserFeedback,
            "transcript_length": transcriptLength,
            "summary_length": summaryLength
        ]
        
        logEvent("summary_feedback", properties: eventProperties)
        print("📊 EnhancedTelemetry: Logged summary feedback - \(type) for \(provider)")
    }
}