import Foundation

// MARK: - OpenAI Summary Provider

class OpenAISummaryProvider: SummaryProvider {
    let name = "OpenAI"
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
        let url = URL(string: "https://api.openai.com/v1/models")!
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
        
        guard let apiKey = try KeyStore.shared.retrieve(for: .openai) else {
            throw SummarizationError.apiKeyMissing
        }
        
        let prompt = buildPrompt(for: length)
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
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
                let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let choices = jsonResponse?["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    throw SummarizationError.invalidResponse
                }
                
                progress(1.0)
                return SummaryResult(clean: content.trimmingCharacters(in: .whitespacesAndNewlines))
                
            case 401:
                throw SummarizationError.apiKeyMissing
            case 429:
                throw SummarizationError.quotaExceeded
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SummarizationError.networkError(NSError(
                    domain: "OpenAI",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorBody)"]
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
        You are an expert at creating concise, actionable summaries of meeting transcripts and voice recordings.
        
        Please provide a well-structured summary that includes:
        - Key topics discussed
        - Important decisions made
        - Action items and next steps
        - Notable quotes or insights
        
        Format your response with clear sections using markdown-style headers.
        """
        
        switch length {
        case .brief:
            return basePrompt + "\n\nProvide a brief summary in 2-3 paragraphs."
        case .standard:
            return basePrompt + "\n\nProvide a comprehensive summary with detailed sections."
        case .detailed:
            return basePrompt + "\n\nProvide an extensive, detailed summary with comprehensive analysis and full context."
        }
    }
}