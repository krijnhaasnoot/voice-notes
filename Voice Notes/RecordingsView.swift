import SwiftUI
import Speech

struct RecordingsView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var appRouter: AppRouter
    
    @State private var selectedRecording: Recording?
    @State private var selectedCalendarDate: Date?
    @State private var showingCalendar = false
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = ["Transcript wordt nog gemaakt…"]
    
    private var filteredRecordings: [Recording] {
        var recordings = recordingsManager.recordings
        
        // Filter by selected date if one is chosen
        if let selectedDate = selectedCalendarDate {
            recordings = recordings.filter { recording in
                Calendar.current.isDate(recording.date, inSameDayAs: selectedDate)
            }
        }
        
        return recordings
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar (when shown)
            if showingCalendar {
                LiquidCalendarView(selectedDate: $selectedCalendarDate, recordings: recordingsManager.recordings, startExpanded: true)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .background(.ultraThinMaterial)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
            
            // Main recordings list
            Group {
                if filteredRecordings.isEmpty {
                    emptyStateView
                } else {
                    recordingsListView
                }
            }
        }
        .navigationTitle("Recordings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation(.smooth(duration: 0.6, extraBounce: 0.2)) {
                        showingCalendar.toggle()
                    }
                }) {
                    Image(systemName: showingCalendar ? "calendar.badge.checkmark" : "calendar")
                        .foregroundStyle(showingCalendar ? .white : .blue)
                }
                .background(showingCalendar ? .blue : .clear)
                .clipShape(Circle())
            }
        }
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recordingId: recording.id, recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: shareItems)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCalendarDate != nil ? "calendar.badge.exclamationmark" : "waveform.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(selectedCalendarDate != nil ? "No recordings for this date" : "No recordings yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                if let selectedDate = selectedCalendarDate {
                    Text("Try selecting a different date or create a new recording from the Home tab")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Go to the Home tab and tap the record button to create your first voice note")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
            
            if selectedCalendarDate != nil {
                Button("Show All Recordings") {
                    withAnimation(.smooth(duration: 0.4)) {
                        selectedCalendarDate = nil
                    }
                }
                .font(.poppins.headline)
                .foregroundColor(.blue)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .animation(.smooth(duration: 0.6), value: selectedCalendarDate)
    }
    
    private var recordingsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Header with selected date info
                if selectedCalendarDate != nil {
                    HStack {
                        Text("Recordings for \(formattedSelectedDate)")
                            .font(.poppins.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Show All") {
                            withAnimation(.smooth(duration: 0.4)) {
                                selectedCalendarDate = nil
                            }
                        }
                        .font(.poppins.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                
                ForEach(filteredRecordings) { recording in
                    Button { 
                        selectedRecording = recording 
                    } label: {
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
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    
    // MARK: - Helper Properties & Functions
    
    private var formattedSelectedDate: String {
        guard let selectedCalendarDate = selectedCalendarDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedCalendarDate)
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
                shareItems = [Voice_Notes.makeShareText(for: recording, overrideTranscript: transcript, overrideSummary: summary)]
            }
        }
    }
}

// MARK: - Extensions for Liquid Glass Support

private var rv_isLiquidGlassAvailable: Bool {
    if #available(iOS 18.0, *) {
        return true
    } else {
        return false
    }
}

extension View {
    @ViewBuilder
    func rv_if<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func rv_glassEffect() -> some View {
        if #available(iOS 18.0, *) {
            // Placeholder for the actual glass effect API when available
            self
        } else {
            self
        }
    }
}

#Preview {
    NavigationView {
        RecordingsView(
            audioRecorder: AudioRecorder(),
            recordingsManager: RecordingsManager()
        )
    }
}
