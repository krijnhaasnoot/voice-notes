//
//  ContentView.swift
//  Voice Notes
//
//  Created by Krijn Haasnoot on 06/09/2025.
//

import SwiftUI
import Speech

struct ContentView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var recordingsManager = RecordingsManager()
    @State private var showingPermissionAlert = false
    @State private var permissionGranted = false
    @State private var selectedRecording: Recording?
    @State private var currentRecordingFileName: String?
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = ["Transcript wordt nog gemaakt…"]
    @State private var selectedCalendarDate: Date?
    @State private var showingCalendar = false
    @State private var showingSettings = false
    @State private var searchText = ""

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            NavigationView {
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
                                Text("Voice Notes")
                                    .font(.system(size: 36, weight: .bold))
                                    .padding(.top, 8)
                                    .padding(.horizontal)

                                VStack(spacing: 16) {
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
                                        .font(.title2).bold()
                                    
                                    if selectedCalendarDate != nil {
                                        Spacer()
                                        Button("Show All") {
                                            withAnimation(.smooth(duration: 0.4)) {
                                                selectedCalendarDate = nil
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)

                                recordingsList
                            }
                        }

                        HStack(spacing: 12) {
                            settingsButton
                            calendarButton
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 20)
                    }
                }
            }
            .navigationBarHidden(true)
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
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recordingId: recording.id, recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var recordButton: some View {
        Button(action: {
            if permissionGranted {
                toggleRecording()
            } else {
                requestPermissions()
            }
        }) {
            Circle()
                .fill(audioRecorder.isRecording ? Color.red : Color.blue)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
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
        if !recording.title.isEmpty {
            return recording.title
        }
        let base = recording.fileName
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "Untitled" : base
    }

    private func previewText(for recording: Recording) -> String { 
        if let transcript = recording.transcript, !transcript.isEmpty {
            return String(transcript.prefix(100)) + (transcript.count > 100 ? "..." : "")
        }
        if let summary = recording.summary, !summary.isEmpty {
            return String(summary.prefix(100)) + (summary.count > 100 ? "..." : "")
        }
        return ""
    }
    
    private func shareRecordingImmediately(_ recording: Recording) {
        shareItems = ["Transcript wordt nog gemaakt…"]
        isSharePresented = true
        
        Task {
            let transcript = recording.transcript
            let summary = recording.summary
            
            await MainActor.run {
                shareItems = [makeShareText(for: recording, overrideTranscript: transcript, overrideSummary: summary)]
            }
        }
    }
    
    // MARK: - Horizontal Layout Components
    
    private var recordingSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Voice Notes")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
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
                    
                    HStack(spacing: 12) {
                        settingsButton
                        calendarButton
                    }
                    .padding(.trailing, 8)
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
                LazyVStack(spacing: 12) {
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
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Extracted View Components
    
    private var recordingStatusView: some View {
        VStack(spacing: 8) {
            if let error = audioRecorder.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text(audioRecorder.isRecording ? "Recording… \(Int(audioRecorder.recordingDuration))s" : "Tap to start recording")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Debug: Show recent transcription status
            if let mostRecent = recordingsManager.recordings.first {
                switch mostRecent.status {
                case .transcribing(let progress):
                    Text("Transcribing: \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.blue)
                case .summarizing(let progress):
                    Text("Summarizing: \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.green)
                case .failed(let reason):
                    Text("Failed: \(reason)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                case .done:
                    if let transcript = mostRecent.transcript, !transcript.isEmpty {
                        Text("✅ Transcribed: \(transcript.count) chars")
                            .font(.caption)
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
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(selectedCalendarDate != nil ? "No recordings for this date" : "No recordings yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                if let selectedDate = selectedCalendarDate {
                    Text("Try selecting a different date or create a new recording")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap the record button to create your first voice note")
                        .font(.body)
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
    
    private var calendarButton: some View {
        Button(action: {
            withAnimation(.smooth(duration: 0.6, extraBounce: 0.2)) {
                showingCalendar.toggle()
            }
        }) {
            Image(systemName: showingCalendar ? "calendar.badge.checkmark" : "calendar")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.gray)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
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
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text(dateFormatted(date))
                    HStack(spacing: 4) { Image(systemName: "clock"); Text(timeFormatted(duration)) }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                statusView
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
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.quaternary.opacity(0.4), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .transcribing(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("Transcribing... \(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
        case .summarizing(let progress):
            HStack {
                ProgressView(value: progress)
                    .frame(width: 100)
                Text("Summarizing... \(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
        case .failed(let reason):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.subheadline)
                Text("Failed: \(reason)")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            
        case .done, .idle:
            if !preview.isEmpty { 
                Text(preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2) 
            }
        }
    }

    private func dateFormatted(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "MMM d 'at' h:mm a"; return df.string(from: date)
    }
    private func timeFormatted(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60, s = Int(interval) % 60; return String(format: "%d:%02d", m, s)
    }
}

#Preview { ContentView() }
