import Foundation

extension String {
    /// Generate a smart title from transcript content (≤7 words)
    func smartTitle(maxWords: Int = 7) -> String {
        let firstLine = self.replacingOccurrences(of: "\n", with: " ")
            .split(separator: ".").first.map(String.init) ?? self
        let words = firstLine.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != " " })
        let title = words.prefix(maxWords).joined(separator: " ")
        let final = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return final.isEmpty ? "Nieuwe opname" : final.capitalized
    }
    
    /// Determines if this string represents a likely actionable task
    var isLikelyAction: Bool {
        let s = self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Skip empty strings
        guard !s.isEmpty else { return false }
        
        // Action verbs that typically start actionable tasks
        let verbs = [
            "call", "email", "buy", "order", "pick up", "pickup", "schedule", "book", 
            "send", "review", "prepare", "follow up", "followup", "check", "research", 
            "plan", "clean", "paint", "fix", "update", "create", "write", "meet", 
            "ask", "decide", "pay", "install", "contact", "reach out", "set up", "setup",
            "organize", "arrange", "confirm", "cancel", "remind", "notify", "submit",
            "complete", "finish", "start", "begin", "purchase", "get", "obtain",
            "reserve", "make", "do", "handle", "process", "deliver", "ship",
            "visit", "go to", "attend", "join", "participate"
        ]
        
        // Check if starts with action verb
        for verb in verbs {
            if s.hasPrefix(verb + " ") || s == verb {
                return true
            }
        }
        
        // Check for common task patterns
        let taskPatterns = [
            " to-do ", " todo ", "task:", "todo:", "action:", "reminder:",
            "need to ", "should ", "must ", "have to ", "remember to "
        ]
        
        for pattern in taskPatterns {
            if s.contains(pattern) || s.hasPrefix(pattern.trimmingCharacters(in: .whitespaces)) {
                return true
            }
        }
        
        // Check if it's a question that implies an action
        if s.hasSuffix("?") && (s.contains("when ") || s.contains("how ") || s.contains("who ")) {
            return true
        }
        
        return false
    }
}

/// Convert Markdown to prettified plain text
func prettifyMarkdownToPlain(_ md: String) -> String {
    var text = md
    // Convert ## headers to **bold**
    text = text.replacingOccurrences(
        of: #"(?m)^#{1,6}\s*(.+)$"#,
        with: "**$1**",
        options: .regularExpression
    )
    // Convert bullet points to •
    text = text.replacingOccurrences(
        of: #"(?m)^\s*[-*]\s+"#,
        with: "• ",
        options: .regularExpression
    )
    return text
}

/// Create share text for a recording
func makeShareText(for recording: Recording, overrideTranscript: String? = nil, overrideSummary: String? = nil) -> String {
    let name = (!recording.title.isEmpty ? recording.title : recording.fileName)
    var parts = ["File: \(name)"]
    
    let transcript = overrideTranscript ?? recording.transcript
    let summary = overrideSummary ?? recording.summary
    
    if let t = transcript, !t.isEmpty {
        parts.append("Transcript:\n\(t)")
    }
    
    if let s = summary, !s.isEmpty {
        parts.append("Samenvatting:\n\(prettifyMarkdownToPlain(s))")
    }
    
    return parts.joined(separator: "\n\n")
}