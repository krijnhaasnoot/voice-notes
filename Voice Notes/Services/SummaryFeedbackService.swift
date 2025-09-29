import Foundation
import SwiftUI

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

// MARK: - Thread-Safe Feedback Actor

actor FeedbackActor {
    private var feedbackHistory: [SummaryFeedback] = []
    private let userDefaults = UserDefaults.standard
    private let feedbackKey = "summary_feedback_history"
    private var pendingSave = false
    
    init() {
        loadFeedbackHistory()
    }
    
    func addFeedback(_ feedback: SummaryFeedback) {
        // Remove any existing feedback for this recording
        feedbackHistory.removeAll { $0.recordingId == feedback.recordingId }
        feedbackHistory.append(feedback)
        
        // Schedule a throttled background save (coalesces multiple writes)
        scheduleSave()
    }
    
    func getFeedbackHistory() -> [SummaryFeedback] {
        return feedbackHistory
    }
    
    func getFeedbackStats() -> (totalFeedback: Int, thumbsUp: Int, thumbsDown: Int, feedbackWithComments: Int) {
        let total = feedbackHistory.count
        let thumbsUp = feedbackHistory.filter { $0.feedbackType == .thumbsUp }.count
        let thumbsDown = feedbackHistory.filter { $0.feedbackType == .thumbsDown }.count
        let withComments = feedbackHistory.filter { $0.userFeedback?.isEmpty == false }.count
        
        return (total, thumbsUp, thumbsDown, withComments)
    }
    
    private func loadFeedbackHistory() {
        guard let data = userDefaults.data(forKey: feedbackKey) else { return }
        
        do {
            feedbackHistory = try JSONDecoder().decode([SummaryFeedback].self, from: data)
        } catch {
            print("❌ SummaryFeedback: Failed to load feedback history: \(error)")
        }
    }
    
    func clearOldFeedback(olderThan cutoffDate: Date) {
        let initialCount = feedbackHistory.count
        feedbackHistory = feedbackHistory.filter { $0.timestamp > cutoffDate }
        
        if feedbackHistory.count != initialCount {
            Task.detached(priority: .utility) { [weak self] in
                await self?.performBackgroundSave()
            }
            print("📝 SummaryFeedback: Cleaned up \(initialCount - feedbackHistory.count) old feedback entries")
        }
    }
    
    // AGGRESSIVE NON-BLOCKING: Queue-based batched writes
    private func scheduleSave() {
        guard !pendingSave else { return }
        pendingSave = true
        
        // Deep background queue - completely isolated from main thread
        Task.detached(priority: .background) { [weak self] in
            // Aggressive coalescing - wait for burst of feedback to settle
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard let self = self else { return }
            
            await self.performBackgroundSave()
            await self.markSaveComplete()
        }
    }
    
    private func markSaveComplete() {
        pendingSave = false
    }
    
    // Completely isolated I/O operation
    private func performBackgroundSave() async {
        let feedbackSnapshot = feedbackHistory
        
        // Move ALL I/O off ANY actor context
        await Task.detached(priority: .background) {
            do {
                let data = try JSONEncoder().encode(feedbackSnapshot)
                UserDefaults.standard.set(data, forKey: "summary_feedback_history")
            } catch {
                print("❌ SummaryFeedback: Failed to save feedback history: \(error)")
            }
        }.value
    }
}

// MARK: - Observable Service

@MainActor
class SummaryFeedbackService: ObservableObject {
    static let shared = SummaryFeedbackService()
    
    @Published private(set) var feedbackSubmissionState: FeedbackSubmissionState = .idle
    @Published private(set) var feedbackStats: FeedbackStats = FeedbackStats()
    let feedbackActor = FeedbackActor()
    
    private init() {
        Task {
            await loadInitialData()
        }
    }
    
    enum FeedbackSubmissionState {
        case idle
        case submitting
        case completed
        case failed(Error)
    }
    
    struct FeedbackStats {
        var totalFeedback: Int = 0
        var thumbsUp: Int = 0
        var thumbsDown: Int = 0
        var feedbackWithComments: Int = 0
    }
    
    // MARK: - Public Interface
    
    private func loadInitialData() async {
        let stats = await feedbackActor.getFeedbackStats()
        await MainActor.run {
            self.feedbackStats = FeedbackStats(
                totalFeedback: stats.totalFeedback,
                thumbsUp: stats.thumbsUp,
                thumbsDown: stats.thumbsDown,
                feedbackWithComments: stats.feedbackWithComments
            )
        }
    }
    
    // Batch state updates into a single animated tick to reduce SwiftUI recompute cost
    private func publishStats(_ s: FeedbackStats) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.feedbackStats = s
            self.feedbackSubmissionState = .completed
        }
    }
    
    // MARK: - Feedback Collection
    
    func submitFeedback(
        recordingId: UUID,
        summaryText: String,
        feedbackType: FeedbackType,
        userFeedback: String? = nil,
        recording: Recording
    ) {
        // ZERO-BLOCKING APPROACH: Fire and forget - no awaiting, no state updates
        // UI gets immediate response, all work happens in background
        
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
        
        // Fire-and-forget: Complete background processing
        Task.detached(priority: .utility) {
            // All work isolated in background - no main thread involvement
            await self.feedbackActor.addFeedback(feedback)
            await self.sendFeedbackToAnalytics(feedback)
            
            print("📝 SummaryFeedback: Collected \(feedbackType.rawValue) feedback for recording \(recordingId)")
            if let userText = userFeedback {
                print("📝 User feedback: \(userText)")
            }
        }
        
        // No state updates, no awaiting, no blocking - UI stays responsive
    }
    
    // MARK: - Analytics Integration
    
    private func sendFeedbackToAnalytics(_ feedback: SummaryFeedback) async {
        // TEMPORARILY DISABLED: Skip all analytics to eliminate any blocking
        // This isolates the issue to determine if analytics is causing freezing
        print("📊 Analytics disabled - feedback logged locally only")
        return
        
        #if false // Analytics temporarily disabled
        Task.detached(priority: .utility) {
            // Enhanced telemetry (non-blocking)
            await EnhancedTelemetryService.shared.logSummaryFeedback(
                type: feedback.feedbackType.rawValue,
                mode: feedback.summaryMode,
                length: feedback.summaryLengthSetting,
                provider: feedback.aiProvider,
                hasUserFeedback: feedback.userFeedback != nil,
                transcriptLength: feedback.transcriptLength,
                summaryLength: feedback.summaryLength
            )

            // General analytics
            var eventData: [String: Any] = [
                "feedback_type": feedback.feedbackType.rawValue,
                "summary_mode": feedback.summaryMode,
                "summary_length_setting": feedback.summaryLengthSetting,  // User's length preference (brief/standard/detailed)
                "ai_provider": feedback.aiProvider,
                "transcript_length": feedback.transcriptLength,
                "summary_character_count": feedback.summaryLength,        // Actual character count of generated summary
                "has_user_feedback": feedback.userFeedback != nil
            ]
            if let userText = feedback.userFeedback { eventData["feedback_text_length"] = userText.count }
            Analytics.track("summary_feedback_submitted", props: eventData)
        }
        #endif
    }
    
    // MARK: - Analytics Dashboard Data
    
    func getFeedbackStats() async -> FeedbackStats {
        let stats = await feedbackActor.getFeedbackStats()
        return FeedbackStats(
            totalFeedback: stats.totalFeedback,
            thumbsUp: stats.thumbsUp,
            thumbsDown: stats.thumbsDown,
            feedbackWithComments: stats.feedbackWithComments
        )
    }
    
    func getRecentNegativeFeedback(limit: Int = 20) async -> [SummaryFeedback] {
        let allFeedback = await feedbackActor.getFeedbackHistory()
        return allFeedback
            .filter { $0.feedbackType == .thumbsDown }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    func getFeedbackByMode() async -> [String: (thumbsUp: Int, thumbsDown: Int)] {
        let allFeedback = await feedbackActor.getFeedbackHistory()
        var modeStats: [String: (Int, Int)] = [:]
        
        for feedback in allFeedback {
            let currentStats = modeStats[feedback.summaryMode] ?? (0, 0)
            if feedback.feedbackType == .thumbsUp {
                modeStats[feedback.summaryMode] = (currentStats.0 + 1, currentStats.1)
            } else {
                modeStats[feedback.summaryMode] = (currentStats.0, currentStats.1 + 1)
            }
        }
        
        return modeStats
    }
    
    func getFeedbackByProvider() async -> [String: (thumbsUp: Int, thumbsDown: Int)] {
        let allFeedback = await feedbackActor.getFeedbackHistory()
        var providerStats: [String: (Int, Int)] = [:]
        
        for feedback in allFeedback {
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
    
    func clearOldFeedback(olderThan days: Int = 90) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        await feedbackActor.clearOldFeedback(olderThan: cutoffDate)
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
            "summary_length_setting": length,        // User's length preference (brief/standard/detailed)
            "ai_provider": provider,
            "has_user_feedback": hasUserFeedback,
            "transcript_length": transcriptLength,
            "summary_character_count": summaryLength  // Actual character count of generated summary
        ]
        
        logEvent("summary_feedback", properties: eventProperties)
        print("📊 EnhancedTelemetry: Logged summary feedback - \(type) for \(provider)")
    }
}
