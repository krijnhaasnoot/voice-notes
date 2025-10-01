import SwiftUI

struct TelemetryView: View {
    private let telemetryService = EnhancedTelemetryService.shared
    private let aggregator = TelemetryAggregator()
    @ObservedObject var recordingsManager: RecordingsManager
    @ObservedObject private var aggregatedService = AggregatedAnalyticsService.shared
    
    @State private var selectedRange: AnalysisRange = AnalysisRange(days: 30)
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    @State private var showingClearConfirmation = false
    @State private var hasLoadedOnce = false
    @Environment(\.dismiss) private var dismiss
    
    private let rangeOptions = [1, 7, 30]
    
    var body: some View {
        List {
            overallStatsSection
            
            // Personal Insights
            Section("📈 Personal Insights") {
                globalInsightsSection
            }
            .headerProminence(.increased)
            
            periodSelectionSection
            
            // Core Usage Metrics
            Section("📊 Usage Overview") {
                sessionMetricsSection
                recordingMetricsSection
            }
            .headerProminence(.increased)
            
            // Settings and Preferences  
            Section("⚙️ Settings & Preferences") {
                settingsDistributionSection
            }
            .headerProminence(.increased)
            
            // User Behavior
            Section("👤 User Behavior") {
                actionMetricsSection
                listsMetricsSection
            }
            .headerProminence(.increased)
            
            // Summary Feedback
            Section("👍 Summary Feedback") {
                summaryFeedbackSection
            }
            .headerProminence(.increased)
            
            dataManagementSection
        }
        .navigationTitle("Usage Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExportSheet) {
            if let data = exportData {
                ShareSheet(items: [data])
            }
        }
        .task {
            // Only load on first appearance to avoid blocking UI
            if !hasLoadedOnce {
                hasLoadedOnce = true
                // Load in background without blocking the view
                Task.detached(priority: .userInitiated) {
                    await loadAggregatedDataInBackground()
                }
            }
        }
        .onAppear {
            // If data is stale (last updated > 5 minutes ago), refresh in background
            if let lastUpdated = aggregatedService.lastUpdated,
               Date().timeIntervalSince(lastUpdated) > 300 {
                Task.detached(priority: .background) {
                    await loadAggregatedDataInBackground()
                }
            }
        }
        .refreshable {
            // Force refresh when user manually pulls to refresh
            await aggregatedService.fetchAggregatedMetrics(force: true)
            await aggregatedService.getUserSegments()
        }
        .alert("Clear Analytics Data?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                clearAnalyticsData()
            }
        } message: {
            Text("This will permanently delete all local analytics data including sessions, events, and usage statistics. This cannot be undone.")
        }
    }
    
    // MARK: - Helper Functions

    private func loadAggregatedData() async {
        await aggregatedService.fetchAggregatedMetrics()
        await aggregatedService.getUserSegments()
    }

    @MainActor
    private func loadAggregatedDataInBackground() async {
        await aggregatedService.fetchAggregatedMetrics()
        await aggregatedService.getUserSegments()
    }

    private func clearAnalyticsData() {
        telemetryService.clearAllData()

        // Force UI refresh by reloading aggregated data
        Task {
            await loadAggregatedData()
        }
    }
    
    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        } else {
            return "\(number)"
        }
    }
    
    private func formatDurationHours(_ hours: Double) -> String {
        if hours >= 8760 { // More than a year
            return String(format: "%.1f years", hours / 8760)
        } else if hours >= 24 { // More than a day
            return String(format: "%.0f days", hours / 24)
        } else {
            return String(format: "%.0fh", hours)
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var daysSinceFirstRecording: String {
        guard let firstRecording = recordingsManager.recordings.min(by: { $0.date < $1.date }) else {
            return "0"
        }
        let days = Calendar.current.dateComponents([.day], from: firstRecording.date, to: Date()).day ?? 0
        return "\(days)"
    }
    
    // MARK: - Overall Stats Tiles
    
    private var overallStatsSection: some View {
        Section {
            VStack(spacing: 16) {
                // Header for admin context
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(aggregatedService.isUsingFallback ? "📊 Personal Analytics" : "🌍 Global Analytics")
                            .font(.poppins.headline)
                            .fontWeight(.bold)
                        Text(aggregatedService.isUsingFallback ? "Local data only (offline)" : "Aggregated data from all users")
                            .font(.poppins.caption)
                            .foregroundColor(aggregatedService.isUsingFallback ? .orange : .secondary)
                    }

                    Spacer()

                    if aggregatedService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let lastUpdated = aggregatedService.lastUpdated {
                        Text("Updated \(formatRelativeTime(lastUpdated))")
                            .font(.poppins.caption2)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
                .padding(.bottom, 8)
                
                // Top row - User & Usage stats
                HStack(spacing: 16) {
                    StatCard(
                        icon: "person.circle.fill",
                        value: aggregatedService.aggregatedMetrics?.activeUsers ?? 0 > 0 ? "Active" : "Inactive",
                        label: "User Status"
                    )
                    
                    StatCard(
                        icon: "calendar.circle.fill",
                        value: daysSinceFirstRecording,
                        label: "Days Using"
                    )
                }
                
                // Second row - Recording stats
                HStack(spacing: 16) {
                    StatCard(
                        icon: "waveform",
                        value: formatLargeNumber(aggregatedService.aggregatedMetrics?.totalRecordings ?? 0),
                        label: "Total Recordings"
                    )
                    
                    if let totalDuration = aggregatedService.aggregatedMetrics?.totalDurationHours {
                        StatCard(
                            icon: "clock.fill",
                            value: formatDurationHours(totalDuration),
                            label: "Recording Time"
                        )
                    } else {
                        StatCard(
                            icon: "clock.fill",
                            value: "N/A",
                            label: "Recording Time"
                        )
                    }
                }
                
                // Third row - Performance metrics
                HStack(spacing: 16) {
                    if let retentionRate = aggregatedService.aggregatedMetrics?.retentionRate {
                        StatCard(
                            icon: "chart.line.uptrend.xyaxis",
                            value: String(format: "%.1f%%", retentionRate * 100),
                            label: "Retention Rate"
                        )
                    } else {
                        StatCard(
                            icon: "chart.line.uptrend.xyaxis",
                            value: "N/A",
                            label: "Retention Rate"
                        )
                    }

                    if let avgSession = aggregatedService.aggregatedMetrics?.averageSessionLength {
                        StatCard(
                            icon: "timer",
                            value: String(format: "%.1f min", avgSession),
                            label: "Avg Session"
                        )
                    } else {
                        StatCard(
                            icon: "timer",
                            value: "N/A",
                            label: "Avg Session"
                        )
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Global Insights Section
    
    private var globalInsightsSection: some View {
        VStack(spacing: 16) {
            // Top Summary Modes
            if let metrics = aggregatedService.aggregatedMetrics {
                VStack(alignment: .leading, spacing: 12) {
                    Text("📝 Most Popular Summary Modes")
                        .font(.poppins.headline)
                        .fontWeight(.semibold)
                    
                    let sortedModes = metrics.topSummaryModes.sorted { $0.value > $1.value }.prefix(5)
                    ForEach(Array(sortedModes), id: \.key) { mode, count in
                        HStack {
                            Text(mode.capitalized)
                                .font(.poppins.body)
                            Spacer()
                            Text("\(formatLargeNumber(count))")
                                .font(.poppins.body)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // User Segments
                if !aggregatedService.userSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("👥 User Segments")
                            .font(.poppins.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(aggregatedService.userSegments, id: \.segment) { segment in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(segment.segment)
                                        .font(.poppins.body)
                                        .fontWeight(.medium)
                                    Text("\(segment.userCount) users • \(String(format: "%.1f", segment.averageRecordings)) avg recordings")
                                        .font(.poppins.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(String(format: "%.1f", segment.churnRate * 100))%")
                                    .font(.poppins.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(segment.churnRate > 0.5 ? .red : segment.churnRate > 0.3 ? .orange : .green)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                }
                
                // Peak Usage Time
                VStack(alignment: .leading, spacing: 8) {
                    Text("⏰ Peak Usage Insights")
                        .font(.poppins.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Peak Time")
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                            Text(aggregatedService.getPeakUsageTime())
                                .font(.poppins.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        if let retentionRate = metrics.retentionRate {
                            VStack(alignment: .trailing) {
                                Text("Retention Rate")
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f%%", retentionRate * 100))
                                    .font(.poppins.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(retentionRate > 0.6 ? .green : retentionRate > 0.4 ? .orange : .red)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading global insights...")
                        .font(.poppins.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }
    
    private var totalDurationText: String {
        let totalSeconds = recordingsManager.recordings.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    
    private var averageRecordingsPerWeek: String {
        guard !recordingsManager.recordings.isEmpty,
              let firstRecording = recordingsManager.recordings.min(by: { $0.date < $1.date }) else {
            return "0"
        }
        
        let timeInterval = Date().timeIntervalSince(firstRecording.date)
        let weeks = max(1, timeInterval / (7 * 24 * 60 * 60)) // 7 days * 24 hours * 60 minutes * 60 seconds
        let average = Double(recordingsManager.recordings.count) / weeks
        
        if average >= 10 {
            return "\(Int(average))"
        } else {
            return String(format: "%.1f", average)
        }
    }
    
    // MARK: - Period Selection
    
    private var periodSelectionSection: some View {
        Section(header: Text("Analysis Period")) {
            Picker("Period", selection: $selectedRange) {
                ForEach(rangeOptions, id: \.self) { days in
                    Text(AnalysisRange(days: days).displayName)
                        .tag(AnalysisRange(days: days))
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Session Metrics
    
    private var sessionMetricsSection: some View {
        let analytics = aggregator.generateAnalytics(for: selectedRange)
        
        return VStack(spacing: 16) {
            // Key session stats in cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Sessions",
                    value: "\(analytics.totalSessions)",
                    subtitle: "\(analytics.sessionsPerDay.formattedOneDecimal)/day",
                    icon: "play.circle.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: "Time in App",
                    value: analytics.totalTimeInApp.formattedDuration,
                    subtitle: "Avg \(analytics.averageSessionDuration.formattedSessionTime)",
                    icon: "clock.fill",
                    color: .green
                )
            }
            
            // Additional details
            VStack(spacing: 8) {
                StatRow(title: "Active Days", value: "\(analytics.activeDays) days")
                StatRow(title: "App Opens per Day", value: analytics.appOpensPerDay.formattedOneDecimal)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Recording Metrics
    
    private var recordingMetricsSection: some View {
        let analytics = aggregator.generateAnalytics(for: selectedRange)
        
        return VStack(spacing: 16) {
            // Key recording stats in cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Recordings",
                    value: "\(analytics.totalRecordings)",
                    subtitle: "This period",
                    icon: "mic.fill",
                    color: .red
                )
                
                MetricCard(
                    title: "Recording Time",
                    value: analytics.totalRecordingTime.formattedDuration,
                    subtitle: "Avg \(analytics.averageRecordingLength.formattedSessionTime)",
                    icon: "waveform",
                    color: .orange
                )
            }
            
            // Recording length distribution (only if there are recordings)
            if analytics.totalRecordings > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("📊 Recording Length Distribution")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(RecordingBucket.allCases, id: \.self) { bucket in
                        let count = analytics.recordingBuckets[bucket] ?? 0
                        if count > 0 {
                            let percentage = analytics.totalRecordings > 0 ? 
                                Double(count) / Double(analytics.totalRecordings) * 100 : 0
                            
                            DistributionRow(
                                label: bucket.rawValue,
                                count: count,
                                percentage: percentage,
                                color: colorForBucket(bucket)
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Settings Distribution
    
    private var settingsDistributionSection: some View {
        let analytics = aggregator.generateAnalytics(for: selectedRange)
        
        return VStack(spacing: 16) {
            // Settings toggles
            VStack(alignment: .leading, spacing: 8) {
                Text("🔧 Settings Usage")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    ToggleCard(
                        title: "Auto Detect",
                        percentage: analytics.settingsToggles.autoDetectEnabled,
                        color: .blue
                    )
                    
                    ToggleCard(
                        title: "Auto Save",
                        percentage: analytics.settingsToggles.autoSaveEnabled,
                        color: .green
                    )
                    
                    ToggleCard(
                        title: "Compact View",
                        percentage: analytics.settingsToggles.compactViewEnabled,
                        color: .purple
                    )
                }
            }
            
            // Provider and Mode distributions (combined)
            HStack(alignment: .top, spacing: 16) {
                // Provider distribution
                if !analytics.providerDistribution.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🤖 AI Providers")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        ForEach(Array(analytics.providerDistribution.sorted(by: { $0.value > $1.value }).prefix(3)), id: \.key) { provider, count in
                            let percentage = analytics.totalRecordings > 0 ? 
                                Double(count) / Double(analytics.totalRecordings) * 100 : 0
                            
                            CompactDistributionRow(
                                label: provider.capitalized,
                                percentage: percentage,
                                color: .blue
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Mode distribution
                if !analytics.modeDistribution.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📝 Recording Modes")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        ForEach(Array(analytics.modeDistribution.sorted(by: { $0.value > $1.value }).prefix(3)), id: \.key) { mode, count in
                            let percentage = analytics.totalRecordings > 0 ? 
                                Double(count) / Double(analytics.totalRecordings) * 100 : 0
                            
                            CompactDistributionRow(
                                label: mode.capitalized,
                                percentage: percentage,
                                color: .orange
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Action Metrics
    
    private var actionMetricsSection: some View {
        let analytics = aggregator.generateAnalytics(for: selectedRange)
        
        return VStack(spacing: 16) {
            // Retry behavior
            VStack(alignment: .leading, spacing: 8) {
                Text("🔄 Retry Behavior")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    MetricCard(
                        title: "Total Retries",
                        value: "\(analytics.retryTaps.total)",
                        subtitle: "\(analytics.retryTaps.ratePerHundredRecordings.formattedOneDecimal) per 100",
                        icon: "arrow.clockwise",
                        color: .orange
                    )
                    
                    MetricCard(
                        title: "Summary Edits",
                        value: "\(analytics.summaryEdits)",
                        subtitle: analytics.summaryEditRate.formattedPercentage,
                        icon: "pencil",
                        color: .blue
                    )
                }
            }
            
            // Detailed breakdown
            VStack(spacing: 6) {
                StatRow(title: "Transcription Retries", value: "\(analytics.retryTaps.transcriptionRetries)")
                StatRow(title: "Summary Retries", value: "\(analytics.retryTaps.summaryRetries)")
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Lists Metrics
    
    private var listsMetricsSection: some View {
        let analytics = aggregator.generateAnalytics(for: selectedRange)
        
        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("📋 Lists Activity")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    MetricCard(
                        title: "Lists Created",
                        value: "\(analytics.listsCreated)",
                        subtitle: "\(analytics.listsUsers) users",
                        icon: "list.bullet",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Items Created",
                        value: "\(analytics.listItemsCreated)",
                        subtitle: "\(analytics.listItemsChecked) completed",
                        icon: "checkmark.square",
                        color: .blue
                    )
                }
            }
            
            if analytics.totalRecordings > 0 {
                StatRow(title: "Recording → List Conversion", value: analytics.recordingToListsConversion.formattedPercentage)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Data Management
    
    private var dataManagementSection: some View {
        Section(
            header: Text("Data Management"),
            footer: Text("All data is stored locally with privacy-first design. Only anonymous usage patterns are tracked using a device-specific anonymous ID.")
        ) {
            Button("Export Analytics Data") {
                exportData = telemetryService.exportData()
                showingExportSheet = true
            }
            .disabled(aggregator.generateAnalytics(for: selectedRange).totalSessions == 0)
            
            #if DEBUG
            Button("Add Test Data") {
                telemetryService.addTestData()
            }
            .disabled(aggregator.generateAnalytics(for: selectedRange).totalSessions > 50)
            #endif
            
            Button("Clear All Analytics Data", role: .destructive) {
                showingClearConfirmation = true
            }
        }
    }
    
    // MARK: - Summary Feedback Section
    
    private var summaryFeedbackSection: some View {
        SummaryFeedbackSectionView()
    }
}

// MARK: - Summary Feedback Section View

struct SummaryFeedbackSectionView: View {
    @ObservedObject private var feedbackService = SummaryFeedbackService.shared
    @State private var feedbackByMode: [String: (thumbsUp: Int, thumbsDown: Int)] = [:]
    @State private var feedbackByProvider: [String: (thumbsUp: Int, thumbsDown: Int)] = [:]
    @State private var recentNegativeFeedback: [SummaryFeedback] = []
    
    var body: some View {
        Group {
            if feedbackService.feedbackStats.totalFeedback > 0 {
                // Overall feedback stats
                HStack(spacing: 16) {
                    MetricCard(
                        title: "Total Feedback",
                        value: "\(feedbackService.feedbackStats.totalFeedback)",
                        subtitle: "\(feedbackService.feedbackStats.feedbackWithComments) with comments",
                        icon: "hand.thumbsup.hand.thumbsdown",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Satisfaction Rate",
                        value: "\(Int((Double(feedbackService.feedbackStats.thumbsUp) / Double(feedbackService.feedbackStats.totalFeedback)) * 100))%",
                        subtitle: "\(feedbackService.feedbackStats.thumbsUp) 👍 / \(feedbackService.feedbackStats.thumbsDown) 👎",
                        icon: "chart.pie",
                        color: feedbackService.feedbackStats.thumbsUp >= feedbackService.feedbackStats.thumbsDown ? .green : .red
                    )
                }
                
                // Feedback by AI mode
                if !feedbackByMode.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback by AI Mode")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(feedbackByMode.keys.sorted(), id: \.self) { mode in
                            let modeFeedback = feedbackByMode[mode]!
                            let total = modeFeedback.thumbsUp + modeFeedback.thumbsDown
                            let satisfaction = total > 0 ? Double(modeFeedback.thumbsUp) / Double(total) : 0
                            
                            FeedbackModeRow(
                                mode: mode,
                                thumbsUp: modeFeedback.thumbsUp,
                                thumbsDown: modeFeedback.thumbsDown,
                                satisfactionRate: satisfaction
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Feedback by AI provider
                if !feedbackByProvider.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Feedback by AI Provider")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(feedbackByProvider.keys.sorted(), id: \.self) { provider in
                            let providerFeedback = feedbackByProvider[provider]!
                            let total = providerFeedback.thumbsUp + providerFeedback.thumbsDown
                            let satisfaction = total > 0 ? Double(providerFeedback.thumbsUp) / Double(total) : 0
                            
                            FeedbackProviderRow(
                                provider: provider,
                                thumbsUp: providerFeedback.thumbsUp,
                                thumbsDown: providerFeedback.thumbsDown,
                                satisfactionRate: satisfaction
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Recent negative feedback
                if !recentNegativeFeedback.isEmpty {
                    NavigationLink(destination: NegativeFeedbackDetailView()) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recent Negative Feedback")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("\(recentNegativeFeedback.count) recent issues to review")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "hand.thumbsup.hand.thumbsdown")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No feedback yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Summary feedback will appear here as users rate AI summaries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .task {
            await loadFeedbackData()
        }
    }
    
    private func loadFeedbackData() async {
        feedbackByMode = await feedbackService.getFeedbackByMode()
        feedbackByProvider = await feedbackService.getFeedbackByProvider()
        recentNegativeFeedback = await feedbackService.getRecentNegativeFeedback(limit: 5)
    }
    
}

// MARK: - Helper Functions Extension

extension TelemetryView {
    private func colorForBucket(_ bucket: RecordingBucket) -> Color {
        switch bucket {
        case .short: return .green
        case .medium: return .blue
        case .long: return .orange
        case .veryLong: return .red
        case .extraLong: return .purple
        }
    }
}

// MARK: - Custom Views

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                }
        }
    }
}

struct ToggleCard: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(percentage.formattedPercentage)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(percentage > 50 ? color : .secondary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(percentage > 50 ? color.opacity(0.1) : Color.gray.opacity(0.05))
        }
    }
}

struct CompactDistributionRow: View {
    let label: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(String(format: "%.0f%%", percentage))")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct DistributionRow: View {
    let label: String
    let count: Int
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("(\(String(format: "%.1f%%", percentage)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.7))
                        .frame(width: geometry.size.width * (percentage / 100), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Feedback Row Components

struct FeedbackModeRow: View {
    let mode: String
    let thumbsUp: Int
    let thumbsDown: Int
    let satisfactionRate: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.capitalized)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(thumbsUp + thumbsDown) total responses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(satisfactionRate * 100))%")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(satisfactionRate >= 0.7 ? .green : satisfactionRate >= 0.4 ? .orange : .red)
                
                HStack(spacing: 8) {
                    Text("\(thumbsUp) 👍")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("\(thumbsDown) 👎")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FeedbackProviderRow: View {
    let provider: String
    let thumbsUp: Int
    let thumbsDown: Int
    let satisfactionRate: Double
    
    private var providerDisplayName: String {
        switch provider.lowercased() {
        case "openai": return "OpenAI"
        case "claude", "anthropic": return "Claude"
        case "gemini": return "Gemini"
        case "mistral": return "Mistral"
        case "app_default": return "App Default"
        default: return provider.capitalized
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(providerDisplayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(thumbsUp + thumbsDown) total responses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(satisfactionRate * 100))%")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(satisfactionRate >= 0.7 ? .green : satisfactionRate >= 0.4 ? .orange : .red)
                
                HStack(spacing: 8) {
                    Text("\(thumbsUp) 👍")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("\(thumbsDown) 👎")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detailed Negative Feedback View

struct NegativeFeedbackDetailView: View {
    @ObservedObject private var feedbackService = SummaryFeedbackService.shared
    @State private var negativeFeedback: [SummaryFeedback] = []
    
    var body: some View {
        List {
            
            if negativeFeedback.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hand.thumbsup")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("No negative feedback")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Great job! All recent summaries have been well received.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(negativeFeedback, id: \.id) { feedback in
                    FeedbackDetailRow(feedback: feedback)
                }
            }
        }
        .navigationTitle("Negative Feedback")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            negativeFeedback = await feedbackService.getRecentNegativeFeedback(limit: 50)
        }
    }
}

struct FeedbackDetailRow: View {
    let feedback: SummaryFeedback
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with metadata
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feedback.summaryMode.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: feedback.timestamp, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(feedback.aiProvider.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text("\(feedback.summaryLength) chars")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // User feedback text
            if let userFeedback = feedback.userFeedback, !userFeedback.isEmpty {
                Text(userFeedback)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Summary preview
            Text(String(feedback.summaryText.prefix(200)) + (feedback.summaryText.count > 200 ? "..." : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        TelemetryView(recordingsManager: RecordingsManager.shared)
    }
}
