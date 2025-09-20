import SwiftUI
import AVFoundation

struct RecordingDetailView: View {
    let recordingId: UUID
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var documentStore: DocumentStore
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var showingDeleteAlert = false
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = ["Transcript wordt nog gemaakt…"]
    @State private var showingRawSummary = false
    @State private var isEditingTranscript = false
    @State private var editedTranscript = ""
    @State private var showingSaveToDocuments = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var savedDocumentId: UUID?
    @State private var extractedActionItems: [String] = []
    @State private var selectedActionItems: Set<String> = []
    @State private var quickAddText = ""
    @State private var showingQuickAddField = false
    @State private var showingSummarySettings = false
    @State private var selectedSummaryMode: SummaryMode = .personal
    @State private var selectedSummaryLength: SummaryLength = .standard
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Group {
                if let recording = recordingsManager.recordings.first(where: { $0.id == recordingId }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection(recording)
                            recordingInfoSection(recording)
                            playbackSection(recording)
                            transcriptSection(recording)
                            summarySection(recording)
                            actionItemsSection(recording)
                            
                            // Share/Copy buttons at bottom
                            if hasContent(recording) {
                                shareSection(recording)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack {
                        Text("Recording not found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Recording Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: HStack(spacing: 16) {
                    if let recording = recordingsManager.recordings.first(where: { $0.id == recordingId }),
                       let rawSummary = recording.rawSummary, !rawSummary.isEmpty {
                        Button("RAW") {
                            showingRawSummary = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    
                    // Visual separator between delete and done
                    Rectangle()
                        .frame(width: 1, height: 20)
                        .foregroundColor(.secondary.opacity(0.3))
                    
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                }
            )
            .alert("Delete Recording", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteRecording()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this recording? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingRawSummary) {
            if let recording = recordingsManager.recordings.first(where: { $0.id == recordingId }),
               let rawSummary = recording.rawSummary {
                NavigationView {
                    ScrollView {
                        Text(rawSummary)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .textSelection(.enabled)
                    }
                    .navigationTitle("Raw AI Output")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.clear, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .navigationBarItems(trailing: Button("Done") {
                        showingRawSummary = false
                    })
                }
            }
        }
        .sheet(isPresented: $showingSaveToDocuments) {
            if let recording = recordingsManager.recordings.first(where: { $0.id == recordingId }) {
                SaveToDocumentsSheet(
                    recording: recording,
                    selectedItems: extractedActionItems,
                    documentStore: documentStore,
                    onSaved: { documentId, itemCount in
                        savedDocumentId = documentId
                        let docTitle = documentStore.documents.first { $0.id == documentId }?.title ?? "List"
                        toastMessage = "Added \(itemCount) items to \(docTitle)"
                        showingToast = true
                        
                        // Auto-hide after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            showingToast = false
                        }
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if showingToast {
                toastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingToast)
            }
        }
        .onAppear {
            // Load current AI settings
            let modeString = UserDefaults.standard.string(forKey: "defaultMode") ?? SummaryMode.personal.rawValue
            let lengthString = UserDefaults.standard.string(forKey: "defaultSummaryLength") ?? SummaryLength.standard.rawValue
            
            selectedSummaryMode = SummaryMode(rawValue: modeString) ?? .personal
            selectedSummaryLength = SummaryLength(rawValue: lengthString) ?? .standard
        }
    }
    
    private func headerSection(_ recording: Recording) -> some View {
        HStack(spacing: 12) {
            Button(action: { togglePlayback(recording) }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title.isEmpty ? recording.fileName.replacingOccurrences(of: ".m4a", with: "") : recording.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
    
    private func recordingInfoSection(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recording Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            InfoRow(label: "Date & Time", value: recording.formattedDate)
            InfoRow(label: "Duration", value: recording.formattedDuration)
            InfoRow(label: "File", value: recording.fileName)
            InfoRow(label: "Size", value: formatBytes(recording.resolvedSizeBytes))
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func playbackSection(_ recording: Recording) -> some View {
        VStack(spacing: 12) {
            Text("Playback")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { togglePlayback(recording) }) {
                HStack {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                    
                    VStack(alignment: .leading) {
                        Text(isPlaying ? "Playing" : "Play Recording")
                            .font(.headline)
                        Text(recording.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func transcriptSection(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let transcript = recording.transcript, !transcript.isEmpty {
                    if isEditingTranscript {
                        HStack {
                            Button("Cancel") {
                                isEditingTranscript = false
                                editedTranscript = ""
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Button("Save") {
                                saveTranscriptEdits(for: recording)
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        }
                    } else {
                        Button("Edit") {
                            startEditingTranscript(transcript)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                } else if case .transcribing(let progress) = recording.status {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if case .failed = recording.status, recording.transcript == nil {
                    Button("Retry") {
                        recordingsManager.retryTranscription(for: recording)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if let transcript = recording.transcript, !transcript.isEmpty {
                if isEditingTranscript {
                    TextEditor(text: $editedTranscript)
                        .font(.body)
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                        .frame(minHeight: 100)
                } else {
                    Text(transcript)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                }
            } else if case .transcribing = recording.status {
                HStack {
                    ProgressView()
                    Text("Processing audio...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if case .failed(let reason) = recording.status {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Transcription failed")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Text(reason)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
            } else {
                Text("No transcript available")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func summarySection(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if case .summarizing(let progress) = recording.status {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if case .failed = recording.status, recording.transcript != nil {
                    summaryControlButtons(for: recording)
                } else if let transcript = recording.transcript, !transcript.isEmpty, recording.summary != nil {
                    summaryControlButtons(for: recording)
                } else if recording.transcript != nil {
                    // Show settings button even when waiting for summary
                    Button(action: { showingSummarySettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // AI Summary Settings (when shown)
            if showingSummarySettings {
                aiSummarySettingsView(for: recording)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            
            // Show detected mode if available
            if let detectedMode = recording.detectedMode, !detectedMode.isEmpty {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Detected mode: \(detectedMode)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let summary = recording.summary, !summary.isEmpty {
                FormattedSummaryText(summary: summary)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            } else if case .summarizing = recording.status {
                HStack {
                    ProgressView()
                    Text("Creating summary...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if case .failed(let reason) = recording.status, recording.transcript != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Summary generation failed")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Text(reason)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
            } else if recording.transcript != nil {
                Text("Summary will be generated after transcription")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            } else {
                Text("No summary available")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func togglePlayback(_ recording: Recording) {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            playAudio(recording)
        }
    }
    
    private func playAudio(_ recording: Recording) {
        let audioURL = recording.resolvedFileURL
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = AudioPlayerDelegate { [self] in
                isPlaying = false
            }
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    private func deleteRecording() {
        audioPlayer?.stop()
        isPlaying = false
        
        recordingsManager.delete(id: recordingId)
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func shareSection(_ recording: Recording) -> some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Button(action: {
                    showingSaveToDocuments = true
                }) {
                    Label("Save to List", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
                
                HStack(spacing: 8) {
                    Button(action: {
                        shareRecording(recording)
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        copyRecording(recording)
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
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func actionItemsSection(_ recording: Recording) -> some View {
        let actionItems = extractActionItems(from: recording)
        
        // Always show the section, but with different content if empty
        if actionItems.isEmpty {
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    Text("Action Items")
                        .font(.headline)
                        .fontWeight(.semibold)
                        HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("No action items detected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(6)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            )
        }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Action Items")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Quick add button
                    Button(action: {
                        showingQuickAddField.toggle()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    
                    // Select All/None toggle
                    Button(selectedActionItems.count == actionItems.count ? "Deselect All" : "Select All") {
                        if selectedActionItems.count == actionItems.count {
                            selectedActionItems.removeAll()
                        } else {
                            selectedActionItems = Set(actionItems)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Text("(\(actionItems.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Quick add intent field
                if showingQuickAddField {
                    HStack {
                        TextField("add to list Personal", text: $quickAddText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                processQuickAddIntent()
                            }
                        
                        Button("Add") {
                            processQuickAddIntent()
                        }
                        .disabled(quickAddText.isEmpty)
                    }
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(Array(actionItems.enumerated()), id: \.offset) { index, item in
                        ActionItemRow(
                            item: item,
                            isSelected: selectedActionItems.contains(item),
                            onSelectionToggle: {
                                if selectedActionItems.contains(item) {
                                    selectedActionItems.remove(item)
                                } else {
                                    selectedActionItems.insert(item)
                                }
                            },
                            onSave: { [item] in
                                showQuickSaveMenu(for: [item])
                            }
                        )
                    }
                }
                
                Button(action: {
                    extractedActionItems = Array(selectedActionItems.isEmpty ? Set(actionItems) : selectedActionItems)
                    showingSaveToDocuments = true
                }) {
                    let selectedCount = selectedActionItems.count
                    let buttonText = selectedCount == 0 ? "Save All to List (\(actionItems.count))" : "Save Selected to List (\(selectedCount))"
                    
                    Label(buttonText, systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedCount == 0 ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(actionItems.isEmpty)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        )
    }
    
    private var toastView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(toastMessage)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                if documentStore.lastAdd != nil {
                    Button("Undo") {
                        documentStore.undoLastAdd()
                        showingToast = false
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
                }
                
                if let docId = savedDocumentId {
                    Button("Open") {
                        // Navigate to document - would need navigation coordination
                        showingToast = false
                        documentStore.markOpened(docId)
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.85))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }
    
    private func extractActionItems(from recording: Recording) -> [String] {
        var items: [String] = []
        
        // Extract from summary if available
        if let summary = recording.summary, !summary.isEmpty {
            items = parseActionItemsFromSummary(summary)
        }
        
        // If no items found in summary, try transcript
        if items.isEmpty, let transcript = recording.transcript, !transcript.isEmpty {
            items = parseActionItemsFromTranscript(transcript)
        }
        
        // Filter to only include actionable items
        return items.filter { $0.isLikelyAction }
    }
    
    private func parseActionItemsFromSummary(_ summary: String) -> [String] {
        var items: [String] = []
        let lines = summary.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for bullet points or numbered items
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let item = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty && item.count > 3 {
                    items.append(item)
                }
            } else if let regex = try? NSRegularExpression(pattern: "^\\d+\\.", options: []) {
                let range = NSRange(location: 0, length: trimmed.count)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    let item = regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.isEmpty && item.count > 3 {
                        items.append(item)
                    }
                }
            }
        }
        
        return Array(items.prefix(10))
    }
    
    private func parseActionItemsFromTranscript(_ transcript: String) -> [String] {
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var items: [String] = []
        
        let actionKeywords = ["need to", "should", "must", "have to", "remember to", "don't forget", "make sure"]
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()
            
            if actionKeywords.contains(where: { lowercased.contains($0) }) && trimmed.count > 10 {
                items.append(trimmed)
            }
        }
        
        return Array(items.prefix(5))
    }
    
    private func showQuickSaveMenu(for items: [String]) {
        // Implementation for long-press quick save menu
        // This would show the 3 most recent documents
    }
    
    private func hasContent(_ recording: Recording) -> Bool {
        return (recording.transcript != nil && !recording.transcript!.isEmpty) || 
               (recording.summary != nil && !recording.summary!.isEmpty)
    }
    
    private func shareRecording(_ recording: Recording) {
        shareItems = ["Transcript wordt nog gemaakt…"]
        isSharePresented = true
        
        Task {
            let transcript = recording.transcript
            let summary = recording.summary
            
            await MainActor.run {
                shareItems = [Voice_Notes.makeShareText(for: recording, overrideTranscript: transcript, overrideSummary: summary)]
            }
        }
    }
    
    private func copyRecording(_ recording: Recording) {
        UIPasteboard.general.string = makeShareText(recording)
    }
    
    private func makeShareText(_ recording: Recording) -> String {
        return Voice_Notes.makeShareText(for: recording)
    }
    
    private func startEditingTranscript(_ transcript: String) {
        editedTranscript = transcript
        isEditingTranscript = true
    }
    
    private func saveTranscriptEdits(for recording: Recording) {
        let trimmedTranscript = editedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Update the transcript in the recording
        recordingsManager.updateRecording(recording.id, transcript: editedTranscript)
        
        // Auto-regenerate summary with the updated transcript if there was one before
        if recording.summary != nil && !trimmedTranscript.isEmpty {
            // Get the updated recording and retry summarization
            if let updatedRecording = recordingsManager.recordings.first(where: { $0.id == recording.id }) {
                recordingsManager.retrySummarization(for: updatedRecording)
            }
        }
        
        // Reset edit state
        isEditingTranscript = false
        editedTranscript = ""
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let b = Double(bytes)
        if b > 1_000_000 { return String(format: "%.1f MB", b/1_000_000) }
        if b > 1_000 { return String(format: "%.1f KB", b/1_000) }
        return "\(bytes) B"
    }
    
    // MARK: - Add to List Intent Handling
    private func handleAddToListIntent(_ phrase: String, items: [String], sourceRecordingId: UUID?) {
        guard !items.isEmpty else { return }
        
        let (targetName, preferredType) = parseAddToListIntent(phrase)
        guard !targetName.isEmpty else { return }
        
        let targetId = documentStore.ensureList(named: targetName, type: preferredType)
        documentStore.addItems(to: targetId, items: items, sourceRecordingId: sourceRecordingId)
        documentStore.markOpened(targetId)
        
        // Show success toast
        let listTitle = documentStore.documents.first { $0.id == targetId }?.title ?? targetName
        savedDocumentId = targetId
        toastMessage = "Added \(items.count) items to \(listTitle)"
        showingToast = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Auto-hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if showingToast {
                showingToast = false
            }
        }
    }
    
    private func parseAddToListIntent(_ phrase: String) -> (targetName: String, preferredType: DocumentType) {
        let lowercased = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern 1: "add to shopping list <name>"
        if let match = lowercased.range(of: #"add to shopping list\s+(.+)"#, options: .regularExpression) {
            let nameRange = lowercased.index(match.lowerBound, offsetBy: "add to shopping list ".count)..<match.upperBound
            let name = String(lowercased[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (name, .shopping)
        }
        
        // Pattern 2: "add to list <name>"
        if let match = lowercased.range(of: #"add to list\s+(.+)"#, options: .regularExpression) {
            let nameRange = lowercased.index(match.lowerBound, offsetBy: "add to list ".count)..<match.upperBound
            let name = String(lowercased[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (name, .todo)
        }
        
        // Pattern 3: "add to <name>" - fallback
        if let match = lowercased.range(of: #"add to\s+(.+)"#, options: .regularExpression) {
            let nameRange = lowercased.index(match.lowerBound, offsetBy: "add to ".count)..<match.upperBound
            let name = String(lowercased[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Determine type from name or content
            let type: DocumentType = name.contains("shop") || name.contains("grocery") || name.contains("store") ? .shopping : .todo
            return (name, type)
        }
        
        return ("", .todo)
    }
    
    private func processQuickAddIntent() {
        guard !quickAddText.isEmpty else { return }
        
        let selectedItems = Array(selectedActionItems)
        let itemsToAdd = selectedItems.isEmpty ? extractActionItems(from: recordingsManager.recordings.first(where: { $0.id == recordingId })!) : selectedItems
        
        handleAddToListIntent(quickAddText, items: itemsToAdd, sourceRecordingId: recordingId)
        
        // Clear field and hide
        quickAddText = ""
        showingQuickAddField = false
        selectedActionItems.removeAll()
    }
    
    // MARK: - AI Summary Settings
    
    @ViewBuilder
    private func summaryControlButtons(for recording: Recording) -> some View {
        HStack(spacing: 12) {
            Button(action: { showingSummarySettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Button("Retry") {
                retryWithSettings(for: recording)
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private func aiSummarySettingsView(for recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Summary Settings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Done") {
                    withAnimation(.smooth(duration: 0.3)) {
                        showingSummarySettings = false
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Summary Mode Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("Summary Mode")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Picker("Mode", selection: $selectedSummaryMode) {
                    ForEach(SummaryMode.allCases, id: \.self) { mode in
                        HStack {
                            Text(mode.displayName)
                                .font(.caption)
                            Spacer()
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                
                Text(selectedSummaryMode.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // Summary Length Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                    Text("Detail Level")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Picker("Length", selection: $selectedSummaryLength) {
                    ForEach(SummaryLength.allCases) { length in
                        HStack {
                            Text(length.displayName)
                                .font(.caption)
                            Spacer()
                        }
                        .tag(length)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                
                Text(selectedSummaryLength.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // Retry button with current settings
            Button(action: {
                retryWithSettings(for: recording)
                withAnimation(.smooth(duration: 0.3)) {
                    showingSummarySettings = false
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 16))
                    Text("Retry with \(selectedSummaryMode.displayName) (\(selectedSummaryLength.displayName))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(20)
            }
            .disabled(!hasTranscriptForRetry(recording))
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func hasTranscriptForRetry(_ recording: Recording) -> Bool {
        return recording.transcript != nil && !recording.transcript!.isEmpty
    }
    
    private func retryWithSettings(for recording: Recording) {
        // Store the selected settings temporarily for this retry
        let currentMode = UserDefaults.standard.string(forKey: "defaultMode")
        let currentLength = UserDefaults.standard.string(forKey: "defaultSummaryLength")
        
        // Temporarily set the selected settings
        UserDefaults.standard.set(selectedSummaryMode.rawValue, forKey: "defaultMode")
        UserDefaults.standard.set(selectedSummaryLength.rawValue, forKey: "defaultSummaryLength")
        
        // Retry summarization
        recordingsManager.retrySummarization(for: recording)
        
        // Restore original settings after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let originalMode = currentMode {
                UserDefaults.standard.set(originalMode, forKey: "defaultMode")
            }
            if let originalLength = currentLength {
                UserDefaults.standard.set(originalLength, forKey: "defaultSummaryLength")
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FormattedSummaryText: View {
    let summary: String
    
    var body: some View {
        // Create AttributedString manually to preserve whitespace and formatting
        Text(createFormattedText())
    }
    
    private func createFormattedText() -> AttributedString {
        var result = AttributedString()
        
        // Split into lines and process each one
        let lines = summary.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check if this line contains a bold label
            if trimmedLine.hasPrefix("**") && trimmedLine.hasSuffix("**") && trimmedLine.count > 4 {
                // This is a bold label - extract the text and make it bold
                let labelText = String(trimmedLine.dropFirst(2).dropLast(2))
                var boldText = AttributedString(labelText)
                boldText.font = .headline.bold()
                result.append(boldText)
            } else if !trimmedLine.isEmpty {
                // Regular text
                result.append(AttributedString(line))
            } else {
                // Empty line - preserve as spacing
                result.append(AttributedString(" "))
            }
        }
        
        return result
    }
}


class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

// MARK: - Save to Documents Sheet
struct SaveToDocumentsSheet: View {
    let recording: Recording
    let selectedItems: [String]
    @ObservedObject var documentStore: DocumentStore
    let onSaved: ((UUID, Int) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var extractedItems: [String] = []
    @State private var selectedDocumentType: DocumentType?
    @State private var isProcessing = false
    @State private var showingSuccess = false
    @State private var createdDocumentId: UUID?
    
    init(recording: Recording, selectedItems: [String] = [], documentStore: DocumentStore, onSaved: ((UUID, Int) -> Void)? = nil) {
        self.recording = recording
        self.selectedItems = selectedItems
        self.documentStore = documentStore
        self.onSaved = onSaved
    }
    
    private var recentDocuments: [Document] {
        documentStore.recentDocuments
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isProcessing {
                    processingView
                } else if showingSuccess {
                    successView
                } else {
                    mainView
                }
            }
            .navigationTitle("Save to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            if selectedItems.isEmpty {
                extractActionItems()
            } else {
                extractedItems = selectedItems
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Extracting action items...")
                .font(.headline)
            Text("Analyzing recording content")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Saved Successfully!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("\(extractedItems.count) items added to list")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private var mainView: some View {
        ScrollView {
            VStack(spacing: 20) {
                extractedItemsSection
                
                suggestedSection
                
                if !recentDocuments.isEmpty {
                    recentDocumentsSection
                }
                
                documentTypesSection
            }
            .padding()
        }
    }
    
    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested")
                .font(.headline)
            
            if let suggested = suggestedDocument {
                Button(action: {
                    saveToExistingDocument(suggested)
                }) {
                    HStack {
                        Image(systemName: suggested.type.systemImage)
                            .foregroundColor(suggested.type.color)
                        
                        VStack(alignment: .leading) {
                            Text(suggested.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.leading)
                            Text("Smart match • \(suggested.itemCount) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(extractedItems.isEmpty)
            } else {
                Button(action: {
                    createNewDocument(type: .todo)
                }) {
                    HStack {
                        Image(systemName: DocumentType.todo.systemImage)
                            .foregroundColor(DocumentType.todo.color)
                        
                        VStack(alignment: .leading) {
                            Text("To-Do — Personal")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Create new document")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(extractedItems.isEmpty)
            }
        }
    }
    
    private var suggestedDocument: Document? {
        let suggestedType = documentStore.suggestedType(for: extractedItems)
        return documentStore.documents
            .filter { $0.type == suggestedType }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first { Calendar.current.isDate($0.updatedAt, inSameDayAs: Date()) }
    }
    
    private var extractedItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Items (\(extractedItems.count))")
                .font(.headline)
            
            if extractedItems.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No action items found in this recording")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(extractedItems.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Image(systemName: "circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(item)
                                .font(.body)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private var recentDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Lists (Today)")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(recentDocuments) { document in
                    Button(action: {
                        saveToExistingDocument(document)
                    }) {
                        HStack {
                            Image(systemName: document.type.systemImage)
                                .foregroundColor(document.type.color)
                            
                            VStack(alignment: .leading) {
                                Text(document.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                Text("\(document.itemCount) items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(extractedItems.isEmpty)
                }
            }
        }
    }
    
    private var documentTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create New List")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DocumentType.allCases, id: \.self) { type in
                    Button(action: {
                        createNewDocument(type: type)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 24))
                                .foregroundColor(type.color)
                            Text(type.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(extractedItems.isEmpty)
                }
            }
        }
    }
    
    private func extractActionItems() {
        isProcessing = true
        
        // Simulate processing time for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var items: [String] = []
            
            // Extract items from summary if available
            if let summary = recording.summary, !summary.isEmpty {
                items = parseActionItemsFromSummary(summary)
            }
            
            // If no items found in summary, try transcript
            if items.isEmpty, let transcript = recording.transcript, !transcript.isEmpty {
                items = parseActionItemsFromTranscript(transcript)
            }
            
            extractedItems = items
            isProcessing = false
        }
    }
    
    private func parseActionItemsFromSummary(_ summary: String) -> [String] {
        var items: [String] = []
        let lines = summary.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for bullet points or numbered items
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                let item = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty && item.count > 3 {
                    items.append(item)
                }
            } else if let regex = try? NSRegularExpression(pattern: "^\\d+\\.", options: []) {
                let range = NSRange(location: 0, length: trimmed.count)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    let item = regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.isEmpty && item.count > 3 {
                        items.append(item)
                    }
                }
            }
        }
        
        return Array(items.prefix(10)) // Limit to 10 items
    }
    
    private func parseActionItemsFromTranscript(_ transcript: String) -> [String] {
        // Simple heuristic: look for sentences that sound like action items
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var items: [String] = []
        
        let actionKeywords = ["need to", "should", "must", "have to", "remember to", "don't forget", "make sure"]
        
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()
            
            if actionKeywords.contains(where: { lowercased.contains($0) }) && trimmed.count > 10 {
                items.append(trimmed)
            }
        }
        
        return Array(items.prefix(5)) // Limit to 5 items from transcript
    }
    
    private func saveToExistingDocument(_ document: Document) {
        guard !extractedItems.isEmpty else { return }
        
        isProcessing = true
        documentStore.addItems(to: document.id, items: extractedItems, sourceRecordingId: recording.id)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isProcessing = false
            onSaved?(document.id, extractedItems.count)
            dismiss()
        }
    }
    
    private func createNewDocument(type: DocumentType) {
        guard !extractedItems.isEmpty else { return }
        
        isProcessing = true
        let documentId = documentStore.saveActionItems(extractedItems, sourceRecordingId: recording.id, preferredType: type)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            createdDocumentId = documentId
            isProcessing = false
            onSaved?(documentId, extractedItems.count)
            dismiss()
        }
    }
}

// MARK: - Action Item Row
struct ActionItemRow: View {
    let item: String
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onSelectionToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            Text(item)
                .font(.body)
                .multilineTextAlignment(.leading)
                .foregroundColor(isSelected ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
        .cornerRadius(6)
        .onTapGesture {
            onSelectionToggle()
        }
        .onLongPressGesture {
            onSave()
        }
    }
}
