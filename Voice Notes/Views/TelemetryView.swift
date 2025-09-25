import SwiftUI

struct TelemetryView: View {
    private let telemetryService = EnhancedTelemetryService.shared
    private let aggregator = TelemetryAggregator()
    @ObservedObject var recordingsManager: RecordingsManager
    
    @State private var selectedRange: AnalysisRange = AnalysisRange(days: 30)
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    
    private let rangeOptions = [1, 7, 30]
    
    var body: some View {
        List {
            overallStatsSection
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
            
            dataManagementSection
        }
        .navigationTitle("Usage Analytics")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingExportSheet) {
            if let data = exportData {
                ShareSheet(items: [data])
            }
        }
    }
    
    // MARK: - Overall Stats Tiles
    
    private var overallStatsSection: some View {
        Section {
            VStack(spacing: 16) {
                // Top row - Main stats
                HStack(spacing: 16) {
                    StatCard(
                        icon: "waveform",
                        value: "\(recordingsManager.recordings.count)",
                        label: "Recording\(recordingsManager.recordings.count == 1 ? "" : "s")"
                    )
                    
                    StatCard(
                        icon: "clock",
                        value: totalDurationText,
                        label: "Total Time"
                    )
                }
                
                // Second row - Additional insights
                HStack(spacing: 16) {
                    StatCard(
                        icon: "calendar",
                        value: daysSinceFirstRecording,
                        label: "Days Active"
                    )
                    
                    StatCard(
                        icon: "chart.line.uptrend.xyaxis",
                        value: averageRecordingsPerWeek,
                        label: "Per Week"
                    )
                }
            }
            .padding(.vertical, 8)
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
    
    private var daysSinceFirstRecording: String {
        guard let firstRecording = recordingsManager.recordings.min(by: { $0.date < $1.date }) else {
            return "0"
        }
        let days = Date().timeIntervalSince(firstRecording.date)
        let dayCount = max(1, Int(days / 86400)) // 86400 seconds in a day
        return "\(dayCount)"
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
                telemetryService.clearAllData()
            }
        }
    }
    
    // MARK: - Helper Functions
    
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

// MARK: - Preview

#Preview {
    NavigationView {
        TelemetryView(recordingsManager: RecordingsManager.shared)
    }
}
