import Foundation
import Speech
import AVFoundation

actor AppleSpeechTranscriptionService: TranscriptionService {
    let name = "Apple Speech"
    
    func transcribe(
        url: URL,
        languageHint: String?,
        onDevicePreferred: Bool,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            throw TranscriptionError.permissionDenied
        }
        
        if cancelToken.isCancelled {
            throw TranscriptionError.cancelled
        }
        
        let recognizer: SFSpeechRecognizer
        if let languageHint = languageHint {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageHint)) ?? SFSpeechRecognizer()!
        } else {
            recognizer = SFSpeechRecognizer()!
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = onDevicePreferred
        request.shouldReportPartialResults = true
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            let task = recognizer.recognitionTask(with: request) { result, error in
                if cancelToken.isCancelled && !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: TranscriptionError.cancelled)
                    return
                }
                
                if let result = result {
                    if result.isFinal {
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: result.bestTranscription.formattedString)
                        }
                    } else {
                        let estimatedProgress = min(0.9, Double(result.bestTranscription.segments.count) * 0.1)
                        Task { @MainActor in
                            progress(estimatedProgress)
                        }
                    }
                }
                
                if let error = error, !hasResumed {
                    hasResumed = true
                    
                    if error.localizedDescription.contains("network") {
                        continuation.resume(throwing: TranscriptionError.networkError(error))
                    } else {
                        continuation.resume(throwing: TranscriptionError.invalidResponse)
                    }
                }
            }
            
            if cancelToken.isCancelled {
                task.cancel()
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: TranscriptionError.cancelled)
                }
            }
        }
    }
}
