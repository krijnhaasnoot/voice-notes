import Foundation
import SwiftUI

// MARK: - AI Settings Store

@MainActor
class AISettingsStore: ObservableObject {
    static let shared = AISettingsStore()
    
    // MARK: - Published Properties
    
    @Published var selectedProvider: AIProviderType {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selected_ai_provider")
            print("🤖 Selected AI provider changed to: \(selectedProvider.displayName)")
        }
    }
    
    @Published var providerValidationStates: [AIProviderType: ValidationState] = [:]
    @Published var isValidatingProvider = false
    
    // MARK: - Private Properties
    
    private let keyStore = KeyStore.shared
    private let providerRegistry = ProviderRegistry.shared
    
    // MARK: - Initialization
    
    private init() {
        // Load selected provider from UserDefaults
        let savedProviderString = UserDefaults.standard.string(forKey: "selected_ai_provider") ?? AIProviderType.appDefault.rawValue
        self.selectedProvider = AIProviderType(rawValue: savedProviderString) ?? .appDefault
        
        // Initialize validation states
        for providerType in AIProviderType.allCases {
            providerValidationStates[providerType] = .notValidated
        }
        
        // Check which providers have stored keys
        updateValidationStatesBasedOnStoredKeys()
        
        print("🤖 AISettingsStore initialized with provider: \(selectedProvider.displayName)")
    }
    
    // MARK: - Public Methods
    
    func hasApiKey(for provider: AIProviderType) -> Bool {
        return keyStore.hasKey(for: provider)
    }
    
    func storeApiKey(_ apiKey: String, for provider: AIProviderType) async {
        do {
            try await keyStore.storeAndValidate(apiKey: apiKey, for: provider)
            providerValidationStates[provider] = .notValidated
            print("🤖 API key stored for provider: \(provider.displayName)")
        } catch {
            print("🤖 ❌ Failed to store API key for \(provider.displayName): \(error)")
            providerValidationStates[provider] = .invalid(error.localizedDescription)
        }
    }
    
    func removeApiKey(for provider: AIProviderType) {
        do {
            try keyStore.delete(for: provider)
            providerValidationStates[provider] = .notValidated
            
            // If we're removing the key for the currently selected provider, switch to app default
            if selectedProvider == provider {
                selectedProvider = .appDefault
            }
            
            print("🤖 API key removed for provider: \(provider.displayName)")
        } catch {
            print("🤖 ❌ Failed to remove API key for \(provider.displayName): \(error)")
        }
    }
    
    func validateProvider(_ provider: AIProviderType, apiKey: String? = nil) async {
        isValidatingProvider = true
        providerValidationStates[provider] = .validating
        
        do {
            let isValid = try await providerRegistry.validateProvider(provider, apiKey: apiKey)
            
            if isValid {
                providerValidationStates[provider] = .valid
                
                // If we provided an API key and it's valid, store it
                if let apiKey = apiKey {
                    await storeApiKey(apiKey, for: provider)
                }
                
                print("🤖 ✅ Provider validation successful: \(provider.displayName)")
            } else {
                providerValidationStates[provider] = .invalid("Validation failed")
                print("🤖 ❌ Provider validation failed: \(provider.displayName)")
            }
        } catch {
            providerValidationStates[provider] = .invalid(error.localizedDescription)
            print("🤖 ❌ Provider validation error for \(provider.displayName): \(error)")
        }
        
        isValidatingProvider = false
    }
    
    func refreshValidationStates() async {
        for providerType in AIProviderType.allCases {
            if providerType.requiresApiKey && hasApiKey(for: providerType) {
                await validateProvider(providerType)
            }
        }
    }
    
    func getConfiguredProviders() -> [AIProviderType] {
        return providerRegistry.configuredProviders()
    }
    
    func canUseProvider(_ provider: AIProviderType) -> Bool {
        if !provider.requiresApiKey {
            return true
        }
        
        return hasApiKey(for: provider) && providerValidationStates[provider] == .valid
    }
    
    // MARK: - Private Methods
    
    private func updateValidationStatesBasedOnStoredKeys() {
        for providerType in AIProviderType.allCases {
            if providerType.requiresApiKey {
                if hasApiKey(for: providerType) {
                    providerValidationStates[providerType] = .notValidated
                } else {
                    providerValidationStates[providerType] = .noKey
                }
            } else {
                providerValidationStates[providerType] = .valid
            }
        }
    }
}

// MARK: - Validation State

enum ValidationState: Equatable {
    case notValidated
    case validating
    case valid
    case invalid(String)
    case noKey
    
    var statusText: String {
        switch self {
        case .notValidated:
            return "Not validated"
        case .validating:
            return "Validating..."
        case .valid:
            return "Valid"
        case .invalid(let message):
            return "Invalid: \(message)"
        case .noKey:
            return "No API key"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .notValidated, .noKey:
            return .secondary
        case .validating:
            return .orange
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }
    
    var systemImage: String {
        switch self {
        case .notValidated:
            return "questionmark.circle"
        case .validating:
            return "clock.circle"
        case .valid:
            return "checkmark.circle"
        case .invalid:
            return "xmark.circle"
        case .noKey:
            return "key.slash"
        }
    }
}