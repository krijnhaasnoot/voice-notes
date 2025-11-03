import SwiftUI
import Speech
import AVFoundation

struct AlternativeHomeView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var appRouter: AppRouter
    @EnvironmentObject var documentStore: DocumentStore
    @ObservedObject private var usageVM = UsageViewModel.shared
    @AppStorage("hasCompletedTour") private var hasCompletedTour = false
    @AppStorage("debug_modeEnabled") private var debugModeEnabled: Bool = false

    @State private var showingPermissionAlert = false
    @State private var permissionGranted = false
    @State private var selectedRecording: Recording?
    @State private var showingSettings = false
    @State private var showingTopUpPurchase = false
    @State private var showingDebugSettings = false
    @State private var currentRecordingFileName: String?
    @State private var isPaused = false
    @State private var showingExpandedRecording = false
    @State private var showExpandedControls = false
    @State private var sessionRecordingIds: Set<UUID> = []
    @State private var appDidBecomeActive = false
    @State private var showingResetConfirmation = false
    
    // Computed properties for stable UI state
    private var recordingButtonGradient: LinearGradient {
        if audioRecorder.isRecording {
            if isPaused {
                return LinearGradient(colors: [.orange.opacity(0.8), .orange], startPoint: .top, endPoint: .bottom)
            } else {
                return LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom)
            }
        } else {
            return LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private var recordingButtonIcon: String {
        if audioRecorder.isRecording {
            return isPaused ? "play.fill" : "stop.fill"
        } else {
            return "mic.fill"
        }
    }
    
    private var recordingButtonScale: CGFloat {
        if audioRecorder.isRecording && !isPaused {
            return 0.95
        } else {
            return 1.0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Clean header with minimal controls
                HStack {
                    // Hidden reset button (long press top-left corner)
                    Color.clear
                        .frame(width: 60, height: 60)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 3.0) {
                            showingResetConfirmation = true
                        }

                    Spacer()

                    // Debug indicator (tappable)
                    if debugModeEnabled {
                        Button(action: { showingDebugSettings = true }) {
                            Text("Debug")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(.orange.opacity(0.15))
                                        .overlay(
                                            Capsule()
                                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
                
                // Large recording section
                VStack(spacing: 24) {
                    // Status text
                    VStack(spacing: 8) {
                        if let error = audioRecorder.lastError {
                            Text(error)
                                .font(.poppins.body)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text(recordingStatusText)
                                .font(.poppins.title2)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .fontWeight(.medium)
                            
                            if audioRecorder.isRecording {
                                Text(formatDuration(audioRecorder.recordingDuration))
                                    .font(.poppins.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Large record button with pause if recording
                    HStack(spacing: 20) {
                        // Pause button (only visible when recording)
                        if audioRecorder.isRecording {
                            Button(action: togglePause) {
                                ZStack {
                                    Circle()
                                        .fill(.regularMaterial)
                                        .frame(width: 70, height: 70)
                                        .overlay {
                                            Circle()
                                                .stroke(.quaternary, lineWidth: 1)
                                        }
                                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                                    
                                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                        .font(.title)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
                            .applyIf(isLiquidGlassAvailable) { view in
                                view.glassEffect(.regular.interactive())
                            }
                        }
                        
                        // Main record button (larger)
                        Button(action: {
                            if permissionGranted {
                                if audioRecorder.isRecording && isPaused {
                                    // If paused, resume recording
                                    togglePause()
                                } else {
                                    // Normal record/stop behavior
                                    toggleRecording()
                                }
                            } else {
                                requestPermissions()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.regularMaterial)
                                    .frame(width: 120, height: 120)
                                    .overlay {
                                        Circle()
                                            .stroke(.quaternary.opacity(0.8), lineWidth: 2)
                                    }
                                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                                
                                Circle()
                                    .fill(recordingButtonGradient)
                                    .frame(width: 90, height: 90)
                                    .overlay {
                                        Image(systemName: recordingButtonIcon)
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .scaleEffect(recordingButtonScale)
                        .animation(.easeInOut(duration: 0.2), value: recordingButtonScale)
                        .disabled(!audioRecorder.isRecording && (usageVM.isOverLimit || usageVM.isLoading))
                        .opacity(!audioRecorder.isRecording && (usageVM.isOverLimit || usageVM.isLoading) ? 0.5 : 1.0)
                        .accessibilityLabel(audioRecorder.isRecording ? "Stop recording" : "Start recording")
                        .applyIf(isLiquidGlassAvailable) { view in
                            view.glassEffect(.regular.interactive())
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    // swipe up to show expanded controls
                                    if value.translation.height < -30 {
                                        showingExpandedRecording = true
                                    }
                                }
                        )
                        // Show an expanded recording sheet when user swipes up
                        .fullScreenCover(isPresented: $showingExpandedRecording) {
                            ExpandedRecordingSheet(
                                isPresented: $showingExpandedRecording,
                                audioRecorder: audioRecorder,
                                recordingsManager: recordingsManager
                            )
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioRecorder.isRecording)

                    // Out of minutes banner (only show when 15 minutes or less remaining)
                    if !audioRecorder.isRecording && usageVM.minutesLeftDisplay <= 15 && !usageVM.isLoading {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: usageVM.isOverLimit ? "clock.badge.exclamationmark" : "clock")
                                    .foregroundStyle(usageVM.isOverLimit ? .red : .orange)
                                Text(usageVM.isOverLimit ? NSLocalizedString("home.out_of_minutes", comment: "Out of recording minutes") : NSLocalizedString("home.running_low_minutes", comment: "Running low on minutes"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(usageVM.isOverLimit ? .red : .orange)
                            }

                            Button(action: { showingTopUpPurchase = true }) {
                                Text(NSLocalizedString("home.get_more_minutes", comment: "Get More Minutes"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(usageVM.isOverLimit ? Color.red : Color.orange)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background((usageVM.isOverLimit ? Color.red : Color.orange).opacity(0.1))
                        .cornerRadius(12)
                        .padding(.top, 8)
                    }

                    // Usage quota display
                    if !audioRecorder.isRecording && !usageVM.isOverLimit {
                        HStack(spacing: 4) {
                            if usageVM.isLoading {
                                Text(NSLocalizedString("home.checking_quota", comment: "Checking quota…"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if usageVM.isStale && usageVM.limitSeconds == 0 {
                                // Never synced or completely failed
                                HStack(spacing: 4) {
                                    Image(systemName: "wifi.exclamationmark")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text(NSLocalizedString("home.offline_mode", comment: "Offline mode"))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    Button {
                                        Task { await usageVM.refresh() }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            } else {
                                Text(String(format: NSLocalizedString("home.minutes_left", comment: "Minutes left"), usageVM.minutesLeftText))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Sync button
                                Button {
                                    Task { await usageVM.refresh() }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                            }
                        }
                        .padding(.top, 8)
                    }

                    // Multi-person conversation indicator
                    if audioRecorder.isRecording, let transcript = getCurrentTranscript(), containsMultipleSpeakers(transcript) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.orange)
                            Text(NSLocalizedString("home.multiple_speakers", comment: "Multiple speakers detected"))
                                .font(.poppins.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.1))
                        .cornerRadius(12)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Spacer()
                
                // Latest recording from current session (bottom of screen)
                if !audioRecorder.isRecording, let latestSessionRecording = currentSessionLatestRecording {
                    VStack(spacing: 0) {
                        Button(action: {
                            selectedRecording = latestSessionRecording
                        }) {
                            CompactRecordingCard(recording: latestSessionRecording, recordingsManager: recordingsManager)
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Only request permissions if tour has been completed
            if hasCompletedTour {
                requestPermissions()
            }
            appDidBecomeActive = true
            Task {
                await usageVM.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Clear session recordings when app becomes inactive
            sessionRecordingIds.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Reset session tracking when app becomes active
            if !appDidBecomeActive {
                sessionRecordingIds.removeAll()
            }
            appDidBecomeActive = true
        }
        .alert(NSLocalizedString("home.permissions_required", comment: "Permissions Required"), isPresented: $showingPermissionAlert) {
            Button(NSLocalizedString("settings.title", comment: "Settings")) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button(NSLocalizedString("alert.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("home.permissions_message", comment: "Permissions message"))
        }
        .alert(NSLocalizedString("home.reset_app", comment: "Reset App"), isPresented: $showingResetConfirmation) {
            Button(NSLocalizedString("home.reset_everything", comment: "Reset Everything"), role: .destructive) {
                resetApp()
            }
            Button(NSLocalizedString("alert.cancel", comment: "Cancel"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("home.reset_message", comment: "Reset message"))
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recordingId: recording.id, recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(showingAlternativeView: .constant(false), recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $showingTopUpPurchase) {
            TopUpPurchaseSheet()
        }
        .sheet(isPresented: $showingDebugSettings) {
            DebugSettingsView(recordingsManager: recordingsManager)
        }
    }
    
    // MARK: - Helper Properties
    
    private var currentSessionLatestRecording: Recording? {
        return recordingsManager.recordings.first { recording in
            sessionRecordingIds.contains(recording.id)
        }
    }
    
    private var recordingStatusText: String {
        if isPaused {
            return NSLocalizedString("home.recording_paused", comment: "Recording paused")
        } else if audioRecorder.isRecording {
            return NSLocalizedString("home.recording_...", comment: "Recording...")
        } else {
            return NSLocalizedString("home.tap_to_record", comment: "Tap to record")
        }
    }
    
    // MARK: - Helper Functions
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            self.permissionGranted = granted
                            if !granted {
                                self.showingPermissionAlert = true
                            }
                        }
                    }
                default:
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            stopRecording()
        } else {
            // startRecording() is async; call it safely from a Task so callers can remain synchronous
            Task { @MainActor in
                await startRecording()
            }
        }
    }
// MARK: - Expanded recording sheet (shown when user swipes up on the record button)
private struct ExpandedRecordingSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var recordingsManager: RecordingsManager

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(NSLocalizedString("home.expanded_recording", comment: "Expanded Recording"))
                    .font(.poppins.title2)
                    .padding(.top, 24)

                Text(audioRecorder.isRecording ? NSLocalizedString("home.recording_...", comment: "Recording...") : NSLocalizedString("home.ready_to_record", comment: "Ready to record"))
                    .font(.poppins.body)
                    .foregroundColor(.secondary)

                // Big stop/start button (replicates main UI but inside a full sheet)
                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    } else {
                        Task { @MainActor in await audioRecorder.startRecording() }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                            .frame(width: 140, height: 140)
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()
                HStack {
                    Button(NSLocalizedString("home.close", comment: "Close")) { isPresented = false }
                        .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            }
            .padding()
            .navigationTitle("")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(NSLocalizedString("home.close", comment: "Close")) { isPresented = false } } }
        }
    }
}
    
    private func startRecording() async {
        isPaused = false

        // Check backend quota before allowing recording
        await usageVM.refresh()

        // Only block if truly over limit - allow recording if sync failed (graceful degradation)
        if usageVM.isOverLimit && !usageVM.isStale {
            print("⚠️ AlternativeHomeView: Backend quota exceeded, blocking recording")
            return
        }

        // If stale but not confirmed over limit, allow recording (offline-friendly)
        if usageVM.isStale && usageVM.limitSeconds > 0 {
            print("⚠️ AlternativeHomeView: Usage data is stale, but allowing recording (offline mode)")
        }

        // Generate a filename up front for our own tracking/UI purposes
        let fileName = generateFileName()
        currentRecordingFileName = fileName

        // Start recording using the recorder's API (no trailing completion)
        await audioRecorder.startRecording()
    }
    
    private func stopRecording() {
        isPaused = false
        let result = audioRecorder.stopRecording()

        print("🎙️ AlternativeHomeView: Recording stopped. Duration: \(result.duration) seconds")

        // Book usage to backend (which will refresh from server)
        Task {
            await usageVM.book(seconds: Int(ceil(result.duration)), recordedAt: Date())
        }

        // Get the actual filename from the AudioRecorder's file URL
        if let fileURL = result.fileURL {
            let actualFileName = fileURL.lastPathComponent
            
            let recordingId = UUID()
            let recording = Recording(
                fileName: actualFileName,
                date: Date(),
                duration: result.duration,
                id: recordingId
            )

            recordingsManager.addRecording(recording)
            
            // Track this recording as part of current session
            sessionRecordingIds.insert(recordingId)
            
            // Only start transcription if we have a valid file with content
            if let fileSize = result.fileSize, fileSize > 0 {
                print("🎯 AlternativeHomeView: Starting transcription for \(actualFileName) (size: \(fileSize) bytes)")
                recordingsManager.startTranscription(for: recording)
            } else {
                print("🎯 AlternativeHomeView: ❌ NOT starting transcription - fileSize: \(result.fileSize ?? -1)")
            }
        } else {
            print("🎯 AlternativeHomeView: ❌ No file URL returned from AudioRecorder")
        }

        currentRecordingFileName = nil
    }
    
    private func togglePause() {
        if isPaused {
            audioRecorder.resumeRecording()
            isPaused = false
        } else {
            audioRecorder.pauseRecording()
            isPaused = true
        }
    }
    
    private func generateFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "recording_\(formatter.string(from: Date()))"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func resetApp() {
        // Delete all recordings and their files
        let allRecordings = recordingsManager.recordings
        for recording in allRecordings {
            recordingsManager.deleteRecording(recording)
        }

        // Clear all documents
        documentStore.documents.removeAll()

        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        // Reset usage tracking
        Task { @MainActor in
            await usageVM.refresh()
        }

        // Clear all tags
        TagStore.shared.clearAllTags()

        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        print("🔄 App reset completed - all data cleared")
    }


    private func getCurrentTranscript() -> String? {
        // Get the most recent recording's transcript if available
        if let mostRecent = recordingsManager.recordings.first,
           let transcript = mostRecent.transcript, !transcript.isEmpty {
            return transcript
        }
        return nil
    }
    
    private func containsMultipleSpeakers(_ transcript: String) -> Bool {
        // Enhanced heuristic: look for conversation patterns
        let conversationIndicators = [
            "Speaker", "Person", "A:", "B:", "1:", "2:",
            "SPEAKER", "PERSON", "Speaker 1", "Speaker 2", 
            "Participant", "Interviewer", "Interviewee",
            "- ", "• ", "Q:", "A:", "Host:", "Guest:"
        ]
        
        let hasIndicators = conversationIndicators.contains { indicator in
            transcript.contains(indicator)
        }
        
        let hasMultipleLineBreaks = transcript.components(separatedBy: "\n").count > 5
        let hasQuestionMarks = transcript.filter { $0 == "?" }.count > 2
        let hasBackAndForth = transcript.contains("?") && transcript.contains(".")
        
        // Look for dialogue patterns like "Well, I think..." followed by "But you said..."
        let dialoguePatterns = ["Well,", "But", "However", "Actually", "I think", "You said", "What do you", "How about"]
        let hasDialogue = dialoguePatterns.filter { pattern in
            transcript.localizedCaseInsensitiveContains(pattern)
        }.count > 2
        
        return hasIndicators || (hasMultipleLineBreaks && hasQuestionMarks && hasBackAndForth) || hasDialogue
    }
}

// MARK: - Compact Recording Card Component (Bottom of Screen)
struct CompactRecordingCard: View {
    let recording: Recording
    @ObservedObject var recordingsManager: RecordingsManager

    var body: some View {
        HStack(spacing: 12) {
            // Status icon (smaller)
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
            }

            // Recording info
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.poppins.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formattedTime)
                        .font(.poppins.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.poppins.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDuration)
                        .font(.poppins.caption2)
                        .foregroundColor(.secondary)
                    
                    if recording.status.isProcessing {
                        Text("•")
                            .font(.poppins.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(statusText)
                            .font(.poppins.caption2)
                            .foregroundColor(statusColor)
                    }
                }
            }
            
            Spacer()
            
            // Action indicator
            if recording.status.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [statusColor.opacity(0.2), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: statusColor.opacity(0.1), radius: 8, y: 4)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        // 1. Use explicit title if set
        if !recording.title.isEmpty {
            return recording.title
        }
        
        // 2. Extract title from AI summary if available
        if let summary = recording.summary, !summary.isEmpty {
            if let aiTitle = extractTitleFromSummary(summary) {
                return aiTitle
            }
        }
        
        return "Latest Recording"
    }
    
    private func extractTitleFromSummary(_ summary: String) -> String? {
        let lines = summary.components(separatedBy: .newlines)
        
        // Look for common title patterns from AI summaries
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Match patterns like "**Title**", "**Session Title**", "**Topic**"
            if trimmed.hasPrefix("**") && trimmed.contains("**") {
                // Extract text after the first title-like pattern
                if trimmed.contains("Title") || trimmed.contains("Topic") || trimmed.contains("Session") {
                    // Look for the next non-empty line as the actual title content
                    if let titleIndex = lines.firstIndex(of: line) {
                        let nextIndex = titleIndex + 1
                        if nextIndex < lines.count {
                            let titleContent = lines[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                            if !titleContent.isEmpty && !titleContent.hasPrefix("**") {
                                return titleContent.count > 30 ? String(titleContent.prefix(30)) + "..." : titleContent
                            }
                        }
                    }
                }
            }
            
            // Alternative: Look for first non-header line if it starts after a title marker
            if trimmed.hasPrefix("**Title**") || trimmed.hasPrefix("**Session Title**") || trimmed.hasPrefix("**Topic**") {
                // Skip this header line and get the next meaningful content
                if let titleIndex = lines.firstIndex(of: line) {
                    for i in (titleIndex + 1)..<lines.count {
                        let content = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !content.isEmpty && !content.hasPrefix("**") {
                            return content.count > 30 ? String(content.prefix(30)) + "..." : content
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: recording.date)
    }
    
    private var formattedDuration: String {
        let minutes = Int(recording.duration) / 60
        let seconds = Int(recording.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var statusColor: Color {
        switch recording.status {
        case .transcribing:
            return .blue
        case .transcribingPaused:
            return .blue.opacity(0.7)
        case .summarizing:
            return .orange
        case .summarizingPaused:
            return .orange.opacity(0.7)
        case .failed:
            return .red
        case .done:
            return .green
        case .idle:
            return .gray
        }
    }

    private var statusIcon: String {
        switch recording.status {
        case .transcribing:
            return "waveform"
        case .transcribingPaused:
            return "pause.circle.fill"
        case .summarizing:
            return "brain.head.profile"
        case .summarizingPaused:
            return "pause.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        case .done:
            return "checkmark.circle"
        case .idle:
            return "mic"
        }
    }

    private var statusText: String {
        switch recording.status {
        case .transcribing:
            return NSLocalizedString("recording.transcribing", comment: "Transcribing")
        case .transcribingPaused:
            return NSLocalizedString("recording.transcribing_paused", comment: "Transcription Paused")
        case .summarizing:
            // Check if large transcript
            if let transcript = recording.transcript, transcript.count > 50000 {
                let estimatedMinutes = transcript.count / 150
                return String(format: NSLocalizedString("progress.large_transcript_status", comment: "Large transcript status"), estimatedMinutes)
            }
            return NSLocalizedString("recording.summarizing", comment: "Summarizing")
        case .summarizingPaused:
            return NSLocalizedString("recording.summarizing_paused", comment: "Summary Paused")
        case .failed:
            return NSLocalizedString("recording.failed", comment: "Failed")
        case .done:
            return NSLocalizedString("recording.done", comment: "Done")
        case .idle:
            return NSLocalizedString("status.processing", comment: "Processing")
        }
    }
}

// MARK: - Latest Recording Card Component
struct LatestRecordingCard: View {
    let recording: Recording
    @ObservedObject var recordingsManager: RecordingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and status
            HStack(alignment: .top, spacing: 12) {
                // Recording icon with status color
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: statusIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(statusColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.poppins.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(formattedDate)
                            .font(.poppins.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.poppins.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formattedDuration)
                            .font(.poppins.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status indicator or chevron
                if recording.status.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Preview text or status
            VStack(alignment: .leading, spacing: 8) {
                if let preview = previewText, !preview.isEmpty {
                    Text(preview)
                        .font(.poppins.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                    statusDescription
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [statusColor.opacity(0.2), statusColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: statusColor.opacity(0.1), radius: 8, y: 4)
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        // 1. Use explicit title if set
        if !recording.title.isEmpty {
            return recording.title
        }
        
        // 2. Extract title from AI summary if available
        if let summary = recording.summary, !summary.isEmpty {
            if let aiTitle = extractTitleFromSummary(summary) {
                return aiTitle
            }
        }
        
        // 3. Fall back to formatted filename
        let base = recording.fileName
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "Recent Recording" : base
    }
    
    private func extractTitleFromSummary(_ summary: String) -> String? {
        let lines = summary.components(separatedBy: .newlines)
        
        // Look for common title patterns from AI summaries
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Match patterns like "**Title**", "**Session Title**", "**Topic**"
            if trimmed.hasPrefix("**") && trimmed.contains("**") {
                // Extract text after the first title-like pattern
                if trimmed.contains("Title") || trimmed.contains("Topic") || trimmed.contains("Session") {
                    // Look for the next non-empty line as the actual title content
                    if let titleIndex = lines.firstIndex(of: line) {
                        let nextIndex = titleIndex + 1
                        if nextIndex < lines.count {
                            let titleContent = lines[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                            if !titleContent.isEmpty && !titleContent.hasPrefix("**") {
                                return titleContent.count > 40 ? String(titleContent.prefix(40)) + "..." : titleContent
                            }
                        }
                    }
                }
            }
            
            // Alternative: Look for first non-header line if it starts after a title marker
            if trimmed.hasPrefix("**Title**") || trimmed.hasPrefix("**Session Title**") || trimmed.hasPrefix("**Topic**") {
                // Skip this header line and get the next meaningful content
                if let titleIndex = lines.firstIndex(of: line) {
                    for i in (titleIndex + 1)..<lines.count {
                        let content = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !content.isEmpty && !content.hasPrefix("**") {
                            return content.count > 40 ? String(content.prefix(40)) + "..." : content
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: recording.date)
    }
    
    private var formattedDuration: String {
        let minutes = Int(recording.duration) / 60
        let seconds = Int(recording.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var previewText: String? {
        // Prioritize AI summary content over raw transcript
        if let summary = recording.summary, !summary.isEmpty {
            // Extract preview content from AI summary, skipping title headers
            let summaryPreview = extractPreviewFromSummary(summary)
            if !summaryPreview.isEmpty {
                return summaryPreview
            }
        }
        // Fall back to transcript if no meaningful summary content
        if let transcript = recording.transcript, !transcript.isEmpty {
            return String(transcript.prefix(80)) + (transcript.count > 80 ? "..." : "")
        }
        return nil
    }
    
    private func extractPreviewFromSummary(_ summary: String) -> String {
        let lines = summary.components(separatedBy: .newlines)
        
        // Skip title/header lines and find the first meaningful content
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines, title headers, and section markers
            if trimmed.isEmpty || 
               trimmed.hasPrefix("**") || 
               trimmed.hasPrefix("#") ||
               trimmed.count < 10 {
                continue
            }
            
            // Return first meaningful content line as preview
            return trimmed.count > 80 ? String(trimmed.prefix(80)) + "..." : trimmed
        }
        
        // If no meaningful content found, return first part of summary
        return String(summary.prefix(80)) + (summary.count > 80 ? "..." : "")
    }
    
    private var statusColor: Color {
        switch recording.status {
        case .transcribing:
            return .blue
        case .transcribingPaused:
            return .blue.opacity(0.7)
        case .summarizing:
            return .orange
        case .summarizingPaused:
            return .orange.opacity(0.7)
        case .failed:
            return .red
        case .done:
            return .green
        case .idle:
            return .gray
        }
    }

    private var statusIcon: String {
        switch recording.status {
        case .transcribing:
            return "waveform"
        case .transcribingPaused:
            return "pause.circle.fill"
        case .summarizing:
            return "brain.head.profile"
        case .summarizingPaused:
            return "pause.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        case .done:
            return "checkmark.circle"
        case .idle:
            return "mic"
        }
    }

    @ViewBuilder
    private var statusDescription: some View {
        switch recording.status {
        case .transcribing(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(height: 4)
                Text("Transcribing: \(Int(progress * 100))%")
                    .font(.poppins.caption)
                    .foregroundColor(.blue)

                // Pause button
                Button(action: {
                    recordingsManager.pauseTranscription(for: recording)
                }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        case .transcribingPaused(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(height: 4)
                Text("Paused: \(Int(progress * 100))%")
                    .font(.poppins.caption)
                    .foregroundColor(.orange)

                // Resume button
                Button(action: {
                    recordingsManager.resumeTranscription(for: recording)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        case .summarizing(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(height: 4)
                Text("Creating summary: \(Int(progress * 100))%")
                    .font(.poppins.caption)
                    .foregroundColor(.orange)

                // Pause button
                Button(action: {
                    recordingsManager.pauseSummarization(for: recording)
                }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        case .summarizingPaused(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(height: 4)
                Text("Summary paused: \(Int(progress * 100))%")
                    .font(.poppins.caption)
                    .foregroundColor(.orange.opacity(0.7))

                // Resume button
                Button(action: {
                    recordingsManager.resumeSummarization(for: recording)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        case .failed(let reason):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("Processing failed: \(reason)")
                    .font(.poppins.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        case .done:
            Text("✅ Processing complete - tap to view")
                .font(.poppins.caption)
                .foregroundColor(.green)
        case .idle:
            Text("Waiting to process...")
                .font(.poppins.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Extensions for Liquid Glass Support

private enum LiquidGlassSupport {
    static var isAvailable: Bool {
        if #available(iOS 18.0, *) {
            return true
        } else {
            return false
        }
    }
}

// Keep availability local to this view to avoid cross-file symbol collisions.
extension AlternativeHomeView {
    var isLiquidGlassAvailable: Bool { LiquidGlassSupport.isAvailable }
}

extension View {
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func glassEffect(_ style: Any) -> some View {
        if #available(iOS 18.0, *) {
            // Placeholder for actual Liquid Glass API when available
            self
        } else {
            self
        }
    }
}

// MARK: - Top-Up Purchase Sheet
struct TopUpPurchaseSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var topUpManager = TopUpManager.shared
    @ObservedObject private var usageVM = UsageViewModel.shared
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        // Outer glow circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)

                        // Main circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        // Voice waveform icon
                        Image(systemName: "waveform")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("Need More Minutes?")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Get extra recording time instantly")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 32)

                // Current Usage
                VStack(spacing: 12) {
                    HStack {
                        Text("Current Usage")
                            .font(.headline)
                        Spacer()
                        Text("\(usageVM.minutesUsedDisplay) / \(usageVM.limitSeconds / 60) min")
                            .font(.headline)
                            .foregroundColor(usageVM.isOverLimit ? .red : .primary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(usageVM.isOverLimit ? Color.red : Color.orange)
                                .frame(width: geometry.size.width * min(Double(usageVM.secondsUsed) / Double(max(usageVM.limitSeconds, 1)), 1.0), height: 12)
                        }
                    }
                    .frame(height: 12)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Purchase Button
                Button {
                    Task {
                        do {
                            try await topUpManager.purchase3Hours()
                            let duration = formatDuration(topUpManager.secondsGranted)
                            toastMessage = "\(duration) added — happy recording!"
                            showToast = true

                            // Auto-dismiss after successful purchase
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                dismiss()
                            }
                        } catch {
                            toastMessage = "Purchase failed: \(error.localizedDescription)"
                            showToast = true
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.plus.fill")
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(topUpManager.displayName)
                                .font(.headline)

                            Text(topUpManager.displayDescription)
                                .font(.caption)
                                .opacity(0.8)
                        }

                        Spacer()

                        if topUpManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(topUpManager.displayPrice)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.white)
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
                .disabled(topUpManager.isLoading)

                // Info text
                Text("This is a one-time purchase that adds 3 hours to your current plan. Minutes never expire.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Buy More Minutes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        dismiss()
                        // TODO: Open settings - need to coordinate with parent view
                    }
                    .font(.subheadline)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showToast)
        .onChange(of: showToast) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showToast = false
                }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
            .shadow(radius: 10)
    }
}

#Preview {
    AlternativeHomeView(
        audioRecorder: AudioRecorder.shared,
        recordingsManager: RecordingsManager.shared
    )
    .environmentObject(AppRouter())
}
