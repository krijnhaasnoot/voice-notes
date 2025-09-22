import Foundation

// Summary detail/length options
enum SummaryLength: String, CaseIterable, Identifiable {
    case brief = "brief"
    case standard = "standard"
    case detailed = "detailed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .brief: return "Brief"
        case .standard: return "Standard"
        case .detailed: return "Detailed"
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

// Mode-specific summary templates
enum SummaryMode: String, CaseIterable, Identifiable {
    case primaryCare = "primaryCare"
    case dentist = "dentist"
    case techTeam = "techTeam"
    case planning = "planning"
    case alignment = "alignment"
    case brainstorm = "brainstorm"
    case lecture = "lecture"
    case personal = "personal"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .primaryCare: return "Primary Care (GP)"
        case .dentist:     return "Dentist"
        case .techTeam:    return "Tech Team"
        case .planning:    return "Planning"
        case .alignment:   return "Alignment / 1:1"
        case .brainstorm:  return "Brainstorm Session"
        case .lecture:     return "Lecture / Learning"
        case .personal:    return "Personal / Other"
        }
    }
    
    func template(length: SummaryLength = .standard) -> String {
        let baseFormatting = "Output must be plain text. No markdown headings (#). Put bold labels with double asterisks on their own line, then one blank line. One blank line between sections. Use bullets '• '. Omit empty sections. Keep the transcript's language. Do not invent facts, owners, or deadlines."
        let lengthInstruction = length.lengthModifier
        
        switch self {
        case .primaryCare:
            return "Summarize this primary care consultation in clear language. Use sections: **Chief Complaint**, **Exam/Findings**, **Advice/Treatment**, **Follow-up**. Be factual and concise; no interpretations not stated in the recording. " + lengthInstruction + " " + baseFormatting
            
        case .dentist:
            return "Summarize this dental visit. Use sections: **Dental Findings**, **Procedure Performed**, **Advice**, **Follow-up**. Keep it short and concrete. Use bullets for advice. " + lengthInstruction + " " + baseFormatting
            
        case .techTeam:
            return "Summarize this team meeting. Use sections: **Title** (short), **Summary**, **Key Points** (bullets), **Decisions**, **Action Items** (only if explicitly mentioned, with assignee if present). Business-neutral tone. " + lengthInstruction + " " + baseFormatting
            
        case .planning:
            return "Summarize this planning discussion. Use sections: **Title**, **Summary**, **Key Dates & Commitments**, **Decisions**, **Action Items**. Include dates/times exactly as mentioned. " + lengthInstruction + " " + baseFormatting
            
        case .alignment:
            return "Summarize this alignment conversation. Use sections: **Title**, **Summary**, **Main Topics**, **Decisions / Next Steps**. Informal but clear tone. " + lengthInstruction + " " + baseFormatting
            
        case .brainstorm:
            return "Summarize this brainstorming session. Use sections: **Session Title**, **Challenge / Goal**, **Ideas Generated**, **Best Ideas**, **Next Steps**. Capture creative energy and group thinking patterns. Organize ideas by theme or priority. " + lengthInstruction + " " + baseFormatting
            
        case .lecture:
            return "Summarize this lecture or learning session. Use sections: **Topic**, **Key Concepts**, **Main Points**, **Examples / Case Studies**, **Takeaways**. Focus on educational content and learning objectives. Structure for study reference. " + lengthInstruction + " " + baseFormatting
            
        case .personal:
            return "Summarize this conversation in simple language. Use sections: **Title**, **Summary**, **Key Points**. Keep it light and personal. " + lengthInstruction + " " + baseFormatting
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
        - Personal / Other: General conversations that don't fit other categories
        
        Respond with ONLY the mode name: Primary Care (GP), Dentist, Tech Team, Planning, Alignment / 1:1, Brainstorm Session, Lecture / Learning, or Personal / Other
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

        // Load API key
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, !apiKey.hasPrefix("$(") else {
            throw SummarizationError.networkError(NSError(domain: "SummaryService", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key missing."]))
        }

        progress(0.1)

        // System & user prompts (strict format; plain text; no Markdown headers)
        let systemPrompt = mode.template(length: length)

        let userPrompt = """
        Summarize the following transcript using the format specified above.

        Transcript:
        \"\"\"\(trimmed)\"\"\"
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
}

// MARK: - Post-processing (layout & bullets)

private func prettifySummaryPlain(_ input: String) -> String {
    // Normalize line endings and trim outer whitespace
    var text = input
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // Known labels we enforce
    let labels = ["Titel", "Samenvatting", "Belangrijkste punten", "Besluiten", "Actiepunten"]

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

