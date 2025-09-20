import SwiftUI
import Speech
import AVFoundation

struct AlternativeHomeView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var appRouter: AppRouter
    
    @State private var showingPermissionAlert = false
    @State private var permissionGranted = false
    @State private var selectedRecording: Recording?
    @State private var showingSettings = false
    @State private var currentRecordingFileName: String?
    @State private var isPaused = false
    @State private var showingExpandedRecording = false
    @State private var showExpandedControls = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Clean header with minimal controls
                HStack {
                    Spacer()
                    
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
                                toggleRecording()
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
                                    .fill(audioRecorder.isRecording ? 
                                          LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom) : 
                                          LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 90, height: 90)
                                    .overlay {
                                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                            .font(.system(size: 36, weight: .bold))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .scaleEffect(audioRecorder.isRecording ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioRecorder.isRecording)
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
                    
                    // Multi-person conversation indicator
                    if audioRecorder.isRecording, let transcript = getCurrentTranscript(), containsMultipleSpeakers(transcript) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.orange)
                            Text("Multiple speakers detected")
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
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { requestPermissions() }
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Voice Notes needs microphone and speech recognition permissions to function.")
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recordingId: recording.id, recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(showingAlternativeView: .constant(false))
        }
    }
    
    // MARK: - Helper Properties
    
    private var recordingStatusText: String {
        if isPaused {
            return "Recording paused"
        } else if audioRecorder.isRecording {
            return "Recording..."
        } else {
            return "Tap to record"
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
                Text("Expanded Recording")
                    .font(.poppins.title2)
                    .padding(.top, 24)

                Text(audioRecorder.isRecording ? "Recording..." : "Ready to record")
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
                    Button("Close") { isPresented = false }
                        .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            }
            .padding()
            .navigationTitle("")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { isPresented = false } } }
        }
    }
}
    
    private func startRecording() async {
        isPaused = false

        // Generate a filename up front for our own tracking/UI purposes
        let fileName = generateFileName()
        currentRecordingFileName = fileName

        // Start recording using the recorder's API (no trailing completion)
        await audioRecorder.startRecording()
    }
    
    private func stopRecording() {
        isPaused = false
        audioRecorder.stopRecording()

        // Safely capture the file name used for this session
        if let fileName = currentRecordingFileName {
            let recording = Recording(
                fileName: fileName,
                date: Date(),
                duration: audioRecorder.recordingDuration,
                id: UUID()
            )

            recordingsManager.addRecording(recording)
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

#Preview {
    AlternativeHomeView(
        audioRecorder: AudioRecorder(),
        recordingsManager: RecordingsManager()
    )
}
