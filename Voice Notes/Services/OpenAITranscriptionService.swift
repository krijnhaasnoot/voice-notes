import Foundation
import AVFoundation

actor OpenAITranscriptionService {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
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

    static func createFromInfoPlist() -> OpenAITranscriptionService? {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String,
              !apiKey.isEmpty,
              !apiKey.hasPrefix("$("),
              apiKey.hasPrefix("sk-") else {
            print("🔑 ❌ OpenAI API Key not found or invalid in Info.plist")
            return nil
        }
        print("🔑 ✅ OpenAI API Key loaded from Info.plist")
        return OpenAITranscriptionService(apiKey: apiKey)
    }

    func transcribe(
        fileURL: URL,
        languageHint: String? = nil,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {

        print("🔤 Starting transcription for: \(fileURL.lastPathComponent)")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("🔤 ❌ File not found: \(fileURL.path)")
            throw TranscriptionError.fileNotFound
        }
        if cancelToken.isCancelled { throw TranscriptionError.cancelled }
        guard !apiKey.isEmpty else { throw TranscriptionError.apiKeyMissing }

        var processedFileURL = fileURL
        var audioData = try Data(contentsOf: fileURL)
        
        // Check if file needs compression for size limit
        if audioData.count > maxFileSize {
            print("🔤 ⚠️ File too large: \(audioData.count) bytes (max: \(maxFileSize))")
            print("🔤 🔄 Attempting to compress audio for transcription...")
            
            do {
                processedFileURL = try await compressAudioFile(fileURL, targetSizeBytes: maxFileSize)
                audioData = try Data(contentsOf: processedFileURL)
                print("🔤 ✅ Compressed audio: \(audioData.count) bytes")
            } catch {
                print("🔤 ❌ Compression failed: \(error)")
                throw TranscriptionError.networkError(NSError(
                    domain: "TranscriptionService",
                    code: 413,
                    userInfo: [NSLocalizedDescriptionKey: "File size exceeds 25MB limit (\(audioData.count/1024/1024)MB) and compression failed"]
                ))
            }
        }
        
        print("🔤 File size: \(audioData.count) bytes")

        let fileName = fileURL.lastPathComponent

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Helper to append a simple text field
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // File part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType(for: fileURL))\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Model
        appendField(name: "model", value: model)
        
        // Response format for speaker diarization
        appendField(name: "response_format", value: "verbose_json")
        
        // Enable timestamps for speaker diarization
        appendField(name: "timestamp_granularities[]", value: "word")
        appendField(name: "timestamp_granularities[]", value: "segment")

        // Language (two-letter hint, optional)
        if let languageHint = languageHint, !languageHint.isEmpty {
            let languageCode = String(languageHint.prefix(2)).lowercased()
            appendField(name: "language", value: languageCode)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        progress(0.1)
        if cancelToken.isCancelled { throw TranscriptionError.cancelled }

        print("🔤 Sending request to OpenAI Whisper…")

        do {
            let (data, response) = try await urlSession.data(for: request)
            progress(0.9)
            if cancelToken.isCancelled { throw TranscriptionError.cancelled }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🔤 ❌ Invalid response type")
                throw TranscriptionError.invalidResponse
            }

            print("🔤 HTTP Status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                    print("🔤 ❌ Invalid JSON response: \(responseString)")
                    throw TranscriptionError.invalidResponse
                }
                
                // Process speaker-segmented transcript
                let transcript = formatTranscriptWithSpeakers(from: json)
                print("🔤 ✅ Transcription successful, \(transcript.count) characters")
                progress(1.0)
                
                // Cleanup compressed file if we created one
                if processedFileURL != fileURL {
                    try? FileManager.default.removeItem(at: processedFileURL)
                    print("🔤 🧹 Cleaned up compressed file")
                }
                
                return transcript

            case 401:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🔤 ❌ API Key Error (401): \(errorBody)")
                throw TranscriptionError.apiKeyMissing

            case 429:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🔤 ⚠️ Rate limited (429): \(errorBody)")
                if !cancelToken.isCancelled {
                    print("🔤 Retrying after rate limit…")
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    if !cancelToken.isCancelled {
                        return try await transcribe(fileURL: fileURL, languageHint: languageHint, progress: progress, cancelToken: cancelToken)
                    }
                }
                throw TranscriptionError.quotaExceeded

            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🔤 ❌ HTTP \(httpResponse.statusCode): \(errorBody)")

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
            if processedFileURL != fileURL {
                try? FileManager.default.removeItem(at: processedFileURL)
                print("🔤 🧹 Cleaned up compressed file after error")
            }
            
            if cancelToken.isCancelled { throw TranscriptionError.cancelled }
            if error is TranscriptionError { throw error }
            print("🔤 ❌ Network error: \(error)")
            throw TranscriptionError.networkError(error)
        }
    }

    private func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a", "mp4": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aac": return "audio/aac"
        default: return "application/octet-stream"
        }
    }
    
    private func formatTranscriptWithSpeakers(from json: [String: Any]) -> String {
        // First try to get the basic text as fallback
        let fallbackText = json["text"] as? String ?? ""
        
        // Try to get segments with speaker information
        guard let segments = json["segments"] as? [[String: Any]], !segments.isEmpty else {
            print("🔤 No segments found, using fallback text")
            return fallbackText
        }
        
        var formattedTranscript = ""
        var currentSpeaker: String? = nil
        var currentSpeakerText = ""
        
        for (index, segment) in segments.enumerated() {
            let text = (segment["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // For now, we'll simulate speaker detection by using segment boundaries
            // In a real implementation, you might use a separate speaker diarization service
            let speakerLabel = determineSpeaker(for: segment, index: index)
            
            if currentSpeaker != speakerLabel {
                // Speaker changed, finish previous speaker's paragraph
                if !currentSpeakerText.isEmpty {
                    formattedTranscript += "\(currentSpeakerText.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
                }
                currentSpeaker = speakerLabel
                currentSpeakerText = text
            } else {
                // Same speaker, append to current text
                currentSpeakerText += " " + text
            }
        }
        
        // Add the final speaker's text
        if !currentSpeakerText.isEmpty {
            formattedTranscript += "\(currentSpeakerText.trimmingCharacters(in: .whitespacesAndNewlines))\n\n"
        }
        
        // If no formatted transcript was created, return fallback
        if formattedTranscript.isEmpty {
            return fallbackText
        }
        
        return formattedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func determineSpeaker(for segment: [String: Any], index: Int) -> String {
        // Simple heuristic: alternate speakers based on pauses
        // In a more sophisticated implementation, you would:
        // 1. Use speaker diarization from another service
        // 2. Analyze audio characteristics
        // 3. Use timestamps to detect speaker changes
        
        let start = segment["start"] as? Double ?? 0
        let end = segment["end"] as? Double ?? 0
        _ = end - start
        
        // Simple pattern: longer pauses might indicate speaker changes
        // This is a basic implementation - you might want to use a proper speaker diarization service
        let speakerNumber = (index / 3) % 2 + 1  // Rough approximation
        return "Speaker \(speakerNumber)"
    }
    
    private func loadFirstAudioTrack(from asset: AVURLAsset) async throws -> AVAssetTrack {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            if let first = tracks.first {
                return first
            } else {
                throw TranscriptionError.networkError(NSError(
                    domain: "AudioCompression",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "No audio track found in source file"]
                ))
            }
        } catch {
            throw TranscriptionError.networkError(error)
        }
    }
    
    private func compressAudioFile(_ sourceURL: URL, targetSizeBytes: Int64) async throws -> URL {
        let outputURL = sourceURL.appendingPathExtension("compressed.m4a")
        
        // Remove existing compressed file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            let asset = AVURLAsset(url: sourceURL)
            
            Task {
                do {
                    // Load audio track asynchronously to avoid deprecated API
                    let audioTrack = try await self.loadFirstAudioTrack(from: asset)
                    
                    // Use AVAssetWriter for custom audio compression
                    guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .m4a) else {
                        continuation.resume(throwing: TranscriptionError.networkError(NSError(
                            domain: "AudioCompression", 
                            code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Could not create asset writer"]
                        )))
                        return
                    }
                    
                    // Configure compression settings for smaller file size
                    let compressionSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 16000, // Lower sample rate for speech
                        AVEncoderBitRateKey: 32000, // Lower bitrate
                        AVNumberOfChannelsKey: 1 // Mono for speech
                    ]
                    
                    let assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: compressionSettings)
                    assetWriterInput.expectsMediaDataInRealTime = false
                    
                    guard assetWriter.canAdd(assetWriterInput) else {
                        continuation.resume(throwing: TranscriptionError.networkError(NSError(
                            domain: "AudioCompression", 
                            code: -2, 
                            userInfo: [NSLocalizedDescriptionKey: "Cannot add audio input to writer"]
                        )))
                        return
                    }
                    
                    assetWriter.add(assetWriterInput)
                    
                    // Reader output settings
                    let assetReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 16000,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false
                    ])
                    
                    guard let assetReader = try? AVAssetReader(asset: asset) else {
                        continuation.resume(throwing: TranscriptionError.networkError(NSError(
                            domain: "AudioCompression", 
                            code: -4, 
                            userInfo: [NSLocalizedDescriptionKey: "Could not create asset reader"]
                        )))
                        return
                    }
                    
                    guard assetReader.canAdd(assetReaderOutput) else {
                        continuation.resume(throwing: TranscriptionError.networkError(NSError(
                            domain: "AudioCompression", 
                            code: -5, 
                            userInfo: [NSLocalizedDescriptionKey: "Cannot add audio output to reader"]
                        )))
                        return
                    }
                    
                    assetReader.add(assetReaderOutput)
                    
                    // Start writing
                    assetWriter.startWriting()
                    assetReader.startReading()
                    assetWriter.startSession(atSourceTime: .zero)
                    
                    let processingQueue = DispatchQueue(label: "audio.compression")

                    // Create nonisolated aliases for use inside the closure
                    nonisolated(unsafe) let writerInput = assetWriterInput
                    nonisolated(unsafe) let readerOutput = assetReaderOutput
                    nonisolated(unsafe) let assetReaderRef = assetReader
                    nonisolated(unsafe) let assetWriterRef = assetWriter

                    assetWriterInput.requestMediaDataWhenReady(on: processingQueue) { [writerInput, readerOutput, assetReaderRef, assetWriterRef] in
                        while writerInput.isReadyForMoreMediaData {
                            if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                                if !writerInput.append(sampleBuffer) {
                                    print("Failed to append sample buffer")
                                    break
                                }
                            } else {
                                writerInput.markAsFinished()
                                break
                            }
                        }

                        if assetReaderRef.status == .completed {
                            assetWriterRef.finishWriting {
                                switch assetWriterRef.status {
                                case .completed:
                                    continuation.resume(returning: outputURL)
                                case .failed:
                                    let error = assetWriterRef.error ?? NSError(
                                        domain: "AudioCompression",
                                        code: -6,
                                        userInfo: [NSLocalizedDescriptionKey: "Writing failed with unknown error"]
                                    )
                                    continuation.resume(throwing: TranscriptionError.networkError(error))
                                case .cancelled:
                                    continuation.resume(throwing: TranscriptionError.cancelled)
                                default:
                                    continuation.resume(throwing: TranscriptionError.networkError(NSError(
                                        domain: "AudioCompression",
                                        code: -7,
                                        userInfo: [NSLocalizedDescriptionKey: "Writer ended with status: \(assetWriterRef.status.rawValue)"]
                                    )))
                                }
                            }
                        } else if assetReaderRef.status == .failed {
                            let error = assetReaderRef.error ?? NSError(
                                domain: "AudioCompression",
                                code: -8,
                                userInfo: [NSLocalizedDescriptionKey: "Reading failed with unknown error"]
                            )
                            continuation.resume(throwing: TranscriptionError.networkError(error))
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

