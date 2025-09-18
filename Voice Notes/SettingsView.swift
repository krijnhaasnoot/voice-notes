import SwiftUI

extension SummaryMode {
    var description: String {
        switch self {
        case .primaryCare:
            return "For primary care consultations with patients"
        case .dentist:
            return "For dental treatments and consultations"
        case .techTeam:
            return "For technical team meetings and development discussions"
        case .planning:
            return "For planning and project meetings"
        case .alignment:
            return "For alignment and strategic sessions"
        case .personal:
            return "For personal conversations and general topics"
        }
    }
}

struct SettingsView: View {
    @AppStorage("defaultMode") private var defaultMode: String = SummaryMode.personal.rawValue
    @AppStorage("defaultSummaryLength") private var defaultSummaryLength: String = SummaryLength.standard.rawValue
    @AppStorage("autoDetectMode") private var autoDetectMode: Bool = false
    @AppStorage("defaultDocumentType") private var defaultDocumentType: String = DocumentType.todo.rawValue
    @AppStorage("autoSaveToDocuments") private var autoSaveToDocuments: Bool = false
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showingTour = false
    
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
                Section(header: Text("Summary Settings")) {
                    // Default Mode Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Mode")
                            .font(.headline)
                        
                        Picker("Default Mode", selection: Binding(
                            get: { selectedMode },
                            set: { defaultMode = $0.rawValue }
                        )) {
                            ForEach(SummaryMode.allCases, id: \.self) { mode in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.body)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Text(selectedMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // Summary Length Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary Detail Level")
                            .font(.headline)
                        
                        Picker("Summary Length", selection: Binding(
                            get: { selectedSummaryLength },
                            set: { defaultSummaryLength = $0.rawValue }
                        )) {
                            ForEach(SummaryLength.allCases) { length in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(length.displayName)
                                        .font(.body)
                                    Text(length.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(length)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Text(selectedSummaryLength.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // Auto-detection Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Automatic Mode Detection", isOn: $autoDetectMode)
                            .font(.headline)
                        
                        Text(autoDetectMode ? 
                             "The app automatically detects which mode best fits the recording content." :
                             "Always uses the default mode for summaries.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("List Settings")) {
                    // Default List Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default List Type")
                            .font(.headline)
                        
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
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // Auto-save to documents Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Auto-save Action Items", isOn: $autoSaveToDocuments)
                            .font(.headline)
                        
                        Text(autoSaveToDocuments ? 
                             "Automatically saves detected action items to lists without asking." :
                             "Asks before saving action items to lists.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Getting Started")) {
                    Button(action: { showingTour = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Take the Tour")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Learn about Voice Notes features")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section(header: Text("Info")) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsInfoRow(
                            icon: "brain.head.profile", 
                            title: "AI Summary", 
                            description: "Uses OpenAI GPT-4 for intelligent summaries"
                        )
                        
                        SettingsInfoRow(
                            icon: "waveform", 
                            title: "Transcription", 
                            description: "Uses OpenAI Whisper for accurate speech-to-text"
                        )
                        
                        SettingsInfoRow(
                            icon: "person.2.fill", 
                            title: "Language Recognition",
                            description: "Automatic detection of different languages"
                        )
                        
                        SettingsInfoRow(
                            icon: "doc.text.fill", 
                            title: "Smart Lists",
                            description: "Organize action items into intelligent list types"
                        )
                    }
                    .padding(.vertical, 4)
                }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingTour) {
            AppTourView()
        }
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}
