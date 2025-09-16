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