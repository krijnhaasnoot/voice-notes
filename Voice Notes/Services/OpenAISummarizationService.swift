import Foundation

actor OpenAISummarizationService: SummarizationService {
    let name = "OpenAI GPT"
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func summarize(
        _ text: String,
        model: SummarizationModel,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummarizationError.emptyText
        }
        
        if cancelToken.isCancelled {
            throw SummarizationError.cancelled
        }
        
        guard !apiKey.isEmpty else {
            throw SummarizationError.apiKeyMissing
        }
        
        if text.count > 50000 {
            throw SummarizationError.textTooLong
        }
        
        let prompt = """
        Please provide a concise summary of the following transcript from a voice recording. Focus on the key points, decisions, and action items. Keep it under 200 words.
        
        Transcript:
        \(text)
        """
        
        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 300,
            "temperature": 0.3,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a helpful assistant that creates concise summaries of voice recordings."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        progress(0.2)
        
        if cancelToken.isCancelled {
            throw SummarizationError.cancelled
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            progress(0.8)
            
            if cancelToken.isCancelled {
                throw SummarizationError.cancelled
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SummarizationError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let choices = json?["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let summary = message["content"] as? String else {
                    throw SummarizationError.invalidResponse
                }
                
                progress(1.0)
                return summary.trimmingCharacters(in: .whitespacesAndNewlines)
                
            case 401:
                throw SummarizationError.apiKeyMissing
            case 429:
                throw SummarizationError.quotaExceeded
            default:
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw SummarizationError.networkError(NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message]))
                } else {
                    throw SummarizationError.invalidResponse
                }
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
}