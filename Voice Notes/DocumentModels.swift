import Foundation
import SwiftUI

// MARK: - Document Types
enum DocumentType: String, CaseIterable, Codable {
    case todo = "todo"
    case shopping = "shopping"
    case ideas = "ideas"
    case meeting = "meeting"
    
    var displayName: String {
        switch self {
        case .todo: return L10n.Document.todo.localized
        case .shopping: return L10n.Document.shopping.localized
        case .ideas: return L10n.Document.ideas.localized
        case .meeting: return L10n.Document.meeting.localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .todo: return "checkmark.circle"
        case .shopping: return "cart"
        case .ideas: return "lightbulb"
        case .meeting: return "person.2"
        }
    }
    
    var color: Color {
        switch self {
        case .todo: return .blue
        case .shopping: return .green
        case .ideas: return .orange
        case .meeting: return .purple
        }
    }
    
    var usesChecklist: Bool {
        switch self {
        case .todo, .shopping, .ideas, .meeting: return true
        }
    }
}

// MARK: - Document Item
struct DocItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var isDone: Bool
    var dueDate: Date?
    var sourceRecordingId: UUID?
    var createdAt: Date
    
    init(id: UUID = UUID(), text: String, isDone: Bool = false, dueDate: Date? = nil, sourceRecordingId: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isDone = isDone
        self.dueDate = dueDate
        self.sourceRecordingId = sourceRecordingId
        self.createdAt = createdAt
    }
}

// MARK: - Document
struct Document: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var type: DocumentType
    var createdAt: Date
    var updatedAt: Date
    var items: [DocItem]
    var notes: String
    var tags: [String]
    
    init(id: UUID = UUID(), title: String, type: DocumentType, createdAt: Date = Date(), updatedAt: Date = Date(), items: [DocItem] = [], notes: String = "", tags: [String] = []) {
        self.id = id
        self.title = title
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
        self.notes = notes
        self.tags = tags.normalized()
    }
    
    var itemCount: Int {
        return items.count
    }
    
    var completedCount: Int {
        return items.filter { $0.isDone }.count
    }
    
    var progressPercent: Double {
        guard itemCount > 0 else { return 0.0 }
        return Double(completedCount) / Double(itemCount)
    }
}

// MARK: - Document Store
// MARK: - Last Add Record for Undo
struct LastAdd {
    let documentId: UUID
    let itemIds: [UUID]
    let timestamp: Date
}

class DocumentStore: ObservableObject {
    @Published var documents: [Document] = []
    @Published var recentlyDeletedDocument: Document?
    @Published var lastAdd: LastAdd?
    
    private let documentsURL: URL
    private var recentDocumentIds: [UUID] = [] // Track recency
    private let telemetryService = EnhancedTelemetryService.shared
    
    init() {
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.documentsURL = documentsPath.appendingPathComponent("voice_notes_documents.json")
        
        loadDocuments()
        setupTagNotifications()
    }
    
    // MARK: - Persistence
    private func saveDocuments() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: documentsURL)
        } catch {
            print("Failed to save documents: \(error)")
        }
    }
    
    private func loadDocuments() {
        do {
            let data = try Data(contentsOf: documentsURL)
            let loadedDocuments = try JSONDecoder().decode([Document].self, from: data)
            
            // Migration: ensure all documents have tags property
            documents = loadedDocuments.map { doc in
                // If Document doesn't have tags property, it will have empty tags from init
                return doc
            }
            
            // Add all existing tags to TagStore on main actor
            Task { @MainActor in
                for document in documents {
                    for tag in document.tags {
                        TagStore.shared.add(tag)
                    }
                }
            }
        } catch {
            print("Failed to load documents (this is normal on first launch): \(error)")
            documents = []
        }
    }
    
    private func setupTagNotifications() {
        NotificationCenter.default.addObserver(
            forName: .tagRenamed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let oldTag = userInfo["old"] as? String,
                  let newTag = userInfo["new"] as? String else { return }
            self?.renameTagInAllDocuments(from: oldTag, to: newTag)
        }
        
        NotificationCenter.default.addObserver(
            forName: .tagRemoved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let tag = userInfo["tag"] as? String else { return }
            self?.removeTagFromAllDocuments(tag: tag)
        }
        
        NotificationCenter.default.addObserver(
            forName: .tagMerged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let fromTag = userInfo["from"] as? String,
                  let intoTag = userInfo["into"] as? String else { return }
            self?.mergeTagInAllDocuments(from: fromTag, into: intoTag)
        }
    }
    
    private func renameTagInAllDocuments(from oldTag: String, to newTag: String) {
        for i in documents.indices {
            if let index = documents[i].tags.firstIndex(where: { $0.lowercased() == oldTag.lowercased() }) {
                documents[i].tags[index] = newTag
                documents[i].updatedAt = Date()
            }
        }
        saveDocuments()
    }
    
    private func removeTagFromAllDocuments(tag: String) {
        for i in documents.indices {
            documents[i].tags.removeAll { $0.lowercased() == tag.lowercased() }
            documents[i].updatedAt = Date()
        }
        saveDocuments()
    }
    
    private func mergeTagInAllDocuments(from fromTag: String, into intoTag: String) {
        for i in documents.indices {
            var tags = documents[i].tags
            
            // Remove the old tag and add the new one if not already present
            tags.removeAll { $0.lowercased() == fromTag.lowercased() }
            if !tags.contains(where: { $0.lowercased() == intoTag.lowercased() }) {
                tags.append(intoTag)
            }
            
            documents[i].tags = tags.normalized()
            documents[i].updatedAt = Date()
        }
        saveDocuments()
    }
    
    // MARK: - CRUD Operations
    func createDocument(title: String, type: DocumentType) -> UUID {
        let document = Document(title: title, type: type)
        documents.append(document)
        saveDocuments()
        
        // Track list creation
        Task { @MainActor in
            telemetryService.logListCreated(type: type.rawValue)
        }
        Analytics.track("list_created", props: ["type": type.rawValue])
        
        return document.id
    }
    
    func addItems(to documentId: UUID, items: [String], sourceRecordingId: UUID? = nil) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        
        let newItems = items.map { text in
            DocItem(text: text, sourceRecordingId: sourceRecordingId)
        }
        
        documents[index].items.append(contentsOf: newItems)
        documents[index].updatedAt = Date()
        saveDocuments()
        
        // Track list item creation
        let documentType = documents[index].type.rawValue
        Task { @MainActor in
            for _ in newItems {
                telemetryService.logListItemCreated(listType: documentType)
            }
        }
    }
    
    func addItems(to documentId: UUID, items: [DocItem]) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        
        documents[index].items.append(contentsOf: items)
        documents[index].updatedAt = Date()
        saveDocuments()
        
        // Track list item creation
        let documentType = documents[index].type.rawValue
        Task { @MainActor in
            for _ in items {
                telemetryService.logListItemCreated(listType: documentType)
            }
        }
    }
    
    func toggleItem(documentId: UUID, itemId: UUID) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentId }),
              let itemIndex = documents[docIndex].items.firstIndex(where: { $0.id == itemId }) else { return }
        
        let wasNotDone = !documents[docIndex].items[itemIndex].isDone
        documents[docIndex].items[itemIndex].isDone.toggle()
        documents[docIndex].updatedAt = Date()
        saveDocuments()
        
        // Track item checking (only when checking, not unchecking)
        if wasNotDone {
            let documentType = documents[docIndex].type.rawValue
            Task { @MainActor in
                telemetryService.logListItemChecked(listType: documentType)
            }
        }
    }
    
    func deleteItem(documentId: UUID, itemId: UUID) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentId }) else { return }
        
        documents[docIndex].items.removeAll { $0.id == itemId }
        documents[docIndex].updatedAt = Date()
        saveDocuments()
    }
    
    func deleteDocument(_ document: Document) {
        recentlyDeletedDocument = document
        documents.removeAll { $0.id == document.id }
        saveDocuments()
        
        // Clear undo after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.recentlyDeletedDocument = nil
        }
    }
    
    func undoDeleteDocument() {
        guard let deletedDoc = recentlyDeletedDocument else { return }
        documents.append(deletedDoc)
        recentlyDeletedDocument = nil
        saveDocuments()
    }
    
    func updateDocumentTitle(documentId: UUID, title: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        documents[index].title = title
        documents[index].updatedAt = Date()
        saveDocuments()
    }
    
    func updateItemDueDate(documentId: UUID, itemId: UUID, dueDate: Date?) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentId }),
              let itemIndex = documents[docIndex].items.firstIndex(where: { $0.id == itemId }) else { return }
        
        documents[docIndex].items[itemIndex].dueDate = dueDate
        documents[docIndex].updatedAt = Date()
        saveDocuments()
    }
    
    func updateDocumentNotes(documentId: UUID, notes: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        documents[index].notes = notes
        documents[index].updatedAt = Date()
        saveDocuments()
    }
    
    @MainActor func updateDocumentTags(documentId: UUID, tags: [String]) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        let normalizedTags = tags.normalized()
        
        // Add new tags to global store
        for tag in normalizedTags {
            TagStore.shared.add(tag)
        }
        
        documents[index].tags = normalizedTags
        documents[index].updatedAt = Date()
        saveDocuments()
    }
    
    @MainActor func addTagToDocument(documentId: UUID, tag: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        var currentTags = documents[index].tags
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanTag.isEmpty && currentTags.count < 50 else { return }
        
        // Check if tag already exists (case insensitive)
        if !currentTags.contains(where: { $0.lowercased() == cleanTag.lowercased() }) {
            currentTags.append(cleanTag)
            TagStore.shared.add(cleanTag)
            
            documents[index].tags = currentTags.normalized()
            documents[index].updatedAt = Date()
            saveDocuments()
        }
    }
    
    func removeTagFromDocument(documentId: UUID, tag: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        documents[index].tags.removeAll { $0.lowercased() == tag.lowercased() }
        documents[index].updatedAt = Date()
        saveDocuments()
    }
    
    func renameDocument(id: UUID, newTitle: String) {
        guard let i = documents.firstIndex(where: { $0.id == id }) else { return }
        let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        documents[i].title = t
        documents[i].updatedAt = Date()
        saveDocuments()
    }
    
    func updateItemText(documentId: UUID, itemId: UUID, newText: String) {
        guard let d = documents.firstIndex(where: { $0.id == documentId }) else { return }
        guard let i = documents[d].items.firstIndex(where: { $0.id == itemId }) else { return }
        let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        documents[d].items[i].text = t
        documents[d].updatedAt = Date()
        saveDocuments()
    }
    
    func reorderItems(documentId: UUID, from source: IndexSet, to destination: Int) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentId }) else { return }
        
        documents[docIndex].items.move(fromOffsets: source, toOffset: destination)
        documents[docIndex].updatedAt = Date()
        saveDocuments()
    }
    
    // MARK: - Recency Tracking
    func markOpened(_ documentId: UUID) {
        // Remove if already exists and add to front
        recentDocumentIds.removeAll { $0 == documentId }
        recentDocumentIds.insert(documentId, at: 0)
        
        // Keep only last 10 for performance
        if recentDocumentIds.count > 10 {
            recentDocumentIds = Array(recentDocumentIds.prefix(10))
        }
    }
    
    var recentDocuments: [Document] {
        let validIds = recentDocumentIds.compactMap { id in
            documents.first { $0.id == id }
        }
        
        // Ensure we have at least 3, fill with most recently updated if needed
        var result = validIds
        if result.count < 3 {
            let additional = documents
                .filter { doc in !recentDocumentIds.contains(doc.id) }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(3 - result.count)
            result.append(contentsOf: additional)
        }
        
        return Array(result.prefix(3))
    }
    
    // MARK: - Undo Functionality
    func undoLastAdd() {
        guard let lastAdd = lastAdd else { return }
        guard let docIndex = documents.firstIndex(where: { $0.id == lastAdd.documentId }) else { return }
        
        // Remove the items that were added
        documents[docIndex].items.removeAll { item in
            lastAdd.itemIds.contains(item.id)
        }
        documents[docIndex].updatedAt = Date()
        
        // Clear last add and save
        self.lastAdd = nil
        saveDocuments()
    }
    
    // MARK: - List Management Helpers
    func listId(named name: String, preferredType: DocumentType? = nil) -> UUID? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedName.isEmpty else { return nil }
        
        var candidates = documents.filter { document in
            document.title.lowercased().contains(normalizedName)
        }
        
        // If preferred type is specified, prioritize it
        if let preferredType = preferredType {
            let typeMatches = candidates.filter { $0.type == preferredType }
            if !typeMatches.isEmpty {
                candidates = typeMatches
            }
        }
        
        // Return the most recently updated match
        return candidates.sorted { $0.updatedAt > $1.updatedAt }.first?.id
    }
    
    func ensureList(named name: String, type: DocumentType = .todo) -> UUID {
        // Check if list already exists
        if let existingId = listId(named: name, preferredType: type) {
            return existingId
        }
        
        // Create new list
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleanName.isEmpty ? "New List" : cleanName
        return createDocument(title: title, type: type)
    }
    
    // MARK: - Helper Methods
    func suggestedType(for texts: [String]) -> DocumentType {
        let combinedText = texts.joined(separator: " ").lowercased()
        
        // Check for shopping keywords
        let shoppingKeywords = ["buy", "purchase", "grocery", "store", "shop", "milk", "bread", "eggs"]
        if shoppingKeywords.contains(where: { combinedText.contains($0) }) {
            return .shopping
        }
        
        // Check for meeting keywords
        let meetingKeywords = ["meeting", "discuss", "agenda", "call", "schedule", "follow up", "action items"]
        if meetingKeywords.contains(where: { combinedText.contains($0) }) {
            return .meeting
        }
        
        // Check for ideas keywords
        let ideasKeywords = ["idea", "brainstorm", "concept", "think about", "consider", "maybe"]
        if ideasKeywords.contains(where: { combinedText.contains($0) }) {
            return .ideas
        }
        
        // Use user's default document type from settings
        let defaultTypeString = UserDefaults.standard.string(forKey: "defaultDocumentType") ?? DocumentType.todo.rawValue
        return DocumentType(rawValue: defaultTypeString) ?? .todo
    }
    
    @discardableResult
    func saveActionItems(_ texts: [String], sourceRecordingId: UUID? = nil, preferredType: DocumentType? = nil) -> UUID {
        let documentType = preferredType ?? suggestedType(for: texts)
        
        // Try to find recent document of same type
        let recentDocument = documents
            .filter { $0.type == documentType }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        
        let documentId: UUID
        if let existingDoc = recentDocument, Calendar.current.isDate(existingDoc.updatedAt, inSameDayAs: Date()) {
            // Add to existing recent document from today
            documentId = existingDoc.id
        } else {
            // Create new document
            let title = generateDocumentTitle(type: documentType)
            documentId = createDocument(title: title, type: documentType)
        }
        
        // Create DocItem objects to track their IDs
        let newItems = texts.map { text in
            DocItem(text: text, sourceRecordingId: sourceRecordingId)
        }
        
        // Track for undo
        lastAdd = LastAdd(
            documentId: documentId,
            itemIds: newItems.map { $0.id },
            timestamp: Date()
        )
        
        // Clear undo after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            if let currentLastAdd = self.lastAdd,
               currentLastAdd.timestamp == self.lastAdd?.timestamp {
                self.lastAdd = nil
            }
        }
        
        addItems(to: documentId, items: newItems)
        return documentId
    }
    
    private func generateDocumentTitle(type: DocumentType) -> String {
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
            return "Meeting Notes — \(dateString)"
        }
    }
}
