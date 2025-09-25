import SwiftUI
import UIKit

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
        case .brainstorm:
            return "For creative brainstorming and ideation sessions"
        case .lecture:
            return "For lectures, talks, and learning content"
        case .interview:
            return "For interviews, Q&A sessions, and structured conversations"
        case .personal:
            return "For general conversations and topics"
        }
    }
}

struct SettingsView: View {
    @AppStorage("defaultMode") private var defaultMode: String = SummaryMode.personal.rawValue
    @AppStorage("defaultSummaryLength") private var defaultSummaryLength: String = SummaryLength.standard.rawValue
    @AppStorage("autoDetectMode") private var autoDetectMode: Bool = false
    @AppStorage("defaultDocumentType") private var defaultDocumentType: String = DocumentType.todo.rawValue
    @AppStorage("autoSaveToDocuments") private var autoSaveToDocuments: Bool = false
    @AppStorage("useCompactView") private var useCompactView: Bool = true
    
    @Binding var showingAlternativeView: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingTour = false
    
    // MARK: - Analytics PIN & Sheet State
    @AppStorage("analyticsPIN") private var analyticsPIN: String = ""
    @State private var showAnalytics = false
    @State private var showPinSheet = false
    @State private var pinEntry: String = ""
    @State private var newPin: String = ""
    @State private var confirmPin: String = ""
    @State private var pinError: String?
    @State private var showResetPinConfirm = false
    
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
        NavigationStack {
            Form {
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
                
                NavigationLink(destination: TelemetryView()) {
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
                
                Section(header: Text("Getting Started")) {
                    Button(action: { showingTour = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Take the Tour")
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)
                                
                                Text("Learn about Voice Notes features")
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.poppins.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section(header: Text("Feedback & Support")) {
                    Button(action: { sendFeedback() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.green)
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Send Feedback via WhatsApp")
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)
                                
                                Text("Report issues or request features")
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right.square")
                                .font(.poppins.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Section(header: Text("Privacy & Data Usage")) {
                    NavigationLink(destination: PrivacyInfoView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Privacy & Data Usage")
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)
                                
                                Text(PrivacyStrings.shortDescription)
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                    Button(role: .destructive) {
                        showResetPinConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.red)
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Analytics PIN")
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)
                                Text("Remove the PIN required to open Analytics")
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
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
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.0) {
                        // Present PIN gate first
                        pinEntry = ""
                        newPin = ""
                        confirmPin = ""
                        pinError = nil
                        showPinSheet = true
                    }
                }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(.poppins.headline)
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingTour) {
            AppTourView(onComplete: {
                showingTour = false
            })
        }
        .sheet(isPresented: $showPinSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    if analyticsPIN.isEmpty {
                        // Set a new PIN flow
                        Text("Set Analytics PIN")
                            .font(.poppins.headline)
                        Text("Create a 4–8 digit code to protect the analytics dashboard.")
                            .font(.poppins.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        SecureField("New PIN", text: $newPin)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        SecureField("Confirm PIN", text: $confirmPin)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        if let pinError {
                            Text(pinError)
                                .font(.poppins.caption)
                                .foregroundColor(.red)
                        }
                        Button {
                            pinError = nil
                            let trimmed = newPin.trimmingCharacters(in: .whitespaces)
                            guard trimmed.count >= 4, trimmed.count <= 8, trimmed.allSatisfy({ $0.isNumber }) else {
                                pinError = "PIN must be 4–8 digits"
                                return
                            }
                            guard trimmed == confirmPin.trimmingCharacters(in: .whitespaces) else {
                                pinError = "PINs do not match"
                                return
                            }
                            analyticsPIN = trimmed
                            showPinSheet = false
                            showAnalytics = true
                        } label: {
                            Text("Save PIN & Open Analytics")
                                .font(.poppins.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    } else {
                        // Enter existing PIN flow
                        Text("Enter Analytics PIN")
                            .font(.poppins.headline)
                        SecureField("PIN", text: $pinEntry)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        if let pinError {
                            Text(pinError)
                                .font(.poppins.caption)
                                .foregroundColor(.red)
                        }
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                showPinSheet = false
                            }
                            .buttonStyle(.bordered)
                            Button("Unlock") {
                                pinError = nil
                                if pinEntry == analyticsPIN {
                                    showPinSheet = false
                                    showAnalytics = true
                                } else {
                                    pinError = "Incorrect PIN"
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("Protected")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showPinSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showAnalytics) {
            TelemetryView()
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Reset Analytics PIN?", isPresented: $showResetPinConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                analyticsPIN = ""
                // light haptic feedback to confirm
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        } message: {
            Text("This will remove the current PIN. You'll be asked to set a new PIN the next time you long-press the Info section.")
        }
        .onChange(of: defaultMode) { oldValue, newValue in
            EnhancedTelemetryService.shared.logSettingsChanged(key: "defaultMode", value: newValue)
            Analytics.track("mode_changed", props: ["from": oldValue, "to": newValue])
        }
        .onChange(of: defaultSummaryLength) { oldValue, newValue in
            EnhancedTelemetryService.shared.logSettingsChanged(key: "defaultSummaryLength", value: newValue)
            Analytics.track("length_changed", props: ["from": oldValue, "to": newValue])
        }
        .onChange(of: autoDetectMode) { _, newValue in
            EnhancedTelemetryService.shared.logSettingsChanged(key: "autoDetectMode", value: newValue)
            Analytics.track("auto_detect_toggled", props: ["on": newValue])
        }
        .onChange(of: defaultDocumentType) { _, newValue in
            EnhancedTelemetryService.shared.logSettingsChanged(key: "defaultDocumentType", value: newValue)
            Analytics.track("default_document_type_changed", props: ["type": newValue])
        }
        .onChange(of: autoSaveToDocuments) { _, newValue in
            EnhancedTelemetryService.shared.logSettingsChanged(key: "autoSaveToDocuments", value: newValue)
            Analytics.track("auto_save_toggled", props: ["on": newValue])
        }
        .onChange(of: useCompactView) { _, newValue in
            EnhancedTelemetryService.shared.logSettingsChanged(key: "useCompactView", value: newValue)
            Analytics.track("compact_view_toggled", props: ["on": newValue])
        }
        }
    }
    
    // MARK: - Feedback Function
    
    private func sendFeedback() {
        // Create feedback message with app info
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        let message = """
        Hi! I'd like to share feedback about the Echo app:
        
        [Please write your feedback, feature requests, or bug reports here]
        
        ---
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(systemVersion)
        Device: \(deviceModel)
        """
        
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let phoneNumber = "31611220008" // +31611220008 without the + for WhatsApp URL
        
        // Try to open WhatsApp first
        if let whatsAppUrl = URL(string: "whatsapp://send?phone=\(phoneNumber)&text=\(encodedMessage)"),
           UIApplication.shared.canOpenURL(whatsAppUrl) {
            UIApplication.shared.open(whatsAppUrl)
        } else {
            // Fallback to showing contact info
            let alert = UIAlertController(
                title: "WhatsApp Not Available",
                message: "To send feedback:\n\n📱 WhatsApp: +31 6 1122 0008\n\nPlease include:\n• Feature requests\n• Bug reports\n• General feedback\n\nApp info: \(appVersion) (\(buildNumber)) - iOS \(systemVersion)",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Copy Phone Number", style: .default) { _ in
                UIPasteboard.general.string = "+31611220008"
            })
            
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            
            // Present alert from the current window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                var topController = rootViewController
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                topController.present(alert, animated: true)
            }
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
                .font(.poppins.regular(size: 20))
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.poppins.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView(showingAlternativeView: .constant(false))
}
