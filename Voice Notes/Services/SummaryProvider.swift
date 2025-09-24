import Foundation

// MARK: - Supporting Types

/// Result of a summarization operation
struct SummaryResult: Sendable {
    let clean: String
    let raw: String?
    
    init(clean: String, raw: String? = nil) {
        self.clean = clean
        self.raw = raw
    }
}

// MARK: - Core Protocol

protocol SummaryProvider {
    var name: String { get }
    var requiresApiKey: Bool { get }
    
    func validateApiKey(_ apiKey: String) async throws -> Bool
    func summarize(
        transcript: String,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> SummaryResult
}

// MARK: - Provider Types

/// AI provider options for summarization services
enum AIProviderType: String, CaseIterable {
    case appDefault = "app_default"
    case openai = "openai"
    case anthropic = "anthropic" 
    case gemini = "gemini"
    case mistral = "mistral"
    
    var displayName: String {
        switch self {
        case .appDefault:
            return "App Default"
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic/Claude"
        case .gemini:
            return "Google Gemini"
        case .mistral:
            return "Mistral AI"
        }
    }
    
    var requiresApiKey: Bool {
        switch self {
        case .appDefault:
            return false
        case .openai, .anthropic, .gemini, .mistral:
            return true
        }
    }
    
    var keyValidationPattern: String? {
        switch self {
        case .appDefault:
            return nil
        case .openai:
            return "^sk-[A-Za-z0-9]{48,}$"
        case .anthropic:
            return "^sk-ant-[A-Za-z0-9\\-_]{95,}$"
        case .gemini:
            return "^[A-Za-z0-9\\-_]{39}$"
        case .mistral:
            return "^[A-Za-z0-9]{32}$"
        }
    }
}

// MARK: - Validation Errors

enum APIKeyValidationError: LocalizedError {
    case invalidFormat
    case networkError(Error)
    case invalidKey
    case quotaExceeded
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "API key format is invalid"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidKey:
            return "API key is invalid or expired"
        case .quotaExceeded:
            return "API quota exceeded"
        case .unknown:
            return "Unknown validation error"
        }
    }
}

// MARK: - Telemetry

struct SummaryTelemetry {
    let providerId: String
    let success: Bool
    let fallbackUsed: Bool
    let processingTimeMs: Int
    let transcriptLength: Int
    let summaryLength: Int
    let timestamp: Date
    
    init(providerId: String, success: Bool, fallbackUsed: Bool = false, processingTimeMs: Int = 0, transcriptLength: Int = 0, summaryLength: Int = 0) {
        self.providerId = providerId
        self.success = success
        self.fallbackUsed = fallbackUsed
        self.processingTimeMs = processingTimeMs
        self.transcriptLength = transcriptLength
        self.summaryLength = summaryLength
        self.timestamp = Date()
    }
}

protocol TelemetryTracker {
    func track(_ telemetry: SummaryTelemetry)
}

// MARK: - Default Telemetry Implementation

class ConsoleTelemetryTracker: TelemetryTracker {
    func track(_ telemetry: SummaryTelemetry) {
        print("📊 Summary Telemetry: provider=\(telemetry.providerId), success=\(telemetry.success), fallback=\(telemetry.fallbackUsed), time=\(telemetry.processingTimeMs)ms")
    }
}