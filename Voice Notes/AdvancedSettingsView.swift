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
            Section(header: Text("AI Provider")) {
                NavigationLink(destination: AIProviderSettingsView()) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI Provider Settings")
                                .font(.poppins.body)

                            Text("Configure OpenAI, Claude, Gemini, or Mistral")
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
                            Text("Usage Analytics")
                                .font(.poppins.body)

                            Text("View AI provider performance stats")
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Summary Settings
            Section(header: Text("Summary Settings")) {
                // AI Summary Mode Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Summary Mode")
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
                    Text("Summary Detail Level")
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
                    Toggle("Automatic Mode Detection", isOn: $autoDetectMode)
                        .font(.poppins.headline)

                    Text(autoDetectMode ?
                         "The app automatically detects which mode best fits the recording content." :
                         "Always uses the default mode for summaries.")
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // List Settings
            Section(header: Text("List Settings")) {
                // Default List Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default List Type")
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

                    Text("When saving action items, use \(selectedDocumentType.displayName) by default if no better type is detected.")
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                // Auto-save to documents Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Auto-save Action Items", isOn: $autoSaveToDocuments)
                        .font(.poppins.headline)

                    Text(autoSaveToDocuments ?
                         "Automatically saves detected action items to lists without asking." :
                         "Asks before saving action items to lists.")
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Organization
            Section(header: Text("Organization")) {
                NavigationLink(destination: TagManagementView()) {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manage Tags")
                                .font(.poppins.body)

                            Text("Organize, rename, merge, and delete tags")
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Interface
            Section(header: Text("Interface")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Compact Recording View", isOn: Binding(
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
                         "Using minimalist recording interface with larger controls and cleaner design" :
                         "Switch to minimalist recording interface with larger controls and cleaner design")
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Advanced Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
