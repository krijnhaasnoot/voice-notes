import Foundation
import Security

// MARK: - Secure Keychain Storage

class KeyStore {
    static let shared = KeyStore()
    private init() {}
    
    private let serviceName = "com.kinder.Voice-Notes.api-keys"
    
    // MARK: - Public Interface
    
    func store(apiKey: String, for provider: AIProviderType) throws {
        let account = provider.rawValue
        
        // Delete existing key first
        try? delete(for: provider)
        
        // Add new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: apiKey.data(using: .utf8) ?? Data(),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeyStoreError.storeFailed(status)
        }
        
        print("🔑 Securely stored API key for provider: \(provider.displayName)")
    }
    
    func retrieve(for provider: AIProviderType) throws -> String? {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let apiKey = String(data: data, encoding: .utf8) else {
                throw KeyStoreError.invalidData
            }
            return apiKey
        case errSecItemNotFound:
            return nil
        default:
            throw KeyStoreError.retrieveFailed(status)
        }
    }
    
    func delete(for provider: AIProviderType) throws {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.deleteFailed(status)
        }
        
        print("🔑 Deleted API key for provider: \(provider.displayName)")
    }
    
    func hasKey(for provider: AIProviderType) -> Bool {
        return (try? retrieve(for: provider)) != nil
    }
    
    // MARK: - Convenience Methods
    
    func storeAndValidate(apiKey: String, for provider: AIProviderType) async throws {
        // Basic format validation first
        if let pattern = provider.keyValidationPattern {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: apiKey.count)
            
            guard regex.firstMatch(in: apiKey, range: range) != nil else {
                throw APIKeyValidationError.invalidFormat
            }
        }
        
        // Store the key
        try store(apiKey: apiKey, for: provider)
        
        print("🔑 API key stored and format validated for provider: \(provider.displayName)")
    }
    
    func clearAllKeys() {
        for provider in AIProviderType.allCases {
            try? delete(for: provider)
        }
        print("🔑 Cleared all stored API keys")
    }
}

// MARK: - Errors

enum KeyStoreError: LocalizedError {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store API key (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve API key (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete API key (status: \(status))"
        case .invalidData:
            return "Invalid data format in keychain"
        }
    }
}