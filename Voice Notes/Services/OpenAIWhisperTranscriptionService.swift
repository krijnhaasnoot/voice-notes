import Foundation
import AVFoundation

actor OpenAIWhisperTranscriptionService: TranscriptionService {
    let name = "OpenAI Whisper"
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let model: String
    private let maxFileSize: Int64 = 25 * 1024 * 1024 // 25MB limit
    private let urlSession: URLSession
    
    init(apiKey: String, model: String = "whisper-1") {
        self.apiKey = apiKey
        self.model = model
        
        // Create custom URLSession with extended timeouts for long audio processing
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 900.0 // 15 minutes for request timeout (for very long recordings)
        config.timeoutIntervalForResource = 3600.0 // 60 minutes for resource timeout (long audio processing)
        self.urlSession = URLSession(configuration: config)
    }
    
    func transcribe(
        url: URL,
        languageHint: String?,
        onDevicePreferred: Bool,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken,
        retryCount: Int = 0
    ) async throws -> String {

        if retryCount > 0 {
            print("🔤 Retry attempt \(retryCount)")
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.fileNotFound
        }
        
        if cancelToken.isCancelled {
            throw TranscriptionError.cancelled
        }
        
        guard !apiKey.isEmpty else {
            throw TranscriptionError.apiKeyMissing
        }
        
        var processedURL = url
        var audioData = try Data(contentsOf: url)
        
        // Check if file needs compression for size limit
        if audioData.count > maxFileSize {
            print("🔤 ⚠️ File too large: \(audioData.count) bytes (max: \(maxFileSize))")
            print("🔤 🔄 Attempting to compress audio for transcription...")
            
            do {
                processedURL = try await compressAudioFile(url, targetSizeBytes: maxFileSize)
                audioData = try Data(contentsOf: processedURL)
                print("🔤 ✅ Compressed audio: \(audioData.count) bytes")
            } catch {
                print("🔤 ❌ Compression failed: \(error)")
                throw TranscriptionError.networkError(NSError(
                    domain: "OpenAIWhisper",
                    code: 413,
                    userInfo: [NSLocalizedDescriptionKey: "File size exceeds 25MB limit (\(audioData.count/1024/1024)MB) and compression failed"]
                ))
            }
        }
        let fileName = url.lastPathComponent
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType(for: processedURL))\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        if let languageHint = languageHint {
            let languageCode = languageHint.prefix(2)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(languageCode)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        progress(0.1)
        
        if cancelToken.isCancelled {
            throw TranscriptionError.cancelled
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            progress(0.9)
            
            if cancelToken.isCancelled {
                throw TranscriptionError.cancelled
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranscriptionError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let transcript = json?["text"] as? String else {
                    throw TranscriptionError.invalidResponse
                }
                
                progress(1.0)
                
                // Cleanup compressed file if we created one
                if processedURL != url {
                    try? FileManager.default.removeItem(at: processedURL)
                    print("🔤 🧹 Cleaned up compressed file")
                }
                
                return transcript
                
            case 401:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("OpenAI API Error 401: \(errorBody)")
                throw TranscriptionError.apiKeyMissing
            case 429:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🔤 ⚠️ Rate limited (429): \(errorBody)")

                // Exponential backoff with max 5 retries
                let maxRetries = 5
                if retryCount < maxRetries && !cancelToken.isCancelled {
                    let backoffSeconds = min(pow(2.0, Double(retryCount)), 30.0) // Max 30 seconds
                    print("🔤 Retrying after \(Int(backoffSeconds))s (attempt \(retryCount + 1)/\(maxRetries))...")
                    try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                    if !cancelToken.isCancelled {
                        return try await transcribe(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken, retryCount: retryCount + 1)
                    }
                }
                throw TranscriptionError.quotaExceeded
            case 500...599:
                // Server errors - retry with exponential backoff
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🔤 ⚠️ Server error (\(httpResponse.statusCode)): \(errorBody)")

                let maxRetries = 3
                if retryCount < maxRetries && !cancelToken.isCancelled {
                    let backoffSeconds = min(pow(2.0, Double(retryCount + 1)), 20.0) // Max 20 seconds
                    print("🔤 Retrying after \(Int(backoffSeconds))s (attempt \(retryCount + 1)/\(maxRetries))...")
                    try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                    if !cancelToken.isCancelled {
                        return try await transcribe(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken, retryCount: retryCount + 1)
                    }
                }

                throw TranscriptionError.networkError(NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(httpResponse.statusCode)). Please try again later."]))

            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("OpenAI API Error \(httpResponse.statusCode): \(errorBody)")

                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw TranscriptionError.networkError(NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message]))
                } else {
                    throw TranscriptionError.networkError(NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorBody)"]))
                }
            }
            
        } catch {
            // Cleanup compressed file if we created one
            if processedURL != url {
                try? FileManager.default.removeItem(at: processedURL)
                print("🔤 🧹 Cleaned up compressed file after error")
            }

            if cancelToken.isCancelled {
                throw TranscriptionError.cancelled
            }

            if error is TranscriptionError {
                throw error
            }

            // Check if it's a timeout error and retry
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && (nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorNetworkConnectionLost) {
                print("🔤 ⚠️ Network timeout/connection lost: \(error)")

                let maxRetries = 3
                if retryCount < maxRetries && !cancelToken.isCancelled {
                    let backoffSeconds = min(pow(2.0, Double(retryCount + 1)), 20.0)
                    print("🔤 Retrying after \(Int(backoffSeconds))s (attempt \(retryCount + 1)/\(maxRetries))...")
                    try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                    if !cancelToken.isCancelled {
                        return try await transcribe(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken, retryCount: retryCount + 1)
                    }
                }

                throw TranscriptionError.networkError(NSError(domain: "TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transcription timed out. This recording may be too long. Try splitting it into shorter segments."]))
            }

            throw TranscriptionError.networkError(error)
        }
    }
    
    private func contentType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "m4a", "mp4":
            return "audio/mp4"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "aac":
            return "audio/aac"
        default:
            return "application/octet-stream"
        }
    }
    
    private func compressAudioFile(_ sourceURL: URL, targetSizeBytes: Int64) async throws -> URL {
        let outputURL = sourceURL.appendingPathExtension("compressed")
        
        // Remove existing compressed file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Set up the asset and export session
        let asset = AVURLAsset(url: sourceURL)
        
        // Use a lower quality preset for better compression
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality) else {
            throw TranscriptionError.networkError(NSError(
                domain: "AudioCompression", 
                code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]
            ))
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Use async/await wrapper for the export operation
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? NSError(
                        domain: "AudioCompression", 
                        code: -2, 
                        userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"]
                    )
                    continuation.resume(throwing: TranscriptionError.networkError(error))
                case .cancelled:
                    continuation.resume(throwing: TranscriptionError.cancelled)
                default:
                    continuation.resume(throwing: TranscriptionError.networkError(NSError(
                        domain: "AudioCompression", 
                        code: -3, 
                        userInfo: [NSLocalizedDescriptionKey: "Export session ended with status: \(exportSession.status.rawValue)"]
                    )))
                }
            }
        }
    }
}
