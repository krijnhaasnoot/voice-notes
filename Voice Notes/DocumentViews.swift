import SwiftUI

// MARK: - Document Row View
struct DocumentRowView: View {
    let document: Document
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if document.type.usesChecklist {
                        Text("\(document.completedCount)/\(document.itemCount) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if document.itemCount > 0 {
                            ProgressView(value: document.progressPercent)
                                .frame(width: 60)
                                .progressViewStyle(.linear)
                                .tint(document.type.color)
                        }
                    } else {
                        Text(document.notes.isEmpty ? "No notes" : "Has notes")
                            .font(.caption)
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
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .opacity(0)
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
            .font(.system(size: 24, weight: .medium))
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
        documentStore.createDocument(title: title, type: type)
        
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
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Document Title")
                        .font(.headline)
                    
                    TextField("Enter title...", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Document Type")
                        .font(.headline)
                    
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(DocumentType.allCases, id: \.self) { type in
                            DocumentTypeButton(
                                type: type,
                                isSelected: selectedType == type,
                                action: { selectedType = type }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Document")
            .navigationBarTitleDisplayMode(.inline)
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
        NavigationView {
            VStack(spacing: 0) {
                if document.type.usesChecklist {
                    checklistView
                } else {
                    notesView
                }
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: shareDocument) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Button("Add from Recording") {
                        // Placeholder for next step
                    }
                    .font(.caption)
                    .disabled(true)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        saveNotesIfNeeded()
                        dismiss()
                    }
                }
            }
            .onAppear {
                notesText = document.notes
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [shareText])
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
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
            // Progress and Filter Header
            VStack(spacing: 12) {
                // Progress Indicator
                HStack {
                    Image(systemName: document.type.systemImage)
                        .foregroundColor(document.type.color)
                    
                    Text("\(getCurrentDocument().completedCount)/\(getCurrentDocument().itemCount) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ItemFilter.allCases, id: \.self) { filter in
                        Label(filter.rawValue, systemImage: filter.systemImage)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(.regularMaterial)
            
            // Items List or Empty State
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredItems) { item in
                        ChecklistItemView(
                            item: item,
                            documentId: document.id,
                            documentStore: documentStore,
                            onDateTap: { itemId in
                                selectedItemForDate = itemId
                                tempDueDate = item.dueDate ?? Date()
                                showingDatePicker = true
                            }
                        )
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // Add New Item Bar
            addItemBar
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: document.type.systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text("No \(selectedFilter.rawValue.lowercased()) items")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("Add items or save action items from a recording.")
                    .font(.body)
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
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            TextField("Add item…", text: $newItemText)
                .textFieldStyle(.plain)
                .focused($isNewItemFocused)
                .onSubmit {
                    addNewItem()
                }
            
            if !newItemText.isEmpty {
                Button("Add") {
                    addNewItem()
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private var notesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: document.type.systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(document.type.color)
                
                Text("Notes")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding()
            .background(.regularMaterial)
            
            // Notes Editor
            TextEditor(text: $notesText)
                .focused($isNotesEditing)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .onChange(of: notesText) { _, newValue in
                    // Debounce saves to avoid excessive writes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if notesText == newValue { // Only save if text hasn't changed
                            documentStore.updateDocumentNotes(documentId: document.id, notes: newValue)
                        }
                    }
                }
        }
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
    
    init(item: DocItem, documentId: UUID, documentStore: DocumentStore, onDateTap: ((UUID) -> Void)? = nil) {
        self.item = item
        self.documentId = documentId
        self.documentStore = documentStore
        self.onDateTap = onDateTap
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: toggleItem) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(item.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.body)
                    .strikethrough(item.isDone)
                    .foregroundColor(item.isDone ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                
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
            .font(.system(size: 24, weight: .medium))
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