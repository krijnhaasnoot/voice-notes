import Foundation
import AVFoundation

/// Utility to decode any iOS-supported audio file to **mono 16 kHz float32 PCM** suitable for whisper.cpp.
struct AudioPCM {

    /// Decodes and resamples to mono 16k f32. Calls `onProgress` with a 0...1 decode progress ratio.
    func decodeToMono16kFloat32(fileURL: URL, onProgress: ((Double) throws -> Void)? = nil) throws -> [Float] {
        let file = try AVAudioFile(forReading: fileURL)
        let srcFormat = file.processingFormat

        // Target format: 16k mono float32
        guard let dstFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: 16_000,
                                            channels: 1,
                                            interleaved: false) else {
            throw NSError(domain: "AudioPCM", code: 9, userInfo: [NSLocalizedDescriptionKey: "Kon doelformat niet aanmaken"])
        }

        guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else {
            throw NSError(domain: "AudioPCM", code: 10, userInfo: [NSLocalizedDescriptionKey: "Kon AVAudioConverter niet aanmaken"])
        }

        // Prepare buffers
        let frameCapacity: AVAudioFrameCount = 4096
        guard let dstBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: frameCapacity) else {
            throw NSError(domain: "AudioPCM", code: 12, userInfo: [NSLocalizedDescriptionKey: "Kon output buffer niet aanmaken"])
        }

        var output: [Float] = []
        let totalFrames = max(1, file.length)
        var processedFrames: AVAudioFramePosition = 0
        var finished = false

        while !finished {
            var error: NSError?

            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: inNumPackets) else {
                    outStatus.pointee = .noDataNow
                    return nil
                }

                do {
                    try file.read(into: srcBuffer)
                    if srcBuffer.frameLength == 0 {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    outStatus.pointee = .haveData
                    return srcBuffer
                } catch {
                    outStatus.pointee = .endOfStream
                    return nil
                }
            }

            let status = converter.convert(to: dstBuffer, error: &error, withInputFrom: inputBlock)

            if status == .error {
                throw error ?? NSError(domain: "AudioPCM", code: 11, userInfo: [NSLocalizedDescriptionKey: "Audio conversie-fout"])
            }

            if dstBuffer.frameLength > 0, let ch0 = dstBuffer.floatChannelData?.pointee {
                let count = Int(dstBuffer.frameLength)
                output.append(contentsOf: UnsafeBufferPointer(start: ch0, count: count))
            }

            processedFrames = file.framePosition
            try onProgress?(Double(processedFrames) / Double(totalFrames))

            if status == .endOfStream {
                finished = true
            }
        }

        return output
    }
}
