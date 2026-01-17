import Foundation
import SwiftUI

// Summary detail/length options
enum SummaryLength: String, CaseIterable, Identifiable {
    case brief = "brief"
    case standard = "standard"
    case detailed = "detailed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .brief: return NSLocalizedString("summary.length.brief", comment: "Brief summary length")
        case .standard: return NSLocalizedString("summary.length.standard", comment: "Standard summary length") 
        case .detailed: return NSLocalizedString("summary.length.detailed", comment: "Detailed summary length")
        }
    }
    
    var description: String {
        switch self {
        case .brief: return "Short and concise summary with key points only"
        case .standard: return "Balanced summary with main topics and details"
        case .detailed: return "Comprehensive summary with extensive detail"
        }
    }
    
    var lengthModifier: String {
        switch self {
        case .brief:
            return "Keep it very concise and brief. Focus only on the most essential points. Use short sentences and minimal detail."
        case .standard:
            return "Provide a balanced level of detail. Include key points with supporting information where relevant."
        case .detailed:
            return "Provide comprehensive detail. Include context, nuances, examples, and thorough explanations of all important points discussed."
        }
    }
}

// Mode-specific summary templates - Simplified to 3 modes
enum SummaryMode: String, CaseIterable, Identifiable {
    case medical = "medical"
    case work = "work"
    case personal = "personal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .medical: return NSLocalizedString("summary.mode.medical", comment: "Medical summary mode")
        case .work:    return NSLocalizedString("summary.mode.work", comment: "Work summary mode")
        case .personal: return NSLocalizedString("summary.mode.personal", comment: "Personal summary mode")
        }
    }

    var shortDescription: String {
        switch self {
        case .medical: return "Medical consultations, healthcare, and dental visits"
        case .work:    return "Meetings, planning, brainstorms, and work discussions"
        case .personal: return "General conversations and personal notes"
        }
    }
    
    func template(length: SummaryLength = .standard) -> String {
        // Detect app language
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = Locale(identifier: preferredLanguage).language.languageCode?.identifier ?? "en"

        let languageInstruction: String
        if languageCode == "nl" {
            languageInstruction = "Generate the summary in Dutch (Nederlands). All section headers, bullet points, and content must be in Dutch."
        } else if languageCode == "en" {
            languageInstruction = "Generate the summary in English."
        } else {
            languageInstruction = "Generate the summary in the same language as the app interface (\(languageCode))."
        }

        let actionItemCriteria = """
        CRITICAL: For action items section - ONLY include items that:
        • Are explicitly stated as something that must be done/completed
        • Contain clear action verbs (e.g., "schedule", "send", "review", "create", "contact")
        • Are NOT generic statements, observations, or context
        • Are NOT section headers like "context", "hoofdpunten", "summary"
        • Are NOT suggestions or possibilities unless explicitly framed as "we should do X" or "action: do Y"
        • Must be concrete, actionable tasks that someone can execute
        If no real action items are found, OMIT the action items section entirely. Do not force items into this section.
        """

        let baseFormatting = "Output must be plain text. No markdown headings (#). Put bold labels with double asterisks on their own line, then one blank line. One blank line between sections. Use bullets '• '. Omit empty sections. Do not invent facts, owners, or deadlines. \(actionItemCriteria) \(languageInstruction)"
        let lengthInstruction = length.lengthModifier

        switch self {
        case .medical:
            return "Summarize this medical consultation in a clear and structured way. Start with patient context and presenting complaint. Identify the healthcare provider and patient interaction. Highlight clinical findings, diagnosis, and treatment decisions. Extract key medical themes, clinical decisions, follow-up questions, and next steps. Use medical headings and bullet points to keep it organized. Keep it factual and concise; do not add clinical interpretations not stated in the recording. Maintain a professional medical tone for quick clinical reference. Use sections: **Patient Context**, **Chief Complaint**, **Clinical Findings**, **Treatment Plan**, **Follow-up Actions**. " + lengthInstruction + " " + baseFormatting

        case .work:
            return "Summarize this work meeting in a clear and structured way. Start with meeting context and purpose. Identify the participants and main topics discussed. Highlight the key points, decisions made, and priorities discussed. Extract key themes and decisions. For Action Items: ONLY include explicit tasks someone committed to doing with clear ownership (e.g., 'John will review the report by Friday'). Exclude observations, discussions, or general statements. Use clear headings and bullet points to keep it organized. Keep it factual and concise; do not add assumptions not stated in the meeting. Maintain a professional tone for quick reference. Use sections: **Meeting Context**, **Main Discussion**, **Key Decisions**, **Action Items** (only if explicit tasks exist). " + lengthInstruction + " " + baseFormatting

        case .personal:
            return "Summarize this transcript in a clear and structured way. Start with a brief context: who the speakers are and what the topic is. Highlight the main points discussed. Extract themes and decisions. For action items or next steps: ONLY include explicit tasks that were stated as things to do (e.g., 'Call the doctor', 'Buy groceries', 'Email John the report'). Do not include general observations, context, or discussion points. If no explicit action items exist, omit that section. Use headings and bullet points to keep it organized. Keep it factual and concise; do not add information that isn't in the transcript. Maintain a neutral, professional tone so the summary is quick to read. " + lengthInstruction + " " + baseFormatting
        }
    }
    
    var color: Color {
        switch self {
        case .medical: return .red
        case .work: return .blue
        case .personal: return .gray
        }
    }

    var icon: String {
        switch self {
        case .medical: return "cross.fill"
        case .work: return "briefcase.fill"
        case .personal: return "doc.text"
        }
    }
}

struct SummarySettings {
    static let defaultModeKey = "defaultMode"
    static let defaultLengthKey = "defaultSummaryLength"
}

// Uses SummarizationError and CancellationToken defined elsewhere in the project.

// MARK: - SummaryService

actor SummaryService {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    // "gpt-5-nano" caused HTTP 400s in production; use a stable small model instead.
    private let model = "gpt-4o-mini"

    /// Detect the most appropriate mode for a transcript
    func detectMode(
        transcript: String,
        cancelToken: CancellationToken
    ) async throws -> SummaryMode {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SummarizationError.emptyText }
        if cancelToken.isCancelled { throw SummarizationError.cancelled }

        // Load API key
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            throw SummarizationError.networkError(NSError(domain: "SummaryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key missing."]))
        }

        let systemPrompt = """
        You are a mode detection AI. Analyze the transcript and determine which type of conversation this is.
        
        Available modes:
        - Primary Care (GP): Medical consultations with patients
        - Dentist: Dental treatments and consultations  
        - Tech Team: Technical team meetings and development discussions
        - Planning: Planning and project meetings
        - Alignment / 1:1: Strategic alignment and coordination sessions
        - Brainstorm Session: Creative brainstorming and ideation discussions
        - Lecture / Learning: Educational content, presentations, or learning sessions
        - Interview: Interviews, Q&A sessions, or structured conversations between interviewer and interviewee
        - General Summary: General conversations that don't fit other categories
        
        Respond with ONLY the mode name: Primary Care (GP), Dentist, Tech Team, Planning, Alignment / 1:1, Brainstorm Session, Lecture / Learning, Interview, or General Summary
        """

        let userPrompt = """
        Analyze this transcript and determine the conversation type:
        
        \"\"\"\(trimmed)\"\"\"
        """

        // Minimal request/response models
        struct Msg: Codable { let role: String; let content: String }
        struct Req: Codable { let model: String; let messages: [Msg]; let temperature: Double; let max_tokens: Int }
        struct Choice: Codable { struct M: Codable { let role: String; let content: String }; let index: Int?; let message: M }
        struct Res: Codable { let choices: [Choice] }

        let payload = Req(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.1,
            max_tokens: 50
        )

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(payload)

        if cancelToken.isCancelled { throw SummarizationError.cancelled }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw SummarizationError.invalidResponse
            }

            switch http.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(Res.self, from: data)
                let result = decoded.choices.first?.message.content ?? ""
                let detectedMode = result.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Map response to enum
                for mode in SummaryMode.allCases {
                    if detectedMode.contains(mode.displayName) {
                        return mode
                    }
                }
                return .personal // Default fallback

            default:
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]))
            }
        } catch {
            if cancelToken.isCancelled { throw SummarizationError.cancelled }
            if error is SummarizationError { throw error }
            throw SummarizationError.networkError(error)
        }
    }

    /// Detect if the transcript contains multiple speakers
    func detectMultipleSpeakers(
        transcript: String,
        cancelToken: CancellationToken
    ) async throws -> Bool {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if cancelToken.isCancelled { throw SummarizationError.cancelled }

        // First do simple heuristics check for performance
        let conversationIndicators = [
            "Speaker", "Person", "A:", "B:", "1:", "2:", 
            "SPEAKER", "PERSON", "Speaker 1", "Speaker 2",
            "Participant", "Interviewer", "Interviewee"
        ]
        
        let hasIndicators = conversationIndicators.contains { indicator in
            trimmed.contains(indicator)
        }
        
        let hasMultipleLineBreaks = trimmed.components(separatedBy: "\n").count > 5
        let hasQuestionMarks = trimmed.filter { $0 == "?" }.count > 2
        
        // If clear indicators, return early
        if hasIndicators {
            return true
        }
        
        // If simple heuristics suggest single speaker, return early
        if !hasMultipleLineBreaks && !hasQuestionMarks {
            return false
        }
        
        // Use AI for ambiguous cases
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            // Fall back to heuristics if no API key
            return hasMultipleLineBreaks && hasQuestionMarks
        }

        let systemPrompt = """
        You are a conversation analysis AI. Determine if this transcript contains multiple people speaking.
        
        Look for:
        - Direct dialogue exchanges
        - Multiple distinct speaking patterns
        - Questions and responses between different people
        - Changes in topics that suggest different speakers
        - Different perspectives or viewpoints expressed
        
        Respond with only "YES" if multiple speakers are detected, or "NO" if it's a single person speaking.
        """

        let userPrompt = """
        Analyze this transcript for multiple speakers:
        
        \"\"\"\(trimmed.prefix(2000))\"\"\"
        """

        // Minimal request/response models (reusing from detectMode)
        struct Msg: Codable { let role: String; let content: String }
        struct Req: Codable { let model: String; let messages: [Msg]; let temperature: Double; let max_tokens: Int }
        struct Choice: Codable { struct M: Codable { let role: String; let content: String }; let index: Int?; let message: M }
        struct Res: Codable { let choices: [Choice] }

        let payload = Req(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.1,
            max_tokens: 10
        )

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(payload)

        if cancelToken.isCancelled { throw SummarizationError.cancelled }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                return hasMultipleLineBreaks && hasQuestionMarks // Fallback
            }

            switch http.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(Res.self, from: data)
                let result = decoded.choices.first?.message.content ?? ""
                let response = result.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                
                return response.contains("YES")

            default:
                return hasMultipleLineBreaks && hasQuestionMarks // Fallback
            }
        } catch {
            if cancelToken.isCancelled { throw SummarizationError.cancelled }
            return hasMultipleLineBreaks && hasQuestionMarks // Fallback
        }
    }

    /// Summarize a transcript into strict plain text with bold labels and bullets.
    /// For transcripts > 60 min (90,000 chars), automatically chunks and combines summaries.
    func summarize(
        transcript: String,
        mode: SummaryMode = .personal,
        length: SummaryLength = .standard,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> (clean: String, raw: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SummarizationError.emptyText }
        if cancelToken.isCancelled { throw SummarizationError.cancelled }

        // Check if transcript needs chunking (>90,000 chars = ~60+ min recording)
        let chunkThreshold = 90000
        if trimmed.count > chunkThreshold {
            print("📊 SummaryService: Large transcript (\(trimmed.count) chars), using chunking strategy")
            return try await summarizeWithChunking(
                transcript: trimmed,
                mode: mode,
                length: length,
                progress: progress,
                cancelToken: cancelToken
            )
        }

        // Standard single-pass summarization for smaller transcripts
        return try await summarizeSinglePass(
            transcript: trimmed,
            mode: mode,
            length: length,
            progress: progress,
            cancelToken: cancelToken
        )
    }

    /// Single-pass summarization (original logic)
    private func summarizeSinglePass(
        transcript: String,
        mode: SummaryMode,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> (clean: String, raw: String) {
        if cancelToken.isCancelled { throw SummarizationError.cancelled }

        // Load API key from KeyStore first, then fall back to Info.plist
        var apiKey: String = ""
        if let storedKey = try? KeyStore.shared.retrieve(for: .openai) {
            apiKey = storedKey
            print("📝 SummaryService: Using OpenAI API key from KeyStore")
        } else if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String {
            apiKey = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            print("📝 SummaryService: Using OpenAI API key from Info.plist")
        }
        
        guard !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            throw SummarizationError.networkError(NSError(domain: "SummaryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key missing. Please add one in Settings > AI Providers."]))
        }

        progress(0.1)

        // System & user prompts (strict format; plain text; no Markdown headers)
        let systemPrompt = mode.template(length: length)

        let userPrompt = """
        Summarize the following transcript using the format specified above.

        Transcript:
        \"\"\"\(transcript)\"\"\"
        """

        // Minimal request/response models
        struct Msg: Codable { let role: String; let content: String }
        struct Req: Codable { let model: String; let messages: [Msg]; let temperature: Double }
        struct Choice: Codable { struct M: Codable { let role: String; let content: String }; let index: Int?; let message: M }
        struct Res: Codable { let choices: [Choice] }

        let payload = Req(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.2
        )

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(payload)

        if cancelToken.isCancelled { throw SummarizationError.cancelled }
        progress(0.25)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw SummarizationError.invalidResponse
            }

            switch http.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(Res.self, from: data)
                let raw = decoded.choices.first?.message.content ?? ""
                if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw SummarizationError.invalidResponse
                }

                let clean = prettifySummaryPlain(raw)
                progress(1.0)

                return (clean: clean, raw: raw)

            case 401:
                let body = String(data: data, encoding: .utf8) ?? ""
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. \(body)"]))
            case 413:
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: 413, userInfo: [NSLocalizedDescriptionKey: "Payload too large (transcript too long)."]))
            case 429:
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited. Please retry shortly."]))
            default:
                let body = String(data: data, encoding: .utf8) ?? ""
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]))
            }
        } catch {
            if cancelToken.isCancelled { throw SummarizationError.cancelled }
            if error is SummarizationError { throw error }
            throw SummarizationError.networkError(error)
        }
    }

    // MARK: - Chunking for Large Transcripts

    /// Split and summarize large transcripts in chunks, then combine
    private func summarizeWithChunking(
        transcript: String,
        mode: SummaryMode,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> (clean: String, raw: String) {
        // Split transcript into ~40,000 char chunks (overlap for context)
        let chunkSize = 40000
        let overlapSize = 2000  // Keep 2000 chars overlap between chunks for context

        let chunks = splitIntoChunks(transcript, chunkSize: chunkSize, overlap: overlapSize)
        print("📊 SummaryService: Split into \(chunks.count) chunks")

        var chunkSummaries: [String] = []
        let totalChunks = Double(chunks.count)

        // Summarize each chunk
        for (index, chunk) in chunks.enumerated() {
            if cancelToken.isCancelled { throw SummarizationError.cancelled }

            let chunkProgress = Double(index) / totalChunks
            let chunkProgressEnd = Double(index + 1) / totalChunks

            print("📊 SummaryService: Processing chunk \(index + 1)/\(chunks.count)")

            // Use brief length for chunks to keep individual summaries concise
            let chunkResult = try await summarizeSinglePass(
                transcript: chunk,
                mode: mode,
                length: .brief,
                progress: { subProgress in
                    // Scale sub-progress to this chunk's portion of total progress
                    let scaledProgress = chunkProgress + (subProgress * (chunkProgressEnd - chunkProgress) * 0.8)  // 80% of progress for chunks
                    progress(scaledProgress)
                },
                cancelToken: cancelToken
            )

            chunkSummaries.append(chunkResult.clean)
        }

        // Combine chunk summaries into final summary
        print("📊 SummaryService: Combining \(chunkSummaries.count) chunk summaries")
        progress(0.85)

        let combinedSummary = try await combineSummaries(
            chunkSummaries: chunkSummaries,
            mode: mode,
            length: length,
            progress: { subProgress in
                // Final 15% of progress for combination
                progress(0.85 + (subProgress * 0.15))
            },
            cancelToken: cancelToken
        )

        progress(1.0)
        return (clean: combinedSummary, raw: combinedSummary)
    }

    /// Split transcript into overlapping chunks
    private func splitIntoChunks(_ text: String, chunkSize: Int, overlap: Int) -> [String] {
        var chunks: [String] = []
        var startIndex = text.startIndex

        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[startIndex..<endIndex])
            chunks.append(chunk)

            // Move start index forward by (chunkSize - overlap)
            if endIndex == text.endIndex { break }
            startIndex = text.index(startIndex, offsetBy: chunkSize - overlap, limitedBy: text.endIndex) ?? text.endIndex
        }

        return chunks
    }

    /// Combine multiple chunk summaries into a coherent final summary
    private func combineSummaries(
        chunkSummaries: [String],
        mode: SummaryMode,
        length: SummaryLength,
        progress: @escaping @Sendable (Double) -> Void,
        cancelToken: CancellationToken
    ) async throws -> String {
        if cancelToken.isCancelled { throw SummarizationError.cancelled }

        // Load API key from KeyStore first, then fall back to Info.plist
        var apiKey: String = ""
        if let storedKey = try? KeyStore.shared.retrieve(for: .openai) {
            apiKey = storedKey
        } else if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String {
            apiKey = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            throw SummarizationError.networkError(NSError(domain: "SummaryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key missing. Please add one in Settings > AI Providers."]))
        }

        progress(0.1)

        // Detect app language for final summary
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = Locale(identifier: preferredLanguage).language.languageCode?.identifier ?? "en"
        let languageInstruction: String
        if languageCode == "nl" {
            languageInstruction = "Generate the summary in Dutch (Nederlands)."
        } else {
            languageInstruction = "Generate the summary in English."
        }

        let systemPrompt = """
        You are combining multiple partial summaries of a long recording into one coherent final summary.

        The recording was split into chunks, and each chunk was summarized separately. Your task is to:
        1. Merge the information from all chunk summaries
        2. Remove any duplicate information across chunks
        3. Organize the content following this format: \(mode.template(length: length))
        4. Maintain chronological flow when relevant
        5. Ensure all key points from the chunk summaries are preserved

        \(languageInstruction)
        Output plain text with bold labels (**Label**) and bullets (• ).
        """

        let combinedInput = chunkSummaries.enumerated().map { (index, summary) in
            "--- Chunk \(index + 1) Summary ---\n\(summary)"
        }.joined(separator: "\n\n")

        let userPrompt = """
        Combine these chunk summaries into one coherent final summary:

        \(combinedInput)
        """

        struct Msg: Codable { let role: String; let content: String }
        struct Req: Codable { let model: String; let messages: [Msg]; let temperature: Double }
        struct Choice: Codable { struct M: Codable { let role: String; let content: String }; let index: Int?; let message: M }
        struct Res: Codable { let choices: [Choice] }

        let payload = Req(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.2
        )

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(payload)

        if cancelToken.isCancelled { throw SummarizationError.cancelled }
        progress(0.5)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw SummarizationError.invalidResponse
            }

            switch http.statusCode {
            case 200:
                let decoded = try JSONDecoder().decode(Res.self, from: data)
                let raw = decoded.choices.first?.message.content ?? ""
                if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw SummarizationError.invalidResponse
                }

                let clean = prettifySummaryPlain(raw)
                progress(1.0)

                return clean

            case 401:
                let body = String(data: data, encoding: .utf8) ?? ""
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. \(body)"]))
            case 413:
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: 413, userInfo: [NSLocalizedDescriptionKey: "Payload too large."]))
            case 429:
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited. Please retry shortly."]))
            default:
                let body = String(data: data, encoding: .utf8) ?? ""
                throw SummarizationError.networkError(NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"]))
            }
        } catch {
            if cancelToken.isCancelled { throw SummarizationError.cancelled }
            if error is SummarizationError { throw error }
            throw SummarizationError.networkError(error)
        }
    }
}

// MARK: - Post-processing (layout & bullets)

private func prettifySummaryPlain(_ input: String) -> String {
    // Normalize line endings and trim outer whitespace
    var text = input
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Known labels we enforce (Dutch)
    let labels = [
        "Titel", "Samenvatting", "Belangrijkste punten", "Besluiten", "Actiepunten",
        "Context", "Hoofdpunten", "Volgende stappen", "Vervolgacties",
        // English equivalents
        "Title", "Summary", "Key Points", "Decisions", "Action Items",
        "Next Steps", "Follow-up Actions", "Context"
    ]

    // 0) Convert accidental Markdown headings to bold labels
    text = text.replacingOccurrences(
        of: #"(?m)^#{1,6}\s*(.+)$"#,
        with: "**$1**",
        options: .regularExpression
    )

    // 1) If a plain (non-bold) label is at line start (optionally followed by ':' or dash), bold it and enforce spacing
    //    e.g., "Samenvatting: Dit..." -> "**Samenvatting**\n\nDit..."
    // placeholder; we'll do per-label loop instead

    // Do per-label normalization so we can keep it deterministic
    for label in labels {
        let esc = NSRegularExpression.escapedPattern(for: label)

        // 1a) Plain label at start of line → bold it and add blank line after
        //     ^\s*Label\s*[:\-–—]?\s*
        text = text.replacingOccurrences(
            of: #"(?m)^\s*"# + esc + #"\s*[:\-–—]?\s*"#,
            with: "**\(label)**\n\n",
            options: .regularExpression
        )

        // 2) If label appears glued to previous text, insert blank line before it
        //    ...tekst**Label** → ...tekst\n\n**Label**
        text = text.replacingOccurrences(
            of: #"([^\n])\s*\*\*"# + esc + #"\*\*"#,
            with: "$1\n\n**\(label)**",
            options: .regularExpression
        )

        // 3) Ensure bold label is on its own line and followed by EXACTLY one blank line
        //    **Label**De tekst → **Label**\n\nDe tekst
        text = text.replacingOccurrences(
            of: #"\*\*"# + esc + #"\*\*(?!\n\n)"#,
            with: "**\(label)**\n\n",
            options: .regularExpression
        )

        // 3b) If there is a single newline, upgrade to double
        text = text.replacingOccurrences(
            of: #"(?m)^\*\*"# + esc + #"\*\*\n(?!\n)"#,
            with: "**\(label)**\n\n",
            options: .regularExpression
        )
        
        // 3c) Guard against cases where there's exactly one newline or whitespace-newline combo after the label
        text = text.replacingOccurrences(
            of: #"(?m)^\*\*"# + esc + #"\*\*[ \t]*\n(?!\n)"#,
            with: "**\(label)**\n\n",
            options: .regularExpression
        )

        // 4) Remove trailing spaces/tabs after label before the enforced newlines
        text = text.replacingOccurrences(
            of: #"\*\*"# + esc + #"\*\*[ \t]*\n\n"#,
            with: "**\(label)**\n\n",
            options: .regularExpression
        )
    }

    // 5) Normalize list markers to bullets on their own line
    //    - Hyphen/asterisk at line start → "• "
    text = text.replacingOccurrences(of: #"(?m)^\s*[-*]\s+"#, with: "• ", options: .regularExpression)
    //    - Middle dot "·" to bullet
    text = text.replacingOccurrences(of: #"(?m)^\s*·\s+"#, with: "• ", options: .regularExpression)
    //    - If a bullet appears mid-line, move it to a new line
    text = text.replacingOccurrences(of: #"(?<!\n)•\s+"#, with: "\n• ", options: .regularExpression)

    // 6) Ensure exactly one blank line between sections (collapse 3+ → 2, then trim to max 2)
    while text.contains("\n\n\n") { text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n") }

    // 7) Trim trailing spaces per line
    text = text.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression)

    // 8) Final trim
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

