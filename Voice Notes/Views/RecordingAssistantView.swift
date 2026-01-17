import SwiftUI
import AVFoundation
import UIKit

// MARK: - Recording Assistant View (Unified Detail + AI Chat)

struct RecordingAssistantView: View {
    let recordingId: UUID
    @ObservedObject var recordingsManager: RecordingsManager
    
    @StateObject private var conversationService = ConversationService.shared
    @State private var customPromptText = ""
    @State private var showingTranscript = false
    @State private var showingDeleteAlert = false
    @State private var cancelToken = CancellationToken()
    @State private var errorMessage: String?
    @State private var processingProgress: Double = 0
    @Environment(\.dismiss) private var dismiss
    
    // Per-message share sheet
    @State private var shareMessagePayload: SharePayload?
    private struct SharePayload: Identifiable {
        let id = UUID()
        let text: String
    }
    
    // Title editing
    @State private var showingTitleEditor = false
    @State private var editedTitle = ""
    
    private var recording: Recording? {
        recordingsManager.recordings.first(where: { $0.id == recordingId })
    }
    
    private var conversation: RecordingConversation {
        conversationService.getConversation(for: recordingId)
    }
    
    private var isProcessing: Bool {
        conversationService.isProcessing[recordingId] ?? false
    }
    
    private var hasTranscript: Bool {
        guard let recording else { return false }
        return (recording.transcript?.isEmpty == false)
    }
    
    private var transcriptionModelLabel: String? {
        guard let recording, (recording.transcript?.isEmpty == false) else { return nil }
        if let model = recording.transcriptionModel, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return model
        }
        return "Transcription model: unknown"
    }
    
    private var summaryLooksLocalFallback: Bool {
        guard let s = recording?.summary else { return false }
        return s.contains("Local Summary")
            || s.contains("Local Extract")
            || s.contains("simplified local extract")
            || s.contains("Summary (Local Extract)")
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            Group {
                if let recording = recording {
                    VStack(spacing: 0) {
                        // Top bar
                        topBar
                        
                        // Scrollable content
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 24) {
                                    // Recording info card
                                    recordingInfoCard(recording)
                                    
                                    // AI Chat area
                                    aiChatArea(recording)
                                        .id("chat-bottom")
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 160) // Space for bottom bar
                            }
                            .onChange(of: conversation.messages.count) { _ in
                                withAnimation {
                                    proxy.scrollTo("chat-bottom", anchor: .bottom)
                                }
                            }
                        }
                        
                        // Sticky bottom bar
                        bottomBar(recording)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Recording not found")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                        Button("Close") { dismiss() }
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptSheet(
                recordingId: recordingId,
                recordingsManager: recordingsManager
            )
        }
        .sheet(item: $shareMessagePayload) { payload in
            ShareSheet(items: [payload.text])
        }
        .alert("Delete Recording?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let recording = recording {
                    recordingsManager.deleteRecording(recording)
                }
                dismiss()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Retry transcription (top-right) — always visible if we have a recording
            if let r = recording {
                Button {
                    recordingsManager.retryTranscription(for: r)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled({
                    if case .transcribing = r.status { return true }
                    return false
                }())
                .opacity({
                    if case .transcribing = r.status { return 0.5 }
                    return 1.0
                }())
                .accessibilityLabel("Retry transcription")
            }
            
            if conversation.hasMessages {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        conversationService.clearConversation(for: recordingId)
                    }
                }) {
                    Text("New chat")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Recording Info Card
    
    private func recordingInfoCard(_ recording: Recording) -> some View {
        VStack(spacing: 12) {
            // Title
            HStack(spacing: 10) {
                Text(recording.title.isEmpty ? "Recording" : recording.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button {
                    editedTitle = recording.title.isEmpty ? "" : recording.title
                    showingTitleEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit title")
            }
            
            // Info row
            HStack(spacing: 16) {
                // Date
                Label {
                    Text(recording.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14, weight: .regular))
                } icon: {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                
                // Duration
                Label {
                    Text(formatDuration(recording.duration))
                        .font(.system(size: 14, weight: .regular))
                } icon: {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                // Status badge
                if hasTranscript {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Ready")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.green)
                } else {
                    statusBadge(recording)
                }
            }
            
            // Model + retry controls (these were missing in this screen before)
            VStack(alignment: .leading, spacing: 8) {
                if let model = transcriptionModelLabel {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 12))
                        Text(model)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                
                // Show summary health + retry when it's a local fallback or missing
                if hasTranscript {
                    if summaryLooksLocalFallback || (recording.summary?.isEmpty != false) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text("Summary is local fallback — retry to generate AI summary")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                            Spacer()
                            Button("Retry") {
                                recordingsManager.retrySummarization(for: recording)
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }
                
                // Retry transcription when transcript is missing / failed / stuck
                if !hasTranscript {
                    switch recording.status {
                    case .transcribing:
                        EmptyView()
                    default:
                        Button {
                            recordingsManager.retryTranscription(for: recording)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry transcription")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .sheet(isPresented: $showingTitleEditor) {
            NavigationView {
                Form {
                    Section(header: Text("Title")) {
                        TextField("Enter a title", text: $editedTitle)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                    }
                    Section(footer: Text("Tip: keep it short so it looks good in the recordings list.")) {
                        EmptyView()
                    }
                }
                .navigationTitle("Edit Title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingTitleEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            recordingsManager.updateRecording(recordingId, title: trimmed)
                            showingTitleEditor = false
                        }
                        .disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
    
    private func statusBadge(_ recording: Recording) -> some View {
        Group {
            switch recording.status {
            case .transcribing(let progress):
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transcribing... \(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .medium))
                        if progress >= 0.5 && progress < 0.9 {
                            Text("Processing audio with AI")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .foregroundColor(.blue)
            case .summarizing(let progress):
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Processing \(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.purple)
            case .failed(let reason):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(reason)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.red)
            default:
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("Pending")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.orange)
            }
        }
    }
    
    // MARK: - AI Chat Area
    
    private func aiChatArea(_ recording: Recording) -> some View {
        VStack(spacing: 24) {
            if conversation.messages.isEmpty {
                // Initial state - show AI visual and prompts
                initialAIState(recording: recording, hasTranscript: hasTranscript)
            } else {
                // Conversation view
                conversationMessages
                
                // Processing indicator
                if isProcessing {
                    thinkingIndicator
                }
                
                // Follow-up prompts
                if !isProcessing {
                    followUpPrompts(recording)
                }
            }
            
            // Error message
            if let error = errorMessage {
                errorBanner(error)
            }
            
            // Custom input field (always visible when transcript ready)
            if hasTranscript && !isProcessing {
                customInputField(recording)
            }
        }
    }
    
    // MARK: - Initial AI State
    
    private func initialAIState(recording: Recording, hasTranscript: Bool) -> some View {
        VStack(spacing: 28) {
            // AI Visual
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.15),
                                Color.purple.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 25,
                            endRadius: 65
                        )
                    )
                    .frame(width: 130, height: 130)
                
                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.top, 20)
            
            // Question
            VStack(spacing: 8) {
                Text("How can I help you?")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                
                if hasTranscript {
                    Text("Your transcript is ready to analyze")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                } else {
                    Text("Transcript will be ready soon...")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            // Prompt chips
            if hasTranscript {
                VStack(spacing: 12) {
                    Text("Choose an option:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    FlowLayout(spacing: 10) {
                        ForEach(initialPrompts, id: \.self) { prompt in
                            PromptChip(prompt: prompt) {
                                selectPrompt(prompt, recording: recording)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Conversation Messages
    
    private var conversationMessages: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(conversation.messages) { message in
                chatBubble(for: message)
            }
        }
    }
    
    private func chatBubble(for message: ConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.role == .user {
                // User message - shows selected prompt
                HStack(spacing: 8) {
                    if let prompt = message.prompt {
                        Image(systemName: prompt.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    
                    Text(message.content)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                // AI response
                VStack(alignment: .leading, spacing: 12) {
                    // AI label
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("AI Assistant")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.purple)
                    
                    // Response text
                    MarkdownBlockText(message.content)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                    
                    // Copy / Share actions
                    HStack(spacing: 16) {
                        Button {
                            UIPasteboard.general.string = message.content
                            let haptic = UINotificationFeedbackGenerator()
                            haptic.notificationOccurred(.success)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.purple.opacity(0.85))
                        
                        Button {
                            shareMessagePayload = SharePayload(text: message.content)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.purple.opacity(0.85))
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.purple.opacity(0.05))
                )
            }
        }
    }
    
    // MARK: - Thinking Indicator
    
    private var thinkingIndicator: some View {
        HStack(spacing: 12) {
            // Animated sparkle
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Thinking...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                // Animated dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.purple.opacity(0.5))
                            .frame(width: 5, height: 5)
                            .scaleEffect(isProcessing ? 1.0 : 0.5)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever()
                                    .delay(Double(index) * 0.15),
                                value: isProcessing
                            )
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.purple.opacity(0.05))
        )
    }
    
    // MARK: - Follow-up Prompts
    
    private func followUpPrompts(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What else?")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 10) {
                ForEach(followUpPromptsArray, id: \.self) { prompt in
                    PromptChip(prompt: prompt) {
                        selectPrompt(prompt, recording: recording)
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Input Field
    
    private func customInputField(_ recording: Recording) -> some View {
        HStack(spacing: 12) {
            TextField("Ask something else...", text: $customPromptText, axis: .vertical)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1...4)
            
            if !customPromptText.isEmpty {
                Button(action: {
                    let text = customPromptText
                    customPromptText = ""
                    selectPrompt(.custom, recording: recording, customText: text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: customPromptText.isEmpty)
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Dismiss") {
                errorMessage = nil
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.orange)
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        // This overload is kept for preview compatibility (if any).
        // The real bar is `bottomBar(_ recording:)`.
        EmptyView()
    }
    
    private func bottomBar(_ recording: Recording) -> some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // View Transcript button
                Button(action: { showingTranscript = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16))
                        Text("View transcript")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(hasTranscript ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(hasTranscript ? 0.1 : 0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!hasTranscript)
                
                Menu {
                    if hasTranscript {
                        Button("Retry summary") {
                            recordingsManager.retrySummarization(for: recording)
                        }
                    }
                    Button("Retry transcription") {
                        recordingsManager.retryTranscription(for: recording)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .frame(width: 48, height: 48)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Actions
    
    private func selectPrompt(_ prompt: PromptTemplate, recording: Recording, customText: String? = nil) {
        guard let transcript = recording.transcript, !transcript.isEmpty else {
            errorMessage = "Transcript not ready yet"
            return
        }
        
        errorMessage = nil
        cancelToken = CancellationToken()
        
        Task {
            do {
                print("🚀 RecordingAssistantView: Processing \(prompt.displayName)")
                let _ = try await conversationService.processPrompt(
                    recordingId: recording.id,
                    transcript: transcript,
                    prompt: prompt,
                    customPromptText: customText,
                    progress: { progress in
                        Task { @MainActor in
                            processingProgress = progress
                        }
                    },
                    cancelToken: cancelToken
                )
                print("✅ RecordingAssistantView: Done!")
            } catch {
                print("❌ RecordingAssistantView: Error - \(error)")
                handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        if let summaryError = error as? SummarizationError {
            switch summaryError {
            case .apiKeyMissing:
                errorMessage = "API key missing. Add it in Settings."
            case .quotaExceeded:
                errorMessage = "API quota exceeded. Try again later."
            case .textTooLong:
                errorMessage = "Transcript too long."
            case .networkError(let e):
                errorMessage = "Network error: \(e.localizedDescription)"
            case .invalidResponse:
                errorMessage = "Invalid response. Try again."
            case .emptyText:
                errorMessage = "No text to analyze."
            case .cancelled:
                break
            }
        } else {
            errorMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helpers
    
    private var initialPrompts: [PromptTemplate] {
        [.makeNotes, .summarizeKeyPoints, .extractActionItems, .makeMinutes]
    }
    
    private var followUpPromptsArray: [PromptTemplate] {
        [.moreDetails, .simplify, .elaborate]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Transcript Sheet

struct TranscriptSheet: View {
    let recordingId: UUID
    @ObservedObject var recordingsManager: RecordingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var isSharePresented = false
    @State private var isEditing = false
    @State private var editedTranscript = ""
    @State private var regenerateSummaryAfterSave = true
    
    private var recording: Recording? {
        recordingsManager.recordings.first(where: { $0.id == recordingId })
    }
    
    private var transcriptText: String {
        recording?.transcript ?? ""
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isEditing {
                    VStack(spacing: 12) {
                        Toggle("Regenerate summary after saving", isOn: $regenerateSummaryAfterSave)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        
                        TextEditor(text: $editedTranscript)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                } else {
                    ScrollView {
                        MarkdownText(transcriptText)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                            .padding(20)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Cancel" : "Done") {
                        if isEditing {
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveEdits()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .disabled(editedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        HStack(spacing: 16) {
                            Button(action: startEditing) {
                                Image(systemName: "pencil")
                            }
                            .disabled(transcriptText.isEmpty)
                            
                            Button(action: { isSharePresented = true }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isSharePresented) {
                ShareSheet(items: [transcriptText])
            }
            .onAppear {
                // Default: only auto-regenerate if there is already a summary
                regenerateSummaryAfterSave = (recording?.summary?.isEmpty == false)
            }
        }
    }
    
    private func startEditing() {
        editedTranscript = transcriptText
        isEditing = true
    }
    
    private func saveEdits() {
        let trimmed = editedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        recordingsManager.updateRecording(recordingId, transcript: editedTranscript)
        isEditing = false
        
        if regenerateSummaryAfterSave, let updated = recordingsManager.recordings.first(where: { $0.id == recordingId }) {
            recordingsManager.retrySummarization(for: updated)
        }
    }
}

// MARK: - Markdown Text Helper
struct MarkdownText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(attributedText)
    }
    
    var attributedText: AttributedString {
        // Try iOS 15+ markdown parsing
        if let attributed = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )) {
            return attributed
        }
        
        // Fallback: manual **bold** parsing
        return parseInlineBold(text)
    }
    
    private func parseInlineBold(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]
        
        while let boldStart = remaining.range(of: "**") {
            let beforeBold = String(remaining[..<boldStart.lowerBound])
            if !beforeBold.isEmpty {
                result.append(AttributedString(beforeBold))
            }
            
            let afterStart = remaining[boldStart.upperBound...]
            if let boldEnd = afterStart.range(of: "**") {
                let boldText = String(afterStart[..<boldEnd.lowerBound])
                var boldAttr = AttributedString(boldText)
                boldAttr.font = .body.bold()
                result.append(boldAttr)
                remaining = afterStart[boldEnd.upperBound...]
            } else {
                result.append(AttributedString("**"))
                remaining = afterStart
            }
        }
        
        if !remaining.isEmpty {
            result.append(AttributedString(String(remaining)))
        }
        
        return result
    }
}

// MARK: - Markdown Block Text Helper (Chat)
/// Renders full Markdown (headings, lists, bold, etc). Used for AI chat messages.
struct MarkdownBlockText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(attributedText)
    }
    
    private var attributedText: AttributedString {
        // Full markdown parsing (supports headings, lists, etc.)
        if let attributed = try? AttributedString(markdown: normalizedText) {
            return attributed
        }
        
        // Fallback: manual **bold** parsing (same as MarkdownText)
        return MarkdownText(normalizedText).attributedText
    }
    
    /// Normalize line breaks so single newlines become true paragraph breaks.
    /// Many LLM responses use single newlines between sections; Markdown collapses those to spaces.
    private var normalizedText: String {
        if text.contains("\n\n") {
            return text
        }
        return text.replacingOccurrences(of: "\n", with: "\n\n")
    }
}
