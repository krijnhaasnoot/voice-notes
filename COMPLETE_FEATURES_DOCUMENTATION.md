# Voice Notes (Echo) - Volledige Functionaliteiten Documentatie

**Versie:** 0.1.6  
**Build:** 6  
**Laatst bijgewerkt:** 12 januari 2026

---

## 📱 Overzicht

**Voice Notes** (ook bekend als **Echo**) is een geavanceerde iOS applicatie voor het opnemen, transcriberen en samenvatten van spraaknotities met AI-ondersteuning. De app combineert professionele audio-opname met state-of-the-art AI-transcriptie en samenvatting, en is beschikbaar voor zowel iPhone, iPad als Apple Watch.

### Kernwaarden
- 🎙️ **Professionele audio-opname** met achtergrondondersteuning
- 🤖 **AI-gestuurde transcriptie** via OpenAI Whisper
- 📝 **Slimme samenvattingen** via meerdere AI-providers (OpenAI, Claude, Gemini, Mistral)
- ⌚ **Apple Watch integratie** voor opnemen onderweg
- 🔐 **Privacy-first** - alle data lokaal opgeslagen
- 📊 **Usage-based billing** met eerlijke quota

---

## 🎯 Hoofdfunctionaliteiten

### 1. Audio Opname

#### 1.1 Basis Opname Functionaliteit
**File:** `AudioRecorder.swift`

**Features:**
- ✅ Hoge kwaliteit audio opname (M4A formaat, AAC codec)
- ✅ Real-time duur tracking tijdens opname
- ✅ Achtergrond opname (tot 60 minuten)
- ✅ Automatisch stoppen bij maximale duur (60 minuten)
- ✅ Automatische file management in Documents directory
- ✅ Audio sessie management (interruptions, route changes)

**Technische Details:**
```swift
// Audio Settings
- Format: M4A (MPEG-4 Audio)
- Codec: AAC
- Sample Rate: 44.1 kHz
- Bit Rate: Variabel (optimaal voor spraak)
- Channels: 1 (mono)
- Max Duration: 3600 seconden (60 minuten)
```

**UI Locaties:**
- `ContentView.swift` - Hoofdopname knop (grote blauwe/rode cirkel)
- `WatchHomeView.swift` - Apple Watch opname interface

**Permissions:**
- Microfoon toegang (`NSMicrophoneUsageDescription`)
- Spraakherkenning (`NSSpeechRecognitionUsageDescription`)
- Achtergrond audio mode (`UIBackgroundModes: audio`)

#### 1.2 Geavanceerde Opname Features
- **Pause/Resume** - Opname pauzeren en hervatten
- **Auto-stop bij achtergrond** - Als app te lang in achtergrond blijft
- **Route change handling** - Automatisch omschakelen tussen speakers/headphones
- **Interruption handling** - Telefoon call, alarm, etc.
- **App lifecycle management** - Correct opslaan bij app terminatie

#### 1.3 Achtergrond Opname
**File:** `BackgroundTaskManager.swift`

**Features:**
- Background task management voor langere opnames
- Automatische cleanup bij task expiratie
- Notificaties bij automatisch stoppen
- Background processing scheduling

**Limiet:**
- iOS geeft ongeveer 3-5 minuten achtergrond tijd
- Bij langere opnames moet app in voorgrond blijven

---

### 2. AI Transcriptie

#### 2.1 OpenAI Whisper Transcriptie
**File:** `OpenAIWhisperTranscriptionService.swift`

**Features:**
- ✅ Cloud-based transcriptie via OpenAI Whisper API
- ✅ Automatische taal detectie
- ✅ Ondersteuning voor lange opnames via chunking
- ✅ Speaker diarization (experimenteel)
- ✅ Timestamp support per segment
- ✅ Automatische compressie voor grote files (>25MB)
- ✅ Retry mechanisme bij netwerk fouten
- ✅ Cancellation support

**Technische Details:**
```swift
Model: whisper-1
Max File Size: 25MB (daarna compressie)
Chunk Duration: 8 minuten per chunk (voor >10 min opnames)
Timeout: 600 seconden request, 1800 seconden resource
Response Format: verbose_json (met timestamps en segments)
```

**Proces Flow:**
1. Audio file validatie (bestaat, > 0 bytes)
2. File size check (compressie als > 25MB)
3. Duration check (chunking als > 10 minuten)
4. API call naar OpenAI
5. JSON parsing met segments
6. Speaker detection formatting
7. Progress updates (0% → 10% → 90% → 100%)

**Error Handling:**
- API key validatie
- Network errors met exponential backoff (max 3 retries)
- File size errors
- Parsing errors met detailed logging
- Cancellation support via CancellationToken

#### 2.2 Lokale Transcriptie (Experimenteel)
**File:** `WhisperCppEngine.swift`, `TranscriptionWorker.swift`

**Features:**
- ✅ On-device transcriptie via SwiftWhisper
- ✅ Privacy-vriendelijk (geen cloud)
- ✅ Gratis (geen API kosten)
- ⚠️ Langzamer dan cloud
- ⚠️ Vereist model download (~1GB)

**Modellen:**
- Tiny (~75MB) - Snelst, minste accuraat
- Base (~150MB) - Gebalanceerd
- Small (~500MB) - Goede balans
- Medium (~1.5GB) - Beste accuraatheid

**Implementatie:**
- Model manager voor downloaden/beheren modellen
- Lokale opslag in app Documents directory
- Progress tracking tijdens transcriptie
- Language selection

---

### 3. AI Samenvattingen

#### 3.1 Multi-Provider Ondersteuning
**File:** `EnhancedSummaryService.swift`, `ProviderRegistry.swift`

**Ondersteunde Providers:**
1. **OpenAI (GPT-4, GPT-4o, GPT-4o-mini)**
2. **Anthropic Claude (Claude 3.5 Sonnet, Opus, Haiku)**
3. **Google Gemini (Gemini 1.5 Pro, Flash)**
4. **Mistral AI (Mistral Large, Medium)**

**File:** `Providers/` directory
- `OpenAISummaryProvider.swift`
- `AnthropicSummaryProvider.swift`
- `GeminiSummaryProvider.swift`
- `MistralSummaryProvider.swift`
- `AppDefaultSummaryProvider.swift` (fallback)

**Features:**
- ✅ Flexibele provider selectie in settings
- ✅ Automatische fallback bij provider failure
- ✅ Telemetry tracking per provider
- ✅ Custom API keys per provider (Own Key plan)
- ✅ Keychain storage voor API keys

#### 3.2 Samenvattings Lengtes
**Enum:** `SummaryLength`

```swift
case brief       // ~150-200 woorden
case standard    // ~250-350 woorden
case detailed    // ~400-600 woorden
```

**Prompt Engineering:**
Elke provider heeft optimized prompts voor:
- Structuur (koppen, opsommingen)
- Tone (professioneel, zakelijk)
- Details (key points, action items, decisions)
- Formattering (markdown met bold, bullets)

#### 3.3 Samenvatting Types
**Via:** `RecordingDetailView.swift` settings

**Modes:**
- **Personal** - Persoonlijke notities stijl
- **Meeting** - Meeting minutes format
- **Lecture** - Lecture notes format
- **Interview** - Interview transcript format

**Uitvoer Formaat:**
```markdown
**Titel**
[Automatisch gegenereerd]

**Hoofdpunten**
- Punt 1
- Punt 2
- Punt 3

**Belangrijkste Beslissingen**
[Als van toepassing]

**Actiepunten**
- [ ] Taak 1
- [ ] Taak 2

**Details**
[Uitgebreide context]
```

---

### 4. Interactieve AI Prompts

#### 4.1 Copilot-achtige Interface
**File:** `InteractivePromptsView.swift`, `ConversationService.swift`

**Inspiratie:** Microsoft Teams Copilot

**Features:**
- ✅ Chat-like interface met conversatie geschiedenis
- ✅ Voorgedefinieerde prompts (snel selecteren)
- ✅ Follow-up prompts gebaseerd op context
- ✅ Custom prompts (vrije tekst invoer)
- ✅ Conversatie bewaren per recording
- ✅ Markdown rendering in responses

#### 4.2 Voorgedefinieerde Prompts
**File:** `Models/ConversationModels.swift`

```swift
1. 📝 Make Notes - Gestructureerde notities
2. 📋 Meeting Minutes - Formele meeting notulen
3. ✨ Key Points - Belangrijkste punten samenvatten
4. 📌 Action Items - Actiepunten extraheren
5. 🔍 Deep Dive - Diepgaande analyse
6. 💡 Insights - Key insights en takeaways
7. 📊 Summary - Korte samenvatting
8. ❓ Q&A - Vragen beantwoorden
```

**Follow-up Prompts:**
- "More details" - Meer details over laatste response
- "Simplify" - Versimpelde versie
- "Expand" - Uitgebreide versie
- "Examples" - Voorbeelden toevoegen

#### 4.3 Conversatie Management
**Features:**
- Conversatie geschiedenis per recording
- Message roles (User, Assistant, System)
- Context-aware responses (eerdere messages worden meegenomen)
- Clear conversation (opnieuw beginnen)
- Export conversation history

**Implementatie:**
```swift
struct ConversationMessage {
    let role: MessageRole  // .user, .assistant, .system
    let content: String
    let prompt: PromptTemplate?
    let timestamp: Date
}

struct RecordingConversation {
    let recordingId: UUID
    var messages: [ConversationMessage]
    var createdAt: Date
}
```

---

### 5. Opname Beheer

#### 5.1 Recordings Manager
**File:** `RecordingsManager.swift`

**Features:**
- ✅ CRUD operaties voor recordings
- ✅ Persistentie via UserDefaults (JSON)
- ✅ File management (verwijderen, verplaatsen)
- ✅ Status tracking (idle, transcribing, summarizing, done, failed)
- ✅ Progress updates via NotificationCenter
- ✅ Automatische title generatie uit samenvatting
- ✅ Tag management per recording

**Data Model:**
```swift
struct Recording: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let date: Date
    var duration: TimeInterval
    var title: String
    var transcript: String?
    var summary: String?
    var rawSummary: String?
    var languageHint: String?
    var tags: [String]
    var status: Status
    var transcriptionModel: String?
    
    enum Status {
        case idle
        case transcribing(progress: Double)
        case summarizing(progress: Double)
        case done
        case failed(reason: String)
    }
}
```

#### 5.2 Processing Manager
**File:** `ProcessingManager.swift`

**Verantwoordelijk voor:**
- Transcriptie en samenvatting orchestratie
- Parallelle operatie tracking
- Progress updates naar UI
- Error handling en retry logic
- Operation cleanup

**Operation Types:**
```swift
enum OperationType {
    case transcription
    case summarization
}

enum OperationStatus {
    case running(progress: Double)
    case completed(result: OperationResult)
    case failed(error: Error)
    case cancelled
}
```

**Process Flow:**
```
Recording Added
    ↓
Start Transcription
    ↓ (ProcessingManager)
OpenAI Whisper API
    ↓ (Progress updates)
Transcript Ready
    ↓
Auto-start Summarization
    ↓ (ProcessingManager)
Selected AI Provider
    ↓ (Progress updates)
Summary Ready
    ↓
Status = Done
```

---

### 6. Lijst & Tag Beheer

#### 6.1 Automatische Lijst Detectie
**File:** `ListItemDetector.swift`

**Features:**
- ✅ Detecteert action items in transcript/samenvatting
- ✅ Haalt TODO items, beslissingen, volgende stappen uit
- ✅ Pattern matching voor verschillende list formats
- ✅ Confidence scoring per item

**Detectie Patterns:**
```
- Action items: "we should", "need to", "must", "action"
- Decisions: "decided to", "agreed on", "conclusion"
- Todo's: "TODO", "to do", "task", "[ ]"
- Next steps: "next step", "follow up", "upcoming"
```

#### 6.2 Tag Systeem
**File:** `TagStore.swift`, `TagManagementView.swift`

**Features:**
- ✅ Globale tag collectie (shared across recordings)
- ✅ Tag CRUD (Create, Read, Update, Delete)
- ✅ Auto-complete bij tag invoer
- ✅ Voorgedefinieerde tags (todo, urgent, meeting, etc.)
- ✅ Tag filtering in recordings list
- ✅ Tag cloud visualisatie

**UI Components:**
- `TagChipView.swift` - Individual tag chip
- `TagRowView` - Row van tags met max visible
- `TagManagementView.swift` - Tag beheer interface

**Tag Limits:**
- Max 500 tags in systeem
- Max 32 karakters per tag
- Case-insensitive matching

#### 6.3 Action Items Extractie
**Feature in:** `RecordingDetailView.swift`

**Workflow:**
1. Samenvatting wordt gegenereerd
2. ListItemDetector analyseert tekst
3. Gevonden items worden gepresenteerd
4. Gebruiker selecteert relevante items
5. Items worden opgeslagen met recording
6. Optie om naar externe apps te exporteren (Reminders, Calendar)

---

### 7. Document Management

#### 7.1 Document Store
**File:** `DocumentModels.swift`, `DocumentStore.swift`

**Features:**
- ✅ Opslaan recordings als documenten
- ✅ Categorieën (Meetings, Ideas, To-Do, Projects, etc.)
- ✅ Rich text met markdown support
- ✅ Attachments (audio file link)
- ✅ Tags en metadata
- ✅ Export als PDF

**Document Types:**
```swift
enum DocumentCategory {
    case meeting
    case idea
    case todo
    case journal
    case project
    case research
    case other
}
```

#### 7.2 PDF Export
**File:** `PDFGenerator.swift`

**Features:**
- ✅ Export recordings naar PDF
- ✅ Inclusief transcript en samenvatting
- ✅ Metadata (datum, duur, tags)
- ✅ Formatting met headers en styling
- ✅ Share sheet integratie

---

### 8. Subscription & Monetization

#### 8.1 Subscription Tiers
**File:** `Products.swift`, `SubscriptionManager.swift`

**Tiers:**

| Tier | Maandprijs | Minuten/maand | Features |
|------|-----------|--------------|----------|
| **Free** | €0 | 30 min (eenmalig) | Basis features, OpenAI only |
| **Standard** | €9.99 | 180 min | Alle AI providers, priority support |
| **Premium** | €19.99 | 600 min | Alles + custom models, API access |
| **Own Key** | €4.99 | Onbeperkt* | Gebruik eigen API keys |

*Onbeperkt = geen app quota, maar eigen API kosten

**StoreKit Integration:**
- Auto-renewable subscriptions
- Receipt validation
- Transaction listening
- Restore purchases
- Family sharing (optioneel)

#### 8.2 Usage Tracking
**File:** `MinutesTracker.swift`, `UsageViewModel.swift`

**Dual System:**
1. **Local Tracking** (`MinutesTracker`)
   - UserDefaults persistentie
   - Real-time updates
   - Monthly reset voor paid tiers
   - Free tier: eenmalig 30 minuten

2. **Backend Tracking** (`UsageViewModel` + Supabase)
   - Authoritative source of truth
   - Server-side validatie
   - Quota enforcement
   - Analytics en reporting

**Usage Flow:**
```
Recording Stopped
    ↓
Calculate duration (seconds)
    ↓
MinutesTracker.addUsage(seconds)
    ↓
UsageQuotaClient.recordUsage(minutes)
    ↓ (Supabase Edge Function)
Backend validates & stores
    ↓
UI updates from UsageViewModel.refresh()
```

#### 8.3 Supabase Backend
**Files:** `supabase/functions/ingest/`

**Edge Functions:**
1. **`ingest`** - Analytics events
2. **`usage`** - Usage quota tracking
3. **`usage-credit-topup`** - Top-up purchases

**Database Schema:**
```sql
Table: user_usage
- user_id (UUID, FK)
- recording_minutes (DECIMAL)
- period_start (TIMESTAMP)
- period_end (TIMESTAMP)
- subscription_tier (TEXT)
- last_updated (TIMESTAMP)
```

#### 8.4 Paywall
**File:** `PaywallView.swift`

**Features:**
- ✅ Moderne UI met gradient backgrounds
- ✅ Feature comparison table
- ✅ Localized pricing
- ✅ Purchase flow met loading states
- ✅ Error handling en retry
- ✅ "Restore Purchases" functionaliteit
- ✅ Terms & Privacy links

---

### 9. Apple Watch App

#### 9.1 Watch Companion
**Files:** `Echo Watch App/`

**Features:**
- ✅ Standalone opname op Watch
- ✅ WatchConnectivity sync met iPhone
- ✅ Haptic feedback bij start/stop
- ✅ Real-time duur display
- ✅ Complications voor snel openen
- ✅ Watch face integratie

**UI Components:**
```swift
- WatchHomeView.swift      // Main interface
- WatchRecorderViewModel   // State management
- WatchAudioRecorder       // Audio recording
- WatchConnectivityClient  // Sync met iPhone
```

#### 9.2 WatchConnectivity
**File:** `WatchConnectivityManager.swift`

**Sync Features:**
- ✅ Bidirectionele communicatie iPhone ↔ Watch
- ✅ Recording commands (start, stop, pause, resume)
- ✅ Status updates (isRecording, duration)
- ✅ File transfer (audio files van Watch naar iPhone)
- ✅ Reachability checking
- ✅ Background transfer queue

**Message Protocol:**
```swift
Messages:
- startRecording → iPhone starts recording
- stopRecording → iPhone stops and returns file info
- requestStatus → Get current recording state
- ping/pong → Connection health check

User Info (file transfers):
- audioData: Data
- fileName: String
- duration: TimeInterval
- timestamp: Date
```

---

### 10. UI/UX Features

#### 10.1 Moderne SwiftUI Interface
**Design System:**
- **Poppins font family** voor gehele app
- **Liquid glass components** met glasmorphism effecten
- **Gradient backgrounds** en smooth animations
- **Adaptive layouts** voor iPhone/iPad landscape/portrait
- **Dark mode support** throughout

**Key Views:**
```swift
- ContentView            // Main home screen
- RecordingDetailView    // Individual recording detail
- RecordingListRow       // List item component
- SettingsView           // App settings
- PaywallView            // Subscription paywall
- InteractivePromptsView // AI chat interface
```

#### 10.2 Calendar View
**File:** `LiquidCalendarView.swift`

**Features:**
- ✅ Maand-overzicht van recordings
- ✅ Highlight dagen met recordings
- ✅ Quick filter op datum
- ✅ Liquid animations bij date selection
- ✅ Badges voor recording count per dag

#### 10.3 Search & Filter
**In:** `ContentView.swift`

**Features:**
- ✅ Real-time search in titles en transcripts
- ✅ Calendar date filtering
- ✅ Tag filtering (future feature)
- ✅ Status filtering (transcribing, done, failed)
- ✅ Sorteer opties (date, duration, title)

#### 10.4 Share & Export
**Files:** `ShareSheet.swift`, `SharingHelper.swift`

**Export Formats:**
- **Plain Text** - Transcript + samenvatting
- **Markdown** - Geformatteerde versie
- **PDF** - Via PDFGenerator
- **Audio File** - Originele M4A

**Share Destinations:**
- Apple Notes
- Mail
- Messages
- Files app
- Third-party apps (via share sheet)

---

### 11. Settings & Configuration

#### 11.1 App Settings
**File:** `SettingsView.swift`

**Secties:**

**1. Account & Subscription**
- Huidige tier display
- Usage meter (minuten gebruikt/beschikbaar)
- Upgrade/Manage subscription
- Restore purchases

**2. AI Provider Settings**
- Provider selectie (OpenAI, Claude, Gemini, Mistral)
- Model selectie per provider
- API key management (voor Own Key subscribers)
- Test connection

**3. Transcription Settings**
- Taal voorkeur (auto-detect, of specifieke taal)
- Cloud vs Local transcriptie toggle
- Local model management (download/delete)

**4. Summary Settings**
- Default summary length
- Default summary mode (personal/meeting/etc)
- Auto-generate summary toggle

**5. Privacy & Security**
- Telemetry opt-out
- Clear cache
- Delete all data
- Export data (GDPR compliance)

**6. Advanced Settings**
- Debug mode toggle
- Subscription tier override (development)
- Force refresh usage quota
- Connection diagnostics

**7. Help & Support**
- Tutorial/onboarding
- FAQ
- Contact support
- Rate app
- Privacy Policy & Terms

#### 11.2 AI Provider Settings
**File:** `AIProviderSettingsView.swift`

**Per Provider:**
- Enable/Disable
- Model selection dropdown
- API Key input (secure keychain storage)
- Test button (validate credentials)
- Usage stats (calls, success rate)

**Keychain Storage:**
- Secure storage via `KeychainHelper.swift`
- Keys never stored in UserDefaults
- Automatic encryption
- Sync across devices (optional)

#### 11.3 Debug Settings
**File:** `DebugSettingsView.swift`

**Features (Development):**
- Subscription tier override
- Force specific user_id
- Clear UserDefaults
- View all stored recordings JSON
- Test Supabase connection
- View analytics queue
- Force telemetry upload

---

### 12. Analytics & Telemetry

#### 12.1 Event Tracking
**File:** `Analytics/Analytics.swift`, `SupabaseAnalyticsClient.swift`

**Tracked Events:**
```swift
- app_open                 // App launch/foreground
- app_background           // App to background
- recording_started        // Begin opname
- recording_stopped        // Stop opname
- recording_duration       // Duration in minutes
- transcription_started    // Begin transcriptie
- transcription_completed  // Transcriptie klaar
- transcription_failed     // Transcriptie fout
- summarization_started    // Begin samenvatting
- summarization_completed  // Samenvatting klaar
- summarization_failed     // Samenvatting fout
- subscription_purchased   // Subscription gekocht
- subscription_restored    // Purchases restored
- paywall_shown            // Paywall displayed
- provider_changed         // AI provider gewisseld
```

**Event Properties:**
- user_id (UUID)
- session_id (UUID per app sessie)
- platform (iOS)
- app_version
- device_model
- os_version
- subscription_tier
- timestamp

#### 12.2 Telemetry Aggregation
**File:** `EnhancedTelemetryService.swift`, `TelemetryAggregator.swift`

**Metrics:**
- Success/failure rates per provider
- Average processing times
- Error types en frequencies
- Feature usage statistics
- Performance metrics (memory, CPU)

**Aggregation:**
- Per hour, day, week, month
- Per user (anonymized)
- Per provider
- Global statistics

#### 12.3 Privacy Compliance
**GDPR/Privacy Features:**
- ✅ Telemetry opt-out in settings
- ✅ Anonymized user_id (UUID, geen PII)
- ✅ No transcript/audio data sent to analytics
- ✅ Data export functie
- ✅ Right to be forgotten (delete all data)
- ✅ Privacy Policy in-app display

---

### 13. Error Handling & Resilience

#### 13.1 Transcriptie Error Handling
**Scenarios:**

1. **Network Errors**
   - Retry met exponential backoff (max 3x)
   - User-friendly error messages
   - Option to retry manually

2. **API Key Errors**
   - Check bij startup (`createFromInfoPlist()`)
   - Prompt user to add key in settings
   - Validation bij API calls

3. **File Errors**
   - Validate file exists en > 0 bytes
   - Check file format (M4A)
   - Handle corrupted files gracefully

4. **Quota Errors**
   - Check usage before starting
   - Show paywall if exhausted
   - Clear error messages

#### 13.2 Samenvatting Error Handling
**Fallback Strategie:**

```
Primary Provider (user selected)
    ↓ (fails)
OpenAI GPT-4o-mini (app default)
    ↓ (fails)
Basic text extraction
    ↓ (always succeeds)
Simple first N characters
```

**Error Types:**
- API key missing/invalid
- Rate limit exceeded
- Network timeout
- Model unavailable
- Transcript too long
- Malformed response

#### 13.3 Health Checks
**File:** `ProcessingHealthCheck.swift`

**Checks:**
- ProcessingManager.shared initialized
- OpenAI API key configured
- Supabase connection working
- Sufficient storage space
- Network connectivity
- Subscription status valid

---

### 14. Localization

#### 14.1 Ondersteunde Talen
**Files:** `en.lproj/`, `nl.lproj/`

**Talen:**
- 🇬🇧 Engels (English) - Primary
- 🇳🇱 Nederlands (Dutch) - Secondary

**Gelocalizeerde Bestanden:**
- `Localizable.strings` - UI strings
- `InfoPlist.strings` - App name, permissions

#### 14.2 Transcriptie Talen
**Via OpenAI Whisper:**

Ondersteunt 50+ talen:
- Nederlands (nl)
- Engels (en)
- Frans (fr)
- Duits (de)
- Spaans (es)
- Italiaans (it)
- Portugees (pt)
- En vele meer...

**Taal Selectie:**
- Auto-detect (default)
- Manual selection in settings
- Per-recording override

---

### 15. Performance & Optimization

#### 15.1 Lazy Loading
- Recordings lijst gebruikt `LazyVStack`
- Audio files worden niet geladen tot playback
- Transcripts/summaries on-demand laden

#### 15.2 Background Processing
**File:** `BackgroundTaskManager.swift`

**Taken:**
- Transcription processing
- Summary generation
- File cleanup
- Analytics upload

**Limits:**
- iOS geeft beperkte achtergrond tijd
- Gebruik van `BGProcessingTask` voor lange taken
- Automatic resume bij app foreground

#### 15.3 Memory Management
- Weak references in delegates
- Automatic cleanup van completed operations
- Audio player cleanup na playback
- Image caching met limits

#### 15.4 Network Optimization
- Request timeouts (600s request, 1800s resource)
- Chunking voor grote files
- Compression voor >25MB files
- Connection reuse

---

### 16. Testing & Quality Assurance

#### 16.1 Unit Tests
**Files:** `Voice NotesTests/`

**Test Suites:**
- `RecordingProcessingTests.swift` - RecordingsManager logic
- `ProcessingManagerTests.swift` - Operation management
- `TranscriptionServiceTests.swift` - API interaction
- `StringExtensionTests.swift` - Helper functions

**Coverage:**
- Core business logic
- Data persistence
- Error handling
- Edge cases

#### 16.2 Integration Tests
**File:** `RecordingFlowIntegrationTests.swift`

**Scenarios:**
- Complete recording → transcription → summary flow
- Error recovery flows
- Multiple concurrent operations
- File management

#### 16.3 UI Tests
**File:** `Voice_NotesUITests.swift`

**Scenarios:**
- Recording start/stop flow
- Navigation tussen views
- Settings changes
- Purchase flow (sandbox)

---

### 17. Developer Tools

#### 17.1 Debug Views
- `DebugSettingsView.swift` - Debug instellingen
- `FontDebugView.swift` - Font testing
- `TelemetryView.swift` - Telemetry dashboard
- `TranscriptionTestView.swift` - Transcriptie testing

#### 17.2 Logging
**Emoji System voor Log Categorieën:**
```
🎙️ - Audio recording
🔤 - Transcription
📋 - Summarization
🎯 - Processing manager
📱 - App lifecycle
⌚ - Watch connectivity
💳 - Purchases/subscriptions
📊 - Analytics
🔐 - Security/keychain
```

**Logging Levels:**
- ✅ Success
- ⚠️ Warning
- ❌ Error
- 🐛 Debug

#### 17.3 Diagnostics
**Features:**
- Connection diagnostics (Supabase, OpenAI)
- WatchConnectivity diagnostics
- File system diagnostics
- Subscription status diagnostics

---

### 18. Security & Privacy

#### 18.1 Data Storage
**Lokaal:**
- Audio files: App Documents directory (encrypted by iOS)
- Recordings metadata: UserDefaults (JSON)
- Conversations: UserDefaults (JSON)
- API Keys: Keychain (encrypted)

**Geen Cloud Storage van:**
- Audio files
- Transcripts (behalve tijdens API call)
- Summaries (behalve tijdens API call)
- PII (Personally Identifiable Information)

#### 18.2 API Key Management
**Security Practices:**
- ✅ Keychain storage (niet UserDefaults)
- ✅ Never logged
- ✅ Validation voor gebruik
- ✅ Secure transmission (HTTPS only)
- ✅ No key in error messages

**Configuration:**
- Development: `Secrets.xcconfig` (niet in git)
- Production: Keychain user input
- Own Key plan: User provides eigen keys

#### 18.3 Network Security
- ✅ HTTPS only (App Transport Security)
- ✅ Certificate pinning (optioneel)
- ✅ Request validation
- ✅ Response validation
- ✅ Timeout enforcement

---

### 19. Deployment & Distribution

#### 19.1 Build Configuration
**Targets:**
- Voice Notes (iOS app)
- Echo (alternative branding)
- Echo Watch App (watchOS app)

**Build Settings:**
- Development Team: 9V592235FH
- Bundle ID: com.kinder.Voice-Notes
- Min iOS: 18.5
- Min watchOS: 11.0

#### 19.2 StoreKit Configuration
**File:** `Configuration.storekit`

**Products:**
```json
{
  "com.kinder.echo.standard": {
    "type": "auto-renewable",
    "price": 9.99,
    "duration": "1 month"
  },
  "com.kinder.echo.premium": {
    "type": "auto-renewable",
    "price": 19.99,
    "duration": "1 month"
  },
  "com.kinder.echo.own_key": {
    "type": "auto-renewable",
    "price": 4.99,
    "duration": "1 month"
  }
}
```

#### 19.3 App Store Assets
- App Icon (1024x1024)
- Screenshots (iPhone, iPad, Watch)
- Preview videos
- App Store description (localized)
- Keywords voor SEO
- Privacy manifest

---

### 20. Toekomstige Features (Roadmap)

#### Gepland voor v0.2.x:
- [ ] Folders/Collections voor recordings
- [ ] Favoriting/Starring recordings
- [ ] iCloud sync (optioneel)
- [ ] Siri Shortcuts integratie
- [ ] Widget voor iOS 17+
- [ ] Live Activities tijdens opname
- [ ] Collaborative notes (delen met anderen)
- [ ] Voice commands (hands-free)

#### Gepland voor v0.3.x:
- [ ] Multi-language UI (Frans, Duits, Spaans)
- [ ] iPad multi-window support
- [ ] Mac Catalyst app
- [ ] Export naar meer formaten (Word, Notion)
- [ ] Custom AI prompt templates
- [ ] Integration met Zapier/Make
- [ ] API voor developers

#### In Overweging:
- Real-time transcriptie (tijdens opname)
- Speaker identification (wie zegt wat)
- Noise reduction/enhancement
- Voice cloning (TTS van eigen voice)
- Integration met Calendar/Reminders
- Team/Business accounts

---

## 🔧 Technische Stack

### Frameworks & Libraries
```swift
- SwiftUI                      // UI framework
- AVFoundation                 // Audio opname/playback
- Speech                       // Speech recognition (permissions)
- WatchConnectivity            // Watch-iPhone sync
- StoreKit 2                   // In-app purchases
- UserDefaults                 // Local persistence
- URLSession                   // Network requests
- SwiftWhisper                 // Lokale transcriptie (optioneel)
```

### External Services
```
- OpenAI Whisper API           // Transcriptie
- OpenAI GPT API               // Samenvatting
- Anthropic Claude API         // Samenvatting (optioneel)
- Google Gemini API            // Samenvatting (optioneel)
- Mistral AI API               // Samenvatting (optioneel)
- Supabase                     // Backend (analytics, usage tracking)
```

### Development Tools
```
- Xcode 16.4+
- Swift 5.0
- Git (version control)
- SwiftLint (code style)
- XCTest (unit testing)
```

---

## 📊 App Statistics

### Code Metrics
```
- Total Swift files: ~80+
- Lines of code: ~15,000+
- Test coverage: ~40%
- Supported devices: iPhone, iPad, Apple Watch
- Min iOS version: 18.5
- App size: ~50MB (zonder local models)
```

### Performance Targets
```
- Recording latency: <100ms
- Transcription time: ~5-10% van audio lengte (cloud)
- Summary generation: ~5-15 seconden
- App launch time: <2 seconden (cold start)
- Memory usage: <100MB (idle), <200MB (processing)
```

---

## 🤝 Credits & Acknowledgments

**Developed by:** Krijn Haasnoot  
**Company:** Kinder  
**Version:** 0.1.6  
**Release Date:** Januari 2026

**Powered by:**
- OpenAI (Whisper & GPT)
- Anthropic (Claude)
- Google (Gemini)
- Mistral AI
- Supabase

**Special Thanks:**
- SwiftUI Community
- iOS Developer Community
- Beta testers

---

## 📝 License & Terms

**Copyright © 2026 Kinder. All rights reserved.**

Dit is proprietary software. Gebruik van deze app vereist acceptatie van de Terms of Service en Privacy Policy, beschikbaar in de app en op de website.

**Privacy Statement:**
- We verzamelen geen transcripts of audio
- Analytics zijn geanonimiseerd
- Gebruikers kunnen telemetry uitschakelen
- Data blijft lokaal op device
- GDPR compliant

---

## 📞 Support & Contact

**Support:**
- In-app Help & Support sectie
- Email: support@kinder.nl (example)
- Website: [To be added]

**Feedback:**
- Feature requests welkom
- Bug reports via TestFlight of email
- Rate in App Store

---

**Einde Documentatie**

*Laatst bijgewerkt: 12 januari 2026*
*Versie: 1.0*


