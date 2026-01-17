import SwiftUI
import UIKit

extension SummaryMode {
    var description: String {
        switch self {
        case .medical:
            return NSLocalizedString("summary.desc.medical", comment: "Medical mode description")
        case .work:
            return NSLocalizedString("summary.desc.work", comment: "Work mode description")
        case .personal:
            return NSLocalizedString("summary.desc.personal", comment: "Personal mode description")
        }
    }
}

struct SettingsView: View {
    @AppStorage("defaultMode") private var defaultMode: String = SummaryMode.personal.rawValue
    @AppStorage("defaultSummaryLength") private var defaultSummaryLength: String = SummaryLength.standard.rawValue
    @AppStorage("autoDetectMode") private var autoDetectMode: Bool = false
    @AppStorage("defaultDocumentType") private var defaultDocumentType: String = DocumentType.todo.rawValue
    @AppStorage("autoSaveToDocuments") private var autoSaveToDocuments: Bool = false
    @AppStorage("useCompactView") private var useCompactView: Bool = false

    @Binding var showingAlternativeView: Bool
    @ObservedObject var recordingsManager: RecordingsManager
    @ObservedObject private var usageVM = UsageViewModel.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingTour = false
    @State private var showingPaywall = false
    @State private var showingToast = false
    @State private var toastMessage = ""

    // MARK: - Analytics PIN & Sheet State
    @AppStorage("analyticsPIN") private var analyticsPIN: String = ""
    @State private var showAnalytics = false
    @State private var showPinSheet = false
    
    private var selectedMode: SummaryMode {
        SummaryMode(rawValue: defaultMode) ?? .personal
    }

    private var selectedSummaryLength: SummaryLength {
        SummaryLength(rawValue: defaultSummaryLength) ?? .standard
    }

    private var selectedDocumentType: DocumentType {
        DocumentType(rawValue: defaultDocumentType) ?? .todo
    }

    // Check if user is on the highest tier (Own Key subscription)
    private var isOnHighestTier: Bool {
        guard let subscription = subscriptionManager.activeSubscription else {
            return false
        }
        return subscription == .ownKey
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Subscription & Minutes Section
                Section(header: Text(NSLocalizedString("settings.subscription", comment: "Subscription"))) {
                    // Backend-authoritative usage display
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subscriptionManager.activeSubscription?.displayName ?? NSLocalizedString("settings.free_trial", comment: "Free Trial"))
                                    .font(.headline)
                                    .fontWeight(.bold)

                                // Show "minutes" for free trial, "minutes per month" for paid subscriptions
                                Text(subscriptionManager.activeSubscription == nil
                                     ? "\(subscriptionManager.currentMonthlyMinutes) \(NSLocalizedString("settings.minutes", comment: "minutes"))"
                                     : "\(subscriptionManager.currentMonthlyMinutes) \(NSLocalizedString("settings.minutes_per_month", comment: "minutes per month"))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Show "Upgrade" if user can upgrade, "Manage" if on highest tier
                            Button(action: { showingPaywall = true }) {
                                Text(isOnHighestTier ? NSLocalizedString("settings.manage", comment: "Manage") : NSLocalizedString("settings.upgrade", comment: "Upgrade"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }

                        VStack(spacing: 8) {
                            HStack {
                                Text(NSLocalizedString("settings.usage_this_month", comment: "Usage this month"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Spacer()

                                if usageVM.isLoading {
                                    ProgressView()
                                } else if usageVM.isStale && usageVM.limitSeconds == 0 {
                                    // Never synced or sync failed - show friendly message
                                    Text(NSLocalizedString("settings.checking", comment: "Checking..."))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                } else {
                                    Text("\(usageVM.minutesUsedDisplay) / \(usageVM.limitSeconds / 60) min")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(usageVM.isOverLimit ? .red : .primary)
                                }
                            }

                            // Progress bar or friendly sync message
                            if usageVM.isStale && usageVM.limitSeconds == 0 && !usageVM.isLoading {
                                VStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "wifi.exclamationmark")
                                            .foregroundColor(.orange)
                                        Text(NSLocalizedString("settings.unable_to_check", comment: "Unable to check usage"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Button {
                                        Task { await usageVM.refresh() }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.clockwise")
                                            Text(NSLocalizedString("settings.try_again", comment: "Try Again"))
                                        }
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(.vertical, 4)
                            } else {
                                // Normal progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 12)

                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(usageVM.isOverLimit ? Color.red : Color.green)
                                            .frame(width: geometry.size.width * min(Double(usageVM.secondsUsed) / Double(max(usageVM.limitSeconds, 1)), 1.0), height: 12)
                                    }
                                }
                                .frame(height: 12)

                                HStack {
                                    Text("\(usageVM.minutesLeftText) \(NSLocalizedString("settings.remaining", comment: "remaining"))")
                                        .font(.caption)
                                        .foregroundColor(usageVM.isOverLimit ? .red : .secondary)

                                    Spacer()

                                    Button {
                                        Task { await usageVM.refresh() }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }

                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .onAppear {
                        Task { await usageVM.refresh() }
                    }
                }

                // Buy More Minutes Section (only show when 15 minutes or less remaining)
                if usageVM.minutesLeftDisplay <= 15 {
                    Section(header: Text("Need More Minutes?")) {
                        Button {
                            Task {
                                do {
                                    try await TopUpManager.shared.purchase3Hours()
                                    // Show success toast
                                    let duration = formatDuration(TopUpManager.shared.secondsGranted)
                                    showToast(message: "\(duration) added — happy recording!")
                                } catch {
                                    print("❌ Failed to purchase: \(error)")
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.badge.plus.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(TopUpManager.shared.displayName)
                                        .font(.poppins.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)

                                    Text(TopUpManager.shared.displayDescription)
                                        .font(.poppins.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }

                                Spacer()

                                if TopUpManager.shared.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(TopUpManager.shared.displayPrice)
                                        .font(.poppins.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(20)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)
                        }
                        .disabled(TopUpManager.shared.isLoading)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                // Local Transcription Navigation Link
                Section {
                    NavigationLink(destination: LocalTranscriptionSettingsView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.badge.mic")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Local Transcription")
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)

                                Text("On-device AI transcription with Whisper")
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Advanced Settings Navigation Link
                Section {
                    NavigationLink(destination: AdvancedSettingsView(showingAlternativeView: $showingAlternativeView, recordingsManager: recordingsManager)) {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.purple)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("settings.advanced_settings", comment: "Advanced Settings"))
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)

                                Text(NSLocalizedString("settings.advanced_settings_desc", comment: "AI provider, summaries, and interface"))
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text(NSLocalizedString("settings.language", comment: "Language"))) {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(NSLocalizedString("settings.app_language", comment: "App Language"))
                                    .font(.poppins.headline)
                                    .foregroundColor(.primary)

                                Text(currentLanguageDisplayName())
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.forward.app")
                                .font(.poppins.regular(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Text(NSLocalizedString("settings.language_change_note", comment: "Language change note"))
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                Section(header: Text(NSLocalizedString("settings.getting_started", comment: "Getting Started"))) {
                    Button(action: { showingTour = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("settings.take_tour", comment: "Take the Tour"))
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)

                                Text(NSLocalizedString("settings.learn_features", comment: "Learn about features"))
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
                
                // Help & Support Navigation Link
                Section {
                    NavigationLink(destination: HelpSupportView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "questionmark.circle")
                                .font(.poppins.regular(size: 20))
                                .foregroundColor(.green)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("settings.help_support", comment: "Help & Support"))
                                    .font(.poppins.body)
                                    .foregroundColor(.primary)

                                Text(NSLocalizedString("settings.help_support_desc", comment: "Feedback, privacy, and analytics"))
                                    .font(.poppins.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text(NSLocalizedString("settings.info", comment: "Info"))) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsInfoRow(
                            icon: "brain.head.profile",
                            title: NSLocalizedString("settings.ai_summary", comment: "AI Summary"),
                            description: NSLocalizedString("settings.ai_summary_desc", comment: "AI Summary description")
                        )

                        SettingsInfoRow(
                            icon: "waveform",
                            title: NSLocalizedString("settings.transcription", comment: "Transcription"),
                            description: NSLocalizedString("settings.transcription_desc", comment: "Transcription description")
                        )

                        SettingsInfoRow(
                            icon: "person.2.fill",
                            title: NSLocalizedString("settings.language_recognition", comment: "Language Recognition"),
                            description: NSLocalizedString("settings.language_recognition_desc", comment: "Language Recognition description")
                        )

                        SettingsInfoRow(
                            icon: "doc.text.fill",
                            title: NSLocalizedString("settings.smart_lists", comment: "Smart Lists"),
                            description: NSLocalizedString("settings.smart_lists_desc", comment: "Smart Lists description")
                        )
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.5) {
                        // Instant haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()

                        // Show PIN sheet immediately
                        showPinSheet = true
                    }
                }
        }
        .navigationTitle(NSLocalizedString("settings.title", comment: "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingTour) {
            AppTourView(onComplete: {
                showingTour = false
            })
        }
        .sheet(isPresented: $showPinSheet) {
            if analyticsPIN.isEmpty {
                // Create new PIN
                ModernPINEntryView(
                    mode: .create,
                    existingPIN: "",
                    onSuccess: { newPIN in
                        analyticsPIN = newPIN
                        showPinSheet = false
                        showAnalytics = true
                    },
                    onCancel: {
                        showPinSheet = false
                    }
                )
            } else {
                // Verify existing PIN
                ModernPINEntryView(
                    mode: .verify,
                    existingPIN: analyticsPIN,
                    onSuccess: { _ in
                        showPinSheet = false
                        showAnalytics = true
                    },
                    onCancel: {
                        showPinSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAnalytics) {
            DebugSettingsView(recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(canDismiss: true)
        }
        .overlay(alignment: .bottom) {
            if showingToast {
                Text(toastMessage)
                    .font(.poppins.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingToast)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

// MARK: - SettingsView Extension

extension SettingsView {
    private func showToast(message: String) {
        toastMessage = message
        showingToast = true

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showingToast = false
        }

        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) min"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    private func currentLanguageDisplayName() -> String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let locale = Locale(identifier: preferredLanguage)
        let languageCode = locale.language.languageCode?.identifier ?? "en"

        // Get localized display name
        let displayLocale = Locale.current
        if let displayName = displayLocale.localizedString(forLanguageCode: languageCode) {
            return displayName.capitalized
        }

        return languageCode.uppercased()
    }
}

#Preview {
    SettingsView(showingAlternativeView: .constant(false), recordingsManager: RecordingsManager.shared)
}
