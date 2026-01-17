import Foundation

@MainActor
class ConversationService: ObservableObject {
    static let shared = ConversationService()
    
    @Published var conversations: [UUID: RecordingConversation] = [:]
    @Published var isProcessing: [UUID: Bool] = [:]
    
    private let conversationsKey = "RecordingConversations"
    
    private init() {
        loadConversations()
    }
    
    // MARK: - Conversation Management
    
    func getConversation(for recordingId: UUID) -> RecordingConversation {
        if let existing = conversations[recordingId] {
            return existing
        }
        
        let new = RecordingConversation(recordingId: recordingId)
        conversations[recordingId] = new
        return new
    }
    
    func clearConversation(for recordingId: UUID) {
        conversations[recordingId] = RecordingConversation(recordingId: recordingId)
        saveConversations()
    }
    
    // MARK: - Process Prompt
    
    func processPrompt(
        recordingId: UUID,
        transcript: String,
        prompt: PromptTemplate,
        customPromptText: String? = nil,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        
        isProcessing[recordingId] = true
        defer { isProcessing[recordingId] = false }
        
        // Build conversation context
        var conversation = getConversation(for: recordingId)
        
        // Create user message
        let userMessage = ConversationMessage(
            role: .user,
            content: customPromptText ?? prompt.displayName,
            prompt: prompt
        )
        
        conversation.addMessage(userMessage)
        conversations[recordingId] = conversation
        
        // Build prompt with context
        let fullPrompt = buildPrompt(
            transcript: transcript,
            prompt: prompt,
            customText: customPromptText,
            conversationHistory: conversation.messages
        )
        
        print("📝 ConversationService: Processing prompt - \(prompt.displayName)")
        print("📝 Transcript length: \(transcript.count) characters")
        print("📝 Full prompt length: \(fullPrompt.count) characters")
        
        // Use the summarization service with custom prompt
        do {
            let result = try await processWithSummaryService(
                transcript: transcript,
                systemPrompt: fullPrompt,
                progress: progress,
                cancelToken: cancelToken
            )
            
            // Add assistant response to conversation
            let assistantMessage = ConversationMessage(
                role: .assistant,
                content: result
            )
            
            conversation.addMessage(assistantMessage)
            conversations[recordingId] = conversation
            saveConversations()
            
            print("📝 ConversationService: ✅ Prompt processed successfully")
            print("📝 Response length: \(result.count) characters")
            
            return result
        } catch {
            print("❌ ConversationService: Error in processWithSummaryService: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildPrompt(
        transcript: String,
        prompt: PromptTemplate,
        customText: String?,
        conversationHistory: [ConversationMessage]
    ) -> String {
        
        var promptBuilder = ""
        
        // For custom prompts, use EXACTLY what the user typed
        if prompt == .custom, let custom = customText {
            promptBuilder = "User request: \(custom)"
        } else {
            // Use the predefined template
            promptBuilder = prompt.systemPrompt
        }
        
        // Add conversation context for follow-up prompts OR custom prompts after initial response
        if conversationHistory.count > 1 {
            promptBuilder += "\n\n--- Previous conversation ---\n"
            
            // Include last assistant response for context
            let recentMessages = conversationHistory.suffix(4)
            for message in recentMessages.dropLast() { // Don't include the current user message
                if message.role == .assistant {
                    // Truncate long responses for context
                    let truncated = message.content.count > 500 
                        ? String(message.content.prefix(500)) + "..." 
                        : message.content
                    promptBuilder += "\nPrevious AI response:\n\(truncated)\n"
                } else if message.role == .user {
                    promptBuilder += "\nUser asked: \(message.content)\n"
                }
            }
            
            promptBuilder += "\n--- End of context ---\n"
        }
        
        return promptBuilder
    }
    
    private func processWithSummaryService(
        transcript: String,
        systemPrompt: String,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        
        // DIRECT OpenAI call with custom system prompt
        // This ensures the user's exact request is used
        
        progress(0.1)
        
        // Get API key
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String,
              !apiKey.isEmpty,
              apiKey.hasPrefix("sk-") else {
            throw SummarizationError.apiKeyMissing
        }
        
        progress(0.2)
        
        // Build request
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // 2 minutes
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a helpful AI assistant analyzing voice recordings. 
                    
                    IMPORTANT RULES:
                    - Be CONCISE and COMPACT - no unnecessary words
                    - Use bullet points and short paragraphs
                    - Get straight to the point
                    - Respond in the same language as the transcript
                    - Follow the user's instructions exactly
                    """
                ],
                [
                    "role": "user",
                    "content": "\(systemPrompt)\n\n---\n\nTranscript:\n\(transcript)"
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        progress(0.3)
        
        print("🤖 ConversationService: Sending to OpenAI...")
        print("🤖 System prompt preview: \(systemPrompt.prefix(100))...")
        
        if cancelToken.isCancelled {
            throw SummarizationError.cancelled
        }
        
        // Simulated progress while waiting
        let progressTask = Task {
            var currentProgress = 0.3
            while currentProgress < 0.8 {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 sec
                currentProgress += 0.1
                progress(currentProgress)
            }
        }
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        progressTask.cancel()
        progress(0.9)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummarizationError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let choices = jsonResponse?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw SummarizationError.invalidResponse
            }
            
            progress(1.0)
            print("🤖 ConversationService: ✅ Response received (\(content.count) chars)")
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
            
        case 401:
            throw SummarizationError.apiKeyMissing
        case 429:
            throw SummarizationError.quotaExceeded
        default:
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SummarizationError.networkError(NSError(
                domain: "OpenAI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "API error \(httpResponse.statusCode): \(errorText)"]
            ))
        }
    }
    
    // MARK: - Persistence
    
    private func saveConversations() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(Array(conversations.values)) {
            UserDefaults.standard.set(encoded, forKey: conversationsKey)
        }
    }
    
    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey),
              let decoded = try? JSONDecoder().decode([RecordingConversation].self, from: data) else {
            return
        }
        
        conversations = Dictionary(uniqueKeysWithValues: decoded.map { ($0.recordingId, $0) })
    }
}

// MARK: - Extensions

extension PromptTemplate {
    var isFollowUp: Bool {
        Self.followUpPrompts.contains(self)
    }
    
    var isInitial: Bool {
        Self.initialPrompts.contains(self)
    }
}



