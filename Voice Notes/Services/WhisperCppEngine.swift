import Foundation
import AVFoundation
#if canImport(SwiftWhisper)
import SwiftWhisper
#endif

#if canImport(SwiftWhisper)
final class WhisperCppEngine: TranscriptionEngine {

    private var whisper: Whisper?
    private(set) var isModelLoaded: Bool = false
    private var currentTask: Task<Void, Never>?
    private var loadedModelURL: URL?

    deinit {
        whisper = nil
    }

    func loadModel(url: URL, language: TranscriptionLanguage) async throws {
        // avoid reloading same model
        if isModelLoaded, loadedModelURL == url, whisper != nil { return }

        // Create new Whisper instance with model file
        do {
            whisper = try Whisper(fromFileURL: url)
            loadedModelURL = url
            isModelLoaded = true
            print("✅ Whisper model loaded: \(url.lastPathComponent)")
        } catch {
            throw NSError(domain: "WhisperCpp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kon Whisper-model niet laden: \(error.localizedDescription)"])
        }
    }

    func transcribe(fileURL: URL, language: TranscriptionLanguage, progressCallback: @escaping (TranscriptionChunk) -> Void) async throws -> String {
        guard let whisper else {
            throw NSError(domain: "WhisperCpp", code: 2, userInfo: [NSLocalizedDescriptionKey: "Model is niet geladen"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            currentTask = Task.detached(priority: .userInitiated) {
                do {
                    // 1) Decode & resample to mono 16k float32
                    let decoder = AudioPCM()
                    var lastEmit = CFAbsoluteTimeGetCurrent()

                    Task { @MainActor in
                        progressCallback(.init(progress: 0.0, text: "Audio decoderen..."))
                    }

                    let decoded = try decoder.decodeToMono16kFloat32(fileURL: fileURL) { ratio in
                        // emit decode progress up to 20%
                        let now = CFAbsoluteTimeGetCurrent()
                        if now - lastEmit > 0.1 {
                            lastEmit = now
                            Task { @MainActor in
                                progressCallback(.init(progress: 0.2 * ratio, text: "Audio decoderen..."))
                            }
                        }
                        if Task.isCancelled { throw CancellationError() }
                    }

                    if Task.isCancelled { throw CancellationError() }

                    Task { @MainActor in
                        progressCallback(.init(progress: 0.2, text: "Transcriptie starten..."))
                    }

                    // 2) Prepare whisper params
                    var params = WhisperParams()
                    // Map our language to SwiftWhisper's WhisperLanguage enum
                    if let whisperLang = SwiftWhisper.WhisperLanguage(rawValue: language.whisperCode) {
                        params.language = whisperLang
                    }
                    params.translate = false

                    // 3) Run inference with progress updates
                    let hb = Task.detached {
                        var t = 0.2
                        while !Task.isCancelled {
                            try? await Task.sleep(nanoseconds: 150_000_000) // ~150ms
                            t = min(0.9, t + 0.02)
                            Task { @MainActor in
                                progressCallback(.init(progress: t, text: "Transcriberen..."))
                            }
                        }
                    }

                    let segments = try await whisper.transcribe(audioFrames: decoded)
                    hb.cancel()

                    if Task.isCancelled { throw CancellationError() }

                    // 4) Collect segments
                    var assembled = ""
                    for (i, segment) in segments.enumerated() {
                        if Task.isCancelled { throw CancellationError() }

                        let text = segment.text.trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty {
                            if !assembled.isEmpty { assembled += " " }
                            assembled += text

                            let prog = 0.9 + (Double(i + 1) / Double(max(1, segments.count))) * 0.1
                            Task { @MainActor in
                                progressCallback(.init(progress: min(1.0, prog), text: assembled))
                            }
                        }
                    }

                    Task { @MainActor in
                        progressCallback(.init(progress: 1.0, text: assembled))
                    }

                    continuation.resume(returning: assembled)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
    }
}
#else
// Fallback for when SwiftWhisper is not available
final class WhisperCppEngine: TranscriptionEngine {
    func loadModel(url: URL, language: TranscriptionLanguage) async throws {
        throw NSError(domain: "WhisperCpp", code: 999, userInfo: [NSLocalizedDescriptionKey: "SwiftWhisper package niet geïnstalleerd"])
    }

    func transcribe(fileURL: URL, language: TranscriptionLanguage, progressCallback: @escaping (TranscriptionChunk) -> Void) async throws -> String {
        throw NSError(domain: "WhisperCpp", code: 999, userInfo: [NSLocalizedDescriptionKey: "SwiftWhisper package niet geïnstalleerd"])
    }

    func cancel() {}
}
#endif
