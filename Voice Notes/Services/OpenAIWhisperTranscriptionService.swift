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
        config.timeoutIntervalForRequest = 300.0 // 5 minutes for request timeout
        config.timeoutIntervalForResource = 1800.0 // 30 minutes for resource timeout (long audio processing)
        self.urlSession = URLSession(configuration: config)
    }
    
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
                print("OpenAI API Error 429: \(errorBody)")
                // Simple retry for rate limiting
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                if !cancelToken.isCancelled {
                    return try await transcribe(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken)
                }
                throw TranscriptionError.quotaExceeded
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
