import Foundation

struct TranscriptionChunk {
    let progress: Double
    let text: String
}

protocol TranscriptionEngine {
    func loadModel(url: URL, language: TranscriptionLanguage) async throws
    func transcribe(fileURL: URL, language: TranscriptionLanguage, progressCallback: @escaping (TranscriptionChunk) -> Void) async throws -> String
    func cancel()
}

final class TranscriptionWorker {
    private let engine: TranscriptionEngine
    private var loadedModelURL: URL?
    private var loadedLanguage: TranscriptionLanguage?

    init(engine: TranscriptionEngine) {
        self.engine = engine
    }

    func ensureModelLoaded(url: URL, language: TranscriptionLanguage) async throws {
        // Alleen opnieuw laden als model of taal is veranderd
        if loadedModelURL != url || loadedLanguage != language {
            print("🔄 Loading model: \(url.lastPathComponent) for language: \(language.displayName)")
            try await engine.loadModel(url: url, language: language)
            loadedModelURL = url
            loadedLanguage = language
            print("✅ Model loaded successfully")
        } else {
            print("ℹ️ Model already loaded, skipping reload")
        }
    }

    func run(fileURL: URL, language: TranscriptionLanguage, progressCallback: @escaping (TranscriptionChunk) -> Void) async throws -> String {
        print("🎙️ Starting transcription for: \(fileURL.lastPathComponent)")
        let result = try await engine.transcribe(fileURL: fileURL, language: language, progressCallback: progressCallback)
        print("✅ Transcription completed, length: \(result.count) characters")
        return result
    }

    func cancel() {
        print("⚠️ Cancelling transcription")
        engine.cancel()
    }
}
