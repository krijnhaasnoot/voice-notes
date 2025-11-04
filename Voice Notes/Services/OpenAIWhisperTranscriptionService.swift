import Foundation
import AVFoundation

actor OpenAIWhisperTranscriptionService: TranscriptionService {
    let name = "OpenAI Whisper"
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let model: String
    private let maxFileSize: Int64 = 25 * 1024 * 1024 // 25MB limit
    private let maxDurationForSingleRequest: TimeInterval = 600 // 10 minutes - split longer files into chunks
    private let urlSession: URLSession

    init(apiKey: String, model: String = "whisper-1") {
        self.apiKey = apiKey
        self.model = model

        // Create custom URLSession with extended timeouts for long audio processing
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600.0 // 10 minutes for request timeout per chunk
        config.timeoutIntervalForResource = 1800.0 // 30 minutes for resource timeout
        self.urlSession = URLSession(configuration: config)
    }

    static func createFromInfoPlist() -> OpenAIWhisperTranscriptionService? {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String,
              !apiKey.isEmpty,
              !apiKey.hasPrefix("$("),
              apiKey.hasPrefix("sk-") else {
            print("🔑 ❌ OpenAI API Key not found or invalid in Info.plist")
            return nil
        }
        print("🔑 ✅ OpenAI API Key loaded from Info.plist")
        return OpenAIWhisperTranscriptionService(apiKey: apiKey)
    }
    
    func transcribe(
        url: URL,
        languageHint: String?,
        onDevicePreferred: Bool,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        // Check audio duration
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds

        print("🔤 Audio duration: \(Int(duration))s (\(Int(duration/60)) minutes)")

        // If recording is longer than max duration, use chunking
        if duration > maxDurationForSingleRequest {
            print("🔤 Recording exceeds \(Int(maxDurationForSingleRequest/60)) minutes, using chunking approach")
            return try await transcribeWithChunking(url: url, duration: duration, languageHint: languageHint, progress: progress, cancelToken: cancelToken)
        }

        // Otherwise use single request with retry
        return try await transcribeWithRetry(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken, retryCount: 0)
    }

    // MARK: - Chunking for Long Recordings

    private func transcribeWithChunking(
        url: URL,
        duration: TimeInterval,
        languageHint: String?,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        // Calculate number of chunks needed (8 minutes per chunk to be safe)
        let chunkDuration: TimeInterval = 480 // 8 minutes
        let numberOfChunks = Int(ceil(duration / chunkDuration))

        print("🔤 Splitting into \(numberOfChunks) chunks of ~\(Int(chunkDuration/60)) minutes each")

        var transcripts: [String] = []
        let asset = AVURLAsset(url: url)

        for chunkIndex in 0..<numberOfChunks {
            if cancelToken.isCancelled {
                throw TranscriptionError.cancelled
            }

            let startTime = CMTime(seconds: Double(chunkIndex) * chunkDuration, preferredTimescale: 600)
            let endTime = CMTime(seconds: min(Double(chunkIndex + 1) * chunkDuration, duration), preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, end: endTime)

            print("🔤 Processing chunk \(chunkIndex + 1)/\(numberOfChunks) (\(Int(startTime.seconds))s - \(Int(endTime.seconds))s)")

            // Update progress (splitting takes 10% of overall progress)
            let baseProgress = 0.1 + (Double(chunkIndex) / Double(numberOfChunks)) * 0.9
            progress(baseProgress)

            // Export chunk
            let chunkURL = try await exportAudioChunk(asset: asset, timeRange: timeRange, chunkIndex: chunkIndex)

            // Transcribe chunk
            let chunkProgress: @Sendable (Double) -> Void = { chunkProg in
                let overallProgress = baseProgress + (chunkProg / Double(numberOfChunks)) * 0.9
                progress(overallProgress)
            }

            let transcript = try await transcribeWithRetry(
                url: chunkURL,
                languageHint: languageHint,
                onDevicePreferred: false,
                progress: chunkProgress,
                cancelToken: cancelToken,
                retryCount: 0
            )

            transcripts.append(transcript)

            // Clean up chunk file
            try? FileManager.default.removeItem(at: chunkURL)

            print("🔤 Chunk \(chunkIndex + 1)/\(numberOfChunks) completed")
        }

        progress(1.0)

        // Combine all transcripts
        let finalTranscript = transcripts.joined(separator: "\n\n")
        print("🔤 ✅ Chunked transcription complete - \(transcripts.count) chunks combined")

        return finalTranscript
    }

    private func exportAudioChunk(asset: AVURLAsset, timeRange: CMTimeRange, chunkIndex: Int) async throws -> URL {
        // Create temporary file for chunk
        let tempDir = FileManager.default.temporaryDirectory
        let chunkURL = tempDir.appendingPathComponent("chunk_\(chunkIndex)_\(UUID().uuidString).m4a")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: chunkURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.networkError(NSError(
                domain: "AudioChunking",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create export session for chunk"]
            ))
        }

        exportSession.outputURL = chunkURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        // Export chunk
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: chunkURL)
                case .failed:
                    let error = exportSession.error ?? NSError(
                        domain: "AudioChunking",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Chunk export failed"]
                    )
                    continuation.resume(throwing: TranscriptionError.networkError(error))
                case .cancelled:
                    continuation.resume(throwing: TranscriptionError.cancelled)
                default:
                    continuation.resume(throwing: TranscriptionError.networkError(NSError(
                        domain: "AudioChunking",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Chunk export ended with status: \(exportSession.status.rawValue)"]
                    )))
                }
            }
        }
    }

    private func transcribeWithRetry(
        url: URL,
        languageHint: String?,
        onDevicePreferred: Bool,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken,
        retryCount: Int
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

        // Request verbose_json format to get timestamps for speaker detection
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)

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

                // Parse verbose_json response with segments
                if let segments = json?["segments"] as? [[String: Any]] {
                    let transcript = formatTranscriptWithSpeakers(segments: segments)

                    progress(1.0)

                    // Cleanup compressed file if we created one
                    if processedURL != url {
                        try? FileManager.default.removeItem(at: processedURL)
                        print("🔤 🧹 Cleaned up compressed file")
                    }

                    return transcript
                }

                // Fallback to plain text if segments not available
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
                        return try await transcribeWithRetry(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken, retryCount: retryCount + 1)
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
                        return try await transcribeWithRetry(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken, retryCount: retryCount + 1)
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
                        return try await transcribeWithRetry(url: url, languageHint: languageHint, onDevicePreferred: onDevicePreferred, progress: progress, cancelToken: cancelToken, retryCount: retryCount + 1)
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

    // MARK: - Speaker Diarization

    private func formatTranscriptWithSpeakers(segments: [[String: Any]]) -> String {
        guard !segments.isEmpty else { return "" }

        var result: [String] = []
        var currentSpeaker = 1
        var lastEndTime: Double = 0.0

        for segment in segments {
            guard let text = segment["text"] as? String,
                  let startTime = segment["start"] as? Double,
                  let endTime = segment["end"] as? Double else {
                continue
            }

            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }

            // Detect speaker change based on pause duration and conversation patterns
            let pauseDuration = startTime - lastEndTime
            let shouldChangeSpeaker = detectSpeakerChange(
                pauseDuration: pauseDuration,
                previousText: result.last,
                currentText: trimmedText,
                isFirstSegment: result.isEmpty
            )

            if shouldChangeSpeaker {
                currentSpeaker = currentSpeaker == 1 ? 2 : 1
            }

            // Add speaker label if not already present in text
            let speakerLabel = "Speaker \(currentSpeaker):"
            let formattedText: String
            if result.isEmpty || shouldChangeSpeaker {
                formattedText = "\n\(speakerLabel) \(trimmedText)"
            } else {
                // Continue same speaker's text
                formattedText = " \(trimmedText)"
            }

            result.append(formattedText)
            lastEndTime = endTime
        }

        return result.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectSpeakerChange(
        pauseDuration: Double,
        previousText: String?,
        currentText: String,
        isFirstSegment: Bool
    ) -> Bool {
        // First segment always starts with Speaker 1
        if isFirstSegment {
            return false
        }

        // Long pause (> 2 seconds) suggests speaker change
        if pauseDuration > 2.0 {
            return true
        }

        // Medium pause (> 1 second) combined with conversation patterns
        if pauseDuration > 1.0 {
            // Check if previous text ended with question mark or statement
            let previousEndsWithQuestion = previousText?.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") ?? false

            // Check if current text starts with typical response patterns
            let currentLower = currentText.lowercased()
            let responseStarters = [
                "yes", "no", "yeah", "sure", "okay", "ok", "right", "exactly",
                "well", "so", "actually", "i think", "i mean", "maybe", "perhaps",
                "ja", "nee", "nou", "oke", "goed", "precies", "dus", "eigenlijk"  // Dutch
            ]

            let startsWithResponse = responseStarters.contains { currentLower.hasPrefix($0) }

            // Question followed by response = likely speaker change
            if previousEndsWithQuestion || startsWithResponse {
                return true
            }
        }

        return false
    }
}
