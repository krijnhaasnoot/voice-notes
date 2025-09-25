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
    @State private var shareItems: [Any] = []
    
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
        ZStack {
            // Subtle background gradient
            LinearGradient(
                colors: [
                    .clear,
                    .blue.opacity(0.02),
                    .purple.opacity(0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
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
        }
        .navigationTitle("Recordings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                EditButton()
                    .foregroundColor(.blue)
                
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
        VStack(spacing: 20) {
            // Attractive gradient icon background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: selectedCalendarDate != nil ? "calendar.badge.exclamationmark" : "mic.badge.plus")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text(selectedCalendarDate != nil ? "No recordings for this date" : "Ready to capture your thoughts")
                    .font(.poppins.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                if let selectedDate = selectedCalendarDate {
                    Text("Try selecting a different date or create a new recording from the Home tab")
                        .font(.poppins.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                } else {
                    Text("Start your first voice note and let AI organize your thoughts automatically")
                        .font(.poppins.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
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
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(25)
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            }
        }
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.8),
                            .blue.opacity(0.05),
                            .purple.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.2), .purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
        .animation(.smooth(duration: 0.6), value: selectedCalendarDate)
    }
    
    private var recordingsListView: some View {
        VStack(spacing: 0) {
            // Header with selected date info
            if selectedCalendarDate != nil {
                HStack {
                    // Calendar icon with gradient
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                    
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.blue.opacity(0.7))
                            Text("Recordings for")
                                .font(.poppins.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(formattedSelectedDate)
                            .font(.poppins.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.smooth(duration: 0.4)) {
                            selectedCalendarDate = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.circle.fill")
                                .font(.system(size: 14))
                            Text("Show All")
                        }
                    }
                    .font(.poppins.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .blue.opacity(0.2), radius: 4, y: 2)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.blue.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            
            // List with native swipe actions
            List {
                ForEach(filteredRecordings) { recording in
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRecording = recording
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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
                .onDelete { indexSet in
                    for index in indexSet {
                        let recording = filteredRecordings[index]
                        recordingsManager.delete(id: recording.id)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 80)
        }
        .onAppear {
            // Clear the red dot when user views recordings
            WatchConnectivityManager.shared.hasNewFromWatch = false
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("newRecordingFromWatch"))) { _ in
            // Optional: could show a toast/notification here
        }
    }
    
    
    // MARK: - Helper Properties & Functions
    
    private var formattedSelectedDate: String {
        guard let selectedCalendarDate = selectedCalendarDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedCalendarDate)
    }
    
    private func displayTitle(for r: Recording) -> String {
        // NEVER use transcript for title - only AI summary or filename
        
        // 1. If AI summary exists: use FIRST meaningful line from summary as title
        if let summary = r.summary, let first = firstMeaningfulLine(from: summary) {
            return first
        }
        
        // 2. Else (no summary yet): use filename WITHOUT extension
        if !r.fileName.isEmpty {
            return URL(fileURLWithPath: r.fileName).deletingPathExtension().lastPathComponent
        }
        
        // 3. If filename empty/unavailable: use "Untitled – {yyyy-MM-dd HH:mm}"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return "Untitled – \(f.string(from: r.date))"
    }
    
    private func firstMeaningfulLine(from text: String) -> String? {
        let stripped = stripSimpleMarkdown(text)
        for raw in stripped.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            // skip markdown bullets/headers
            if line.hasPrefix("#") || line.hasPrefix("**") || line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix(">") { continue }
            if line.count >= 10 { return line }
        }
        return nil
    }

    private func stripSimpleMarkdown(_ s: String) -> String {
        var out = s
        // remove common markdown tokens
        let tokens = ["**", "__", "*", "_", "`"]
        tokens.forEach { out = out.replacingOccurrences(of: $0, with: "") }
        return out
    }
    
    private func previewText(for recording: Recording) -> String { 
        // Show AI summary content (skip first line since it's used as title)
        if let summary = recording.summary, !summary.isEmpty {
            let stripped = stripSimpleMarkdown(summary)
            let lines = stripped.components(separatedBy: .newlines)
            var foundFirstMeaningful = false
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("**") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix(">") { continue }
                if trimmed.count < 10 { continue }
                
                // Skip first meaningful line (it's used as title)
                if !foundFirstMeaningful {
                    foundFirstMeaningful = true
                    continue
                }
                
                // Return second meaningful line as preview
                return trimmed.count > 100 ? String(trimmed.prefix(100)) + "..." : trimmed
            }
        }
        
        // If no summary content available, show processing status
        return ""
    }
    
    
    private func shareRecordingImmediately(_ recording: Recording) {
        // Generate share text immediately since transcript and summary are already available
        let shareText = Voice_Notes.makeShareText(for: recording)
        shareItems = [shareText]
        isSharePresented = true
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
            audioRecorder: AudioRecorder.shared,
            recordingsManager: RecordingsManager.shared
        )
    }
}
