import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let date: Date
    let duration: TimeInterval
    let transcript: String?
    let summary: String?
    let rawSummary: String?
    let status: Status
    let languageHint: String?
    let transcriptLastUpdated: Date?
    let summaryLastUpdated: Date?
    let title: String
    let detectedMode: String?
    let preferredSummaryProvider: String? // AIProviderType.rawValue
    var tags: [String]
    let transcriptionModel: String? // e.g., "Local (Tiny)", "Cloud (OpenAI Whisper)"
    
    init(fileName: String, date: Date = Date(), duration: TimeInterval = 0, transcript: String? = nil, summary: String? = nil, rawSummary: String? = nil, status: Status = .idle, languageHint: String? = nil, transcriptLastUpdated: Date? = nil, summaryLastUpdated: Date? = nil, title: String = "", detectedMode: String? = nil, preferredSummaryProvider: String? = nil, tags: [String] = [], transcriptionModel: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.fileName = fileName
        self.date = date
        self.duration = duration
        self.transcript = transcript
        self.summary = summary
        self.rawSummary = rawSummary
        self.status = status
        self.languageHint = languageHint
        self.transcriptLastUpdated = transcriptLastUpdated
        self.summaryLastUpdated = summaryLastUpdated
        self.title = title
        self.detectedMode = detectedMode
        self.preferredSummaryProvider = preferredSummaryProvider
        self.tags = tags.normalized()
        self.transcriptionModel = transcriptionModel
    }
    
    // Convenience computed property for AI provider
    var aiProviderType: AIProviderType? {
        get {
            guard let providerString = preferredSummaryProvider else { return nil }
            return AIProviderType(rawValue: providerString)
        }
    }
    
    // Method to create a copy with different provider
    func withProvider(_ provider: AIProviderType?) -> Recording {
        return Recording(
            fileName: fileName,
            date: date,
            duration: duration,
            transcript: transcript,
            summary: summary,
            rawSummary: rawSummary,
            status: status,
            languageHint: languageHint,
            transcriptLastUpdated: transcriptLastUpdated,
            summaryLastUpdated: summaryLastUpdated,
            title: title,
            detectedMode: detectedMode,
            preferredSummaryProvider: provider?.rawValue,
            tags: tags,
            transcriptionModel: transcriptionModel,
            id: id
        )
    }

    // Method to create a copy with updated tags
    func withTags(_ newTags: [String]) -> Recording {
        return Recording(
            fileName: fileName,
            date: date,
            duration: duration,
            transcript: transcript,
            summary: summary,
            rawSummary: rawSummary,
            status: status,
            languageHint: languageHint,
            transcriptLastUpdated: transcriptLastUpdated,
            summaryLastUpdated: summaryLastUpdated,
            title: title,
            detectedMode: detectedMode,
            preferredSummaryProvider: preferredSummaryProvider,
            tags: newTags,
            transcriptionModel: transcriptionModel,
            id: id
        )
    }
    
    enum Status: Codable, Equatable {
        case idle
        case transcribing(progress: Double)
        case transcribingPaused(progress: Double)
        case summarizing(progress: Double)
        case summarizingPaused(progress: Double)
        case done
        case failed(reason: String)

        var isProcessing: Bool {
            switch self {
            case .transcribing, .transcribingPaused, .summarizing, .summarizingPaused:
                return true
            default:
                return false
            }
        }

        var isPaused: Bool {
            switch self {
            case .transcribingPaused, .summarizingPaused:
                return true
            default:
                return false
            }
        }

        var progress: Double? {
            switch self {
            case .transcribing(let progress), .transcribingPaused(let progress),
                 .summarizing(let progress), .summarizingPaused(let progress):
                return progress
            default:
                return nil
            }
        }
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var isTranscribing: Bool {
        if case .transcribing = status { return true }
        return false
    }
    
    var isSummarizing: Bool {
        if case .summarizing = status { return true }
        return false
    }
    
    var resolvedFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }
    
    var resolvedCreatedDate: Date {
        return date
    }
    
    var resolvedSizeBytes: Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: resolvedFileURL.path)
            return attributes[.size] as? Int ?? 0
        } catch {
            return 0
        }
    }
}