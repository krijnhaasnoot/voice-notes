import Foundation

struct ConfigurationManager {
    static func getOpenAIAPIKey() -> String? {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String else {
            print("❌ OpenAI API Key not found in Info.plist")
            return nil
        }
        
        if apiKey.hasPrefix("$(") || apiKey.isEmpty || apiKey.contains("YOUR_ACTUAL_API_KEY") {
            print("❌ OpenAI API Key not configured properly. Current value: \(apiKey.isEmpty ? "empty" : "placeholder")")
            return nil
        }
        
        if apiKey.hasPrefix("sk-") {
            print("✅ OpenAI API Key found and appears valid")
            return apiKey
        } else {
            print("❌ OpenAI API Key doesn't start with 'sk-': \(String(apiKey.prefix(10)))...")
            return nil
        }
    }
    
    static func validateConfiguration() {
        print("🔧 Configuration Check:")
        print("   API Key: \(getOpenAIAPIKey() != nil ? "✅ Valid" : "❌ Invalid")")
    }
}