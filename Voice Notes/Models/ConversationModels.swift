import Foundation

// MARK: - Conversation Models for Interactive Prompts

struct ConversationMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let prompt: PromptTemplate?
    let timestamp: Date
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    init(id: UUID = UUID(), role: MessageRole, content: String, prompt: PromptTemplate? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.prompt = prompt
        self.timestamp = timestamp
    }
}

// MARK: - Prompt Templates

enum PromptTemplate: String, CaseIterable, Codable {
    case makeNotes = "make_notes"
    case makeMinutes = "make_minutes"
    case summarizeKeyPoints = "summarize_key_points"
    case extractActionItems = "extract_action_items"
    case createOutline = "create_outline"
    case moreDetails = "more_details"
    case simplify = "simplify"
    case elaborate = "elaborate"
    case focusOn = "focus_on"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .makeNotes:
            return "Turn this into notes"
        case .makeMinutes:
            return "Create meeting minutes"
        case .summarizeKeyPoints:
            return "Give me a short summary"
        case .extractActionItems:
            return "What are the action items?"
        case .createOutline:
            return "Create Outline"
        case .moreDetails:
            return "Give me more details"
        case .simplify:
            return "Make this simpler"
        case .elaborate:
            return "Expand on this"
        case .focusOn:
            return "Focus On..."
        case .custom:
            return "Custom Prompt"
        }
    }
    
    var icon: String {
        switch self {
        case .makeNotes:
            return "note.text"
        case .makeMinutes:
            return "doc.text"
        case .summarizeKeyPoints:
            return "list.bullet.clipboard"
        case .extractActionItems:
            return "checkmark.circle"
        case .createOutline:
            return "list.number"
        case .moreDetails:
            return "plus.magnifyingglass"
        case .simplify:
            return "arrow.down.circle"
        case .elaborate:
            return "arrow.up.circle"
        case .focusOn:
            return "scope"
        case .custom:
            return "text.cursor"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .makeNotes:
            return "Organized and clear"
        case .makeMinutes:
            return "Meeting format"
        case .summarizeKeyPoints:
            return "Quick overview"
        case .extractActionItems:
            return "To-do list"
        case .createOutline:
            return "Structured"
        case .moreDetails:
            return "Expand this"
        case .simplify:
            return "Make it shorter"
        case .elaborate:
            return "Add more depth"
        case .focusOn:
            return "Specific topic"
        case .custom:
            return "Your question"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .makeNotes:
            return """
            Create comprehensive notes from this transcript. Include:
            - Main topics and themes
            - Important details and facts
            - Key insights
            - Notable quotes or statements
            Format as clear, organized notes with sections and bullet points.
            """
            
        case .makeMinutes:
            return """
            Create professional meeting minutes from this transcript. Include:
            - Meeting overview
            - Attendees (if mentioned)
            - Key discussion points
            - Decisions made
            - Action items with owners (if mentioned)
            - Next steps
            Format as formal meeting minutes with clear sections.
            """
            
        case .summarizeKeyPoints:
            return """
            Extract and summarize the key points from this transcript. Focus on:
            - Main ideas and conclusions
            - Critical information
            - Essential takeaways
            Present as a concise bulleted list of key points.
            """
            
        case .extractActionItems:
            return """
            Extract all action items and tasks mentioned in this transcript.
            For each action item, include:
            - The task description
            - Assigned person (if mentioned)
            - Deadline (if mentioned)
            - Priority or importance (if indicated)
            Format as a clear checklist.
            """
            
        case .createOutline:
            return """
            Create a structured outline from this transcript.
            Use hierarchical format (I, A, 1, a) to organize:
            - Main topics
            - Subtopics
            - Key details
            - Supporting information
            Make it easy to scan and understand the structure.
            """
            
        case .moreDetails:
            return """
            Provide more details and elaboration on the previous response.
            Expand on important points, add context, examples, and nuances.
            Include information that was omitted before.
            """
            
        case .simplify:
            return """
            Simplify the previous response. Make it:
            - Easier to understand
            - More concise
            - Less technical
            - Suitable for a general audience
            Remove jargon and complex language.
            """
            
        case .elaborate:
            return """
            Provide a more detailed and comprehensive version of the previous response.
            Add depth, context, explanations, and examples.
            Include relevant background information and implications.
            """
            
        case .focusOn:
            return """
            Focus specifically on the topic or aspect the user requests.
            Provide detailed information about that particular element.
            """
            
        case .custom:
            return ""
        }
    }
    
    // Initial prompts that appear first
    static var initialPrompts: [PromptTemplate] {
        [.makeNotes, .makeMinutes, .summarizeKeyPoints, .extractActionItems, .createOutline]
    }
    
    // Follow-up prompts that appear after initial response
    static var followUpPrompts: [PromptTemplate] {
        [.moreDetails, .simplify, .elaborate, .focusOn]
    }
}

// MARK: - Recording Conversation

struct RecordingConversation: Codable {
    let recordingId: UUID
    var messages: [ConversationMessage]
    let createdAt: Date
    var updatedAt: Date
    
    init(recordingId: UUID, messages: [ConversationMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.recordingId = recordingId
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    mutating func addMessage(_ message: ConversationMessage) {
        messages.append(message)
        updatedAt = Date()
    }
    
    var lastAssistantMessage: ConversationMessage? {
        messages.last { $0.role == .assistant }
    }
    
    var hasMessages: Bool {
        !messages.isEmpty
    }
}



