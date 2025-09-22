import Foundation

// MARK: - App Default Provider (uses existing SummaryService)

class AppDefaultSummaryProvider: SummaryProvider {
    let name = "App Default"
    let requiresApiKey = false
    
    private let summaryService: SummaryService
    
    init() {
        self.summaryService = SummaryService()
    }
    
    func validateApiKey(_ apiKey: String) async throws -> Bool {
        // App default doesn't require API key validation
        return true
    }
    
    func summarize(
        transcript: String,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> SummaryResult {
        // Delegate to existing SummaryService
        let result = try await summaryService.summarize(
            transcript: transcript,
            length: length,
            progress: progress,
            cancelToken: cancelToken
        )
        
        // Convert tuple result to SummaryResult
        return SummaryResult(clean: result.clean, raw: result.raw)
    }
}