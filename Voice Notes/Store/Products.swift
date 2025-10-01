import Foundation

public enum EchoProductID: String, CaseIterable {
    case standard = "com.kinder.echo.standard.monthly"
    case premium  = "com.kinder.echo.premium.monthly"
    case ownKey   = "com.kinder.echo.ownkey.monthly"

    var displayName: String {
        switch self {
        case .standard: return "Echo Standard"
        case .premium: return "Echo Premium"
        case .ownKey: return "Echo Own Key"
        }
    }

    var monthlyMinutes: Int {
        switch self {
        case .standard: return 120
        case .premium: return 600
        case .ownKey: return 10000
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "Perfect for casual users"
        case .premium:
            return "For power users"
        case .ownKey:
            return "Bring your own API key"
        }
    }

    var features: [String] {
        switch self {
        case .standard:
            return [
                "\(monthlyMinutes) minutes per month",
                "AI transcription",
                "Smart summaries",
                "All summary modes"
            ]
        case .premium:
            return [
                "\(monthlyMinutes) minutes per month",
                "AI transcription",
                "Smart summaries",
                "All summary modes",
                "Priority support"
            ]
        case .ownKey:
            return [
                "Up to \(monthlyMinutes) minutes per month",
                "Use your own OpenAI API key",
                "Full control over AI settings",
                "All premium features"
            ]
        }
    }
}

// Free tier constants
public struct FreeTier {
    public static let monthlyMinutes: Int = 30
    public static let displayName: String = "Free Trial"
}
