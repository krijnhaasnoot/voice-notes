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
                        .font(.body)
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
                Text(L10n.Progress.transcribing.localized(with: Int(progress * 100)))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
        case .summarizing(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text(L10n.Progress.summarizing.localized(with: Int(progress * 100)))
                    .font(.caption)
                    .foregroundColor(.orange)
            }

        case .transcribingPaused(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 80)
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle.fill")
                    Text("Transcribing paused: \(Int(progress * 100))%")
                }
                .font(.caption)
                .foregroundColor(.blue.opacity(0.7))
            }

        case .summarizingPaused(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 80)
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle.fill")
                    Text("Summarizing paused: \(Int(progress * 100))%")
                }
                .font(.caption)
                .foregroundColor(.orange.opacity(0.7))
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
        // Use the auto-generated title if available
        if !recording.title.isEmpty {
            return recording.title
        }
        
        // Fallback while title is being generated
        return L10n.Recording.newRecording.localized
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
