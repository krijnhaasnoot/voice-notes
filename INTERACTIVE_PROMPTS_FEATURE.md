# Interactive AI Prompts Feature

## Overview

This feature adds a **Copilot-like interactive experience** to recording details, allowing users to have a conversation with AI about their recordings. Users can choose from preset prompts or create custom ones, and refine responses iteratively.

## User Experience

### Initial Prompts
When viewing a recording with a transcript, users see:

**"What would you like me to do?"**

🗒️ **Make Notes** - Create comprehensive notes  
📄 **Make Minutes** - Generate meeting minutes  
📋 **Summarize Key Points** - Extract key takeaways  
✅ **Extract Action Items** - Create task checklist  
📊 **Create Outline** - Structured hierarchical outline  
✏️ **Custom Prompt** - Write your own instruction

### Follow-up Prompts
After receiving a response, users get follow-up options:

**"What's next?"**

🔍 **More Details** - Expand on the response  
⬇️ **Simplify** - Make it easier to understand  
⬆️ **Elaborate** - Provide deeper analysis  
🎯 **Focus On...** - Dive into specific aspect  
✏️ **Custom Prompt** - Ask anything

### Conversation View
Responses appear in a chat-like interface:
- User prompts (blue bubbles on right)
- AI responses (gray bubbles on left)
- Timestamps for each message
- Scrollable conversation history
- "Clear" button to start fresh

## Technical Architecture

### Files Created

#### 1. `Models/ConversationModels.swift`
**Data models for the conversation system**

```swift
struct ConversationMessage
- id: UUID
- role: MessageRole (user/assistant/system)
- content: String
- prompt: PromptTemplate?
- timestamp: Date

enum PromptTemplate
- 10 predefined prompts
- Display names and icons
- System prompt templates
- Initial vs. follow-up categorization

struct RecordingConversation
- recordingId: UUID
- messages: [ConversationMessage]
- Persistence timestamps
```

**Key Features:**
- Codable for UserDefaults persistence
- Conversation history per recording
- Template-based prompt system

#### 2. `Services/ConversationService.swift`
**Business logic for processing prompts**

```swift
@MainActor class ConversationService
- Singleton pattern
- Manages all conversations
- Processes prompts through EnhancedSummaryService
- Handles persistence
```

**Key Methods:**
- `getConversation(for:)` - Retrieve/create conversation
- `processPrompt(...)` - Execute AI processing
- `clearConversation(for:)` - Reset conversation
- `buildPrompt(...)` - Construct prompts with context

**Features:**
- Uses existing `EnhancedSummaryService` infrastructure
- Includes conversation context for follow-ups
- Progress tracking
- Cancellation support
- Auto-saves to UserDefaults

#### 3. `Views/InteractivePromptsView.swift`
**UI component for the interactive interface**

**Main Components:**
- `InteractivePromptsView` - Main container
- `MessageBubble` - Chat bubble for messages
- `PromptChip` - Clickable prompt buttons
- `FlowLayout` - Responsive chip layout

**State Management:**
- Observes `ConversationService`
- Tracks processing state
- Manages custom prompt input
- Handles errors and cancellation

**UI Features:**
- Empty state with icon
- Scrollable message history
- Processing indicator with progress
- Error display
- Responsive prompt chips
- Custom prompt text field

#### 4. `RecordingDetailView.swift` (Modified)
**Integration point**

**Changes:**
- Added `@State var showingInteractivePrompts`
- Added `interactivePromptsSection()` function
- Integrated view after recording info section
- Only shows when transcript available

### Data Flow

```
User Clicks Prompt
       ↓
InteractivePromptsView
       ↓
ConversationService.processPrompt()
       ↓
Build prompt with context + history
       ↓
EnhancedSummaryService.summarize()
       ↓
AI Provider (Anthropic/OpenAI/etc)
       ↓
Response returned
       ↓
Save to conversation history
       ↓
UI updates automatically
```

### Persistence

**Storage Location:** UserDefaults  
**Key:** `"RecordingConversations"`  
**Format:** JSON-encoded array of `RecordingConversation`

**Lifecycle:**
- Conversations persist across app restarts
- Tied to recording ID
- Can be cleared individually
- Auto-saves after each message

## Prompt Templates

### Initial Prompts

| Template | Purpose | Output Format |
|----------|---------|---------------|
| Make Notes | Comprehensive note-taking | Organized sections with bullets |
| Make Minutes | Meeting documentation | Formal minutes structure |
| Summarize Key Points | Essential takeaways | Bulleted key points |
| Extract Action Items | Task extraction | Checklist with details |
| Create Outline | Hierarchical structure | Multi-level outline |

### Follow-up Prompts

| Template | Purpose | Context Used |
|----------|---------|--------------|
| More Details | Expand response | Previous conversation |
| Simplify | Reduce complexity | Last AI response |
| Elaborate | Add depth | Last AI response |
| Focus On... | Specific deep-dive | User specifies topic |

### Custom Prompts

Users can type any question or instruction:
- "What are the main risks mentioned?"
- "Create a bullet list of attendees"
- "Translate the summary to Dutch"
- "Extract all dates and deadlines"

## Integration with Existing Features

### Works With:
✅ All AI providers (Anthropic, OpenAI, Gemini, Mistral)  
✅ Own Key subscriptions  
✅ Usage tracking and quotas  
✅ Existing summarization infrastructure  
✅ Cancellation tokens  
✅ Progress callbacks  

### Doesn't Interfere With:
✅ Original summary section (still available)  
✅ Transcript editing  
✅ Action items extraction  
✅ Document creation  
✅ Sharing/exporting  

## User Benefits

### 1. **Flexibility**
- Multiple ways to analyze same recording
- Iterative refinement of insights
- Custom questions for specific needs

### 2. **Efficiency**
- No need to re-read transcript
- Quick access to different formats
- Build on previous responses

### 3. **Discovery**
- Explore different angles
- Uncover hidden insights
- Learn from AI suggestions

### 4. **Control**
- User chooses what to generate
- Clear conversation history
- Cancel anytime
- Keep or discard results

## Usage Examples

### Example 1: Meeting Notes → Action Items → Details

```
1. User clicks "Make Minutes"
   → AI generates meeting minutes

2. User clicks "Extract Action Items"
   → AI creates task checklist from minutes

3. User clicks "More Details"
   → AI expands each action item with context
```

### Example 2: Complex Topic → Simplify → Focus

```
1. User clicks "Summarize Key Points"
   → AI provides technical summary

2. User clicks "Simplify"
   → AI rewrites in plain language

3. User types "Focus on the financial implications"
   → AI provides detailed financial analysis
```

### Example 3: Custom Research Flow

```
1. User types "What decisions were made?"
   → AI lists all decisions

2. User types "Who disagreed and why?"
   → AI analyzes disagreements

3. User clicks "Create Outline"
   → AI structures all information hierarchically
```

## Technical Considerations

### Performance
- Uses existing optimized services
- Minimal new API calls
- Efficient conversation storage
- Lazy loading of UI components

### Memory
- Conversations stored efficiently in JSON
- Old conversations can be cleared
- No large data in memory
- Proper cleanup on deletion

### Error Handling
- API failures shown as errors
- Retry available for all prompts
- Cancellation works correctly
- Doesn't break other features

### Testing
Recommended test scenarios:
1. Create conversation with multiple prompts
2. Clear conversation mid-way
3. Delete recording with conversation
4. Test all prompt templates
5. Test custom prompts
6. Test with long transcripts
7. Test follow-up context
8. Test cancellation
9. Test with no API key (Own Key users)
10. Test persistence across app restarts

## Future Enhancements

Potential improvements:
- [ ] Export conversation as document
- [ ] Share individual responses
- [ ] Suggested follow-up prompts based on context
- [ ] Voice input for custom prompts
- [ ] Multi-recording analysis
- [ ] Template customization
- [ ] Conversation search
- [ ] Response bookmarking
- [ ] Conversation analytics

## Comparison to Teams Copilot

### Similar Features
✅ Prompt suggestions  
✅ Follow-up capabilities  
✅ Custom prompts  
✅ Conversation history  
✅ Iterative refinement  

### Unique to Voice Notes
🎯 Recording-specific context  
🎯 Integration with transcripts  
🎯 Multiple AI providers  
🎯 Local conversation storage  
🎯 Template system  

## User Education

### In-App Hints
Consider adding:
- Tooltip on first view: "Try different prompts to analyze your recording"
- Prompt chip hover hints
- Example prompts in empty state
- Tips for custom prompts

### Documentation
User-facing docs should explain:
- What each template does
- How to write good custom prompts
- How to use follow-up prompts effectively
- How conversation context works

---

**Status:** ✅ Ready for testing  
**Created:** January 12, 2026  
**Dependencies:** Existing summarization services  
**Breaking Changes:** None



