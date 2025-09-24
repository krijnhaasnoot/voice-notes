import Foundation

// MARK: - Mistral Summary Provider

class MistralSummaryProvider: SummaryProvider {
    let name = "Mistral AI"
    let requiresApiKey = true
    
    private let urlSession: URLSession
    
    init() {
        // Create custom URLSession with extended timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 600.0
        self.urlSession = URLSession(configuration: config)
    }
    
    func validateApiKey(_ apiKey: String) async throws -> Bool {
        let url = URL(string: "https://api.mistral.ai/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    return true
                case 401:
                    throw APIKeyValidationError.invalidKey
                case 429:
                    throw APIKeyValidationError.quotaExceeded
                default:
                    throw APIKeyValidationError.unknown
                }
            }
            return false
        } catch {
            if error is APIKeyValidationError {
                throw error
            }
            throw APIKeyValidationError.networkError(error)
        }
    }
    
    func summarize(
        transcript: String,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> SummaryResult {
        
        guard let apiKey = try KeyStore.shared.retrieve(for: .mistral) else {
            throw SummarizationError.apiKeyMissing
        }
        
        let prompt = buildPrompt(for: length)
        
        let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "mistral-large-latest",
            "messages": [
                [
                    "role": "system",
                    "content": prompt
                ],
                [
                    "role": "user", 
                    "content": transcript
                ]
            ],
            "max_tokens": length.maxTokens,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        progress(0.1)
        
        if cancelToken.isCancelled {
            throw SummarizationError.cancelled
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            progress(0.8)
            
            if cancelToken.isCancelled {
                throw SummarizationError.cancelled
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SummarizationError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let result = try parseMistralResponse(data)
                progress(1.0)
                return result
                
            case 401:
                throw SummarizationError.apiKeyMissing
                
            case 429:
                throw SummarizationError.quotaExceeded
                
            case 400:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🤖 Mistral API error (400): \(errorBody)")
                throw SummarizationError.networkError(NSError(domain: "MistralAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: errorBody]))
                
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🤖 Mistral API error (\(httpResponse.statusCode)): \(errorBody)")
                throw SummarizationError.networkError(NSError(
                    domain: "MistralAPI",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorBody]
                ))
            }
            
        } catch {
            if cancelToken.isCancelled {
                throw SummarizationError.cancelled
            }
            if error is SummarizationError {
                throw error
            }
            throw SummarizationError.networkError(error)
        }
    }
    
    private func buildPrompt(for length: SummaryLength) -> String {
        let basePrompt = """
        Summarize this transcript in a clear and structured way. Start with a brief context: who the speakers are and what the topic is. Highlight the main points discussed. Extract themes, decisions, questions, and next steps. Use headings and bullet points to keep it organized. Keep it factual and concise; do not add information that isn't in the transcript. Maintain a neutral, professional tone so the summary is quick to read.
        
        Output must be plain text. No markdown headings (#). Put bold labels with double asterisks on their own line, then one blank line. One blank line between sections. Use bullets '• '. Omit empty sections. Keep the transcript's language. Do not invent facts, owners, or deadlines.
        """
        
        let lengthModifier: String
        switch length {
        case .brief:
            lengthModifier = "Keep it very concise and brief. Focus only on the most essential points. Use short sentences and minimal detail."
        case .standard:
            lengthModifier = "Provide a balanced level of detail. Include key points with supporting information where relevant."
        case .detailed:
            lengthModifier = "Provide comprehensive detail. Include context, nuances, examples, and thorough explanations of all important points discussed."
        }
        
        return "\(basePrompt)\n\n\(lengthModifier)"
    }
    
    private func parseMistralResponse(_ data: Data) throws -> SummaryResult {
        struct MistralResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let role: String
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let response = try JSONDecoder().decode(MistralResponse.self, from: data)
        
        guard let firstChoice = response.choices.first else {
            throw SummarizationError.invalidResponse
        }
        
        let rawContent = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if rawContent.isEmpty {
            throw SummarizationError.invalidResponse
        }
        
        // Clean up the response for better formatting
        let cleanContent = cleanupSummary(rawContent)
        
        return SummaryResult(clean: cleanContent, raw: rawContent)
    }
    
    private func cleanupSummary(_ text: String) -> String {
        var cleaned = text
        
        // Remove markdown headers and replace with bold
        cleaned = cleaned.replacingOccurrences(of: #"(?m)^#{1,6}\s*(.+)$"#, with: "**$1**", options: .regularExpression)
        
        // Normalize line endings
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        
        // Ensure proper spacing around bold headings
        cleaned = cleaned.replacingOccurrences(of: #"(?m)^(\*\*.+\*\*)$"#, with: "\n$1\n", options: .regularExpression)
        
        // Clean up excessive whitespace
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
