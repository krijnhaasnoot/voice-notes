# Interactive AI Prompts - Visual Guide

## 📱 User Interface Walkthrough

### 1. Initial State (Before Any Prompts)

```
╔════════════════════════════════════════════╗
║  ✨ AI Assistant              [Clear]     ║
╟────────────────────────────────────────────╢
║                                            ║
║         🪄                                 ║
║     Wand and Stars                        ║
║                                            ║
║   Choose a prompt to get started          ║
║                                            ║
╟────────────────────────────────────────────╢
║  What would you like me to do?            ║
║                                            ║
║  ┌────────────┐ ┌──────────────┐         ║
║  │ 🗒️ Make    │ │ 📄 Make      │         ║
║  │   Notes    │ │   Minutes    │         ║
║  └────────────┘ └──────────────┘         ║
║                                            ║
║  ┌────────────┐ ┌──────────────┐         ║
║  │ 📋 Summarize│ │ ✅ Extract   │         ║
║  │   Key Points│ │   Actions    │         ║
║  └────────────┘ └──────────────┘         ║
║                                            ║
║  ┌────────────┐ ┌──────────────┐         ║
║  │ 📊 Create  │ │ ✏️ Custom    │         ║
║  │   Outline  │ │   Prompt     │         ║
║  └────────────┘ └──────────────┘         ║
╚════════════════════════════════════════════╝
```

### 2. After User Clicks "Make Minutes"

```
╔════════════════════════════════════════════╗
║  ✨ AI Assistant              [Clear]     ║
╟────────────────────────────────────────────╢
║                                            ║
║  ┌──────────────────────────┐    11:23 AM ║
║  │ 📄 Make Minutes           │            ║
║  └──────────────────────────┘            ║
║                          (Blue bubble →)  ║
║                                            ║
║  11:23 AM                                 ║
║  ┌────────────────────────────────────┐  ║
║  │ Meeting Minutes                     │  ║
║  │                                     │  ║
║  │ Date: January 12, 2026             │  ║
║  │                                     │  ║
║  │ Attendees:                         │  ║
║  │ • John Smith (CEO)                 │  ║
║  │ • Sarah Johnson (CFO)              │  ║
║  │ • Mike Chen (CTO)                  │  ║
║  │                                     │  ║
║  │ Key Discussion Points:             │  ║
║  │ 1. Q1 Revenue Review               │  ║
║  │    - Revenue exceeded targets...   │  ║
║  │                                     │  ║
║  │ 2. New Product Launch              │  ║
║  │    - Launch scheduled for...       │  ║
║  │                                     │  ║
║  │ Decisions Made:                    │  ║
║  │ • Approved budget increase...      │  ║
║  │                                     │  ║
║  │ Action Items:                      │  ║
║  │ • Sarah: Prepare budget report     │  ║
║  │ • Mike: Review technical specs     │  ║
║  └────────────────────────────────────┘  ║
║  (← Gray bubble)                         ║
║                                            ║
╟────────────────────────────────────────────╢
║  What's next?                             ║
║                                            ║
║  ┌────────────┐ ┌──────────────┐         ║
║  │ 🔍 More    │ │ ⬇️ Simplify  │         ║
║  │   Details  │ │              │         ║
║  └────────────┘ └──────────────┘         ║
║                                            ║
║  ┌────────────┐ ┌──────────────┐         ║
║  │ ⬆️ Elaborate│ │ 🎯 Focus On  │         ║
║  │            │ │              │         ║
║  └────────────┘ └──────────────┘         ║
║                                            ║
║  ┌──────────────────────────────┐        ║
║  │ ✏️ Custom Prompt            │        ║
║  └──────────────────────────────┘        ║
╚════════════════════════════════════════════╝
```

### 3. After Clicking "Extract Action Items"

```
╔════════════════════════════════════════════╗
║  ✨ AI Assistant              [Clear]     ║
╟────────────────────────────────────────────╢
║  [Previous conversation scrolled up...]    ║
║                                            ║
║  ┌──────────────────────────┐    11:24 AM ║
║  │ ✅ Extract Action Items  │            ║
║  └──────────────────────────┘            ║
║                                            ║
║  11:24 AM                                 ║
║  ┌────────────────────────────────────┐  ║
║  │ Action Items Checklist              │  ║
║  │                                     │  ║
║  │ High Priority:                     │  ║
║  │ □ Prepare Q1 budget report         │  ║
║  │   • Owner: Sarah Johnson (CFO)     │  ║
║  │   • Due: January 19, 2026          │  ║
║  │   • Details: Comprehensive review  │  ║
║  │                                     │  ║
║  │ □ Review technical specifications  │  ║
║  │   • Owner: Mike Chen (CTO)         │  ║
║  │   • Due: January 15, 2026          │  ║
║  │   • Details: New product specs     │  ║
║  │                                     │  ║
║  │ Medium Priority:                   │  ║
║  │ □ Schedule follow-up meeting       │  ║
║  │   • Owner: John Smith (CEO)        │  ║
║  │   • Due: End of month              │  ║
║  │                                     │  ║
║  │ □ Update project timeline          │  ║
║  │   • Owner: Project team            │  ║
║  │   • Due: Next week                 │  ║
║  └────────────────────────────────────┘  ║
║                                            ║
╟────────────────────────────────────────────╢
║  What's next?                             ║
║  [Follow-up prompts...]                   ║
╚════════════════════════════════════════════╝
```

### 4. Custom Prompt Mode

```
╔════════════════════════════════════════════╗
║  ✨ AI Assistant              [Clear]     ║
╟────────────────────────────────────────────╢
║  [Conversation history...]                 ║
║                                            ║
╟────────────────────────────────────────────╢
║  What's next?                             ║
║  [Follow-up chips...]                     ║
║                                            ║
║  ╔════════════════════════════════════╗  ║
║  ║ Enter your custom prompt           ║  ║
║  ╟────────────────────────────────────╢  ║
║  ║ ┌────────────────────────────┐ 🔵 ║  ║
║  ║ │ What financial risks were  │ ↑  ║  ║
║  ║ │ discussed in the meeting?  │    ║  ║
║  ║ └────────────────────────────┘    ║  ║
║  ╚════════════════════════════════════╝  ║
╚════════════════════════════════════════════╝
```

### 5. Processing State

```
╔════════════════════════════════════════════╗
║  ✨ AI Assistant              [Clear]     ║
╟────────────────────────────────────────────╢
║  [Conversation history...]                 ║
║                                            ║
║  ╔════════════════════════════════════╗  ║
║  ║  ⚙️  Processing...                ║  ║
║  ║  ━━━━━━━━━━━━━━━━░░░░  75%       ║  ║
║  ║                          [Cancel]  ║  ║
║  ╚════════════════════════════════════╝  ║
╚════════════════════════════════════════════╝
```

### 6. Error State

```
╔════════════════════════════════════════════╗
║  ✨ AI Assistant              [Clear]     ║
╟────────────────────────────────────────────╢
║  [Conversation history...]                 ║
║                                            ║
║  ╔════════════════════════════════════╗  ║
║  ║  ⚠️  Network error: Unable to     ║  ║
║  ║  reach AI service. Please check   ║  ║
║  ║  your connection.      [Dismiss]  ║  ║
║  ╚════════════════════════════════════╝  ║
║                                            ║
║  What's next?                             ║
║  [Prompts remain available...]            ║
╚════════════════════════════════════════════╝
```

## 🎨 Design Details

### Color Scheme
```
User Messages:
  Background: Blue (#007AFF)
  Text: White
  Position: Right-aligned

AI Messages:
  Background: Light Gray (systemGray5)
  Text: Primary label color
  Position: Left-aligned

Prompt Chips:
  Background: Blue 10% opacity
  Text: Blue
  Border: None
  Hover: Slight scale effect

Processing:
  Background: Blue 10% opacity
  Progress Bar: Blue
  
Error:
  Background: Orange 10% opacity
  Icon: Orange
  Text: Secondary label
```

### Typography
```
Headers:
  "AI Assistant": Poppins Headline (17pt)
  
Prompts:
  Chip text: Poppins Subheadline (15pt)
  Section headers: Poppins Subheadline (15pt)
  
Messages:
  Content: Poppins Body (17pt)
  Timestamps: Poppins Caption2 (11pt)
  
Processing:
  Status: Poppins Subheadline (15pt)
```

### Spacing
```
Section Padding: 16pt
Message Spacing: 12pt between messages
Chip Spacing: 8pt between chips
Internal Padding: 12pt inside message bubbles
Corner Radius: 16pt for sections, 12pt for messages
```

### Animations
```
Message Appear: Slide from bottom + fade (0.3s spring)
Chip Tap: Scale 0.95 (0.1s ease)
Custom Input: Slide from top + fade (0.3s ease)
Processing: Fade in/out (0.2s linear)
Scroll to New: Smooth scroll with animation
```

## 📐 Layout Variations

### iPhone Portrait
```
• Full width chips (2 per row)
• Conversation max height: 400pt
• Messages: 75% width maximum
```

### iPhone Landscape
```
• Smaller chips (3 per row)
• Conversation max height: 300pt
• Messages: 60% width maximum
```

### iPad
```
• Chips in flexible grid
• Conversation max height: 500pt
• Messages: 50% width maximum
• More spacious layout
```

## 🎯 Interaction States

### Chip States
```
Normal: Blue background 10%, blue text
Pressed: Blue background 20%, blue text, scale 0.95
Disabled: Gray background 10%, gray text (during processing)
```

### Message States
```
Sending: Opacity 0.6, right-aligned
Sent: Opacity 1.0, right-aligned
Received: Fade in animation, left-aligned
```

### Input Field
```
Empty: Gray placeholder text
Typing: Active cursor
Has Text: Send button becomes blue
Disabled: Gray background (during processing)
```

## 🔄 State Flow Diagram

```
     Empty State
         ↓
   [User clicks chip]
         ↓
   Processing State
         ↓
   Response Appears
         ↓
   Follow-up Prompts Show
         ↓
   [User chooses follow-up]
         ↓
   Processing State
         ↓
   New Response
         ↓
   [Repeat or Clear]
         ↓
   Back to Empty State
```

## 📱 Real-World Example Screens

### Example 1: Team Meeting Analysis
```
User Message (right):
"📄 Make Minutes"

AI Response (left):
"Meeting Minutes - Product Roadmap Discussion
Date: January 12, 2026
Duration: 45 minutes

Attendees:
• Alex Chen (Product Manager)
• Jordan Smith (Engineering Lead)
• Sam Williams (Design Lead)

Discussion Topics:
1. Q1 Feature Prioritization
   - Discussed top 5 features for Q1
   - Agreed on mobile app improvements as priority
   - Timeline: Complete by March 31

2. Resource Allocation
   - Need 2 additional engineers
   - Design bandwidth confirmed
   - Budget approved

Key Decisions:
✓ Launch mobile app v2.0 in Q1
✓ Delay web redesign to Q2
✓ Hire 2 senior engineers

Action Items:
• Alex: Draft feature specs by Jan 19
• Jordan: Create technical timeline
• Sam: Finalize design mockups

Next Meeting: January 26, 2026"
```

### Example 2: Interview Notes
```
User Message:
"🗒️ Make Notes"

AI Response:
"Interview Notes - Senior Developer Position

Candidate: Jamie Rodriguez
Date: January 12, 2026
Interviewers: Tech team

Technical Skills:
• 8 years JavaScript/TypeScript experience
• Strong React and Node.js background
• Experience with AWS and cloud infrastructure
• Familiar with our tech stack

Highlights:
• Led team of 5 engineers at previous company
• Built scalable microservices architecture
• Strong communication and teaching skills
• Enthusiastic about our product vision

Concerns:
• Limited mobile development experience
• Would need to relocate from NYC

Discussion Points:
- Salary expectations: $150-160k (within budget)
- Start date: 2 weeks notice, available early Feb
- Remote work: Open to hybrid 3 days/week

Overall Impression: ⭐⭐⭐⭐ Strong candidate
Recommendation: Move forward with offer"
```

## 💡 UX Tips for Users

### Getting the Best Results

**1. Start Broad, Then Narrow**
```
✅ First: "Summarize Key Points"
✅ Then: "Focus on financial aspects"
```

**2. Use Follow-ups Wisely**
```
✅ "More Details" - When response is too brief
✅ "Simplify" - When response is too technical
✅ "Elaborate" - When you need deeper analysis
```

**3. Custom Prompts**
```
✅ Be specific: "List all mentioned deadlines"
✅ Ask questions: "What risks were identified?"
✅ Request formats: "Create a bullet list of attendees"
```

**4. Conversation Context**
```
✅ Follow-ups use previous context automatically
✅ You don't need to repeat information
✅ Build on previous responses
```

---

**Visual Guide Version:** 1.0  
**Last Updated:** January 12, 2026  
**Platform:** iOS 18.5+



