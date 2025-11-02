import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("defaultMode") private var defaultMode: String = SummaryMode.personal.rawValue
    @AppStorage("defaultSummaryLength") private var defaultSummaryLength: String = SummaryLength.standard.rawValue
    @AppStorage("autoDetectMode") private var autoDetectMode: Bool = false
    @AppStorage("defaultDocumentType") private var defaultDocumentType: String = DocumentType.todo.rawValue
    @AppStorage("autoSaveToDocuments") private var autoSaveToDocuments: Bool = false
    @AppStorage("useCompactView") private var useCompactView: Bool = true
    @Binding var showingAlternativeView: Bool
    @ObservedObject var recordingsManager: RecordingsManager
    @Environment(\.dismiss) private var dismiss

    private var selectedMode: SummaryMode {
        SummaryMode(rawValue: defaultMode) ?? .personal
    }

    private var selectedSummaryLength: SummaryLength {
        SummaryLength(rawValue: defaultSummaryLength) ?? .standard
    }

    private var selectedDocumentType: DocumentType {
        DocumentType(rawValue: defaultDocumentType) ?? .todo
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

            // List Settings
            Section(header: Text(NSLocalizedString("settings.list_settings", comment: "List Settings"))) {
                // Default List Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("settings.default_list_type", comment: "Default List Type"))
                        .font(.poppins.headline)

                    Picker("Default List Type", selection: Binding(
                        get: { selectedDocumentType },
                        set: { defaultDocumentType = $0.rawValue }
                    )) {
                        ForEach(DocumentType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.systemImage)
                                    .foregroundColor(type.color)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(String(format: NSLocalizedString("settings.default_list_note", comment: "Default list note"), selectedDocumentType.displayName))
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                // Auto-save to documents Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("settings.auto_save_action_items", comment: "Auto-save Action Items"), isOn: $autoSaveToDocuments)
                        .font(.poppins.headline)

                    Text(autoSaveToDocuments ?
                         NSLocalizedString("settings.auto_save_on", comment: "Auto-save on") :
                         NSLocalizedString("settings.auto_save_off", comment: "Auto-save off"))
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Organization
            Section(header: Text(NSLocalizedString("settings.organization", comment: "Organization"))) {
                NavigationLink(destination: TagManagementView()) {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("settings.manage_tags", comment: "Manage Tags"))
                                .font(.poppins.body)

                            Text(NSLocalizedString("settings.organize_rename_merge", comment: "Organize, rename, merge tags"))
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
        }
        .navigationTitle(NSLocalizedString("settings.advanced_settings", comment: "Advanced Settings"))
        .navigationBarTitleDisplayMode(.large)
    }
}
