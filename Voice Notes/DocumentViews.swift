import SwiftUI
import AVFoundation
import Speech

// MARK: - Document Row View
struct DocumentRowView: View {
    let document: Document
    @EnvironmentObject var documentStore: DocumentStore
    @State private var renamingId: UUID? = nil
    @State private var tempTitle: String = ""
    @FocusState private var renameFocus: UUID?
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if renamingId == document.id {
                    TextField("List title", text: $tempTitle, onCommit: {
                        documentStore.renameDocument(id: document.id, newTitle: tempTitle)
                        renamingId = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .focused($renameFocus, equals: document.id)
                    .onAppear { 
                        tempTitle = document.title
                        renameFocus = document.id
                    }
                } else {
                    Text(document.title)
                        .font(.poppins.headline)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if document.type.usesChecklist {
                        Text("\(document.completedCount)/\(document.itemCount) items")
                            .font(.poppins.caption)
                            .foregroundStyle(.secondary)
                        
                        if document.itemCount > 0 {
                            ProgressView(value: document.progressPercent)
                                .frame(width: 60)
                                .progressViewStyle(.linear)
                                .tint(document.type.color)
                        }
                    } else {
                        Text(document.notes.isEmpty ? "No notes" : "Has notes")
                            .font(.poppins.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text(RelativeDateTimeFormatter().localizedString(for: document.updatedAt, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .background(Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                renamingId = document.id
                tempTitle = document.title
            }
        }
    }
}

// MARK: - Quick Create Button
struct QuickCreateButton: View {
    let type: DocumentType
    let documentStore: DocumentStore
    @State private var isPressed = false
    
    var body: some View {
        Button(action: createDocument) {
            buttonContent
        }
        .buttonStyle(.plain)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
    
    private var buttonContent: some View {
        VStack(spacing: 8) {
            typeIcon
            typeLabel
        }
        .frame(width: 80, height: 80)
        .background(buttonBackground)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
    }
    
    private var typeIcon: some View {
        Image(systemName: type.systemImage)
            .font(.poppins.medium(size: 24))
            .foregroundStyle(type.color)
    }
    
    private var typeLabel: some View {
        Text(type.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.regularMaterial)
            .overlay(strokeOverlay)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
    
    private var strokeOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(.quaternary, lineWidth: 1)
    }
    
    private func createDocument() {
        let title = generateQuickTitle(for: type)
        _ = documentStore.createDocument(title: title, type: type)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func generateQuickTitle(for type: DocumentType) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: Date())
        
        switch type {
        case .todo:
            return "Tasks — \(dateString)"
        case .shopping:
            return "Shopping — \(dateString)"
        case .ideas:
            return "Ideas — \(dateString)"
        case .meeting:
            return "Meeting — \(dateString)"
        }
    }
}

// MARK: - Document List Overview View
struct DocumentListOverviewView: View {
    @EnvironmentObject var documentStore: DocumentStore
    @State private var showingCreateSheet = false
    
    var body: some View {
        Group {
            if documentStore.documents.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet")
                        .font(.poppins.regular(size: 44))
                        .foregroundStyle(.tertiary)
                    Text("No lists yet")
                        .font(.poppins.title3)
                    Text("Create a To‑Do, Shopping, Ideas or Meeting list.")
                        .font(.poppins.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Order: To‑Do, Shopping, Ideas, Meeting
                    Section(header: sectionHeader(.todo)) {
                        ForEach(documentStore.documents.filter { $0.type == .todo }) { document in
                            NavigationLink(destination: DocumentDetailView(document: document)) {
                                DocumentRowView(document: document)
                            }
                        }
                    }

                    Section(header: sectionHeader(.shopping)) {
                        ForEach(documentStore.documents.filter { $0.type == .shopping }) { document in
                            NavigationLink(destination: DocumentDetailView(document: document)) {
                                DocumentRowView(document: document)
                            }
                        }
                    }

                    Section(header: sectionHeader(.ideas)) {
                        ForEach(documentStore.documents.filter { $0.type == .ideas }) { document in
                            NavigationLink(destination: DocumentDetailView(document: document)) {
                                DocumentRowView(document: document)
                            }
                        }
                    }

                    Section(header: sectionHeader(.meeting)) {
                        ForEach(documentStore.documents.filter { $0.type == .meeting }) { document in
                            NavigationLink(destination: DocumentDetailView(document: document)) {
                                DocumentRowView(document: document)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateDocumentSheet()
                .environmentObject(documentStore)
        }
    }

    private func sectionHeader(_ type: DocumentType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: type.systemImage)
                .foregroundStyle(type.color)
            Text(type.displayName)
                .font(.poppins.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Create Document Sheet
struct CreateDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var documentStore: DocumentStore
    @State private var title = ""
    @State private var selectedType = DocumentType.todo
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("List Title")) {
                    TextField("Enter title...", text: $title)
                }
                
                Section(header: Text("List Type")) {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(DocumentType.allCases, id: \.self) { type in
                            DocumentTypeButton(
                                type: type,
                                isSelected: selectedType == type,
                                action: { selectedType = type }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let documentTitle = title.isEmpty ? generateDefaultTitle(for: selectedType) : title
                        documentStore.createDocument(title: documentTitle, type: selectedType)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func generateDefaultTitle(for type: DocumentType) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: Date())
        
        switch type {
        case .todo: return "Tasks — \(dateString)"
        case .shopping: return "Shopping — \(dateString)"
        case .ideas: return "Ideas — \(dateString)"
        case .meeting: return "Meeting — \(dateString)"
        }
    }
}

// MARK: - Filter Types
enum ItemFilter: String, CaseIterable {
    case all = "All"
    case open = "Open" 
    case done = "Done"
    
    var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .open: return "circle"
        case .done: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Document Detail View
struct DocumentDetailView: View {
    let document: Document
    @EnvironmentObject var documentStore: DocumentStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingTitle = false
    @State private var newTitleText = ""
    @State private var newItemText = ""
    @State private var notesText = ""
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var selectedFilter: ItemFilter = .all
    @State private var showingDatePicker = false
    @State private var selectedItemForDate: UUID?
    @State private var tempDueDate = Date()
    @FocusState private var isNewItemFocused: Bool
    @FocusState private var isNotesEditing: Bool
    @State private var editingItemId: UUID? = nil
    @State private var itemDraft: String = ""
    @FocusState private var itemFocus: UUID?
    @FocusState private var titleFocus: Bool
    @State private var isRecordingNewItem = false
    @StateObject private var voiceRecorder = VoiceRecorder()
    
    private var filteredItems: [DocItem] {
        let items = getCurrentDocument().items
        switch selectedFilter {
        case .all:
            return items
        case .open:
            return items.filter { !$0.isDone }
        case .done:
            return items.filter { $0.isDone }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title editing header
            if editingTitle {
                titleEditingHeader
            }
            
            if document.type.usesChecklist {
                checklistView
            } else {
                notesView
            }
        }
        .navigationTitle(editingTitle ? "Edit Title" : getCurrentDocument().title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if editingTitle {
                    Button("Cancel") {
                        editingTitle = false
                    }
                } else {
                    Button("Done") {
                        saveNotesIfNeeded()
                        dismiss()
                    }
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if editingTitle {
                    Button("Save") {
                        saveTitleAndExit()
                    }
                    .disabled(newTitleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button(action: { 
                        newTitleText = document.title
                        editingTitle = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            titleFocus = true
                        }
                    }) {
                        Image(systemName: "pencil")
                    }
                    
                    Button(action: shareDocument) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            notesText = document.notes
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
    }
    
    private var titleEditingHeader: some View {
        VStack(spacing: 12) {
            TextField("List title", text: $newTitleText)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .focused($titleFocus)
                .onSubmit {
                    saveTitleAndExit()
                }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private func saveTitleAndExit() {
        let trimmedTitle = newTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            documentStore.renameDocument(id: document.id, newTitle: trimmedTitle)
            
            // Haptic feedback to confirm save
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        editingTitle = false
        titleFocus = false
    }
    
    private var datePickerSheet: some View {
        NavigationView {
            VStack {
                DatePicker("Due Date", selection: $tempDueDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Set Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingDatePicker = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let itemId = selectedItemForDate {
                            documentStore.updateItemDueDate(documentId: document.id, itemId: itemId, dueDate: tempDueDate)
                        }
                        showingDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveNotesIfNeeded() {
        if !document.type.usesChecklist && notesText != document.notes {
            documentStore.updateDocumentNotes(documentId: document.id, notes: notesText)
        }
    }
    
    
    private var checklistView: some View {
        VStack(spacing: 0) {
            // Filter and Progress Section
            VStack(spacing: 16) {
                // Filter Picker - moved to top for cleaner hierarchy
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ItemFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.systemImage)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Progress Indicator - simplified
                HStack {
                    Image(systemName: document.type.systemImage)
                        .foregroundColor(document.type.color)
                        .font(.headline)
                    
                    Text("\(getCurrentDocument().completedCount)/\(getCurrentDocument().itemCount) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Items List
            List {
                if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: document.type.systemImage)
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        VStack(spacing: 8) {
                            Text("No \(selectedFilter.rawValue.lowercased()) items")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text("Add items or save action items from a recording.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredItems) { item in
                        ChecklistItemView(
                            item: item,
                            documentId: document.id,
                            documentStore: documentStore,
                            onDateTap: { itemId in
                                selectedItemForDate = itemId
                                tempDueDate = item.dueDate ?? Date()
                                showingDatePicker = true
                            },
                            editingItemId: $editingItemId,
                            itemDraft: $itemDraft,
                            itemFocus: $itemFocus
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Edit") {
                                editingItemId = item.id
                                itemDraft = item.text
                            }
                            .tint(.indigo)
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    documentStore.deleteItem(documentId: document.id, itemId: item.id)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation {
                                    documentStore.toggleItem(documentId: document.id, itemId: item.id)
                                }
                            } label: {
                                Label(item.isDone ? "Uncomplete" : "Complete", 
                                      systemImage: item.isDone ? "arrow.counterclockwise" : "checkmark")
                            }
                            .tint(item.isDone ? .orange : .green)
                        }
                    }
                    .onMove(perform: selectedFilter == .all ? moveItems : nil)
                }
            }
            .listStyle(.insetGrouped)
            
            // Add New Item Bar
            addItemBar
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: document.type.systemImage)
                .font(.poppins.light(size: 48))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No \(selectedFilter.rawValue.lowercased()) items")
                    .font(.poppins.title3)
                    .fontWeight(.medium)
                
                Text("Add items or save action items from a recording.")
                    .font(.poppins.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var addItemBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.poppins.regular(size: 20))
                .foregroundColor(.blue)
            
            TextField("Add item…", text: $newItemText)
                .textFieldStyle(.plain)
                .focused($isNewItemFocused)
                .onSubmit {
                    addNewItem()
                }
            
            // Voice recording button
            Button(action: toggleVoiceRecording) {
                Image(systemName: isRecordingNewItem ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.poppins.regular(size: 20))
                    .foregroundColor(isRecordingNewItem ? .red : .blue)
                    .scaleEffect(isRecordingNewItem ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecordingNewItem)
            }
            .buttonStyle(.plain)
            
            if !newItemText.isEmpty {
                Button("Add") {
                    addNewItem()
                }
                .font(.poppins.body)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(.regularMaterial)
        .onAppear {
            voiceRecorder.onTranscriptionComplete = { transcript in
                newItemText = transcript
                isRecordingNewItem = false
            }
        }
    }
    
    private var notesView: some View {
        VStack(spacing: 0) {
            // Notes Editor - full screen like Settings
            TextEditor(text: $notesText)
                .focused($isNotesEditing)
                .font(.body)
                .padding(16)
                .background(Color(.systemBackground))
                .onChange(of: notesText) { _, newValue in
                    // Debounce saves to avoid excessive writes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if notesText == newValue { // Only save if text hasn't changed
                            documentStore.updateDocumentNotes(documentId: document.id, notes: newValue)
                        }
                    }
                }
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func getCurrentDocument() -> Document {
        return documentStore.documents.first { $0.id == document.id } ?? document
    }
    
    private func addNewItem() {
        guard !newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        documentStore.addItems(to: document.id, items: [newItemText])
        newItemText = ""
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        documentStore.reorderItems(documentId: document.id, from: source, to: destination)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func toggleVoiceRecording() {
        if isRecordingNewItem {
            voiceRecorder.stopRecording()
        } else {
            voiceRecorder.startRecording()
        }
        isRecordingNewItem.toggle()
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func shareDocument() {
        let doc = getCurrentDocument()
        var text = "\(doc.title)\n\n"
        
        if doc.type.usesChecklist {
            if !doc.items.isEmpty {
                for item in doc.items.sorted(by: { !$0.isDone && $1.isDone }) {
                    let checkmark = item.isDone ? "✓" : "•"
                    text += "\(checkmark) \(item.text)"
                    
                    if let dueDate = item.dueDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        text += " (due: \(formatter.string(from: dueDate)))"
                    }
                    text += "\n"
                }
            }
        }
        
        if !doc.notes.isEmpty {
            text += "\nNotes:\n\(doc.notes)\n"
        }
        
        text += "\n---\nShared from Voice Notes"
        shareText = text
        showingShareSheet = true
    }
}

// MARK: - Checklist Item View
struct ChecklistItemView: View {
    let item: DocItem
    let documentId: UUID
    let documentStore: DocumentStore
    let onDateTap: ((UUID) -> Void)?
    @Binding var editingItemId: UUID?
    @Binding var itemDraft: String
    @FocusState.Binding var itemFocus: UUID?
    
    init(item: DocItem, documentId: UUID, documentStore: DocumentStore, onDateTap: ((UUID) -> Void)? = nil, editingItemId: Binding<UUID?>, itemDraft: Binding<String>, itemFocus: FocusState<UUID?>.Binding) {
        self.item = item
        self.documentId = documentId
        self.documentStore = documentStore
        self.onDateTap = onDateTap
        self._editingItemId = editingItemId
        self._itemDraft = itemDraft
        self._itemFocus = itemFocus
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: toggleItem) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.poppins.regular(size: 20))
                    .foregroundColor(item.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                if editingItemId == item.id {
                    TextField("Edit item", text: $itemDraft, onCommit: {
                        documentStore.updateItemText(documentId: documentId, itemId: item.id, newText: itemDraft)
                        editingItemId = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .focused($itemFocus, equals: item.id)
                    .onAppear { 
                        itemDraft = item.text
                        itemFocus = item.id
                    }
                } else {
                    Text(item.text)
                        .font(.poppins.body)
                        .strikethrough(item.isDone)
                        .foregroundColor(item.isDone ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") {
                                editingItemId = item.id
                                itemDraft = item.text
                            }
                        }
                }
                
                if let dueDate = item.dueDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Date picker button
            if let onDateTap = onDateTap {
                Button(action: { onDateTap(item.id) }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleItem()
        }
    }
    
    private func toggleItem() {
        documentStore.toggleItem(documentId: documentId, itemId: item.id)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Document Type Button
struct DocumentTypeButton: View {
    let type: DocumentType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .buttonStyle(.plain)
    }
    
    private var buttonContent: some View {
        VStack(spacing: 8) {
            typeIcon
            typeLabel
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(buttonBackground)
    }
    
    private var typeIcon: some View {
        Image(systemName: type.systemImage)
            .font(.poppins.medium(size: 24))
            .foregroundStyle(isSelected ? .white : type.color)
    }
    
    private var typeLabel: some View {
        Text(type.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(isSelected ? .white : .primary)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? AnyShapeStyle(type.color) : AnyShapeStyle(.regularMaterial))
            .overlay(strokeOverlay)
    }
    
    private var strokeOverlay: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(isSelected ? AnyShapeStyle(.clear) : AnyShapeStyle(.quaternary), lineWidth: 1)
    }
}

// MARK: - Voice Recorder for List Items
class VoiceRecorder: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    var onTranscriptionComplete: ((String) -> Void)?
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }
    
    func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        // Request permissions
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                print("Speech recognition not authorized")
                return
            }
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            audioEngine = AVAudioEngine()
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let audioEngine = audioEngine,
                  let recognitionRequest = recognitionRequest else {
                print("Failed to create audio engine or recognition request")
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        DispatchQueue.main.async {
                            self?.onTranscriptionComplete?(transcript)
                        }
                    }
                }
                
                if error != nil || (result?.isFinal ?? false) {
                    DispatchQueue.main.async {
                        self?.stopRecording()
                    }
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        audioEngine = nil
    }
}

// MARK: - Press Gesture Extension
extension View {
    func onPressGesture(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self
            .onTapGesture(perform: onRelease)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }, perform: {})
    }
}

