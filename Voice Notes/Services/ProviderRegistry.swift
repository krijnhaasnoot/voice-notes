import Foundation

// MARK: - Provider Registry

class ProviderRegistry {
    static let shared = ProviderRegistry()
    
    private let providers: [AIProviderType: SummaryProvider]
    
    private init() {
        self.providers = [
            .appDefault: AppDefaultSummaryProvider(),
            .openai: OpenAISummaryProvider(),
            .anthropic: AnthropicSummaryProvider(),
            .gemini: GeminiSummaryProvider()
        ]
    }
    
    func provider(for type: AIProviderType) -> SummaryProvider {
        guard let provider = providers[type] else {
            print("⚠️ Provider not found for type: \(type), falling back to app default")
            return providers[.appDefault]!
        }
        return provider
    }
    
    func validateProvider(_ type: AIProviderType, apiKey: String? = nil) async throws -> Bool {
        let provider = self.provider(for: type)
        
        if provider.requiresApiKey {
            let keyToValidate: String
            
            if let apiKey = apiKey {
                keyToValidate = apiKey
            } else {
                guard let storedKey = try KeyStore.shared.retrieve(for: type) else {
                    throw APIKeyValidationError.invalidKey
                }
                keyToValidate = storedKey
            }
            
            return try await provider.validateApiKey(keyToValidate)
        }
        
        return true // App default doesn't require validation
    }
    
    func availableProviders() -> [AIProviderType] {
        return AIProviderType.allCases
    }
    
    func configuredProviders() -> [AIProviderType] {
        return AIProviderType.allCases.filter { type in
            if !type.requiresApiKey {
                return true
            }
            return KeyStore.shared.hasKey(for: type)
        }
    }
}