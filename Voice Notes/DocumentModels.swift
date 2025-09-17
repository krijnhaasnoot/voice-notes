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
        case .todo: return "To-Do"
        case .shopping: return "Shopping"
        case .ideas: return "Ideas"
        case .meeting: return "Meeting"
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
        case .todo, .shopping: return true
        case .ideas, .meeting: return false
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
    
    init(id: UUID = UUID(), title: String, type: DocumentType, createdAt: Date = Date(), updatedAt: Date = Date(), items: [DocItem] = [], notes: String = "") {
        self.id = id
        self.title = title
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
        self.notes = notes
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
    
    init() {
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.documentsURL = documentsPath.appendingPathComponent("voice_notes_documents.json")
        
        loadDocuments()
        
        #if DEBUG
        seedSampleDataIfNeeded()
        #endif
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
            documents = try JSONDecoder().decode([Document].self, from: data)
        } catch {
            print("Failed to load documents (this is normal on first launch): \(error)")
            documents = []
        }
    }
    
    // MARK: - CRUD Operations
    func createDocument(title: String, type: DocumentType) -> UUID {
        let document = Document(title: title, type: type)
        documents.append(document)
        saveDocuments()
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
    }
    
    func addItems(to documentId: UUID, items: [DocItem]) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        
        documents[index].items.append(contentsOf: items)
        documents[index].updatedAt = Date()
        saveDocuments()
    }
    
    func toggleItem(documentId: UUID, itemId: UUID) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentId }),
              let itemIndex = documents[docIndex].items.firstIndex(where: { $0.id == itemId }) else { return }
        
        documents[docIndex].items[itemIndex].isDone.toggle()
        documents[docIndex].updatedAt = Date()
        saveDocuments()
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
    
    // MARK: - Sample Data
    #if DEBUG
    private func seedSampleDataIfNeeded() {
        guard documents.isEmpty else { return }
        
        // Sample To-Do document (Today)
        let todoDoc = Document(
            title: "Personal Tasks — Today",
            type: .todo,
            createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
            updatedAt: Date().addingTimeInterval(-1800), // 30 min ago
            items: [
                DocItem(text: "Review project proposals", isDone: true),
                DocItem(text: "Call dentist for appointment"),
                DocItem(text: "Update resume", isDone: false),
                DocItem(text: "Plan weekend trip"),
                DocItem(text: "Respond to client emails", isDone: true),
                DocItem(text: "Book flight tickets for conference")
            ]
        )
        
        // Sample Shopping document (Today)
        let shoppingDoc = Document(
            title: "Weekly Groceries",
            type: .shopping,
            createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
            updatedAt: Date().addingTimeInterval(-900), // 15 min ago
            items: [
                DocItem(text: "Organic milk", isDone: true),
                DocItem(text: "Whole grain bread"),
                DocItem(text: "Fresh apples"),
                DocItem(text: "Chicken breast"),
                DocItem(text: "Pasta sauce"),
                DocItem(text: "Greek yogurt", isDone: true),
                DocItem(text: "Spinach leaves"),
                DocItem(text: "Olive oil", isDone: true)
            ]
        )
        
        // Sample Ideas document
        let ideasDoc = Document(
            title: "App Feature Ideas",
            type: .ideas,
            createdAt: Date().addingTimeInterval(-86400), // Yesterday
            updatedAt: Date().addingTimeInterval(-82800), // Yesterday evening
            notes: "Ideas for improving the voice notes app:\n\n• Voice-to-text accuracy improvements\n• Better organization with tags and categories\n• Export options for different formats (PDF, Markdown)\n• Integration with calendar apps for meeting notes\n• Collaboration features for team documents\n• Dark mode optimization\n• Widget for quick note capture\n• Backup to cloud services\n• Custom templates for different document types"
        )
        
        // Sample Meeting document
        let meetingDoc = Document(
            title: "Team Standup — Sep 15",
            type: .meeting,
            createdAt: Date().addingTimeInterval(-90000), // Yesterday morning
            updatedAt: Date().addingTimeInterval(-88000), // Yesterday noon
            items: [
                DocItem(text: "Finalize Q4 roadmap presentation", isDone: true),
                DocItem(text: "Review code coverage metrics"),
                DocItem(text: "Schedule user testing sessions"),
                DocItem(text: "Update project documentation", isDone: false),
                DocItem(text: "Follow up with design team on mockups")
            ],
            notes: "Key Discussion Points:\n\n**Sprint Progress:**\n• All stories completed ahead of schedule\n• Code review process working well\n• Need to address technical debt in auth module\n\n**Blockers:**\n• Waiting for API specification from backend team\n• Design assets delayed by 2 days\n\n**Next Steps:**\n• Begin integration testing tomorrow\n• Prepare demo for stakeholder review"
        )
        
        documents = [todoDoc, shoppingDoc, meetingDoc, ideasDoc]
        saveDocuments()
    }
    #endif
}