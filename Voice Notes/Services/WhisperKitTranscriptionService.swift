import Foundation
import AVFoundation

// MARK: - WhisperKit Integration
// To use this service, add WhisperKit as a Swift Package dependency:
// Repository: https://github.com/argmaxinc/WhisperKit
// Version: Latest (1.0.0+)
//
// Uncomment the import below after adding the package:
// import WhisperKit

/// On-device transcription service using WhisperKit (Apple's CoreML-optimized Whisper)
actor WhisperKitTranscriptionService: TranscriptionService {
    let name = "WhisperKit (On-Device)"

    private let modelManager: WhisperModelManager
    // private var whisperKit: WhisperKit?  // Uncomment when WhisperKit is added
    private var currentTask: Task<String, Error>?

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
        // Check if model is downloaded
        let model = await modelManager.selectedModel
        let isDownloaded = await modelManager.isModelDownloaded(model)

        guard isDownloaded else {
            throw WhisperKitError.modelNotDownloaded
        }

        // Get model path
        let modelPath = await modelManager.modelPath(for: model)

        // Initialize WhisperKit if needed
        try await initializeWhisperKitIfNeeded(modelPath: modelPath)

        // Start transcription with progress tracking
        return try await performTranscription(
            audioURL: url,
            languageHint: languageHint,
            progress: progress,
            cancelToken: cancelToken
        )
    }

    // MARK: - WhisperKit Initialization

    private func initializeWhisperKitIfNeeded(modelPath: URL) async throws {
        // Uncomment when WhisperKit is added:
        /*
        if whisperKit == nil {
            print("🎙️ Initializing WhisperKit with model at: \(modelPath.path)")
            whisperKit = try await WhisperKit(
                modelFolder: modelPath.path,
                verbose: true,
                logLevel: .info
            )
            print("✅ WhisperKit initialized successfully")
        }
        */

        // For now, throw an error to indicate WhisperKit needs to be added
        throw WhisperKitError.notImplemented
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
            // Check for cancellation
            try Task.checkCancellation()

            print("🎙️ Starting WhisperKit transcription")
            print("   Audio: \(audioURL.lastPathComponent)")
            print("   Language: \(language)")

            // Uncomment when WhisperKit is added:
            /*
            guard let whisperKit = whisperKit else {
                throw WhisperKitError.notInitialized
            }

            // Transcribe with progress callbacks
            let result = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                language: language,
                task: .transcribe,
                progressCallback: { progressValue in
                    Task { @MainActor in
                        progress(progressValue)
                    }
                }
            )

            // Check for cancellation after transcription
            try Task.checkCancellation()

            // Extract text from result
            let transcriptText = result.text

            print("✅ WhisperKit transcription completed")
            print("   Length: \(transcriptText.count) characters")

            return transcriptText
            */

            // Temporary placeholder until WhisperKit is added
            // Simulate transcription progress
            for i in 0...100 {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                await MainActor.run {
                    progress(Double(i) / 100.0)
                }
            }

            throw WhisperKitError.notImplemented
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
                try await Task.sleep(nanoseconds: 100_000_000) // Check every 0.1 seconds
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
            // Rethrow the error (likely WhisperKitError)
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
        // whisperKit = nil  // Uncomment when WhisperKit is added
    }
}

// MARK: - Errors

enum WhisperKitError: LocalizedError {
    case modelNotDownloaded
    case notInitialized
    case invalidAudioFile
    case conversionFailed
    case transcriptionFailed(String)
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Whisper model not downloaded. Please download a model in Settings."
        case .notInitialized:
            return "WhisperKit not initialized"
        case .invalidAudioFile:
            return "Invalid or corrupted audio file"
        case .conversionFailed:
            return "Failed to convert audio to required format"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .notImplemented:
            return "WhisperKit package needs to be added. See instructions in WhisperKitTranscriptionService.swift"
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
