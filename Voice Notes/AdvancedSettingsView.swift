import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("defaultMode") private var defaultMode: String = SummaryMode.personal.rawValue
    @AppStorage("defaultSummaryLength") private var defaultSummaryLength: String = SummaryLength.standard.rawValue
    @AppStorage("autoDetectMode") private var autoDetectMode: Bool = false
    @AppStorage("useCompactView") private var useCompactView: Bool = true
    @Binding var showingAlternativeView: Bool
    @ObservedObject var recordingsManager: RecordingsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingRegenerateAllConfirm = false

    private var selectedMode: SummaryMode {
        SummaryMode(rawValue: defaultMode) ?? .personal
    }

    private var selectedSummaryLength: SummaryLength {
        SummaryLength(rawValue: defaultSummaryLength) ?? .standard
    }

    var body: some View {
        Form {
            // AI Provider
            Section(header: Text(NSLocalizedString("settings.ai_provider", comment: "AI Provider"))) {
                NavigationLink(destination: AIProviderSettingsView()) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("settings.ai_provider_settings", comment: "AI Provider Settings"))
                                .font(.poppins.body)

                            Text(NSLocalizedString("settings.configure_providers", comment: "Configure providers"))
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                NavigationLink(destination: TelemetryView(recordingsManager: recordingsManager)) {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("settings.usage_analytics", comment: "Usage Analytics"))
                                .font(.poppins.body)

                            Text(NSLocalizedString("settings.view_performance", comment: "View performance stats"))
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Summary Settings
            Section(header: Text(NSLocalizedString("settings.summary_settings", comment: "Summary Settings"))) {
                // AI Summary Mode Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.ai_summary_mode", comment: "AI Summary Mode"))
                        .font(.poppins.headline)

                    Picker("AI Summary Mode", selection: Binding(
                        get: { selectedMode },
                        set: { defaultMode = $0.rawValue }
                    )) {
                        ForEach(SummaryMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                    .font(.poppins.body)
                                Text(mode.description)
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(selectedMode.description)
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                // Summary Length Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.summary_detail_level", comment: "Summary Detail Level"))
                        .font(.poppins.headline)

                    Picker("Summary Length", selection: Binding(
                        get: { selectedSummaryLength },
                        set: { defaultSummaryLength = $0.rawValue }
                    )) {
                        ForEach(SummaryLength.allCases) { length in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(length.displayName)
                                    .font(.poppins.body)
                                Text(length.description)
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(length)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(selectedSummaryLength.description)
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                // Auto-detection Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("settings.auto_mode_detection", comment: "Automatic Mode Detection"), isOn: $autoDetectMode)
                        .font(.poppins.headline)

                    Text(autoDetectMode ?
                         NSLocalizedString("settings.auto_mode_on", comment: "Auto mode on") :
                         NSLocalizedString("settings.auto_mode_off", comment: "Auto mode off"))
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Interface
            Section(header: Text(NSLocalizedString("settings.interface", comment: "Interface"))) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("settings.compact_recording_view", comment: "Compact Recording View"), isOn: Binding(
                        get: { useCompactView },
                        set: { newValue in
                            useCompactView = newValue
                            if newValue {
                                // Light haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()

                                dismiss()

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        showingAlternativeView = true
                                    }
                                }
                            }
                        }
                    ))
                        .font(.poppins.headline)

                    Text(useCompactView ?
                         NSLocalizedString("settings.compact_view_on", comment: "Compact view on") :
                         NSLocalizedString("settings.compact_view_off", comment: "Compact view off"))
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Maintenance
            Section(header: Text("Maintenance")) {
                VStack(alignment: .leading, spacing: 12) {
                    if recordingsManager.isRegeneratingSummaries {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: recordingsManager.regenerateSummariesProgress)
                            
                            Text(recordingsManager.regenerateSummariesStatusText)
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(recordingsManager.regenerateSummariesProcessedCount) / \(recordingsManager.regenerateSummariesTotalCount)")
                                .font(.poppins.caption2)
                                .foregroundColor(.secondary)
                            
                            if let err = recordingsManager.regenerateSummariesLastError {
                                Text("Last error: \(err)")
                                    .font(.poppins.caption2)
                                    .foregroundColor(.red)
                            }
                            
                            Button("Cancel") {
                                recordingsManager.cancelRegenerateSummariesInBulk()
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button("Fix Local Summaries (recommended)") {
                            recordingsManager.regenerateSummariesInBulk(onlyFixLocalFallback: true)
                        }
                        
                        Button("Regenerate ALL Summaries") {
                            showingRegenerateAllConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                    
                    Text("Tip: ‘Fix Local Summaries’ will only re-run summaries that look like the local fallback (or missing).")
                        .font(.poppins.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(NSLocalizedString("settings.advanced_settings", comment: "Advanced Settings"))
        .navigationBarTitleDisplayMode(.large)
        .alert("Regenerate all summaries?", isPresented: $showingRegenerateAllConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Regenerate All", role: .destructive) {
                recordingsManager.regenerateSummariesInBulk(onlyFixLocalFallback: false)
            }
        } message: {
            Text("This will overwrite existing summaries for all recordings that have a transcript.")
        }
    }
}
