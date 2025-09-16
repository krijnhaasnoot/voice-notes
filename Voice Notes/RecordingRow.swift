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
                    Text(recording.title.isEmpty ? recording.fileName.replacingOccurrences(of: ".m4a", with: "") : recording.title)
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
            if let transcript = recording.transcript, !transcript.isEmpty {
                Text(transcript.prefix(100) + (transcript.count > 100 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text("Processing complete")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
        case .idle:
            if let transcript = recording.transcript, !transcript.isEmpty {
                Text(transcript.prefix(100) + (transcript.count > 100 ? "..." : ""))
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
}