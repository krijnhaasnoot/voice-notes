import SwiftUI

struct TelemetryView: View {
    private let telemetryService = EnhancedTelemetryService.shared
    private let aggregator = TelemetryAggregator()
    
    @State private var selectedRange: AnalysisRange = AnalysisRange(days: 30)
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    
    private let rangeOptions = [1, 7, 30]
    
    var body: some View {
        List {
            periodSelectionSection
            sessionMetricsSection
            recordingMetricsSection
            settingsDistributionSection
            actionMetricsSection
            listsMetricsSection
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
        Section(header: Text("Sessions & Activity")) {
            let analytics = aggregator.generateAnalytics(for: selectedRange)
            
            VStack(spacing: 12) {
                StatRow(title: "Total Sessions", value: "\(analytics.totalSessions)")
                StatRow(title: "Active Days", value: "\(analytics.activeDays)")
                StatRow(title: "Sessions per Day", value: analytics.sessionsPerDay.formattedOneDecimal)
                StatRow(title: "App Opens per Day", value: analytics.appOpensPerDay.formattedOneDecimal)
                StatRow(title: "Total Time in App", value: analytics.totalTimeInApp.formattedDuration)
                StatRow(title: "Avg Session Duration", value: analytics.averageSessionDuration.formattedSessionTime)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Recording Metrics
    
    private var recordingMetricsSection: some View {
        Section(header: Text("Recording Analytics")) {
            let analytics = aggregator.generateAnalytics(for: selectedRange)
            
            VStack(spacing: 12) {
                StatRow(title: "Total Recordings", value: "\(analytics.totalRecordings)")
                StatRow(title: "Total Recording Time", value: analytics.totalRecordingTime.formattedDuration)
                StatRow(title: "Avg Recording Length", value: analytics.averageRecordingLength.formattedSessionTime)
            }
            .padding(.vertical, 8)
            
            // Recording length distribution
            if analytics.totalRecordings > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording Length Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.top, 8)
                    
                    ForEach(RecordingBucket.allCases, id: \.self) { bucket in
                        let count = analytics.recordingBuckets[bucket] ?? 0
                        if count > 0 {
                            let percentage = analytics.totalRecordings > 0 ? 
                                Double(count) / Double(analytics.totalRecordings) * 100 : 0
                            
                            HStack {
                                Text(bucket.displayName)
                                    .font(.caption)
                                Spacer()
                                Text("\(count) (\(String(format: "%.1f%%", percentage)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Settings Distribution
    
    private var settingsDistributionSection: some View {
        Section(header: Text("Settings Usage")) {
            let analytics = aggregator.generateAnalytics(for: selectedRange)
            
            VStack(spacing: 12) {
                StatRow(title: "Auto Detect Enabled", value: analytics.settingsToggles.autoDetectEnabled.formattedPercentage)
                StatRow(title: "Auto Save Enabled", value: analytics.settingsToggles.autoSaveEnabled.formattedPercentage)
                StatRow(title: "Compact View Enabled", value: analytics.settingsToggles.compactViewEnabled.formattedPercentage)
            }
            .padding(.vertical, 8)
            
            // Provider distribution
            if !analytics.providerDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provider Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.top, 8)
                    
                    ForEach(Array(analytics.providerDistribution.sorted(by: { $0.value > $1.value })), id: \.key) { provider, count in
                        let percentage = analytics.totalRecordings > 0 ? 
                            Double(count) / Double(analytics.totalRecordings) * 100 : 0
                        
                        HStack {
                            Text(provider.capitalized)
                                .font(.caption)
                            Spacer()
                            Text("\(count) (\(String(format: "%.1f%%", percentage)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Mode distribution
            if !analytics.modeDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mode Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.top, 8)
                    
                    ForEach(Array(analytics.modeDistribution.sorted(by: { $0.value > $1.value })), id: \.key) { mode, count in
                        let percentage = analytics.totalRecordings > 0 ? 
                            Double(count) / Double(analytics.totalRecordings) * 100 : 0
                        
                        HStack {
                            Text(mode.capitalized)
                                .font(.caption)
                            Spacer()
                            Text("\(count) (\(String(format: "%.1f%%", percentage)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Action Metrics
    
    private var actionMetricsSection: some View {
        Section(header: Text("User Actions")) {
            let analytics = aggregator.generateAnalytics(for: selectedRange)
            
            VStack(spacing: 12) {
                StatRow(title: "Total Retry Taps", value: "\(analytics.retryTaps.total)")
                StatRow(title: "Transcription Retries", value: "\(analytics.retryTaps.transcriptionRetries)")
                StatRow(title: "Summary Retries", value: "\(analytics.retryTaps.summaryRetries)")
                StatRow(title: "Retry Rate", value: "\(analytics.retryTaps.ratePerHundredRecordings.formattedOneDecimal) per 100")
                StatRow(title: "Summary Edits", value: "\(analytics.summaryEdits)")
                StatRow(title: "Summary Edit Rate", value: analytics.summaryEditRate.formattedPercentage)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Lists Metrics
    
    private var listsMetricsSection: some View {
        Section(header: Text("Lists Usage")) {
            let analytics = aggregator.generateAnalytics(for: selectedRange)
            
            VStack(spacing: 12) {
                StatRow(title: "Lists Users", value: "\(analytics.listsUsers)")
                StatRow(title: "Lists Created", value: "\(analytics.listsCreated)")
                StatRow(title: "List Items Created", value: "\(analytics.listItemsCreated)")
                StatRow(title: "List Items Checked", value: "\(analytics.listItemsChecked)")
                StatRow(title: "Recording to Lists Conversion", value: analytics.recordingToListsConversion.formattedPercentage)
            }
            .padding(.vertical, 8)
        }
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
        TelemetryView()
    }
}