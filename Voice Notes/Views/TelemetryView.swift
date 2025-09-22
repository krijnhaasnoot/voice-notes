import SwiftUI

struct TelemetryView: View {
    private let telemetryService = TelemetryService.shared
    @State private var selectedDays = 30
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    
    private let dayOptions = [7, 30, 90]
    
    var body: some View {
        List {
                periodSelectionSection
                overallStatsSection
                providerBreakdownSection
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
            Picker("Days", selection: $selectedDays) {
                ForEach(dayOptions, id: \.self) { days in
                    Text("\(days) days")
                        .tag(days)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Overall Statistics
    
    private var overallStatsSection: some View {
        Section(header: Text("Overall Statistics")) {
            let stats = telemetryService.getUsageStats(days: selectedDays)
            
            VStack(spacing: 12) {
                StatRow(title: "Total Requests", value: "\(stats.totalRequests)")
                StatRow(title: "Success Rate", value: stats.formattedSuccessRate)
                StatRow(title: "Fallback Rate", value: stats.formattedFallbackRate)
                StatRow(title: "Avg Processing Time", value: stats.formattedProcessingTime)
                StatRow(title: "Avg Transcript Length", value: "\(stats.averageTranscriptLength) chars")
                StatRow(title: "Avg Summary Length", value: "\(stats.averageSummaryLength) chars")
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Provider Breakdown
    
    private var providerBreakdownSection: some View {
        Section(header: Text("Provider Breakdown")) {
            let breakdown = telemetryService.getProviderBreakdown(days: selectedDays)
            
            ForEach(Array(breakdown.sorted(by: { $0.value.totalRequests > $1.value.totalRequests })), id: \.key) { provider, stats in
                if stats.totalRequests > 0 {
                    ProviderStatsRow(providerName: provider, stats: stats)
                }
            }
            
            if breakdown.values.allSatisfy({ $0.totalRequests == 0 }) {
                Text("No usage data available for selected period")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    // MARK: - Data Management
    
    private var dataManagementSection: some View {
        Section(
            header: Text("Data Management"),
            footer: Text("Telemetry data is stored locally and contains no personal information. Only anonymized usage statistics are tracked.")
        ) {
            Button("Export Data") {
                exportData = telemetryService.exportTelemetryData()
                showingExportSheet = true
            }
            .disabled(telemetryService.getUsageStats(days: selectedDays).totalRequests == 0)
            
            Button("Add Test Data") {
                telemetryService.addTestData()
            }
            .disabled(telemetryService.getUsageStats(days: selectedDays).totalRequests > 50)
            
            Button("Clear Data", role: .destructive) {
                telemetryService.clearTelemetryData()
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

// MARK: - Provider Stats Row

struct ProviderStatsRow: View {
    let providerName: String
    let stats: UsageStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(providerName)
                    .fontWeight(.medium)
                Spacer()
                Text("\(stats.totalRequests) requests")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Success")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(stats.formattedSuccessRate)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(stats.successRate > 0.9 ? .green : stats.successRate > 0.7 ? .orange : .red)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg Time")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(stats.formattedProcessingTime)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                if stats.fallbacksUsed > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fallbacks")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(stats.formattedFallbackRate)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Preview

#Preview {
    TelemetryView()
}