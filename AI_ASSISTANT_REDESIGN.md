# ✨ AI Assistant Screen Redesign

## 🎯 Design Concept

Een volledig nieuwe, **full-screen, calm en premium** AI Assistant ervaring die aanvoelt als **een chat met een AI**, niet als een tool met knoppen.

---

## 🎨 Implementatie

### ✅ Nieuwe Files:
- `/Views/AIAssistantScreen.swift` - Volledig nieuwe view

### 📐 Structuur:

```
AIAssistantScreen
├─ Top Bar (minimal)
│   ├─ Close button (X)
│   └─ "New" button (als conversatie bestaat)
├─ Main Content (ScrollView)
│   ├─ Idle State
│   │   ├─ AI Visual (gradient circle + sparkles)
│   │   ├─ Central question
│   │   └─ 4 Prompt pills
│   ├─ Thinking State
│   │   ├─ Conversation history
│   │   └─ Thinking animation
│   └─ Conversation State
│       ├─ Messages (user + AI)
│       └─ Follow-up section
│           ├─ 3 Context prompts
│           └─ Text input field
└─ Bottom Bar
    └─ "View transcript" link
```

---

## 🎭 States

### 1. **Idle State** (Geen conversatie)
```
        ●                    ← AI visual (gradient circle)
      ✨                     ← Sparkles icon
      
What would you like me to do
    with this recording?      ← Central question
    
┌─────────────────────┐
│  📝 Make notes      │      ← 4 Prompt pills
└─────────────────────┘
┌─────────────────────┐
│  • Summarize key    │
│    points           │
└─────────────────────┘
┌─────────────────────┐
│  ✓ Extract action   │
│    items            │
└─────────────────────┘
┌─────────────────────┐
│  📄 Create minutes  │
└─────────────────────┘

        ─────
    View transcript         ← Bottom link
```

### 2. **Thinking State** (Processing)
```
📝 Make notes               ← User message (compact)

● ● ●  Thinking...         ← Subtle animation

        ─────
    View transcript
```

### 3. **Conversation State** (Result + Follow-up)
```
📝 Make notes               ← User message

Key Points                  ← AI response (document-like)
• Point 1 with detail
• Point 2 with context
• Point 3 with nuance

Action Items
1. Task one with owner
2. Task two with deadline

Next Steps
- Follow up next week
- Review the proposal

┌─────────────────────┐    ← Follow-up prompts
│  ⬇ Shorter version │
└─────────────────────┘
┌─────────────────────┐
│  🔍 More details    │
└─────────────────────┘

┌──────────────────────┐   ← Custom input
│ Ask a follow-up…    ↑│
└──────────────────────┘

        ─────
    View transcript
```

---

## 🎨 Visual Design

### Colors & Style:
- ✅ iOS native appearance
- ✅ Veel witruimte (padding: 24pt)
- ✅ Zachte contrasten (secondary opacity 0.08)
- ✅ Gradient accent (blue → purple)
- ✅ Rounded corners (16-20pt)
- ✅ Geen zware borders

### Typography:
- **Title**: SF Pro 24pt Regular
- **Body**: SF Pro 17pt Regular
- **Secondary**: SF Pro 15pt Regular
- **Caption**: SF Pro 14pt Regular
- **Line spacing**: 6pt

### Animaties:
- ✅ Spring animation (response: 0.4, damping: 0.8)
- ✅ Opacity + Scale transitions
- ✅ Asymmetric transitions (insert/remove)
- ✅ Thinking dots animation

---

## 💬 User Flow

### Flow 1: First Use
```
1. Open recording →
2. Tap "AI Assistant" →
3. See idle state →
4. Choose prompt →
5. Thinking animation →
6. See AI response →
7. Choose follow-up or custom prompt →
8. Continue conversation
```

### Flow 2: Return Visit
```
1. Open recording →
2. Tap "AI Assistant" →
3. See previous conversation →
4. Scroll through history →
5. Add follow-up question →
6. Get new response
```

### Flow 3: Start Fresh
```
1. Open recording (with existing conversation) →
2. Tap "New" button →
3. Confirmation (implicit) →
4. Return to idle state →
5. Start new conversation
```

---

## 🔧 Integration

### Huidige Integratie Opties:

#### Optie A: Vervang RecordingDetailView
```swift
// In RecordingsView.swift
.sheet(item: $selectedRecording) { recording in
    if let transcript = recording.transcript {
        AIAssistantScreen(
            recordingId: recording.id,
            transcript: transcript
        )
    } else {
        RecordingDetailView(...) // Fallback
    }
}
```

#### Optie B: AI button in RecordingRow
```swift
HStack {
    // Existing content
    Button {
        showAIAssistant = true
    } label: {
        Image(systemName: "sparkles")
    }
}
.sheet(isPresented: $showAIAssistant) {
    AIAssistantScreen(...)
}
```

#### Optie C: Swipe action (meest elegant)
```swift
.swipeActions(edge: .leading) {
    Button {
        showAIAssistant = true
    } label: {
        Label("AI Assistant", systemImage: "sparkles")
    }
    .tint(.blue)
}
```

---

## 📝 Prompts

### Initial Prompts (4):
1. **Make notes** - Comprehensive notes
2. **Summarize key points** - Bullet list
3. **Extract action items** - Checklist
4. **Create minutes** - Formal meeting minutes

### Follow-up Prompts (3):
1. **Simplify** - Shorter, easier
2. **More details** - Elaborate
3. **Elaborate** - Add depth

### Custom Prompt:
- Open text field
- Placeholder: "Ask a follow-up…"
- Submit with arrow button

---

## 🎯 Key Principles

### 1. **Single Purpose**
Elke state heeft 1 duidelijk doel:
- Idle: Kies wat je wil
- Thinking: Wacht even
- Conversation: Lees & reageer

### 2. **Calm UX**
- Geen drukke UI elementen
- Veel witruimte
- Subtiele animaties
- Rustige kleuren

### 3. **Chat Metaphor**
- Messages (user + AI)
- Conversation history
- Follow-up suggesties
- Text input voor eigen vragen

### 4. **Premium Feel**
- Gradient accents
- Smooth animaties
- Perfect spacing
- Quality typography

---

## ✅ Features

### Implemented:
- ✅ Full-screen layout
- ✅ Idle state met centrale vraag
- ✅ 4 Initial prompt pills
- ✅ Thinking state met animatie
- ✅ Conversation view (chat-like)
- ✅ Message bubbles (user + AI)
- ✅ Follow-up prompts (3)
- ✅ Custom text input
- ✅ Transcript sheet (bottom link)
- ✅ Clear conversation ("New")
- ✅ Spring animations
- ✅ State management via ConversationService

### To Add:
- ⏳ Better markdown parsing in AI responses
- ⏳ Syntax highlighting voor code blocks
- ⏳ Copy button voor messages
- ⏳ Share conversation
- ⏳ Scroll to bottom on new message
- ⏳ Error handling UI
- ⏳ Cancellation support

---

## 🚀 Next Steps

1. **Test de nieuwe view:**
   ```swift
   AIAssistantScreen(
       recordingId: recording.id,
       transcript: recording.transcript
   )
   ```

2. **Integreer in app:**
   - Kies integratie methode (A/B/C)
   - Update navigation
   - Test user flow

3. **Polish:**
   - Fine-tune animaties
   - Test met echte content
   - Optimize performance

---

**Status:** ✅ Core implementation done (Jan 2026)
**File:** `/Views/AIAssistantScreen.swift`
**Dependencies:** `ConversationService`, `PromptTemplate`

