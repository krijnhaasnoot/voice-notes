import SwiftUI
import Speech

// MARK: - Tab Selection Enum
enum Tab: String, CaseIterable {
    case home = "home"
    case documents = "documents"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .documents: return "Documents"
        }
    }
    
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .documents: return "doc.text"
        }
    }
}

// MARK: - App Router for Tab Switching
class AppRouter: ObservableObject {
    @Published var selectedTab: Tab = .home
}

// MARK: - Root View
struct RootView: View {
    @StateObject private var appRouter = AppRouter()
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var recordingsManager = RecordingsManager()
    
    var body: some View {
        TabView(selection: $appRouter.selectedTab) {
            // Home Tab
            NavigationStack {
                HomeView(
                    audioRecorder: audioRecorder,
                    recordingsManager: recordingsManager
                )
            }
            .tabItem {
                Label(Tab.home.title, systemImage: Tab.home.systemImage)
            }
            .tag(Tab.home)
            
            // Documents Tab
            NavigationStack {
                DocumentsView(
                    audioRecorder: audioRecorder,
                    recordingsManager: recordingsManager
                )
            }
            .tabItem {
                Label(Tab.documents.title, systemImage: Tab.documents.systemImage)
            }
            .tag(Tab.documents)
        }
        .applyLiquidGlassTabBar()
        .environmentObject(appRouter)
    }
}

// MARK: - Documents View
struct DocumentsView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var appRouter: AppRouter
    @EnvironmentObject var documentStore: DocumentStore
    @State private var selectedDocument: Document?
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationView {
            Group {
                if documentStore.documents.isEmpty {
                    emptyStateView
                } else {
                    documentsListView
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document)
                .onAppear {
                    documentStore.markOpened(document.id)
                }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateDocumentSheet()
        }
        .overlay(alignment: .bottom) {
            if documentStore.recentlyDeletedDocument != nil {
                undoToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: documentStore.recentlyDeletedDocument != nil)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.tertiary)
                
                VStack(spacing: 8) {
                    Text("Create your first document")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Organize your voice notes into actionable documents")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    QuickCreateButton(type: .todo, documentStore: documentStore)
                    QuickCreateButton(type: .shopping, documentStore: documentStore)
                }
                
                HStack(spacing: 16) {
                    QuickCreateButton(type: .ideas, documentStore: documentStore)
                    QuickCreateButton(type: .meeting, documentStore: documentStore)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    private var documentsListView: some View {
        List {
            ForEach(DocumentType.allCases, id: \.self) { type in
                let documentsOfType = documentStore.documents.filter { $0.type == type }
                
                if !documentsOfType.isEmpty {
                    Section(header: 
                        HStack {
                            Image(systemName: type.systemImage)
                                .foregroundStyle(type.color)
                            Text(type.displayName)
                                .textCase(nil)
                        }
                        .font(.headline)
                    ) {
                        ForEach(documentsOfType.sorted(by: { $0.updatedAt > $1.updatedAt })) { document in
                            DocumentRowView(document: document)
                                .onTapGesture {
                                    selectedDocument = document
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let sortedDocs = documentsOfType.sorted(by: { $0.updatedAt > $1.updatedAt })
                                documentStore.deleteDocument(sortedDocs[index])
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    private var undoToast: some View {
        HStack {
            Text("Document deleted")
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Undo") {
                documentStore.undoDeleteDocument()
            }
            .font(.body)
            .fontWeight(.semibold)
            .foregroundColor(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.85))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 34) // Account for tab bar
    }
}

// MARK: - Search View
struct SearchView: View {
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var documentStore: DocumentStore
    @State private var searchText = ""
    @State private var selectedRecording: Recording?
    @State private var selectedDocument: Document?
    @State private var selectedTab: SearchTab = .recordings
    @Environment(\.dismiss) private var dismiss
    
    enum SearchTab: String, CaseIterable {
        case recordings = "Recordings"
        case documents = "Documents"
        
        var systemImage: String {
            switch self {
            case .recordings: return "waveform"
            case .documents: return "doc.text"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Search")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial)
            
            // Tab Picker
            Picker("Search Type", selection: $selectedTab) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(.regularMaterial)
            
            // Search content
            VStack {
                LiquidGlassSearchBar(
                    text: $searchText,
                    placeholder: selectedTab == .recordings ? "Search recordings..." : "Search documents..."
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                if searchText.isEmpty {
                    emptyStateView
                } else {
                    searchResultsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .dismissKeyboardOnTap()
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recordingId: recording.id, recordingsManager: recordingsManager)
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document)
                .onAppear {
                    documentStore.markOpened(document.id)
                }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedTab.systemImage)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("Search your \(selectedTab.rawValue.lowercased())")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(selectedTab == .recordings ? 
                     "Find recordings by title, content, or transcript" :
                     "Find documents and items by title or content")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if selectedTab == .recordings {
                    recordingResults
                } else {
                    documentResults
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private var recordingResults: some View {
        ForEach(filteredRecordings) { recording in
            RecordingRow(recording: recording)
                .onTapGesture {
                    selectedRecording = recording
                }
        }
    }
    
    private var documentResults: some View {
        ForEach(filteredDocuments) { document in
            SearchDocumentRow(document: document, searchText: searchText)
                .onTapGesture {
                    selectedDocument = document
                }
        }
    }
    
    private var filteredRecordings: [Recording] {
        guard !searchText.isEmpty else { return [] }
        
        return recordingsManager.recordings.filter { recording in
            recording.title.localizedCaseInsensitiveContains(searchText) ||
            recording.fileName.localizedCaseInsensitiveContains(searchText) ||
            (recording.transcript?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (recording.summary?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var filteredDocuments: [Document] {
        guard !searchText.isEmpty else { return [] }
        
        return documentStore.documents.filter { document in
            document.title.localizedCaseInsensitiveContains(searchText) ||
            document.notes.localizedCaseInsensitiveContains(searchText) ||
            document.items.contains { item in
                item.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Search Document Row
struct SearchDocumentRow: View {
    let document: Document
    let searchText: String
    
    private var matchingItems: [DocItem] {
        document.items.filter { item in
            item.text.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var hasContentMatch: Bool {
        document.notes.localizedCaseInsensitiveContains(searchText) && !document.notes.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: document.type.systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(document.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(document.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if document.type.usesChecklist {
                            Text("•")
                                .foregroundStyle(.quaternary)
                            Text("\(document.completedCount)/\(document.itemCount) items")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(RelativeDateTimeFormatter().localizedString(for: document.updatedAt, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // Show matching content preview
            if !matchingItems.isEmpty || hasContentMatch {
                VStack(alignment: .leading, spacing: 4) {
                    if !matchingItems.isEmpty {
                        Text("Matching items:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        ForEach(Array(matchingItems.prefix(2)), id: \.id) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                    .foregroundStyle(item.isDone ? .green : .secondary)
                                
                                Text(highlightedText(item.text))
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if matchingItems.count > 2 {
                            Text("and \(matchingItems.count - 2) more...")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    if hasContentMatch {
                        Text("Notes contain: \"\(searchText)\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                .padding(.horizontal, 36)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private func highlightedText(_ text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        if let range = text.range(of: searchText, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: text)
            if let attributedRange = Range<AttributedString.Index>(nsRange, in: attributedString) {
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attributedRange].foregroundColor = .primary
            }
        }
        
        return attributedString
    }
}

// MARK: - Home View (Original Start Screen)
struct HomeView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @ObservedObject var recordingsManager: RecordingsManager
    @EnvironmentObject var appRouter: AppRouter
    
    @State private var showingPermissionAlert = false
    @State private var permissionGranted = false
    @State private var selectedRecording: Recording?
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var searchScope: SearchScope = .all
    @FocusState private var isSearchFocused: Bool
    @State private var currentRecordingFileName: String?
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = ["Transcript wordt nog gemaakt…"]
    @State private var selectedCalendarDate: Date?
    @State private var showingCalendar = false
    @State private var showingSettings = false
    
    enum SearchScope: String, CaseIterable {
        case all = "All"
        case transcripts = "Transcripts"
        case titles = "Titles"
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
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
                // Original vertical layout for portrait (matching ContentView exactly)
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

                    LiquidGlassButtonContainer {
                        HStack(spacing: 8) {
                            searchButton
                            settingsButton
                            calendarButton
                        }
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .focused($isSearchFocused)
        .onChange(of: searchText) { oldValue, newValue in
            // Debounce search with 250ms delay
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                if searchText == newValue {
                    await MainActor.run {
                        debouncedSearchText = newValue
                    }
                }
            }
        }
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
        .sheet(item: $selectedRecording) { recording in
            RecordingDetailView(recordingId: recording.id, recordingsManager: recordingsManager)
        }
        .sheet(isPresented: $isSharePresented) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .dismissKeyboardOnTap()
    }

    private var recordButton: some View {
        Button(action: {
            if permissionGranted {
                toggleRecording()
            } else {
                requestPermissions()
            }
        }) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Circle()
                            .stroke(.quaternary, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                
                Circle()
                    .fill(audioRecorder.isRecording ? 
                          LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .top, endPoint: .bottom) : 
                          LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .scaleEffect(audioRecorder.isRecording ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioRecorder.isRecording)
        .accessibilityLabel(audioRecorder.isRecording ? "Stop recording" : "Start recording")
        .if(isLiquidGlassAvailable) { view in
            view.glassEffect(.regular.interactive())
        }
    }
    
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

    private var filteredRecordings: [Recording] {
        var recordings = recordingsManager.recordings
        
        // Filter by selected date if one is chosen
        if let selectedDate = selectedCalendarDate {
            recordings = recordings.filter { recording in
                Calendar.current.isDate(recording.date, inSameDayAs: selectedDate)
            }
        }
        
        // Filter by debounced search query with scopes
        let query = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            recordings = recordings.filter { recording in
                switch searchScope {
                case .all:
                    return displayTitle(for: recording).localizedCaseInsensitiveContains(query) ||
                           recording.fileName.localizedCaseInsensitiveContains(query) ||
                           (recording.transcript?.localizedCaseInsensitiveContains(query) ?? false) ||
                           (recording.summary?.localizedCaseInsensitiveContains(query) ?? false)
                
                case .transcripts:
                    return (recording.transcript?.localizedCaseInsensitiveContains(query) ?? false) ||
                           (recording.summary?.localizedCaseInsensitiveContains(query) ?? false)
                
                case .titles:
                    return displayTitle(for: recording).localizedCaseInsensitiveContains(query) ||
                           recording.fileName.localizedCaseInsensitiveContains(query)
                }
            }
        }
        
        return recordings
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
                    
                    HStack(spacing: 8) {
                        searchButton
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
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(showingCalendar ? .white : .blue)
                .frame(width: 40, height: 40)
                .background {
                    if showingCalendar {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(showingCalendar ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingCalendar)
        .if(isLiquidGlassAvailable) { view in
            view.glassEffect(.regular)
        }
    }
    
    private var searchButton: some View {
        Button(action: {
            // Light haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Focus the native search field
            isSearchFocused = true
        }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.quaternary.opacity(0.6), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
        }
        .buttonStyle(.plain)
        .if(isLiquidGlassAvailable) { view in
            view.glassEffect(.regular)
        }
    }

    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.quaternary.opacity(0.6), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
        }
        .buttonStyle(.plain)
        .if(isLiquidGlassAvailable) { view in
            view.glassEffect(.regular)
        }
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
                        print("🎯 HomeView: Starting transcription for \(fileName) (size: \(fileSize) bytes)")
                        await MainActor.run {
                            recordingsManager.startTranscription(for: newRecording)
                        }
                    } else {
                        print("🎯 HomeView: ❌ NOT starting transcription - fileSize: \(result.fileSize ?? -1)")
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
                shareItems = [Voice_Notes.makeShareText(for: recording, overrideTranscript: transcript, overrideSummary: summary)]
            }
        }
    }
}