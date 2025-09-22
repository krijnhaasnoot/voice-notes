import Foundation

// MARK: - Anthropic/Claude Summary Provider

class AnthropicSummaryProvider: SummaryProvider {
    let name = "Anthropic/Claude"
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
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Test with minimal request
        let testBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 10,
            "messages": [
                [
                    "role": "user",
                    "content": "Hi"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: testBody)
        
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
        
        guard let apiKey = try KeyStore.shared.retrieve(for: .anthropic) else {
            throw SummarizationError.apiKeyMissing
        }
        
        let prompt = buildPrompt(for: length, transcript: transcript)
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": selectModel(for: length),
            "max_tokens": length.maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
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
                guard let content = jsonResponse?["content"] as? [[String: Any]],
                      let firstContent = content.first,
                      let text = firstContent["text"] as? String else {
                    throw SummarizationError.invalidResponse
                }
                
                progress(1.0)
                return SummaryResult(clean: text.trimmingCharacters(in: .whitespacesAndNewlines))
                
            case 401:
                throw SummarizationError.apiKeyMissing
            case 429:
                throw SummarizationError.quotaExceeded
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SummarizationError.networkError(NSError(
                    domain: "Anthropic",
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
    
    private func selectModel(for length: SummaryLength) -> String {
        switch length {
        case .brief:
            return "claude-3-haiku-20240307"
        case .standard:
            return "claude-3-5-sonnet-20241022"
        case .detailed:
            return "claude-3-5-sonnet-20241022"
        }
    }
    
    private func buildPrompt(for length: SummaryLength, transcript: String) -> String {
        let basePrompt = """
        I need you to analyze and summarize the following meeting transcript or voice recording.
        
        Please provide a well-structured summary that includes:
        - Key topics discussed
        - Important decisions made
        - Action items and next steps
        - Notable quotes or insights
        
        Format your response with clear sections using markdown-style headers.
        """
        
        let lengthInstruction = switch length {
        case .brief:
            "Provide a brief summary in 2-3 paragraphs."
        case .standard:
            "Provide a comprehensive summary with detailed sections."
        case .detailed:
            "Provide an extensive, detailed summary with comprehensive analysis and full context."
        }
        
        return "\(basePrompt)\n\n\(lengthInstruction)\n\nTranscript:\n\(transcript)"
    }
}