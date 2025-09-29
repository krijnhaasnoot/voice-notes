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

// Mode-specific summary templates
enum SummaryMode: String, CaseIterable, Identifiable {
    case primaryCare = "primaryCare"
    case patientRecord = "patientRecord"
    case dentist = "dentist"
    case techTeam = "techTeam"
    case planning = "planning"
    case alignment = "alignment"
    case brainstorm = "brainstorm"
    case lecture = "lecture"
    case interview = "interview"
    case personal = "personal"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .primaryCare: return NSLocalizedString("summary.mode.primaryCare", comment: "Primary care summary mode")
        case .patientRecord: return NSLocalizedString("summary.mode.patientRecord", comment: "Patient record summary mode")
        case .dentist:     return NSLocalizedString("summary.mode.dentist", comment: "Dentist summary mode")
        case .techTeam:    return NSLocalizedString("summary.mode.techTeam", comment: "Tech team summary mode")
        case .planning:    return NSLocalizedString("summary.mode.planning", comment: "Planning summary mode")
        case .alignment:   return NSLocalizedString("summary.mode.alignment", comment: "Alignment summary mode")
        case .brainstorm:  return NSLocalizedString("summary.mode.brainstorm", comment: "Brainstorm summary mode")
        case .lecture:     return NSLocalizedString("summary.mode.lecture", comment: "Lecture summary mode")
        case .interview:   return NSLocalizedString("summary.mode.interview", comment: "Interview summary mode")
        case .personal:    return NSLocalizedString("summary.mode.personal", comment: "Personal summary mode")
        }
    }
    
    var shortDescription: String {
        switch self {
        case .primaryCare: return "Medical consultations and healthcare discussions"
        case .patientRecord: return "Comprehensive patient documentation and medical records"
        case .dentist:     return "Dental treatments and oral health consultations"
        case .techTeam:    return "Technical meetings and development discussions"
        case .planning:    return "Project planning and strategic sessions"
        case .alignment:   return "Team coordination and 1:1 meetings"
        case .brainstorm:  return "Creative ideation and brainstorming sessions"
        case .lecture:     return "Educational content and learning sessions"
        case .interview:   return "Interviews and structured Q&A conversations"
        case .personal:    return "General conversations and personal notes"
        }
    }
    
    func template(length: SummaryLength = .standard) -> String {
        let baseFormatting = "Output must be plain text. No markdown headings (#). Put bold labels with double asterisks on their own line, then one blank line. One blank line between sections. Use bullets '• '. Omit empty sections. Keep the transcript's language. Do not invent facts, owners, or deadlines."
        let lengthInstruction = length.lengthModifier
        
        switch self {
        case .primaryCare:
            return "Summarize this primary care consultation in a clear and structured way. Start with patient context and presenting complaint. Identify the healthcare provider and patient interaction. Highlight clinical findings, diagnosis, and treatment decisions. Extract key medical themes, clinical decisions, follow-up questions, and next steps. Use medical headings and bullet points to keep it organized. Keep it factual and concise; do not add clinical interpretations not stated in the recording. Maintain a professional medical tone for quick clinical reference. Use sections: **Patient Context**, **Chief Complaint**, **Clinical Findings**, **Treatment Plan**, **Follow-up Actions**. " + lengthInstruction + " " + baseFormatting
            
        case .patientRecord:
            return "Create a comprehensive patient dossier entry based on this medical consultation or examination. Document all relevant patient information in a structured medical record format. Include patient demographics if mentioned, medical history, current symptoms and complaints, physical examination findings, diagnostic test results, clinical assessments and diagnoses, prescribed treatments and medications, patient education provided, and follow-up plans. Maintain strict medical confidentiality and accuracy. Only document information explicitly stated in the recording. Use professional medical terminology and structured sections: **Patient Information**, **Medical History**, **Present Illness**, **Physical Examination**, **Diagnostic Results**, **Assessment & Diagnosis**, **Treatment Plan**, **Medications Prescribed**, **Patient Education**, **Follow-up Plan**, **Additional Notes**. " + lengthInstruction + " " + baseFormatting
            
        case .dentist:
            return "Summarize this dental consultation in a clear and structured way. Start with patient context and dental concerns. Identify the dentist and patient interaction. Highlight dental findings, procedures performed, and treatment recommendations. Extract key dental themes, treatment decisions, patient questions, and next steps. Use dental headings and bullet points to keep it organized. Keep it factual and concise; do not add clinical interpretations not stated in the recording. Maintain a professional dental tone for quick reference. Use sections: **Patient Context**, **Dental Assessment**, **Procedures Performed**, **Treatment Recommendations**, **Follow-up Care**. " + lengthInstruction + " " + baseFormatting
            
        case .techTeam:
            return "Summarize this technical team meeting in a clear and structured way. Start with team context and meeting purpose. Identify the participants and technical topics discussed. Highlight the main technical points, architecture decisions, and development priorities. Extract key technical themes, engineering decisions, outstanding questions, and next steps. Use technical headings and bullet points to keep it organized. Keep it factual and concise; do not add technical assumptions not stated in the meeting. Maintain a professional technical tone for quick team reference. Use sections: **Meeting Context**, **Technical Discussion**, **Key Decisions**, **Action Items**, **Next Steps**. " + lengthInstruction + " " + baseFormatting
            
        case .planning:
            return "Summarize this planning session in a clear and structured way. Start with project context and planning objectives. Identify the participants and project scope being discussed. Highlight the main planning points, resource allocations, and timeline decisions. Extract key planning themes, strategic decisions, scheduling questions, and next steps. Use planning headings and bullet points to keep it organized. Keep it factual and concise; do not add project assumptions not stated in the session. Maintain a professional project tone for quick planning reference. Use sections: **Project Context**, **Planning Discussion**, **Key Milestones**, **Resource Decisions**, **Action Items**. " + lengthInstruction + " " + baseFormatting
            
        case .alignment:
            return "Summarize this alignment meeting in a clear and structured way. Start with participants and alignment objectives. Identify the team members and strategic topics being aligned on. Highlight the main alignment points, priority decisions, and coordination agreements. Extract key strategic themes, alignment decisions, clarification questions, and next steps. Use alignment headings and bullet points to keep it organized. Keep it factual and concise; do not add strategic assumptions not stated in the meeting. Maintain a professional collaborative tone for quick reference. Use sections: **Alignment Context**, **Strategic Discussion**, **Key Agreements**, **Priority Decisions**, **Follow-up Actions**. " + lengthInstruction + " " + baseFormatting
            
        case .brainstorm:
            return "Summarize this brainstorming session in a clear and structured way. Start with participants and creative challenge being addressed. Identify the facilitator and team members contributing ideas. Highlight the main creative concepts, innovative solutions, and promising directions. Extract key creative themes, concept decisions, exploration questions, and next steps. Use creative headings and bullet points to keep it organized. Keep it factual and concise; do not add ideas not actually proposed in the session. Maintain an energetic yet professional tone for quick creative reference. Use sections: **Session Context**, **Creative Challenge**, **Ideas Generated**, **Promising Concepts**, **Next Steps**. " + lengthInstruction + " " + baseFormatting
            
        case .lecture:
            return "Summarize this educational session in a clear and structured way. Start with instructor and learning context. Identify the educator and educational objectives being covered. Highlight the main educational points, key concepts taught, and learning outcomes. Extract key educational themes, concept explanations, student questions, and next steps. Use educational headings and bullet points to keep it organized. Keep it factual and concise; do not add educational content not actually presented. Maintain a professional educational tone for quick learning reference. Use sections: **Learning Context**, **Key Concepts**, **Main Teaching Points**, **Examples Provided**, **Learning Outcomes**. " + lengthInstruction + " " + baseFormatting
            
        case .interview:
            return "Summarize this interview in a clear and structured way. Start with interviewer and interviewee context. Identify the participants and interview purpose or topic. Highlight the main discussion points, key responses, and important revelations. Extract key interview themes, significant answers, follow-up questions, and next steps. Use interview headings and bullet points to keep it organized. Keep it factual and concise; do not add interpretations not stated in the interview. Maintain a professional interview tone for quick reference. Use sections: **Interview Context**, **Key Questions**, **Main Responses**, **Important Insights**, **Follow-up Items**. " + lengthInstruction + " " + baseFormatting
            
        case .personal:
            return "Summarize this transcript in a clear and structured way. Start with a brief context: who the speakers are and what the topic is. Highlight the main points discussed. Extract themes, decisions, questions, and next steps. Use headings and bullet points to keep it organized. Keep it factual and concise; do not add information that isn't in the transcript. Maintain a neutral, professional tone so the summary is quick to read. " + lengthInstruction + " " + baseFormatting
        }
    }
    
    var color: Color {
        switch self {
        case .primaryCare: return .red
        case .patientRecord: return .teal
        case .dentist: return .blue
        case .techTeam: return .purple
        case .planning: return .orange
        case .alignment: return .green
        case .brainstorm: return .yellow
        case .lecture: return .indigo
        case .interview: return .pink
        case .personal: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .primaryCare: return "cross.fill"
        case .patientRecord: return "folder.fill.badge.plus"
        case .dentist: return "mouth.fill"
        case .techTeam: return "laptopcomputer"
        case .planning: return "calendar"
        case .alignment: return "arrow.triangle.2.circlepath"
        case .brainstorm: return "lightbulb.fill"
        case .lecture: return "graduationcap.fill"
        case .interview: return "person.2.fill"
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

