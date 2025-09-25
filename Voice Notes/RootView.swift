import SwiftUI
import Speech

// MARK: - Tab Selection Enum
enum Tab: String, CaseIterable {
    case home = "home"
    case recordings = "recordings"
    case documents = "documents"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .recordings: return "Recordings"
        case .documents: return "Lists"
        case .settings: return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .recordings: return "waveform"
        case .documents: return "doc.text"
        case .settings: return "gearshape"
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
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var recordingsManager: RecordingsManager
    @StateObject private var watchBridge = WatchConnectivityManager.shared
    @EnvironmentObject var documentStore: DocumentStore
    @AppStorage("hasCompletedTour") private var hasCompletedTour = false
    @AppStorage("useCompactView") private var useCompactView = true
    @State private var showingTour = false
    
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
            
            // Recordings Tab
            NavigationStack {
                RecordingsView(
                    audioRecorder: audioRecorder,
                    recordingsManager: recordingsManager
                )
            }
            .tabItem {
                Label(Tab.recordings.title, systemImage: Tab.recordings.systemImage)
            }
            .tag(Tab.recordings)
            .badge(watchBridge.hasNewFromWatch ? "●" : nil)
            
            // Lists Tab
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
            
            // Settings Tab
            NavigationStack {
                SettingsView(showingAlternativeView: $useCompactView, recordingsManager: recordingsManager)
            }
            .tabItem {
                Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
            }
            .tag(Tab.settings)
        }
        .applyLiquidGlassTabBar()
        .environmentObject(appRouter)
        .onChange(of: appRouter.selectedTab) { _, newTab in
            EnhancedTelemetryService.shared.logScreenView(screen: newTab.rawValue)
        }
        .onAppear {
            // Show tour on first app launch
            if !hasCompletedTour {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingTour = true
                }
            }
        }
        .sheet(isPresented: $showingTour) {
            AppTourView(onComplete: {
                hasCompletedTour = true
                showingTour = false
            })
        }
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
        Group {
            if documentStore.documents.isEmpty {
                emptyStateView
            } else {
                documentsListView
            }
        }
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
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
        .onAppear {
            EnhancedTelemetryService.shared.logListsOpen(from: "tab")
            Analytics.track("lists_opened")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.poppins.light(size: 64))
                    .foregroundStyle(.tertiary)
                
                VStack(spacing: 8) {
                    Text("Create your first document")
                        .font(.poppins.title2)
                        .foregroundStyle(.primary)
                    
                    Text("Organize your voice notes into actionable documents")
                        .font(.poppins.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            // Quick create buttons for each list type
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
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
                            Button(action: {
                                selectedDocument = document
                            }) {
                                DocumentRowView(document: document)
                            }
                            .buttonStyle(.plain)
                            .hoverEffect(.highlight)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    documentStore.deleteDocument(document)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
    }
    
    private var undoToast: some View {
        HStack {
            Text("List deleted")
                .font(.poppins.body)
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Undo") {
                documentStore.undoDeleteDocument()
            }
            .font(.poppins.body)
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
    @State private var selectedTagFilters: Set<String> = []
    @State private var showingTagFilterSheet = false
    @Environment(\.dismiss) private var dismiss
    
    enum SearchTab: String, CaseIterable {
        case recordings = "Recordings"
        case documents = "Lists"
        
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
                    .font(.poppins.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .font(.poppins.medium(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 64, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.quaternary.opacity(0.6), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .if(isLiquidGlassAvailable) { view in
                    view.glassEffect(.regular)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.quaternary.opacity(0.3))
                    .frame(height: 1)
            }
            
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
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.quaternary.opacity(0.2))
                    .frame(height: 1)
            }
            
            // Search content
            VStack {
                VStack(spacing: 12) {
                    LiquidGlassSearchBar(
                        text: $searchText,
                        placeholder: selectedTab == .recordings ? "Search recordings..." : "Search lists..."
                    )
                    
                    // Tag filters section
                    HStack {
                        // Selected tag filters
                        if !selectedTagFilters.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(selectedTagFilters).sorted(), id: \.self) { tag in
                                        TagChipView(
                                            tag: tag,
                                            isRemovable: true,
                                            onRemove: { selectedTagFilters.remove(tag) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer()
                        
                        // Tag filter button
                        Button(action: { showingTagFilterSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "tag")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Filter")
                                    .font(.poppins.medium(size: 14))
                            }
                            .foregroundColor(selectedTagFilters.isEmpty ? .secondary : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.regularMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(selectedTagFilters.isEmpty ? .clear : .blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }
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
        .sheet(isPresented: $showingTagFilterSheet) {
            TagFilterSheet(isPresented: $showingTagFilterSheet, selectedTags: $selectedTagFilters)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedTab.systemImage)
                .font(.poppins.light(size: 64))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("Search your \(selectedTab.rawValue.lowercased())")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text(selectedTab == .recordings ? 
                     "Find recordings by title, content, or transcript" :
                     "Find lists and items by title or content")
                    .font(.poppins.body)
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
        guard !searchText.isEmpty || !selectedTagFilters.isEmpty else { return [] }
        
        var recordings = recordingsManager.recordings
        
        // First apply tag filters if any
        if !selectedTagFilters.isEmpty {
            recordings = recordings.filter { recording in
                // Recording must have ALL selected tags (AND logic)
                selectedTagFilters.allSatisfy { selectedTag in
                    recording.tags.contains { recordingTag in
                        recordingTag.lowercased() == selectedTag.lowercased()
                    }
                }
            }
        }
        
        // Then apply text search if present
        if !searchText.isEmpty {
            let (tagSearches, textSearch) = parseSearchText(searchText)
            
            recordings = recordings.filter { recording in
                // Tag searches (#tag) - must match ALL
                let tagMatches = tagSearches.isEmpty || tagSearches.allSatisfy { tagSearch in
                    recording.tags.contains { recordingTag in
                        recordingTag.lowercased().contains(tagSearch.lowercased())
                    }
                }
                
                // Text search (if present)
                let textMatches = textSearch.isEmpty || (
                    displayTitle(for: recording).localizedCaseInsensitiveContains(textSearch) ||
                    recording.fileName.localizedCaseInsensitiveContains(textSearch) ||
                    (recording.transcript?.localizedCaseInsensitiveContains(textSearch) ?? false) ||
                    (recording.summary?.localizedCaseInsensitiveContains(textSearch) ?? false)
                )
                
                return tagMatches && textMatches
            }
        }
        
        return recordings
    }
    
    // MARK: - Helper Functions for Search
    
    private func parseSearchText(_ text: String) -> ([String], String) {
        var tagSearches: [String] = []
        var remainingText: [String] = []
        
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        for word in words {
            if word.hasPrefix("#") {
                let tag = String(word.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty {
                    tagSearches.append(tag)
                }
            } else {
                remainingText.append(word)
            }
        }
        
        return (tagSearches, remainingText.joined(separator: " "))
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
    
    private var filteredDocuments: [Document] {
        guard !searchText.isEmpty || !selectedTagFilters.isEmpty else { return [] }
        
        var documents = documentStore.documents
        
        // First apply tag filters if any
        if !selectedTagFilters.isEmpty {
            documents = documents.filter { document in
                // Document must have ALL selected tags (AND logic)
                selectedTagFilters.allSatisfy { selectedTag in
                    document.tags.contains { documentTag in
                        documentTag.lowercased() == selectedTag.lowercased()
                    }
                }
            }
        }
        
        // Then apply text search if present
        if !searchText.isEmpty {
            let (tagSearches, textSearch) = parseSearchText(searchText)
            
            documents = documents.filter { document in
                // Tag searches (#tag) - must match ALL
                let tagMatches = tagSearches.isEmpty || tagSearches.allSatisfy { tagSearch in
                    document.tags.contains { documentTag in
                        documentTag.lowercased().contains(tagSearch.lowercased())
                    }
                }
                
                // Text search (if present)
                let textMatches = textSearch.isEmpty || (
                    document.title.localizedCaseInsensitiveContains(textSearch) ||
                    document.notes.localizedCaseInsensitiveContains(textSearch) ||
                    document.items.contains { item in
                        item.text.localizedCaseInsensitiveContains(textSearch)
                    }
                )
                
                return tagMatches && textMatches
            }
        }
        
        return documents
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
                    .font(.poppins.medium(size: 20))
                    .foregroundStyle(document.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(document.type.displayName)
                            .font(.poppins.caption)
                            .foregroundStyle(.secondary)
                        
                        if document.type.usesChecklist {
                            Text("•")
                                .foregroundStyle(.quaternary)
                            Text("\(document.completedCount)/\(document.itemCount) items")
                                .font(.poppins.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(RelativeDateTimeFormatter().localizedString(for: document.updatedAt, relativeTo: Date()))
                            .font(.poppins.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.poppins.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // Show matching content preview
            if !matchingItems.isEmpty || hasContentMatch {
                VStack(alignment: .leading, spacing: 4) {
                    if !matchingItems.isEmpty {
                        Text("Matching items:")
                            .font(.poppins.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(Array(matchingItems.prefix(2)), id: \.id) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.poppins.caption)
                                    .foregroundStyle(item.isDone ? .green : .secondary)
                                
                                Text(highlightedText(item.text))
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if matchingItems.count > 2 {
                            Text("and \(matchingItems.count - 2) more...")
                                .font(.poppins.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    if hasContentMatch {
                        Text("Notes contain: \"\(searchText)\"")
                            .font(.poppins.caption)
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
    @State private var currentRecordingFileName: String?
    @State private var showingSettings = false
    @State private var showingAlternativeView = false
    @State private var isPaused = false
    @AppStorage("useCompactView") private var useCompactView = true
    
    // AI Summary mode settings
    @AppStorage("defaultMode") private var defaultMode: String = SummaryMode.personal.rawValue
    @AppStorage("autoDetectMode") private var autoDetectMode: Bool = false
    @State private var showingModeSheet = false

    var body: some View {
        if showingAlternativeView || useCompactView {
            AlternativeHomeView(
                audioRecorder: audioRecorder,
                recordingsManager: recordingsManager
            )
            .gesture(
                DragGesture()
                    .onEnded { gesture in
                        // Swipe down to return to original view (only if not set by toggle)
                        if gesture.translation.height > 100 && !useCompactView {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showingAlternativeView = false
                            }
                        }
                    }
            )
            .transition(.asymmetric(
                insertion: .push(from: .top),
                removal: .push(from: .bottom)
            ))
        } else {
            originalHomeView
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            // Swipe up on the top part to show alternative view
                            if gesture.translation.height < -100 && gesture.startLocation.y < 200 {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showingAlternativeView = true
                                }
                            }
                        }
                )
        }
    }
    
    private var originalHomeView: some View {
        VStack(spacing: 0) {
            // Sticky header
            stickyHeader
            
            // Simple content area with welcome message
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome/info section
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(.blue.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("Ready to Record")
                                .font(.poppins.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text("Tap the record button above to create a new voice note. Your recordings will appear in the Recordings tab.")
                                .font(.poppins.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 40)
                    
                    // AI Summary Mode Selector
                    summaryModeSelector
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(showingAlternativeView: $showingAlternativeView, recordingsManager: recordingsManager)
        }
        .dismissKeyboardOnTap()
        .sheet(isPresented: $showingModeSheet) {
            summaryModeSheetView
        }
    }
    
    // MARK: - AI Summary Mode Selector
    
    private var summaryModeSelector: some View {
        VStack(spacing: 16) {
            Text("AI Summary Mode")
                .font(.poppins.headline)
                .foregroundStyle(.primary)
            
            Button(action: {
                showingModeSheet = true
            }) {
                HStack(spacing: 16) {
                    // Mode icon with background
                    ZStack {
                        Circle()
                            .fill(selectedMode.color.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: selectedMode.icon)
                            .foregroundStyle(selectedMode.color)
                            .font(.system(size: 20, weight: .medium))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedMode.displayName)
                            .font(.poppins.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(selectedMode.shortDescription)
                            .font(.poppins.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary.opacity(0.8), lineWidth: 0.5)
                }
            }
            .buttonStyle(.plain)
            
            if autoDetectMode {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    
                    Text("Auto-detect mode is enabled - mode may change during recording")
                        .font(.poppins.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, -8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: autoDetectMode)
    }
    
    private var summaryModeSheetView: some View {
        NavigationView {
            List {
                Section {
                    ForEach(SummaryMode.allCases, id: \.self) { mode in
                        Button(action: {
                            let oldMode = defaultMode
                            defaultMode = mode.rawValue
                            showingModeSheet = false
                            
                            // Track mode change in analytics
                            Analytics.track("mode_changed", props: [
                                "from": oldMode,
                                "to": mode.rawValue,
                                "source": "home_mode_picker"
                            ])
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(mode.color.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: mode.icon)
                                        .foregroundStyle(mode.color)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.poppins.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text(mode.shortDescription)
                                        .font(.poppins.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if mode.rawValue == defaultMode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Choose the type of conversation you'll be recording")
                        .font(.poppins.caption)
                }
            }
            .navigationTitle("Recording Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingModeSheet = false
                    }
                    .font(.poppins.body)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Helper Properties
    
    private var selectedMode: SummaryMode {
        SummaryMode(rawValue: defaultMode) ?? .personal
    }
    
}


extension HomeView {
    private var recordingControls: some View {
        HStack(spacing: 20) {
            // Pause button (only visible when recording)
            if audioRecorder.isRecording {
                Button(action: togglePause) {
                    ZStack {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .stroke(.quaternary, lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
                .accessibilityLabel(isPaused ? "Resume recording" : "Pause recording")
                .if(isLiquidGlassAvailable) { view in
                    view.glassEffect(.regular.interactive())
                }
            }
            
            // Main record button
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
                                .font(.poppins.bold(size: 24))
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioRecorder.isRecording)
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
                Text(recordingStatusText)
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

    // MARK: - Sticky Header Component
    private var stickyHeader: some View {
        VStack(spacing: 16) {
            // Title row with control buttons
            HStack {
                Text("Voice Notes")
                    .font(.poppins.bold(size: 36))
                
                Spacer()
                
                HStack(spacing: 8) {
                    settingsButton
                }
            }
            .padding(.top, 8)
            
            // Centered mic button and status
            VStack(spacing: 16) {
                recordingControls
                recordingStatusView
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
        .padding(.top, 8) // Additional top padding for status bar
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
    }

    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape.fill")
                .font(.poppins.medium(size: 18))
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

    // MARK: - Helper Properties
    
    private var recordingStatusText: String {
        if isPaused {
            return "Recording paused"
        } else if audioRecorder.isRecording {
            return "Recording… \(Int(audioRecorder.recordingDuration))s"
        } else {
            return "Tap to start recording"
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
                
                // Reset pause state when stopping
                isPaused = false
                
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
                // Reset pause state when starting new recording
                isPaused = false
                currentRecordingFileName = await audioRecorder.startRecording()
            }
        }
    }
    
    private func togglePause() {
        if isPaused {
            audioRecorder.resumeRecording()
            isPaused = false
        } else {
            audioRecorder.pauseRecording()
            isPaused = true
        }
    }
    
    private var isLiquidGlassAvailable: Bool {
        if #available(iOS 18.0, *) {
            return true
        } else {
            return false
        }
    }
}
