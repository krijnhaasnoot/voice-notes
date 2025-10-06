# Intelligent List Item Detection Feature

## Overview
Echo now intelligently detects when users mention adding items to lists (todo, shopping, ideas, action items, etc.) in their voice notes and automatically offers to save them.

## How It Works

### 1. Detection Triggers
The system detects list items when users say phrases like:
- **English**: "put this on my todo list", "add to shopping list", "I need to buy...", "I have to...", "don't forget to..."
- **Dutch**: "zet dit op mijn lijst", "ik moet...", "vergeet niet om...", "dingen om te kopen"

### 2. Supported List Types
- **To-Do** - General tasks and reminders
- **Shopping** - Items to buy
- **Ideas** - Brainstorming and concepts
- **Action Items** - Follow-up tasks
- **General** - Catch-all for other lists

### 3. Detection Methods
The system uses multiple strategies to extract items:

1. **Numbered Lists**: Detects "1. item", "2. item", etc.
2. **Bullet Points**: Detects "- item", "* item", "• item"
3. **Imperative Phrases**: Detects "I need to...", "I have to...", "ik moet..."
4. **Trigger Phrases**: Detects text after phrases like "add to my todo"

### 4. User Experience

#### After Summary Completion
1. Summary is generated for a voice note
2. System analyzes summary + transcript for list items
3. If detected, a popup appears showing the items
4. User can:
   - ✅ Confirm and save all items
   - ✏️ Edit individual items
   - ➕ Add more items manually
   - 🗑️ Remove unwanted items
   - ❌ Dismiss entirely

#### What Happens on Confirmation
- Items are saved to the appropriate document (To-Do, Shopping, etc.)
- If the document exists, items are added to it
- If not, a new document is created
- A toast notification confirms the action
- The recording is auto-tagged with the list type

## Technical Implementation

### Core Components

#### `ListItemDetector.swift`
- Main detection engine
- Pattern matching for multilingual support
- Multiple extraction strategies
- Deduplication and cleaning

#### `ListItemConfirmationSheet.swift`
- SwiftUI sheet for user confirmation
- Inline editing capabilities
- Add/remove functionality
- Beautiful, user-friendly UI

#### Integration in `RecordingDetailView.swift`
- Monitors summary completion via `onChange`
- Triggers detection automatically
- Handles confirmed items
- Creates/updates documents

### Example Usage

**User says:**
> "Hey, I need to add a few things to my shopping list. Number one: milk. Number two: eggs. Number three: bread. Oh, and don't forget butter."

**System detects:**
- List Type: Shopping
- Items: ["milk", "eggs", "bread", "butter"]

**Confirmation popup appears with:**
```
🛒 List Items Detected!
I noticed you mentioned a shopping list. Would you like to save these items?

✓ milk
✓ eggs
✓ bread
✓ butter

[Save 4 Items]  [Dismiss]
```

## Pattern Examples

### English Patterns
- "Put this on my todo list"
- "Add to my shopping list"
- "I need to buy milk and eggs"
- "Don't forget to call the dentist"
- "Remember to send that email"

### Dutch Patterns
- "Zet dit op mijn todolijst"
- "Ik moet boodschappen doen"
- "Vergeet niet om te bellen"
- "Dingen die ik moet kopen"

## Configuration

### Adding New Patterns
Edit `ListItemDetector.swift` and add patterns to:
- `todoPatterns`
- `shoppingPatterns`
- `ideasPatterns`
- `actionPatterns`
- `generalListPatterns`

### Adding New List Types
1. Add case to `DetectedListItem.ListType` enum
2. Add detection patterns
3. Update icon mapping
4. Update document type mapping in `RecordingDetailView`

## Benefits

1. **Time Saver**: No need to manually create lists after recording
2. **Smart**: Understands natural language and context
3. **Multilingual**: Works in English and Dutch
4. **Flexible**: User can edit/add/remove before saving
5. **Integrated**: Seamlessly works with existing document system

## Future Enhancements

- [ ] Add more languages (French, German, Spanish)
- [ ] Support for date/time extraction (e.g., "call dentist tomorrow")
- [ ] Priority detection (urgent, important)
- [ ] Smart categorization (work vs. personal)
- [ ] Integration with calendar for time-based items
