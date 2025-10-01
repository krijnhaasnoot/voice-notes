//
//  ContentView.swift
//  Voice Notes
//
//  Created by Krijn Haasnoot on 06/09/2025.
//

import SwiftUI
import Speech

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder.shared
    @StateObject private var recordingsManager = RecordingsManager.shared
    @ObservedObject private var minutesTracker = MinutesTracker.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPermissionAlert = false
    @State private var permissionGranted = false
    @State private var selectedRecording: Recording?
    @State private var currentRecordingFileName: String?
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []
    @State private var selectedCalendarDate: Date?
    @State private var showingCalendar = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @State private var showingAlternativeView = false
    @State private var showingPaywall = false
    @State private var showingMinutesExhaustedAlert = false
    @State private var showingApiKeyAlert = false

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            NavigationStack {
                if isLandscape {
                    // Horizontal layout for landscape
                    HStack(spacing: 0) {
                        // Left side - Record button section
                        recordingSection
                            .frame(width: geometry.size.width * 0.4)
                            .background(Color(.systemGroupedBackground))

                        Divider()

                        // Right side - Recordings list
                        recordingsListSection
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    // Original vertical layout for portrait
                    ZStack(alignment: .topTrailing) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(spacing: 16) {
                                    // Minutes meter
                                    MinutesMeterView(compact: true)
                                        .padding(.horizontal)

                                    recordButton

                                    recordingStatusView
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)

                                // Calendar in portrait mode
                                if showingCalendar {
                                    LiquidCalendarView(selectedDate: $selectedCalendarDate, recordings: recordingsManager.recordings, startExpanded: true)
                                        .padding(.horizontal)
                                        .transition(.asymmetric(
                                            insertion: .push(from: .top).combined(with: .opacity),
                                            removal: .push(from: .bottom).combined(with: .opacity)
                                        ))
                                }

                                HStack {
                                    Text("Recent Recordings")
                                        .font(.poppins.semiBold(size: 32))

                                    if selectedCalendarDate != nil {
                                        Spacer()
                                        Button("Show All") {
                                            withAnimation(.smooth(duration: 0.4)) {
                                                selectedCalendarDate = nil
                                            }
                                        }
                                        .font(.poppins.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)

                                recordingsList
                            }
                        }
                        // Removed header overlay buttons in portrait mode
                    }
                }
            }
            // Remove .navigationBarHidden(true)
            .onAppear { requestPermissions() }
            .alert("Permissions Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Voice Notes needs microphone and speech recognition permissions to function.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        withAnimation(.smooth(duration: 0.6, extraBounce: 0.2)) { showingCalendar.toggle() }
                    }) { Image(systemName: showingCalendar ? "calendar.badge.checkmark" : "calendar") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingSettings = true }) { Image(systemName: "gearshape.fill") }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar(.visible, for: .navigationBar)
            .navigationTitle("Voice Notes")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recordingId: recording.id, recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(showingAlternativeView: $showingAlternativeView, recordingsManager: recordingsManager)
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
            Text("You've used all \(minutesTracker.monthlyLimit) minutes for this month. Upgrade to continue recording.")
        }
        .alert("API Key Required", isPresented: $showingApiKeyAlert) {
            Button("Open Settings", role: nil) {
                showingSettings = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You're on the Own Key plan. Please add your API key in AI Provider Settings to start recording.")
        }
    }

    private var recordButton: some View {
        let canStartRecording = minutesTracker.canRecord && subscriptionManager.canRecord

        return Button(action: {
            if !audioRecorder.isRecording {
                if !minutesTracker.canRecord {
                    showingMinutesExhaustedAlert = true
                } else if subscriptionManager.isOwnKeySubscriber && !subscriptionManager.hasApiKeyConfigured {
                    showingApiKeyAlert = true
                } else if permissionGranted {
                    toggleRecording()
                } else {
                    requestPermissions()
                }
            } else {
                toggleRecording()
            }
        }) {
            Circle()
                .fill(audioRecorder.isRecording ? Color.red : (canStartRecording ? Color.blue : Color.gray))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
                .opacity((!audioRecorder.isRecording && !canStartRecording) ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(audioRecorder.isRecording ? "Stop recording" : "Start recording")
    }

    private var filteredRecordings: [Recording] {
        var recordings = recordingsManager.recordings
        
        // Filter by selected date if one is chosen
        if let selectedDate = selectedCalendarDate {
            recordings = recordings.filter { recording in
                Calendar.current.isDate(recording.date, inSameDayAs: selectedDate)
            }
        }
        
        // Filter by search query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            recordings = recordings.filter { rec in
                displayTitle(for: rec).lowercased().contains(query)
            }
        }
        
        return recordings
    }

    private func requestPermissions() {
        Task {
            let audioGranted = await audioRecorder.requestPermission()
            if audioGranted {
                SFSpeechRecognizer.requestAuthorization { speechStatus in
                    DispatchQueue.main.async {
                        self.permissionGranted = (speechStatus == .authorized)
                        if !self.permissionGranted { 
                            self.showingPermissionAlert = true 
                        }
                    }
                }
            } else {
                await MainActor.run {
                    self.showingPermissionAlert = true
                }
            }
        }
    }

    private func toggleRecording() {
        Task {
            if audioRecorder.isRecording {
                let result = await MainActor.run {
                    audioRecorder.stopRecording()
                }

                print("🎙️ ContentView: Recording stopped. Duration: \(result.duration) seconds")
                print("🎙️ ContentView: Current minutes before tracking: \(minutesTracker.minutesUsed)")

                // Track minutes used
                await MainActor.run {
                    print("🎙️ ContentView: About to track usage...")
                    print("🎙️ ContentView: MinutesTracker instance ID: \(ObjectIdentifier(minutesTracker))")
                    print("🎙️ ContentView: MinutesTracker.shared instance ID: \(ObjectIdentifier(MinutesTracker.shared))")
                    minutesTracker.addUsage(seconds: result.duration)
                    print("🎙️ ContentView: Usage tracked!")
                    print("🎙️ ContentView: Current minutes after tracking: \(minutesTracker.minutesUsed)")
                }

                if let fileName = currentRecordingFileName {
                    let newRecording = Recording(fileName: fileName, date: Date(), duration: result.duration, title: "")

                    await MainActor.run {
                        recordingsManager.addRecording(newRecording)
                    }

                    // Only start transcription if we have a valid file with content
                    if let fileSize = result.fileSize, fileSize > 0 {
                        print("🎯 ContentView: Starting transcription for \(fileName) (size: \(fileSize) bytes)")
                        await MainActor.run {
                            recordingsManager.startTranscription(for: newRecording)
                        }
                    } else {
                        print("🎯 ContentView: ❌ NOT starting transcription - fileSize: \(result.fileSize ?? -1)")
                    }

                    currentRecordingFileName = nil
                }
            } else {
                currentRecordingFileName = await audioRecorder.startRecording()
            }
        }
    }

    private func displayTitle(for recording: Recording) -> String {
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
                                return titleContent.count > 50 ? String(titleContent.prefix(50)) + "..." : titleContent
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
                            return content.count > 50 ? String(content.prefix(50)) + "..." : content
                        }
                    }
                }
            }
        }
        
        return nil
    }

    private func previewText(for recording: Recording) -> String { 
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
    
    private func shareRecordingImmediately(_ recording: Recording) {
        // Generate share text immediately since transcript and summary are already available
        let shareText = makeShareText(for: recording)
        shareItems = [shareText]
        isSharePresented = true
    }
    
    // MARK: - Horizontal Layout Components
    
    private var recordingSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                recordButton
                recordingStatusView
            }
            .padding(.top, 40)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var recordingsListSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Recent Recordings")
                        .font(.title2)
                        .bold()

                    if selectedCalendarDate != nil {
                        Button("Show All") {
                            withAnimation(.smooth(duration: 0.4)) {
                                selectedCalendarDate = nil
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }

                    Spacer()
                }

                // Calendar in landscape mode (more compact)
                if showingCalendar {
                    LiquidCalendarView(selectedDate: $selectedCalendarDate, recordings: recordingsManager.recordings, startExpanded: true)
                        .transition(.asymmetric(
                            insertion: .push(from: .top).combined(with: .opacity),
                            removal: .push(from: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color(.systemGroupedBackground))

            ScrollView {
                recordingsList
            }
        }
    }
    
    // MARK: - Extracted View Components
    
    private var recordingStatusView: some View {
        VStack(spacing: 8) {
            if let error = audioRecorder.lastError {
                Text(error)
                    .font(.poppins.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text(audioRecorder.isRecording ? "Recording… \(Int(audioRecorder.recordingDuration))s" : "Tap to start recording")
                    .font(.poppins.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Debug: Show recent transcription status
            if let mostRecent = recordingsManager.recordings.first {
                switch mostRecent.status {
                case .transcribing(let progress):
                    Text("Transcribing: \(Int(progress * 100))%")
                        .font(.poppins.caption)
                        .foregroundColor(.blue)
                case .summarizing(let progress):
                    Text("Summarizing: \(Int(progress * 100))%")
                        .font(.poppins.caption)
                        .foregroundColor(.green)
                case .failed(let reason):
                    Text("Failed: \(reason)")
                        .font(.poppins.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                case .done:
                    if let transcript = mostRecent.transcript, !transcript.isEmpty {
                        Text("✅ Transcribed: \(transcript.count) chars")
                            .font(.poppins.caption)
                            .foregroundColor(.green)
                    }
                case .idle:
                    EmptyView()
                }
            }
        }
    }
    
    private var recordingsList: some View {
        LazyVStack(spacing: 12) {
            if filteredRecordings.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredRecordings) { recording in
                    Button { selectedRecording = recording } label: {
                        RecordingListRow(
                            title: displayTitle(for: recording),
                            date: recording.date,
                            duration: recording.duration,
                            preview: previewText(for: recording),
                            status: recording.status,
                            onCancel: recording.status.isProcessing ? {
                                recordingsManager.cancelProcessing(for: recording.id)
                            } : nil,
                            recording: recording
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            recordingsManager.delete(id: recording.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            shareRecordingImmediately(recording)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCalendarDate != nil ? "calendar.badge.exclamationmark" : "mic.slash")
                .font(.poppins.regular(size: 48))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(selectedCalendarDate != nil ? "No recordings for this date" : "No recordings yet")
                    .font(.poppins.title3)
                    .foregroundStyle(.secondary)
                
                if selectedCalendarDate != nil {
                    Text("Try selecting a different date or create a new recording")
                        .font(.poppins.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap the record button to create your first voice note")
                        .font(.poppins.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
        )
        .animation(.smooth(duration: 0.6), value: selectedCalendarDate)
    }
    
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField(placeholder, text: $text)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct RecordingListRow: View, Equatable {
    let title: String
    let date: Date
    let duration: TimeInterval
    let preview: String
    let status: Recording.Status
    let onCancel: (() -> Void)?
    let recording: Recording

    static func == (lhs: RecordingListRow, rhs: RecordingListRow) -> Bool {
        return lhs.recording.id == rhs.recording.id &&
               lhs.title == rhs.title &&
               lhs.preview == rhs.preview &&
               lhs.status == rhs.status
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Status-based recording icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.poppins.body)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // Enhanced date with calendar icon
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.blue.opacity(0.7))
                        Text(dateFormatted(date))
                    }
                    
                    // Enhanced duration with waveform icon
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.purple.opacity(0.7))
                        Text(timeFormatted(duration))
                    }
                }
                .font(.poppins.subheadline)
                .foregroundColor(.secondary)
                
                // Preview content with type icons
                if !preview.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: hasTranscript ? "quote.bubble" : "text.alignleft")
                            .font(.system(size: 12))
                            .foregroundColor(.green.opacity(0.7))
                        
                        Text(preview)
                            .font(.poppins.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                statusView
                
                // Tags
                if !recording.tags.isEmpty {
                    TagRowView(
                        tags: recording.tags,
                        maxVisible: 3,
                        isRemovable: false
                    )
                    .padding(.top, 2)
                }
            }
            Spacer()
            
            if status.isProcessing && onCancel != nil {
                Button(action: { onCancel?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "chevron.right").font(.headline).foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.15), .purple.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .blue.opacity(0.08), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Icon System Properties
    
    private var statusColor: Color {
        switch status {
        case .transcribing:
            return .blue
        case .summarizing:
            return .orange
        case .failed:
            return .red
        case .done:
            return .green
        case .idle:
            return .gray
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .transcribing:
            return "waveform.circle.fill"
        case .summarizing:
            return "brain.head.profile.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .done:
            return "checkmark.circle.fill"
        case .idle:
            return "mic.circle.fill"
        }
    }
    
    private var hasTranscript: Bool {
        return recording.transcript != nil && !recording.transcript!.isEmpty
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .transcribing(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("Transcribing... \(Int(progress * 100))%")
                    .font(.poppins.subheadline)
                    .foregroundColor(.blue)
            }
            
        case .summarizing(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("Summarizing... \(Int(progress * 100))%")
                    .font(.poppins.subheadline)
                    .foregroundColor(.orange)
            }
            
        case .failed(let reason):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.poppins.subheadline)
                Text("Failed: \(reason)")
                    .font(.poppins.subheadline)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            
        case .done, .idle:
            // Don't duplicate preview text here - it's already shown above
            EmptyView()
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d 'at' h:mm a"
        return df
    }()
    private func dateFormatted(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
    private func timeFormatted(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60, s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview { ContentView() }
