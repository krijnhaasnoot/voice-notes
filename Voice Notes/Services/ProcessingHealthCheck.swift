import Foundation
import Network
import SystemConfiguration

enum ProcessingHealthStatus {
    case healthy
    case warning(message: String, suggestion: String)
    case critical(message: String, suggestion: String)
}

enum NetworkQuality {
    case excellent // Fast WiFi/5G
    case good      // WiFi/4G
    case poor      // 3G/slow connection
    case offline   // No connection
}

@MainActor
class ProcessingHealthCheck: ObservableObject {
    static let shared = ProcessingHealthCheck()

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkHealthMonitor")

    @Published var currentNetworkQuality: NetworkQuality = .good
    @Published var isConnected: Bool = true

    private var currentPath: NWPath?

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.currentPath = path
                self?.isConnected = path.status == .satisfied
                self?.updateNetworkQuality(path)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func updateNetworkQuality(_ path: NWPath) {
        if path.status != .satisfied {
            currentNetworkQuality = .offline
            return
        }

        // Check connection type
        if path.usesInterfaceType(.wifi) {
            currentNetworkQuality = .excellent
        } else if path.usesInterfaceType(.cellular) {
            // Try to determine cellular quality
            currentNetworkQuality = .good // Default to good for cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            currentNetworkQuality = .excellent
        } else {
            currentNetworkQuality = .good
        }
    }

    // MARK: - Pre-flight Checks

    func checkTranscriptionReadiness(duration: TimeInterval, fileSize: Int64) -> ProcessingHealthStatus {
        // Check network connectivity
        if !isConnected {
            return .critical(
                message: "No internet connection",
                suggestion: "Connect to WiFi or enable cellular data, then tap Resume to continue"
            )
        }

        // Check network quality for large files
        let fileSizeMB = Double(fileSize) / (1024 * 1024)

        if currentNetworkQuality == .offline {
            return .critical(
                message: "No internet connection",
                suggestion: "Connect to WiFi or enable cellular data, then tap Resume to continue"
            )
        }

        if currentNetworkQuality == .poor && fileSizeMB > 5 {
            return .warning(
                message: "Slow connection detected",
                suggestion: "Connect to WiFi for faster processing, or continue with cellular"
            )
        }

        // Check for very large files
        if duration > 3600 { // 1 hour
            return .warning(
                message: "Very long recording (\(formatDuration(duration)))",
                suggestion: "This may take several minutes to process"
            )
        }

        if fileSizeMB > 50 {
            return .warning(
                message: "Large file size (\(String(format: "%.1f", fileSizeMB)) MB)",
                suggestion: "Processing may take longer than usual"
            )
        }

        return .healthy
    }

    func checkSummarizationReadiness(transcriptLength: Int) -> ProcessingHealthStatus {
        // Check network connectivity
        if !isConnected {
            return .critical(
                message: "No internet connection",
                suggestion: "Connect to WiFi or enable cellular data, then tap Resume to continue"
            )
        }

        if currentNetworkQuality == .offline {
            return .critical(
                message: "No internet connection",
                suggestion: "Connect to WiFi or enable cellular data, then tap Resume to continue"
            )
        }

        // Check for very long transcripts
        if transcriptLength > 50000 { // ~50k characters
            return .warning(
                message: "Very long transcript (\(transcriptLength / 1000)k characters)",
                suggestion: "Summarization may take 30+ seconds"
            )
        }

        return .healthy
    }

    // MARK: - Runtime Health Monitoring

    func monitorTranscriptionHealth(startTime: Date, progress: Double, timeout: TimeInterval = 10.0) -> ProcessingHealthStatus {
        let elapsed = Date().timeIntervalSince(startTime)

        // Within first 10 seconds
        if elapsed < timeout {
            // If no progress after 8 seconds, likely stuck
            if elapsed > 8.0 && progress < 0.01 {
                return .critical(
                    message: "Transcription not starting",
                    suggestion: "Check your internet connection and tap Resume to retry"
                )
            }

            // If very slow progress
            if elapsed > 5.0 && progress < 0.05 {
                if currentNetworkQuality == .poor || !isConnected {
                    return .warning(
                        message: "Slow network detected",
                        suggestion: "Switch to WiFi or wait for better connection"
                    )
                }
            }
        }

        // After 10 seconds, check if stuck
        if elapsed > 15.0 {
            let expectedProgress = elapsed / 120.0 // Assume ~2 min for full transcription
            if progress < expectedProgress * 0.3 { // Less than 30% of expected
                return .warning(
                    message: "Processing slower than expected",
                    suggestion: "Poor connection detected. Consider pausing and resuming on WiFi"
                )
            }
        }

        return .healthy
    }

    func monitorSummarizationHealth(startTime: Date, progress: Double, timeout: TimeInterval = 10.0) -> ProcessingHealthStatus {
        let elapsed = Date().timeIntervalSince(startTime)

        // Within first 10 seconds
        if elapsed < timeout {
            // If no progress after 8 seconds, likely stuck
            if elapsed > 8.0 && progress < 0.01 {
                return .critical(
                    message: "AI summarization not starting",
                    suggestion: "Check your internet connection and tap Resume to retry"
                )
            }
        }

        // After 10 seconds, check if stuck
        if elapsed > 15.0 && progress < 0.1 {
            if !isConnected || currentNetworkQuality == .poor {
                return .warning(
                    message: "Slow network detected",
                    suggestion: "Switch to WiFi or wait for better connection"
                )
            }
        }

        return .healthy
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var networkStatusDescription: String {
        switch currentNetworkQuality {
        case .excellent:
            return "Excellent connection"
        case .good:
            return "Good connection"
        case .poor:
            return "Poor connection"
        case .offline:
            return "No connection"
        }
    }
}
