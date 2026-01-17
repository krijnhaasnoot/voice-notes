import Foundation

struct CancellationToken: Sendable {
    let id = UUID()
    private let _isCancelled: @Sendable () -> Bool
    
    var isCancelled: Bool { _isCancelled() }
    
    init(isCancelled: @escaping @Sendable () -> Bool = { false }) {
        self._isCancelled = isCancelled
    }
}

enum SummarizationModel: String, CaseIterable, Codable {
    case anthropicClaude35Sonnet = "claude-3-5-sonnet-20241022"
    case openaiGPT4oMini = "gpt-4o-mini"
    
    var displayName: String {
        switch self {
        case .anthropicClaude35Sonnet:
            return "Claude 3.5 Sonnet"
        case .openaiGPT4oMini:
            return "GPT-4o mini"
        }
    }
}

protocol TranscriptionService {
    var name: String { get }
    func transcribe(
        url: URL,
        languageHint: String?,
        onDevicePreferred: Bool,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String
}

protocol SummarizationService {
    var name: String { get }
    func summarize(
        _ text: String,
        model: SummarizationModel,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String
}

enum TranscriptionError: LocalizedError {
    case fileNotFound
    case permissionDenied
    case networkError(Error)
    case cancelled
    case invalidResponse
    case apiKeyMissing
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .permissionDenied:
            return "Permission denied for speech recognition"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .cancelled:
            return "Transcription was cancelled"
        case .invalidResponse:
            return "Invalid response from transcription service"
        case .apiKeyMissing:
            return "API key is missing or invalid"
        case .quotaExceeded:
            return "API quota exceeded"
        }
    }
}

enum SummarizationError: LocalizedError {
    case emptyText
    case networkError(Error)
    case cancelled
    case invalidResponse
    case apiKeyMissing
    case quotaExceeded
    case textTooLong
    
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "No text provided for summarization"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .cancelled:
            return "Summarization was cancelled"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .apiKeyMissing:
            return "API key is missing or invalid"
        case .quotaExceeded:
            return "API quota exceeded"
        case .textTooLong:
            return "Text is too long for summarization"
        }
    }
}