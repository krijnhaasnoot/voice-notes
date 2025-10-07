import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let userKeyIdentifier = "com.echo.userkey"

    func getUserKey() -> String {
        // Try to retrieve existing key
        if let existingKey = retrieve(key: userKeyIdentifier) {
            return existingKey
        }

        // Generate new UUID and store it
        let newKey = UUID().uuidString
        store(key: userKeyIdentifier, value: newKey)
        return newKey
    }

    private func store(key: String, value: String) {
        guard let data = value.data(using: .utf8) else {
            print("⚠️ KeychainHelper: Failed to convert value to data")
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete any existing item
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            print("⚠️ KeychainHelper: Failed to delete existing item for '\(key)': \(deleteStatus)")
        }

        // Add new item
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus != errSecSuccess {
            print("❌ KeychainHelper: Failed to add item for '\(key)': \(addStatus)")
        } else {
            print("✅ KeychainHelper: Successfully stored '\(key)'")
        }
    }

    private func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}
