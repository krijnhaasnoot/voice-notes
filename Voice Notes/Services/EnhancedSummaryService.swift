import Foundation

// MARK: - Enhanced Summary Service with Provider Support

@MainActor
class EnhancedSummaryService: ObservableObject {
    static let shared = EnhancedSummaryService()
    
    private let providerRegistry = ProviderRegistry.shared
    private let aiSettings = AISettingsStore.shared
    private let telemetryTracker: TelemetryTracker
    private let fallbackService = SummaryService() // Original service as fallback
    
    @Published var isProcessing = false
    
    private init() {
        self.telemetryTracker = TelemetryService.shared
    }
    
    // MARK: - Main Summarization Method
    
    func summarize(
        transcript: String,
        length: SummaryLength = .standard,
        providerOverride: AIProviderType? = nil,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> SummaryResult {
        
        isProcessing = true
        defer { isProcessing = false }
        
        let startTime = Date()
        let selectedProvider = providerOverride ?? aiSettings.selectedProvider
        
        print("📋 Starting summary with provider: \(selectedProvider.displayName)")
        
        do {
            // Try primary provider
            let result = try await summarizeWithProvider(
                selectedProvider,
                transcript: transcript,
                length: length,
                progress: progress,
                cancelToken: cancelToken
            )
            
            // Track successful telemetry
            let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
            let telemetry = SummaryTelemetry(
                providerId: selectedProvider.rawValue,
                success: true,
                fallbackUsed: false,
                processingTimeMs: processingTime,
                transcriptLength: transcript.count,
                summaryLength: result.clean.count
            )
            telemetryTracker.track(telemetry)
            
            return result
            
        } catch {
            print("📋 ❌ Primary provider failed: \(error)")
            
            // Try fallback logic
            let fallbackResult = try await handleProviderFailure(
                primaryProvider: selectedProvider,
                transcript: transcript,
                length: length,
                progress: progress,
                cancelToken: cancelToken,
                originalError: error
            )
            
            // Track fallback telemetry
            let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
            let telemetry = SummaryTelemetry(
                providerId: selectedProvider.rawValue,
                success: true,
                fallbackUsed: true,
                processingTimeMs: processingTime,
                transcriptLength: transcript.count,
                summaryLength: fallbackResult.clean.count
            )
            telemetryTracker.track(telemetry)
            
            return fallbackResult
        }
    }
    
    // MARK: - Provider-Specific Summarization
    
    private func summarizeWithProvider(
        _ providerType: AIProviderType,
        transcript: String,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> SummaryResult {
        
        let provider = providerRegistry.provider(for: providerType)
        
        // Check if provider is properly configured
        if provider.requiresApiKey && !KeyStore.shared.hasKey(for: providerType) {
            throw SummarizationError.apiKeyMissing
        }
        
        return try await provider.summarize(
            transcript: transcript,
            length: length,
            progress: progress,
            cancelToken: cancelToken
        )
    }
    
    // MARK: - Fallback Logic
    
    private func handleProviderFailure(
        primaryProvider: AIProviderType,
        transcript: String,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken,
        originalError: Error
    ) async throws -> SummaryResult {
        
        print("📋 🔄 Attempting fallback strategies...")
        
        // Strategy 1: Try app default if primary wasn't app default
        if primaryProvider != .appDefault {
            do {
                print("📋 🔄 Trying app default provider...")
                return try await summarizeWithProvider(
                    .appDefault,
                    transcript: transcript,
                    length: length,
                    progress: progress,
                    cancelToken: cancelToken
                )
            } catch {
                print("📋 ❌ App default also failed: \(error)")
            }
        }
        
        // Strategy 2: Try other configured providers
        let configuredProviders = providerRegistry.configuredProviders()
            .filter { $0 != primaryProvider && $0 != .appDefault }
        
        for fallbackProvider in configuredProviders {
            do {
                print("📋 🔄 Trying fallback provider: \(fallbackProvider.displayName)")
                return try await summarizeWithProvider(
                    fallbackProvider,
                    transcript: transcript,
                    length: length,
                    progress: progress,
                    cancelToken: cancelToken
                )
            } catch {
                print("📋 ❌ Fallback provider \(fallbackProvider.displayName) failed: \(error)")
                continue
            }
        }
        
        // Strategy 3: Local extraction fallback
        print("📋 🔄 All providers failed, using local extraction...")
        return try await createLocalExtractFallback(transcript: transcript, length: length)
    }
    
    // MARK: - Local Extract Fallback
    
    private func createLocalExtractFallback(
        transcript: String,
        length: SummaryLength
    ) async throws -> SummaryResult {
        
        // Simple local extraction logic
        let sentences = transcript.components(separatedBy: ".").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let extractLength = switch length {
        case .brief: min(3, sentences.count)
        case .standard: min(6, sentences.count)
        case .detailed: min(10, sentences.count)
        }
        
        let extract = sentences.prefix(extractLength).joined(separator: ". ")
        
        let fallbackSummary = """
        **Summary (Local Extract)**
        
        This is a simplified local extract as all AI providers were unavailable:
        
        \(extract.trimmingCharacters(in: .whitespacesAndNewlines))
        
        *Note: Full AI summarization was unavailable. Please check your provider configuration.*
        """
        
        return SummaryResult(clean: fallbackSummary)
    }
    
    // MARK: - Validation Methods
    
    func validateCurrentProvider() async -> Bool {
        let currentProvider = aiSettings.selectedProvider
        
        if !currentProvider.requiresApiKey {
            return true
        }
        
        do {
            return try await providerRegistry.validateProvider(currentProvider)
        } catch {
            print("📋 ❌ Provider validation failed: \(error)")
            return false
        }
    }
    
    func getAvailableProviders() -> [AIProviderType] {
        return providerRegistry.configuredProviders()
    }
    
    // MARK: - Provider Status
    
    func getProviderStatus(_ provider: AIProviderType) -> (configured: Bool, valid: Bool) {
        let configured = !provider.requiresApiKey || KeyStore.shared.hasKey(for: provider)
        let validationState = aiSettings.providerValidationStates[provider]
        let valid = validationState == .valid
        
        return (configured: configured, valid: valid)
    }
}

// MARK: - Extension for Max Tokens

extension SummaryLength {
    var maxTokens: Int {
        switch self {
        case .brief:
            return 300
        case .standard:
            return 800
        case .detailed:
            return 1500
        }
    }
}