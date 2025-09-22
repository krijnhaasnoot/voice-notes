import SwiftUI

struct RecordingRow: View {
    let recording: Recording
    let onCancel: (() -> Void)?
    
    init(recording: Recording, onCancel: (() -> Void)? = nil) {
        self.recording = recording
        self.onCancel = onCancel
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(recording.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                statusView
            }
            
            Spacer()
            
            if recording.status.isProcessing && onCancel != nil {
                Button(action: { onCancel?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch recording.status {
        case .transcribing(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("Transcribing... \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
        case .summarizing(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("Summarizing... \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
        case .failed(let reason):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                Text("Failed: \(reason)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            
        case .done:
            if !previewText.isEmpty {
                Text(previewText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("Processing complete")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
        case .idle:
            if !previewText.isEmpty {
                Text(previewText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("Tap to view details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Properties & Functions
    
    private var displayTitle: String {
        // 1. Use explicit title if set
        if !recording.title.isEmpty {
            return recording.title
        }
        
        // 2. Extract title from AI summary if available
        if let summary = recording.summary, !summary.isEmpty {
            if let aiTitle = extractTitleFromSummary(summary) {
                return aiTitle
            }
        }
        
        // 3. Fall back to formatted filename
        let base = recording.fileName
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "Untitled" : base
    }
    
    private func extractTitleFromSummary(_ summary: String) -> String? {
        let lines = summary.components(separatedBy: .newlines)
        
        // Look for common title patterns from AI summaries
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Match patterns like "**Title**", "**Session Title**", "**Topic**"
            if trimmed.hasPrefix("**") && trimmed.contains("**") {
                // Extract text after the first title-like pattern
                if trimmed.contains("Title") || trimmed.contains("Topic") || trimmed.contains("Session") {
                    // Look for the next non-empty line as the actual title content
                    if let titleIndex = lines.firstIndex(of: line) {
                        let nextIndex = titleIndex + 1
                        if nextIndex < lines.count {
                            let titleContent = lines[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                            if !titleContent.isEmpty && !titleContent.hasPrefix("**") {
                                return titleContent.count > 40 ? String(titleContent.prefix(40)) + "..." : titleContent
                            }
                        }
                    }
                }
            }
            
            // Alternative: Look for first non-header line if it starts after a title marker
            if trimmed.hasPrefix("**Title**") || trimmed.hasPrefix("**Session Title**") || trimmed.hasPrefix("**Topic**") {
                // Skip this header line and get the next meaningful content
                if let titleIndex = lines.firstIndex(of: line) {
                    for i in (titleIndex + 1)..<lines.count {
                        let content = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !content.isEmpty && !content.hasPrefix("**") {
                            return content.count > 40 ? String(content.prefix(40)) + "..." : content
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private var previewText: String {
        // Prioritize AI summary content over raw transcript
        if let summary = recording.summary, !summary.isEmpty {
            // Extract preview content from AI summary, skipping title headers
            let summaryPreview = extractPreviewFromSummary(summary)
            if !summaryPreview.isEmpty {
                return summaryPreview
            }
        }
        // Fall back to transcript if no meaningful summary content
        if let transcript = recording.transcript, !transcript.isEmpty {
            return String(transcript.prefix(100)) + (transcript.count > 100 ? "..." : "")
        }
        return ""
    }
    
    private func extractPreviewFromSummary(_ summary: String) -> String {
        let lines = summary.components(separatedBy: .newlines)
        
        // Skip title/header lines and find the first meaningful content
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines, title headers, and section markers
            if trimmed.isEmpty || 
               trimmed.hasPrefix("**") || 
               trimmed.hasPrefix("#") ||
               trimmed.count < 10 {
                continue
            }
            
            // Return first meaningful content line as preview
            return trimmed.count > 100 ? String(trimmed.prefix(100)) + "..." : trimmed
        }
        
        // If no meaningful content found, return first part of summary
        return String(summary.prefix(100)) + (summary.count > 100 ? "..." : "")
    }
}