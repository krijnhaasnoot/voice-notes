import Foundation
import AVFoundation
import WhisperKit

/// On-device transcription service using WhisperKit (Apple's CoreML-optimized Whisper)
/// 🚀 ~10x faster than real-time with Tiny model on modern devices
actor WhisperKitTranscriptionService: TranscriptionService {
    let name = "WhisperKit (On-Device)"

    private let modelManager: WhisperModelManager
    private var whisperKit: WhisperKit?
    private var currentTask: Task<String, Error>?
    private var isInitialized = false
    
    // Singleton to reuse model across transcriptions (memory optimization)
    private static var sharedInstance: WhisperKitTranscriptionService?
    
    static func shared() -> WhisperKitTranscriptionService {
        if sharedInstance == nil {
            sharedInstance = WhisperKitTranscriptionService()
        }
        return sharedInstance!
    }

    init(modelManager: WhisperModelManager = .shared) {
        self.modelManager = modelManager
    }

    // MARK: - TranscriptionService Protocol

    func transcribe(
        url: URL,
        languageHint: String?,
        onDevicePreferred: Bool,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        // Check for bundled model first
        let hasBundledModel = await getBundledModelPath() != nil
        
        // NOTE:
        // Previously we required the selected model to already be downloaded, otherwise we threw `modelNotDownloaded`.
        // That creates a “fallback” behavior elsewhere (or repeated failures) and can lead to poor user experience.
        // We now allow WhisperKit to download the selected model on-demand (or use bundled/downloaded if present).

        // Get model path (will use bundled or downloaded)
        let modelPath = await modelManager.modelPath(for: await modelManager.selectedModel)

        // Initialize WhisperKit if needed
        try await initializeWhisperKitIfNeeded(modelPath: modelPath)

        // Start transcription with progress tracking
        // Ensure audio is in a good format for WhisperKit (16kHz mono). This can improve reliability on longer files.
        let preparedURL = try await prepareAudioFile(url)
        
        let result = try await performTranscription(
            audioURL: preparedURL,
            languageHint: languageHint,
            progress: progress,
            cancelToken: cancelToken
        )
        
        // Release model from memory after transcription to prevent SIGKILL
        await releaseModelFromMemory()
        
        return result
    }
    
    /// Release model from memory to prevent iOS from killing the app
    private func releaseModelFromMemory() async {
        print("🧹 WhisperKit: Releasing model from memory...")
        whisperKit = nil
        isInitialized = false
        
        // Force garbage collection hint
        await Task.yield()
    }

    // MARK: - WhisperKit Initialization

    private func initializeWhisperKitIfNeeded(modelPath: URL) async throws {
        guard !isInitialized else { return }
        
        let selectedModel = await modelManager.selectedModel
        print("🎙️ Initializing WhisperKit...")
        print("   Selected model: \(selectedModel.displayName)")
        print("   Model path: \(modelPath.path)")
        
        // Check if using bundled model
        if let bundledModelPath = await getBundledModelPath() {
            print("📦 Using bundled Whisper model at: \(bundledModelPath)")
            whisperKit = try await WhisperKit(
                modelFolder: bundledModelPath,
                computeOptions: getComputeOptions(),
                verbose: false,
                logLevel: .error
            )
        } else if FileManager.default.fileExists(atPath: modelPath.path) {
            print("📁 Using downloaded model at: \(modelPath.path)")
            whisperKit = try await WhisperKit(
                modelFolder: modelPath.path,
                computeOptions: getComputeOptions(),
                verbose: false,
                logLevel: .error
            )
        } else {
            // Download the selected model from WhisperModelManager
            let selectedModel = await modelManager.selectedModel
            let modelIdentifier = "openai_whisper-\(selectedModel.rawValue)"
            print("⬇️ No local model found, downloading \(selectedModel.displayName) model...")
            print("   Model identifier: \(modelIdentifier)")
            whisperKit = try await WhisperKit(
                model: modelIdentifier,
                computeOptions: getComputeOptions(),
                verbose: false,
                logLevel: .error
            )
        }
        
        isInitialized = true
        print("✅ WhisperKit initialized successfully")
    }
    
    private func getComputeOptions() -> ModelComputeOptions {
        // Optimize for speed on Neural Engine
        return ModelComputeOptions(
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine
        )
    }
    
    private func getBundledModelPath() async -> String? {
        // Check for bundled model in app bundle
        // Structure: BundledModels/openai_whisper-[model] or similar
        // Priority: selected model first, then base, then tiny as fallback
        let selectedModel = await modelManager.selectedModel.rawValue
        let modelNames = [
            "openai_whisper-\(selectedModel)", "whisper-\(selectedModel)", selectedModel,  // Selected model
            "openai_whisper-base", "whisper-base", "base",  // Base as fallback
            "openai_whisper-tiny", "whisper-tiny", "tiny"   // Tiny as last resort
        ]
        
        print("🔍 Searching for bundled Whisper model (priority: \(selectedModel))...")
        
        for modelName in modelNames {
            if let path = Bundle.main.path(forResource: modelName, ofType: nil, inDirectory: "BundledModels") {
                print("✅ Found bundled model: \(modelName)")
                return path
            }
            // Also check root bundle
            if let path = Bundle.main.path(forResource: modelName, ofType: nil) {
                print("✅ Found bundled model in root: \(modelName)")
                return path
            }
        }
        
        print("❌ No bundled model found")
        return nil
    }

    // MARK: - Transcription Implementation

    private func performTranscription(
        audioURL: URL,
        languageHint: String?,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        // Get language before entering task
        let selectedLanguage = await modelManager.selectedLanguage.rawValue
        let language = languageHint ?? selectedLanguage

        // Create cancellable task
        let transcriptionTask = Task<String, Error> {
            try Task.checkCancellation()

            let currentModel = await modelManager.selectedModel
            print("🎙️ Starting WhisperKit transcription")
            print("   Model: \(currentModel.displayName) (\(currentModel.rawValue))")
            print("   Audio: \(audioURL.lastPathComponent)")
            print("   Language: \(language == "auto" ? "auto-detect" : language)")

            guard let whisperKit = whisperKit else {
                throw WhisperKitError.notInitialized
            }

            // Configure transcription options
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: language == "auto" ? nil : language,
                temperatureFallbackCount: 3,
                sampleLength: 224,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: false,
                suppressBlank: true
            )

            // Track progress
            await MainActor.run { progress(0.1) }

            // Transcribe audio
            let results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )

            try Task.checkCancellation()
            
            await MainActor.run { progress(0.9) }

            // Combine all segments into final transcript
            let transcriptText = results
                .compactMap { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            await MainActor.run { progress(1.0) }

            print("✅ WhisperKit transcription completed")
            print("   Length: \(transcriptText.count) characters")
            print("   Segments: \(results.count)")

            return transcriptText
        }

        // Store task for potential cancellation
        currentTask = transcriptionTask

        // Set up cancellation monitoring
        let cancellationTask = Task {
            while !Task.isCancelled && !transcriptionTask.isCancelled {
                if cancelToken.isCancelled {
                    transcriptionTask.cancel()
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        defer {
            cancellationTask.cancel()
            currentTask = nil
        }

        do {
            let result = try await transcriptionTask.value
            return result
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch {
            print("❌ WhisperKit transcription error: \(error)")
            throw error
        }
    }

    // MARK: - Audio Preprocessing

    private func prepareAudioFile(_ url: URL) async throws -> URL {
        // WhisperKit requires 16kHz mono audio
        // Convert if necessary

        let asset = AVURLAsset(url: url)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw WhisperKitError.invalidAudioFile
        }

        // Check format
        let formatDescriptions = try await assetTrack.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            throw WhisperKitError.invalidAudioFile
        }

        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        let sampleRate = audioStreamBasicDescription?.pointee.mSampleRate ?? 0

        // If already 16kHz mono, return original
        if abs(sampleRate - 16000.0) < 100.0 {
            print("✅ Audio already in correct format (16kHz)")
            return url
        }

        // Convert to 16kHz mono
        print("🔄 Converting audio to 16kHz mono...")
        return try await convertAudioTo16kHzMono(url)
    }

    private func convertAudioTo16kHzMono(_ inputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw WhisperKitError.invalidAudioFile
        }

        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A) else {
            throw WhisperKitError.conversionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        // Export
        await exportSession.export()

        guard exportSession.status == .completed else {
            throw WhisperKitError.conversionFailed
        }

        print("✅ Audio converted successfully")
        return outputURL
    }

    // MARK: - Cleanup

    func cleanup() async {
        currentTask?.cancel()
        currentTask = nil
        whisperKit = nil
        isInitialized = false
    }
}

// MARK: - Errors

enum WhisperKitError: LocalizedError {
    case modelNotDownloaded
    case notInitialized
    case invalidAudioFile
    case conversionFailed
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Whisper model not available. Please check Settings."
        case .notInitialized:
            return "WhisperKit not initialized"
        case .invalidAudioFile:
            return "Invalid or corrupted audio file"
        case .conversionFailed:
            return "Failed to convert audio to required format"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        }
    }
}

// MARK: - Performance Estimation

extension WhisperKitTranscriptionService {
    /// Estimate transcription time based on model size and device
    func estimateTranscriptionTime(audioDuration: TimeInterval, model: WhisperModelSize) -> TimeInterval {
        // Real-time factors (how many seconds of processing per second of audio)
        // These are approximate and vary by device
        let rtf: Double
        switch model {
        case .tiny:
            rtf = 0.1  // 10x faster than real-time on A16+
        case .base:
            rtf = 0.2  // 5x faster than real-time
        case .small:
            rtf = 0.5  // 2x faster than real-time
        case .medium:
            rtf = 1.0  // Real-time
        case .large:
            rtf = 2.0  // 2x slower than real-time
        }

        return audioDuration * rtf
    }
}
