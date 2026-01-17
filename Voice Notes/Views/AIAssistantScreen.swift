import SwiftUI

// MARK: - AI Assistant Screen (Redesigned)

struct AIAssistantScreen: View {
    let recordingId: UUID
    let transcript: String
    
    @StateObject private var conversationService = ConversationService.shared
    @State private var customPromptText = ""
    @State private var showingTranscript = false
    @State private var cancelToken = CancellationToken()
    @State private var errorMessage: String?
    @State private var showingError = false
    @Environment(\.dismiss) private var dismiss
    
    private var conversation: RecordingConversation {
        conversationService.getConversation(for: recordingId)
    }
    
    private var isProcessing: Bool {
        conversationService.isProcessing[recordingId] ?? false
    }
    
    private var currentState: AssistantState {
        if conversation.messages.isEmpty {
            return .idle
        } else if isProcessing {
            return .thinking
        } else {
            return .conversation
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar (minimal)
                topBar
                
                // Main content (scrollable)
                ScrollView {
                    VStack(spacing: 0) {
                        switch currentState {
                        case .idle:
                            idleStateContent
                                .padding(.top, 40)
                        case .thinking:
                            conversationView
                            thinkingState
                        case .conversation:
                            conversationView
                            followUpPromptsOnly
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 180) // Space for sticky input
                }
                
                // Sticky bottom section
                VStack(spacing: 0) {
                    Divider()
                        .opacity(0.2)
                    
                    stickyTextInput
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial)
                    
                    // Bottom bar (transcript link)
                    bottomBarCompact
                }
            }
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(transcript: transcript)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            verifyAPIKeyAvailability()
        }
    }
    
    private func verifyAPIKeyAvailability() {
        print("🔑 AIAssistantScreen: Verifying API key availability...")
        
        // Check KeyStore first
        if let storedKey = try? KeyStore.shared.retrieve(for: .openai) {
            print("✅ API key found in KeyStore: \(storedKey.prefix(10))...")
            return
        }
        
        // Check Info.plist
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String {
            if plistKey.hasPrefix("sk-") {
                print("✅ API key found in Info.plist: \(plistKey.prefix(10))...")
            } else {
                print("⚠️ API key in Info.plist appears to be a placeholder: \(plistKey)")
            }
        } else {
            print("❌ No API key found in Info.plist")
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            if conversation.hasMessages {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        conversationService.clearConversation(for: recordingId)
                    }
                }) {
                    Text("New")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Idle State Content (without text field)
    
    private var idleStateContent: some View {
        VStack(spacing: 32) {
            // AI Visual (animated)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.blue.opacity(0.15),
                                Color.purple.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Central question + context
            VStack(spacing: 12) {
                Text("What would you like me to do with this recording?")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                
                // Context line
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                    
                    Text(transcriptContext)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            // Prompt chips (compact flow)
            VStack(spacing: 16) {
                Text("Want me to…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Flow layout with chips
                FlowLayout(spacing: 10) {
                    ForEach(initialPrompts, id: \.self) { prompt in
                        PromptChip(prompt: prompt) {
                            selectPrompt(prompt)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var transcriptContext: String {
        let duration = "1 minute"
        return "Transcript ready · \(duration) · Dutch ✓"
    }
    
    // MARK: - Thinking State
    
    private var thinkingState: some View {
        HStack(spacing: 12) {
            // Animated sparkle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Thinking…")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                // Subtle progress dots
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue.opacity(0.5))
                            .frame(width: 4, height: 4)
                            .scaleEffect(isProcessing ? 1.0 : 0.5)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: isProcessing
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.06))
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Conversation View
    
    private var conversationView: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(conversation.messages) { message in
                MessageView(message: message)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }
        }
        .padding(.top, 32)
    }
    
    // MARK: - Follow-Up Prompts Only
    
    private var followUpPromptsOnly: some View {
        VStack(spacing: 16) {
            Text("Want me to…")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            FlowLayout(spacing: 10) {
                ForEach(followUpPrompts, id: \.self) { prompt in
                    PromptChip(prompt: prompt) {
                        selectPrompt(prompt)
                    }
                }
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Sticky Text Input
    
    private var stickyTextInput: some View {
        HStack(spacing: 12) {
            TextField("What would you like to know?", text: $customPromptText, axis: .vertical)
                .font(.system(size: 16, weight: .regular))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .lineLimit(1...3)
                .disabled(isProcessing)
            
            if !customPromptText.isEmpty {
                Button(action: {
                    let text = customPromptText
                    customPromptText = ""
                    selectPrompt(.custom, customText: text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: customPromptText.isEmpty)
    }
    
    // MARK: - Bottom Bar Compact
    
    private var bottomBarCompact: some View {
        Button(action: { showingTranscript = true }) {
            Text("View transcript")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.vertical, 12)
        }
    }
    
    // MARK: - Actions
    
    private func selectPrompt(_ prompt: PromptTemplate, customText: String? = nil) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // State will automatically update through conversation
        }
        
        cancelToken = CancellationToken()
        
        Task {
            do {
                print("🚀 AIAssistantScreen: Starting prompt processing for \(prompt.displayName)")
                let result = try await conversationService.processPrompt(
                    recordingId: recordingId,
                    transcript: transcript,
                    prompt: prompt,
                    customPromptText: customText,
                    progress: { progress in
                        print("📊 AIAssistantScreen: Progress: \(Int(progress * 100))%")
                    },
                    cancelToken: cancelToken
                )
                print("✅ AIAssistantScreen: Prompt processing completed successfully")
                print("📝 Result preview: \(result.prefix(100))...")
            } catch {
                print("❌ AIAssistantScreen: Error processing prompt: \(error)")
                await MainActor.run {
                    if let summaryError = error as? SummarizationError {
                        switch summaryError {
                        case .apiKeyMissing:
                            errorMessage = "OpenAI API key is missing or invalid. Please add your API key in Settings."
                        case .quotaExceeded:
                            errorMessage = "OpenAI API quota exceeded. Please check your account or wait a moment before trying again."
                        case .textTooLong:
                            errorMessage = "The transcript is too long to process. Try a shorter recording."
                        case .networkError(let underlyingError):
                            errorMessage = "Network error: \(underlyingError.localizedDescription)"
                        case .invalidResponse:
                            errorMessage = "Invalid response from AI service. Please try again."
                        case .emptyText:
                            errorMessage = "No transcript text to analyze. Please try again."
                        case .cancelled:
                            return // Don't show error for user cancellation
                        }
                    } else {
                        errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    }
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var initialPrompts: [PromptTemplate] {
        [
            .makeNotes,
            .summarizeKeyPoints,
            .extractActionItems,
            .makeMinutes
        ]
    }
    
    private var followUpPrompts: [PromptTemplate] {
        [
            .simplify,
            .moreDetails,
            .elaborate
        ]
    }
}

// MARK: - Assistant State

enum AssistantState {
    case idle
    case thinking
    case conversation
}

// MARK: - Message View

struct MessageView: View {
    let message: ConversationMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if message.role == .user {
                // User message (compact)
                HStack(spacing: 8) {
                    if let prompt = message.prompt {
                        Image(systemName: prompt.icon)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(message.content)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
            } else {
                // AI response (document-like)
                VStack(alignment: .leading, spacing: 20) {
                    Text(message.content)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Transcript View

struct TranscriptView: View {
    let transcript: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                MarkdownText(transcript)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(24)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

