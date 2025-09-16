import SwiftUI

struct TranscriptionTestView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @State private var selectedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var shareText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Status Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status")
                            .font(.headline)
                        
                        Text(viewModel.statusText)
                            .foregroundColor(statusColor)
                            .font(.subheadline)
                        
                        if viewModel.isProcessing {
                            ProgressView(value: currentProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Test Controls
                    VStack(spacing: 12) {
                        Button("Test with Sample Recording") {
                            testWithSampleFile()
                        }
                        .disabled(viewModel.isProcessing)
                        
                        if viewModel.isProcessing {
                            Button("Cancel") {
                                viewModel.cancelProcessing()
                            }
                            .foregroundColor(.red)
                        }
                        
                        if !viewModel.transcript.isEmpty {
                            Button("Retry Summary") {
                                Task {
                                    await viewModel.retrySummarization()
                                }
                            }
                            .disabled(viewModel.isSummarizing)
                        }
                    }
                    .padding()
                    
                    // Transcript Section
                    if !viewModel.transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Transcript (\(viewModel.transcript.count) chars)")
                                .font(.headline)
                            
                            Text(viewModel.transcript)
                                .font(.body)
                                .padding()
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Summary Section
                    if !viewModel.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AI Summary (\(viewModel.summary.count) chars)")
                                .font(.headline)
                            
                            Text(viewModel.summary)
                                .font(.body)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Share Section
                    if viewModel.hasContent {
                        VStack(spacing: 10) {
                            Text("Share Content")
                                .font(.headline)
                            
                            HStack(spacing: 20) {
                                Button(action: {
                                    shareTestContent()
                                }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    copyTestContent()
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Transcription Test")
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(activityItems: [shareText])
            }
        }
    }
    
    private var statusColor: Color {
        switch viewModel.status {
        case .idle: return .secondary
        case .transcribing, .summarizing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
    
    private var currentProgress: Double {
        if viewModel.isTranscribing {
            return viewModel.transcriptionProgress
        } else if viewModel.isSummarizing {
            return viewModel.summarizationProgress
        }
        return 0.0
    }
    
    private func testWithSampleFile() {
        // Get the most recent recording file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
            
            let audioFiles = files.filter { url in
                ["m4a", "mp3", "wav", "aac"].contains(url.pathExtension.lowercased())
            }.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
            
            if let mostRecentFile = audioFiles.first {
                print("🎵 Testing with: \(mostRecentFile.lastPathComponent)")
                Task {
                    await viewModel.transcribe(fileURL: mostRecentFile)
                }
            } else {
                Task { @MainActor in
                    viewModel.errorMessage = "No audio files found. Record something first!"
                }
            }
            
        } catch {
            Task { @MainActor in
                viewModel.errorMessage = "Failed to find audio files: \(error.localizedDescription)"
            }
        }
    }
    
    private func shareTestContent() {
        var parts: [String] = []
        parts.append("Test Transcription Results")
        
        if !viewModel.transcript.isEmpty {
            parts.append("Transcript:\n\(viewModel.transcript)")
        }
        
        if !viewModel.summary.isEmpty {
            parts.append("Summary:\n\(viewModel.summary)")
        }
        
        shareText = parts.joined(separator: "\n\n")
        showingShareSheet = true
    }
    
    private func copyTestContent() {
        var parts: [String] = []
        
        if !viewModel.transcript.isEmpty {
            parts.append("Transcript:\n\(viewModel.transcript)")
        }
        
        if !viewModel.summary.isEmpty {
            parts.append("Summary:\n\(viewModel.summary)")
        }
        
        let content = parts.joined(separator: "\n\n")
        UIPasteboard.general.string = content
    }
}

#Preview {
    TranscriptionTestView()
}