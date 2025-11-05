import SwiftUI
import AVFoundation

struct RecordingDetailView: View {
    let recordingId: UUID
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var documentStore: DocumentStore
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var usageVM = UsageViewModel.shared
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var showingDeleteAlert = false
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []
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
    @State private var showingPaywall = false
    @State private var showingMinutesExhaustedAlert = false
    @State private var showingListItemConfirmation = false
    @State private var detectedListItems: DetectionResult?
    @State private var lastProcessedSummary: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Group {
                if let recording = recordingsManager.recordings.first(where: { $0.id == recordingId }) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection(recording)

                            // API Key warning for Own Key subscribers
                            if subscriptionManager.isOwnKeySubscriber && !subscriptionManager.hasApiKeyConfigured {
                                apiKeyWarningBanner
                            }

                            recordingInfoSection(recording)
                            summarySection(recording)
                            transcriptSection(recording)
                            actionItemsSection(recording)
                            playbackSection(recording)

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
                            .font(.poppins.headline)
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
                    .font(.poppins.headline)
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView(canDismiss: true)
        }
        .alert("Minutes Exhausted", isPresented: $showingMinutesExhaustedAlert) {
            Button("Upgrade", role: nil) {
                showingPaywall = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've used all your minutes for this month. Upgrade to continue recording.")
        }
        .sheet(isPresented: $showingListItemConfirmation) {
            if let detectedItems = detectedListItems {
                ListItemConfirmationSheet(
                    detectionResult: detectedItems,
                    onConfirm: { confirmedItems in
                        handleConfirmedListItems(confirmedItems)
                        showingListItemConfirmation = false
                    },
                    onDismiss: {
                        showingListItemConfirmation = false
                    }
                )
            }
        }
        .onChange(of: recordingsManager.recordings.count) { _ in
            // Check if summary was just completed
            if let recording = recordingsManager.recordings.first(where: { $0.id == recordingId }),
               let summary = recording.summary,
               !summary.isEmpty,
               summary != lastProcessedSummary {

                lastProcessedSummary = summary

                // Detect list items from summary and transcript
                let textToAnalyze = [summary, recording.transcript ?? ""].joined(separator: "\n\n")

                if let detection = ListItemDetector.shared.detectListItems(from: textToAnalyze) {
                    detectedListItems = detection

                    // Show confirmation sheet after a brief delay (allows UI to settle)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingListItemConfirmation = true
                    }
                }
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
                    .font(.poppins.regular(size: 40))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title.isEmpty ? recording.fileName.replacingOccurrences(of: ".m4a", with: "") : recording.title)
                    .font(.poppins.headline)
                    .lineLimit(1)
                Text(recording.formattedDate)
                    .font(.poppins.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var apiKeyWarningBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key Required")
                        .font(.poppins.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("You're on the Own Key plan. Add your API key to use transcription and summaries.")
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            NavigationLink(destination: AIProviderSettingsView()) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open AI Provider Settings")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    private func recordingInfoSection(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recording Information")
                .font(.poppins.headline)
                .fontWeight(.semibold)

            InfoRow(label: "Date & Time", value: recording.formattedDate)
            InfoRow(label: "Duration", value: recording.formattedDuration)

            if let transcriptionModel = recording.transcriptionModel {
                InfoRow(label: "Transcription", value: transcriptionModel)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func playbackSection(_ recording: Recording) -> some View {
        VStack(spacing: 12) {
            Text("Playback")
                .font(.poppins.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: { togglePlayback(recording) }) {
                HStack {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.poppins.regular(size: 50))
                    
                    VStack(alignment: .leading) {
                        Text(isPlaying ? "Playing" : "Play Recording")
                            .font(.poppins.headline)
                        Text(recording.formattedDuration)
                            .font(.poppins.caption)
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
                    .font(.poppins.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let transcript = recording.transcript, !transcript.isEmpty {
                    if isEditingTranscript {
                        HStack {
                            Button("Cancel") {
                                isEditingTranscript = false
                                editedTranscript = ""
                            }
                            .font(.poppins.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button("Save") {
                                saveTranscriptEdits(for: recording)
                            }
                            .font(.poppins.body)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    } else {
                        Button("Edit") {
                            startEditingTranscript(transcript)
                        }
                        .font(.poppins.body)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else if case .transcribing(let progress) = recording.status {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.poppins.caption)
                        .foregroundColor(.blue)
                } else if case .failed = recording.status, recording.transcript == nil {
                    Button("Retry") {
                        if usageVM.isOverLimit {
                            showingMinutesExhaustedAlert = true
                        } else {
                            recordingsManager.retryTranscription(for: recording)
                        }
                    }
                    .font(.poppins.body)
                    .disabled(usageVM.isOverLimit || usageVM.isLoading || usageVM.isStale)
                    .opacity((usageVM.isOverLimit || usageVM.isLoading || usageVM.isStale) ? 0.5 : 1.0)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            if let transcript = recording.transcript, !transcript.isEmpty {
                if isEditingTranscript {
                    TextEditor(text: $editedTranscript)
                        .font(.poppins.body)
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                        .frame(minHeight: 100)
                } else {
                    Text(transcript)
                        .font(.poppins.body)
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
                            .font(.poppins.caption)
                    }
                    Text(reason)
                        .foregroundColor(.secondary)
                        .font(.poppins.caption)
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
                    .font(.poppins.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if case .summarizing(let progress) = recording.status {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.poppins.caption)
                        .foregroundColor(.orange)
                } else if case .failed = recording.status, recording.transcript != nil {
                    summaryControlButtons(for: recording)
                } else if let transcript = recording.transcript, !transcript.isEmpty, recording.summary != nil {
                    summaryControlButtons(for: recording)
                } else if recording.transcript != nil {
                    // Show settings button even when waiting for summary
                    Button(action: { showingSummarySettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 32)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
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
                        .font(.poppins.caption)
                    Text("Detected mode: \(detectedMode)")
                        .font(.poppins.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let summary = recording.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    FormattedSummaryText(summary: summary)
                        .font(.poppins.body)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    // Summary Feedback Buttons
                    HStack {
                        Text("Was this summary helpful?")
                            .font(.poppins.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        SummaryFeedbackButtons(recording: recording)
                    }
                    .padding(.horizontal, 4)
                }
            } else if case .summarizing = recording.status {
                VStack(spacing: 8) {
                    HStack {
                        ProgressView()
                        Text(summarizingMessage(for: recording))
                            .foregroundColor(.secondary)
                    }

                    // Show extra info for large transcripts
                    if let transcript = recording.transcript, transcript.count > 50000 {
                        Text(NSLocalizedString("progress.large_transcript_warning", comment: "Large transcript warning"))
                            .font(.poppins.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            } else if case .failed(let reason) = recording.status, recording.transcript != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Summary generation failed")
                            .foregroundColor(.red)
                            .font(.poppins.caption)
                    }
                    Text(reason)
                        .foregroundColor(.secondary)
                        .font(.poppins.caption)
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
        VStack(spacing: 16) {
            Text("Actions")
                .font(.poppins.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Grid layout with 3 buttons
            HStack(spacing: 12) {
                // Share Audio File
                Button(action: {
                    shareAudioFile(recording)
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)

                            Image(systemName: "waveform.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)
                        }

                        Text("Share Audio")
                            .font(.poppins.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Share as PDF
                Button(action: {
                    sharePDFRecording(recording)
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.purple.opacity(0.2), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)

                            Image(systemName: "doc.richtext")
                                .font(.system(size: 22))
                                .foregroundColor(.purple)
                        }

                        Text("Share PDF")
                            .font(.poppins.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Copy Text
                Button(action: {
                    copyRecording(recording)
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)

                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                        }

                        Text("Copy Text")
                            .font(.poppins.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private func actionItemsSection(_ recording: Recording) -> some View {
        let actionItems = extractActionItems(from: recording)
        
        // Always show the section, but with different content if empty
        if actionItems.isEmpty {
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    Text("Action Items")
                        .font(.poppins.headline)
                        .fontWeight(.semibold)
                        HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .font(.poppins.caption)
                        Text("No action items detected")
                            .font(.poppins.subheadline)
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
                        .font(.poppins.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Quick add button
                    Button(action: {
                        showingQuickAddField.toggle()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.poppins.medium(size: 16))
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
                    .font(.poppins.caption)
                    .foregroundColor(.blue)
                    
                    Text("(\(actionItems.count))")
                        .font(.poppins.caption)
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
                    .font(.poppins.body)
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
                    .font(.poppins.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
                }
                
                if let docId = savedDocumentId {
                    Button("Open") {
                        // Navigate to document - would need navigation coordination
                        showingToast = false
                        documentStore.markOpened(docId)
                    }
                    .font(.poppins.body)
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

        // Items are already filtered by explicit action phrases, no additional filtering needed
        return items
    }
    
    private func parseActionItemsFromSummary(_ summary: String) -> [String] {
        var items: [String] = []
        let lines = summary.components(separatedBy: .newlines)

        // Action item section headers (Dutch and English)
        let actionSectionHeaders = [
            "actiepunten", "action items", "actions", "next steps",
            "volgende stappen", "vervolgacties", "follow-up actions",
            "to do", "todo", "tasks", "taken"
        ]

        var inActionSection = false
        var currentSectionHeader = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            // Check if this line is a section header (bold text: **Header**)
            if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
                let headerText = trimmed.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
                currentSectionHeader = headerText.lowercased()

                // Check if we're entering an action items section
                inActionSection = actionSectionHeaders.contains { currentSectionHeader.contains($0) }
                continue
            }

            // Only extract bullets if we're in an action items section
            if inActionSection {
                // Look for bullet points or numbered items
                if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                    let item = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)

                    // Additional validation: must have action verbs or be a real task
                    if !item.isEmpty && item.count > 10 && looksLikeActionItem(item) {
                        items.append(item)
                    }
                } else if trimmed.hasPrefix("*") && !trimmed.hasPrefix("**") {
                    let item = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.isEmpty && item.count > 10 && looksLikeActionItem(item) {
                        items.append(item)
                    }
                } else if let regex = try? NSRegularExpression(pattern: "^\\d+\\.", options: []) {
                    let range = NSRange(location: 0, length: trimmed.count)
                    if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                        let item = regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !item.isEmpty && item.count > 10 && looksLikeActionItem(item) {
                            items.append(item)
                        }
                    }
                }
            }

            // Exit action section if we hit a new bold header or empty line sequence
            if trimmed.isEmpty && inActionSection {
                // Don't exit immediately on first empty line, but track it
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("•") && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("**") && inActionSection {
                // Likely moved to regular text after bullets, exit section
                if trimmed.first?.isNumber != true {
                    inActionSection = false
                }
            }
        }

        return Array(items.prefix(10))
    }

    private func looksLikeActionItem(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Reject obvious non-action items
        let nonActionPatterns = [
            "*context*", "*hoofdpunten*", "*summary*", "*samenvatting*",
            "context", "hoofdpunten", "key points", "belangrijkste punten",
            "summary", "samenvatting", "overview", "overzicht"
        ]

        for pattern in nonActionPatterns {
            if lowercased.contains(pattern) || lowercased == pattern.replacingOccurrences(of: "*", with: "") {
                return false
            }
        }

        // Must contain action verbs or imperative language
        let actionVerbs = [
            "schedule", "send", "review", "create", "contact", "call", "email",
            "prepare", "finalize", "submit", "update", "complete", "deliver",
            "organize", "plan", "book", "order", "buy", "purchase", "arrange",
            "follow up", "follow-up", "check", "confirm", "verify", "test",
            "will ", " moet ", " zal ", " ga ", " moet "  // Dutch/English future indicators
        ]

        return actionVerbs.contains { lowercased.contains($0) }
    }
    
    private func isSectionHeaderSimple(_ text: String, headers: [String]) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if the text exactly matches or starts with a section header
        for header in headers {
            if lowercased == header || lowercased.hasPrefix(header + ":") {
                return true
            }
        }
        
        // Check if it looks like a markdown header (contains only header words)
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count <= 3 { // Short phrases are likely headers
            let joinedWords = words.joined(separator: " ")
            for header in headers {
                if joinedWords.contains(header) || header.contains(joinedWords) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func parseActionItemsFromTranscript(_ transcript: String) -> [String] {
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var items: [String] = []

        // Only detect EXPLICIT action item phrases - be very critical
        let explicitActionPhrases = [
            "add to list", "add to the list", "add to my list",
            "add this to", "add that to",
            "put on list", "put on the list", "put on my list",
            "todo", "to do", "to-do",
            "we should do", "I should do", "let's do",
            "remember to add", "don't forget to add",
            "make sure to add", "need to add",
            "write down", "note to self",
            "action item", "action items"
        ]

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            // Only include if it contains an EXPLICIT action phrase
            if explicitActionPhrases.contains(where: { lowercased.contains($0) }) && trimmed.count > 10 {
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
        Analytics.track("share_summary")
        
        // Generate share text immediately since transcript and summary are already available
        let shareText = Voice_Notes.makeShareText(for: recording)
        shareItems = [shareText]
        isSharePresented = true
    }
    
    private func shareAudioFile(_ recording: Recording) {
        Analytics.track("share_audio_file")

        let audioURL = recording.resolvedFileURL

        // Check if file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("❌ Audio file does not exist at path: \(audioURL.path)")
            shareItems = ["Audio file not found"]
            isSharePresented = true
            return
        }

        // Get file info
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0

            print("✅ Sharing audio file: \(audioURL.lastPathComponent)")
            print("📊 File size: \(String(format: "%.2f", fileSizeMB)) MB")

            // Create a better filename for sharing
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH-mm"
            let dateString = dateFormatter.string(from: recording.date)

            let shareFileName: String
            if !recording.title.isEmpty {
                shareFileName = "\(recording.title) - \(dateString).m4a"
            } else {
                shareFileName = "Voice Recording - \(dateString).m4a"
            }

            // Create temporary file with better name for sharing
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(shareFileName)

            // Remove existing temp file if it exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }

            // Copy file to temp location with new name
            try FileManager.default.copyItem(at: audioURL, to: tempURL)

            shareItems = [tempURL]
            isSharePresented = true

            print("✅ Audio file ready for sharing")
        } catch {
            print("❌ Error preparing audio file for sharing: \(error)")
            shareItems = ["Error: \(error.localizedDescription)"]
            isSharePresented = true
        }
    }

    private func sharePDFRecording(_ recording: Recording) {
        shareItems = ["Generating PDF…"]
        isSharePresented = true
        Analytics.track("share_pdf")

        Task {
            // Generate PDF in background
            if let pdfData = PDFGenerator.generatePDF(for: recording, includeTranscript: true) {
                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let pdfURL = tempDir.appendingPathComponent("\(recording.title.isEmpty ? recording.fileName : recording.title).pdf")

                do {
                    try pdfData.write(to: pdfURL)

                    await MainActor.run {
                        shareItems = [pdfURL]
                    }
                } catch {
                    await MainActor.run {
                        shareItems = ["Error generating PDF: \(error.localizedDescription)"]
                    }
                }
            } else {
                await MainActor.run {
                    shareItems = ["Failed to generate PDF"]
                }
            }
        }
    }

    private func copyRecording(_ recording: Recording) {
        UIPasteboard.general.string = makeShareText(recording)
        Analytics.track("copy_summary")

        // Show success toast
        toastMessage = "Recording details copied to clipboard"
        showingToast = true

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if showingToast {
                showingToast = false
            }
        }
    }
    
    private func makeShareText(_ recording: Recording) -> String {
        return Voice_Notes.makeShareText(for: recording)
    }
    
    private func startEditingTranscript(_ transcript: String) {
        editedTranscript = transcript
        isEditingTranscript = true
        EnhancedTelemetryService.shared.logSummaryEditTap(source: "transcript")
        Analytics.track("edit_tapped", props: ["type": "transcript"])
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

    private func summarizingMessage(for recording: Recording) -> String {
        guard let transcript = recording.transcript else {
            return NSLocalizedString("progress.creating_summary", comment: "Creating summary")
        }

        let charCount = transcript.count
        let estimatedMinutes = charCount / 150  // ~150 chars per minute of speech

        if charCount > 75000 {
            return String(format: NSLocalizedString("progress.processing_large_transcript", comment: "Processing large transcript"), estimatedMinutes)
        } else if charCount > 50000 {
            return String(format: NSLocalizedString("progress.processing_long_transcript", comment: "Processing long transcript"), estimatedMinutes)
        } else {
            return NSLocalizedString("progress.creating_summary", comment: "Creating summary")
        }
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
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 32)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Button("Retry") {
                if usageVM.isOverLimit {
                    showingMinutesExhaustedAlert = true
                } else {
                    retryWithSettings(for: recording)
                }
            }
            .font(.poppins.body)
            .disabled(usageVM.isOverLimit || usageVM.isLoading || usageVM.isStale)
            .opacity((usageVM.isOverLimit || usageVM.isLoading || usageVM.isStale) ? 0.5 : 1.0)
            .foregroundColor(.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func aiSummarySettingsView(for recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Summary Settings")
                    .font(.poppins.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Done") {
                    withAnimation(.smooth(duration: 0.3)) {
                        showingSummarySettings = false
                    }
                }
                .font(.poppins.caption)
                .foregroundColor(.blue)
            }
            
            // Summary Mode Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.poppins.regular(size: 14))
                        .foregroundColor(.blue)
                    Text("AI Summary Mode")
                        .font(.poppins.caption)
                        .fontWeight(.medium)
                }
                
                Picker("Mode", selection: $selectedSummaryMode) {
                    ForEach(SummaryMode.allCases, id: \.self) { mode in
                        HStack {
                            Text(mode.displayName)
                                .font(.poppins.caption)
                            Spacer()
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .font(.poppins.caption)
                
                Text(selectedSummaryMode.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // Summary Length Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.poppins.regular(size: 14))
                        .foregroundColor(.purple)
                    Text("Detail Level")
                        .font(.poppins.caption)
                        .fontWeight(.medium)
                }
                
                Picker("Length", selection: $selectedSummaryLength) {
                    ForEach(SummaryLength.allCases) { length in
                        HStack {
                            Text(length.displayName)
                                .font(.poppins.caption)
                            Spacer()
                        }
                        .tag(length)
                    }
                }
                .pickerStyle(.menu)
                .font(.poppins.caption)
                
                Text(selectedSummaryLength.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            // AI Provider Section
            aiProviderSection(for: recording)
            
            // Retry button with current settings
            Button(action: {
                retryWithSettings(for: recording)
                withAnimation(.smooth(duration: 0.3)) {
                    showingSummarySettings = false
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.poppins.regular(size: 16))
                    Text("Retry with \(selectedSummaryMode.displayName) (\(selectedSummaryLength.displayName))")
                        .font(.poppins.caption)
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
    
    @ViewBuilder
    private func aiProviderSection(for recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.poppins.regular(size: 14))
                    .foregroundColor(.green)
                Text("AI Provider")
                    .font(.poppins.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // Provider icon and name
                    currentProvider(for: recording).iconView(size: 16)
                    
                    Text(currentProvider(for: recording).displayName)
                        .font(.poppins.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(providerStatus(for: recording).color)
                            .frame(width: 8, height: 8)
                        
                        Text(providerStatus(for: recording).text)
                            .font(.caption2)
                            .foregroundColor(providerStatus(for: recording).color)
                    }
                }
                
                Text(providerDescription(for: recording))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                if let recordingProvider = recording.aiProviderType {
                    Text("This recording will use: \(recordingProvider.displayName)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            .padding(8)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func currentProvider(for recording: Recording) -> AIProviderType {
        // Check if recording has specific provider, otherwise use global setting
        return recording.aiProviderType ?? AISettingsStore.shared.selectedProvider
    }
    
    private func providerStatus(for recording: Recording) -> (color: Color, text: String) {
        let aiSettings = AISettingsStore.shared
        let provider = currentProvider(for: recording)
        if aiSettings.canUseProvider(provider) {
            return (.green, "Connected")
        } else if provider.requiresApiKey {
            return (.orange, "Not configured")
        } else {
            return (.blue, "Ready")
        }
    }
    
    private func providerDescription(for recording: Recording) -> String {
        if recording.aiProviderType != nil {
            return "This recording has a specific provider override"
        } else {
            return "Using global default: \(currentProvider(for: recording).displayName)"
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
                .font(.poppins.headline)
            Text("Analyzing recording content")
                .font(.poppins.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.poppins.regular(size: 60))
                .foregroundColor(.green)
            
            Text("Saved Successfully!")
                .font(.poppins.title2)
                .fontWeight(.semibold)
            
            Text("\(extractedItems.count) items added to list")
                .font(.poppins.body)
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
                .font(.poppins.headline)
            
            if let suggested = suggestedDocument {
                Button(action: {
                    saveToExistingDocument(suggested)
                }) {
                    HStack {
                        Image(systemName: suggested.type.systemImage)
                            .foregroundColor(suggested.type.color)
                        
                        VStack(alignment: .leading) {
                            Text(suggested.title)
                                .font(.poppins.body)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.leading)
                            Text("Smart match • \(suggested.itemCount) items")
                                .font(.poppins.caption)
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
                                .font(.poppins.body)
                                .fontWeight(.medium)
                            Text("Create new document")
                                .font(.poppins.caption)
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
                .font(.poppins.headline)
            
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
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                            Text(item)
                                .font(.poppins.body)
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
                .font(.poppins.headline)
            
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
                                    .font(.poppins.body)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                Text("\(document.itemCount) items")
                                    .font(.poppins.caption)
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
                .font(.poppins.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DocumentType.allCases, id: \.self) { type in
                    Button(action: {
                        createNewDocument(type: type)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: type.systemImage)
                                .font(.poppins.regular(size: 24))
                                .foregroundColor(type.color)
                            Text(type.displayName)
                                .font(.poppins.caption)
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

        // Action item section headers (Dutch and English)
        let actionSectionHeaders = [
            "actiepunten", "action items", "actions", "next steps",
            "volgende stappen", "vervolgacties", "follow-up actions",
            "to do", "todo", "tasks", "taken"
        ]

        var inActionSection = false
        var currentSectionHeader = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            // Check if this line is a section header (bold text: **Header**)
            if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
                let headerText = trimmed.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
                currentSectionHeader = headerText.lowercased()

                // Check if we're entering an action items section
                inActionSection = actionSectionHeaders.contains { currentSectionHeader.contains($0) }
                continue
            }

            // Only extract bullets if we're in an action items section
            if inActionSection {
                // Look for bullet points or numbered items
                if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") {
                    let item = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)

                    // Additional validation: must have action verbs or be a real task
                    if !item.isEmpty && item.count > 10 && looksLikeRealActionItem(item) {
                        items.append(item)
                    }
                } else if trimmed.hasPrefix("*") && !trimmed.hasPrefix("**") {
                    let item = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !item.isEmpty && item.count > 10 && looksLikeRealActionItem(item) {
                        items.append(item)
                    }
                } else if let regex = try? NSRegularExpression(pattern: "^\\d+\\.", options: []) {
                    let range = NSRange(location: 0, length: trimmed.count)
                    if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                        let item = regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !item.isEmpty && item.count > 10 && looksLikeRealActionItem(item) {
                            items.append(item)
                        }
                    }
                }
            }

            // Exit action section if we hit a new bold header
            if trimmed.isEmpty && inActionSection {
                // Don't exit immediately on first empty line
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("•") && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("*") && !trimmed.hasPrefix("**") && inActionSection {
                // Likely moved to regular text after bullets
                if trimmed.first?.isNumber != true {
                    inActionSection = false
                }
            }
        }

        return Array(items.prefix(10)) // Limit to 10 items
    }

    private func looksLikeRealActionItem(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Reject obvious non-action items
        let nonActionPatterns = [
            "*context*", "*hoofdpunten*", "*summary*", "*samenvatting*",
            "context", "hoofdpunten", "key points", "belangrijkste punten",
            "summary", "samenvatting", "overview", "overzicht"
        ]

        for pattern in nonActionPatterns {
            if lowercased.contains(pattern) || lowercased == pattern.replacingOccurrences(of: "*", with: "") {
                return false
            }
        }

        // Must contain action verbs or imperative language
        let actionVerbs = [
            "schedule", "send", "review", "create", "contact", "call", "email",
            "prepare", "finalize", "submit", "update", "complete", "deliver",
            "organize", "plan", "book", "order", "buy", "purchase", "arrange",
            "follow up", "follow-up", "check", "confirm", "verify", "test",
            "will ", " moet ", " zal ", " ga "  // Dutch/English future indicators
        ]

        return actionVerbs.contains { lowercased.contains($0) }
    }
    
    private func parseActionItemsFromTranscript(_ transcript: String) -> [String] {
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        var items: [String] = []

        // Only detect EXPLICIT action item phrases - be very critical
        let explicitActionPhrases = [
            "add to list", "add to the list", "add to my list",
            "add this to", "add that to",
            "put on list", "put on the list", "put on my list",
            "todo", "to do", "to-do",
            "we should do", "I should do", "let's do",
            "remember to add", "don't forget to add",
            "make sure to add", "need to add",
            "write down", "note to self",
            "action item", "action items"
        ]

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            // Only include if it contains an EXPLICIT action phrase
            if explicitActionPhrases.contains(where: { lowercased.contains($0) }) && trimmed.count > 10 {
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
                    .font(.poppins.medium(size: 18))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            
            Text(item)
                .font(.poppins.body)
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

// MARK: - Auto-Tagging Extension
extension RecordingDetailView {
    private func autoGenerateTags(for recording: Recording) {
        var suggestedTags: [String] = []

        // Combine summary and transcript for analysis
        let content = [recording.summary, recording.transcript]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        // Common categories and keywords
        let tagCategories: [String: [String]] = [
            "work": ["meeting", "project", "task", "deadline", "client", "presentation", "email", "office"],
            "personal": ["family", "friend", "relationship", "home", "life", "personal"],
            "health": ["health", "doctor", "medicine", "exercise", "fitness", "diet", "wellness"],
            "finance": ["money", "budget", "expense", "payment", "invoice", "financial", "bank", "investment"],
            "ideas": ["idea", "brainstorm", "concept", "innovation", "creative", "inspiration"],
            "shopping": ["buy", "shop", "purchase", "order", "store", "product"],
            "travel": ["travel", "trip", "vacation", "flight", "hotel", "destination"],
            "todo": ["todo", "reminder", "task", "action", "need to", "must", "should"],
            "notes": ["note", "remember", "important", "key point", "highlight"],
            "urgent": ["urgent", "asap", "immediately", "critical", "priority"]
        ]

        // Check for category matches
        for (tag, keywords) in tagCategories {
            if keywords.contains(where: { content.contains($0) }) {
                suggestedTags.append(tag)
            }
        }

        // Extract potential proper nouns (capitalized words from original text)
        let originalContent = [recording.summary, recording.transcript]
            .compactMap { $0 }
            .joined(separator: " ")

        let words = originalContent.components(separatedBy: .whitespacesAndNewlines)
        let properNouns = words
            .filter { word in
                guard let first = word.first else { return false }
                return first.isUppercase && word.count > 3 && !["The", "This", "That", "With", "From"].contains(word)
            }
            .prefix(3)
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters) }

        suggestedTags.append(contentsOf: properNouns)

        // Remove duplicates and limit to 5 tags
        let uniqueTags = Array(Set(suggestedTags))
            .filter { !$0.isEmpty }
            .prefix(5)
            .map { String($0) }

        // Add tags to recording
        for tag in uniqueTags {
            recordingsManager.addTagToRecording(recordingId: recordingId, tag: tag)
        }

        // Show toast
        if !uniqueTags.isEmpty {
            toastMessage = "Added \(uniqueTags.count) tag\(uniqueTags.count == 1 ? "" : "s")"
            showingToast = true

            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
}

// MARK: - List Item Detection Extension
extension RecordingDetailView {
    private func handleConfirmedListItems(_ items: [DetectedListItem]) {
        guard !items.isEmpty else { return }

        // Group items by list type if there are multiple types
        let listType = items.first?.listType ?? .general

        // Create or find the appropriate document
        let documentType: DocumentType = {
            switch listType {
            case .todo: return .todo
            case .shopping: return .shopping
            case .action: return .todo
            case .ideas: return .ideas
            case .general: return .todo
            }
        }()

        let documentTitle = listType.rawValue

        // Check if a document with this title already exists
        if let existingDoc = documentStore.documents.first(where: { $0.title == documentTitle }) {
            // Add items to existing document
            let itemTexts = items.map { $0.text }
            documentStore.addItems(to: existingDoc.id, items: itemTexts)

            toastMessage = "Added \(items.count) item\(items.count == 1 ? "" : "s") to \(documentTitle)"
            showingToast = true

            // Auto-hide after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                showingToast = false
            }
        } else {
            // Create new document
            let newDoc = Document(
                title: documentTitle,
                type: documentType,
                items: items.map { DocItem(text: $0.text) }
            )

            documentStore.documents.append(newDoc)

            toastMessage = "Created \(documentTitle) with \(items.count) item\(items.count == 1 ? "" : "s")"
            showingToast = true

            // Auto-hide after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                showingToast = false
            }
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Optionally add a tag to the recording
        recordingsManager.addTagToRecording(recordingId: recordingId, tag: listType.rawValue.lowercased())
    }
}
