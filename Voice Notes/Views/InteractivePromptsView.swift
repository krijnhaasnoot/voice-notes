import SwiftUI

struct InteractivePromptsView: View {
    let recordingId: UUID
    let transcript: String
    
    @StateObject private var conversationService = ConversationService.shared
    @State private var selectedPrompt: PromptTemplate?
    @State private var customPromptText = ""
    @State private var showingCustomPrompt = false
    @State private var processingProgress: Double = 0.0
    @State private var errorMessage: String?
    @State private var cancelToken = CancellationToken()
    
    private var conversation: RecordingConversation {
        conversationService.getConversation(for: recordingId)
    }
    
    private var isProcessing: Bool {
        conversationService.isProcessing[recordingId] ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("AI Assistant")
                    .font(.poppins.headline)
                
                Spacer()
                
                if conversation.hasMessages {
                    Button(action: {
                        conversationService.clearConversation(for: recordingId)
                    }) {
                        Text("Clear")
                            .font(.poppins.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Conversation messages
            if conversation.hasMessages {
                conversationMessagesView
            } else {
                emptyStateView
            }
            
            // Error message
            if let error = errorMessage {
                errorView(error)
            }
            
            // Processing indicator
            if isProcessing {
                processingView
            }
            
            // Prompt selection
            if !isProcessing {
                if conversation.hasMessages {
                    followUpPromptsView
                } else {
                    initialPromptsView
                }
            }
            
            // Custom prompt input
            if showingCustomPrompt && !isProcessing {
                customPromptView
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.3))
            
            Text("Choose a prompt to get started")
                .font(.poppins.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var conversationMessagesView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .onChange(of: conversation.messages.count) { _ in
                    if let lastMessage = conversation.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 400)
    }
    
    private var initialPromptsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What would you like me to do?")
                .font(.poppins.subheadline)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(PromptTemplate.initialPrompts, id: \.self) { prompt in
                    PromptChip(
                        prompt: prompt,
                        action: { processPrompt(prompt) }
                    )
                }
                
                // Custom prompt button
                PromptChip(
                    prompt: .custom,
                    action: { showingCustomPrompt.toggle() }
                )
            }
        }
    }
    
    private var followUpPromptsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's next?")
                .font(.poppins.subheadline)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(PromptTemplate.followUpPrompts, id: \.self) { prompt in
                    PromptChip(
                        prompt: prompt,
                        action: { processPrompt(prompt) }
                    )
                }
                
                // Custom prompt button
                PromptChip(
                    prompt: .custom,
                    action: { showingCustomPrompt.toggle() }
                )
            }
        }
    }
    
    private var customPromptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter your custom prompt")
                .font(.poppins.caption)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("What would you like to know?", text: $customPromptText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                
                Button(action: {
                    if !customPromptText.isEmpty {
                        processPrompt(.custom, customText: customPromptText)
                        customPromptText = ""
                        showingCustomPrompt = false
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(customPromptText.isEmpty ? .gray : .blue)
                }
                .disabled(customPromptText.isEmpty)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var processingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing...")
                    .font(.poppins.subheadline)
                    .fontWeight(.medium)
                
                if processingProgress > 0 {
                    ProgressView(value: processingProgress)
                        .frame(width: 150)
                }
            }
            
            Spacer()
            
            Button("Cancel") {
                cancelToken = CancellationToken { true }
            }
            .font(.poppins.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(error)
                .font(.poppins.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Dismiss") {
                errorMessage = nil
            }
            .font(.poppins.caption)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func processPrompt(_ prompt: PromptTemplate, customText: String? = nil) {
        errorMessage = nil
        processingProgress = 0.0
        cancelToken = CancellationToken()
        
        Task {
            do {
                print("🚀 InteractivePromptsView: Starting prompt processing for \(prompt.displayName)")
                let _ = try await conversationService.processPrompt(
                    recordingId: recordingId,
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
                
                // Success - conversation is automatically updated
                processingProgress = 1.0
                print("✅ InteractivePromptsView: Prompt processed successfully")
                
            } catch {
                print("❌ InteractivePromptsView: Error processing prompt: \(error)")
                
                // User-friendly error messages
                if let summaryError = error as? SummarizationError {
                    switch summaryError {
                    case .apiKeyMissing:
                        errorMessage = "API key is missing. Please add your OpenAI API key in Settings."
                    case .quotaExceeded:
                        errorMessage = "API quota exceeded. Please try again later."
                    case .textTooLong:
                        errorMessage = "Transcript is too long. Try a shorter recording."
                    case .networkError(let underlyingError):
                        errorMessage = "Network error: \(underlyingError.localizedDescription)"
                    case .invalidResponse:
                        errorMessage = "Invalid response from AI. Please try again."
                    case .emptyText:
                        errorMessage = "No text to analyze."
                    case .cancelled:
                        errorMessage = nil // Don't show error for user cancellation
                    }
                } else {
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Prompt label for user messages
                if message.role == .user, let prompt = message.prompt {
                    HStack(spacing: 4) {
                        Image(systemName: prompt.icon)
                            .font(.caption2)
                        Text(prompt.displayName)
                            .font(.poppins.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Render markdown for assistant messages
                Group {
                    if message.role == .assistant {
                        MarkdownFormattedText(message.content)
                            .font(.poppins.body)
                    } else {
                        Text(message.content)
                            .font(.poppins.body)
                    }
                }
                .padding(12)
                .background(message.role == .user ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.poppins.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Prompt Chip

struct PromptChip: View {
    let prompt: PromptTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(promptColor)
                
                Text(prompt.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(promptColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var promptColor: Color {
        switch prompt {
        case .makeNotes: return .blue
        case .summarizeKeyPoints: return .purple
        case .extractActionItems: return .green
        case .makeMinutes: return .orange
        case .moreDetails: return .blue
        case .simplify: return .indigo
        case .elaborate: return .pink
        default: return .blue
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Markdown Formatted Text

struct MarkdownFormattedText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(text), id: \.id) { element in
                element.view
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                // Empty line - add spacing
                elements.append(MarkdownElement(type: .spacer))
            } else if trimmed.hasPrefix("## ") {
                // H2 heading
                let content = String(trimmed.dropFirst(3))
                elements.append(MarkdownElement(type: .heading2(parseInline(content))))
            } else if trimmed.hasPrefix("# ") {
                // H1 heading
                let content = String(trimmed.dropFirst(2))
                elements.append(MarkdownElement(type: .heading1(parseInline(content))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                // List item
                let content = String(trimmed.dropFirst(2))
                elements.append(MarkdownElement(type: .listItem(parseInline(content))))
            } else {
                // Regular paragraph
                elements.append(MarkdownElement(type: .paragraph(parseInline(trimmed))))
            }
        }
        
        return elements
    }
    
    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]
        
        while let boldStart = remaining.range(of: "**") {
            // Add text before **
            let beforeBold = String(remaining[..<boldStart.lowerBound])
            if !beforeBold.isEmpty {
                result.append(AttributedString(beforeBold))
            }
            
            // Find closing **
            let afterStart = remaining[boldStart.upperBound...]
            if let boldEnd = afterStart.range(of: "**") {
                // Extract bold text
                let boldText = String(afterStart[..<boldEnd.lowerBound])
                var boldAttr = AttributedString(boldText)
                boldAttr.font = .body.bold()
                result.append(boldAttr)
                
                // Move past closing **
                remaining = afterStart[boldEnd.upperBound...]
            } else {
                // No closing **, treat ** as literal
                result.append(AttributedString("**"))
                remaining = afterStart
            }
        }
        
        // Add remaining text
        if !remaining.isEmpty {
            result.append(AttributedString(String(remaining)))
        }
        
        return result
    }
}

struct MarkdownElement: Identifiable {
    let id = UUID()
    let type: ElementType
    
    enum ElementType {
        case heading1(AttributedString)
        case heading2(AttributedString)
        case paragraph(AttributedString)
        case listItem(AttributedString)
        case spacer
    }
    
    @ViewBuilder
    var view: some View {
        switch type {
        case .heading1(let content):
            Text(content)
                .font(.poppins.headline)
                .fontWeight(.bold)
                .padding(.top, 8)
                .padding(.bottom, 4)
        case .heading2(let content):
            Text(content)
                .font(.poppins.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 6)
                .padding(.bottom, 2)
        case .paragraph(let content):
            Text(content)
                .font(.poppins.body)
        case .listItem(let content):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.poppins.body)
                Text(content)
                    .font(.poppins.body)
            }
            .padding(.leading, 8)
        case .spacer:
            Spacer()
                .frame(height: 4)
        }
    }
}



