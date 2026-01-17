import Foundation

/// Post-processes raw ASR output into a more readable transcript.
/// - Adds paragraph breaks based on sentence boundaries and length.
/// - Preserves existing speaker labels like "John:" if present.
/// - Optionally adds generic "Speaker 1/2" labels only when dialogue-style text is strongly detected.
enum TranscriptPostProcessor {
    static func format(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        // Normalize whitespace (keep newlines)
        let normalized = normalizeWhitespacePreservingNewlines(trimmed)
        
        // If it already contains explicit speaker labels (e.g. "Name:"), just format into turns/paragraphs.
        if containsSpeakerLabels(normalized) {
            return formatWithExistingSpeakerLabels(normalized)
        }
        
        // Otherwise: paragraphize plain text.
        let paragraphs = paragraphize(normalized)
        
        // Only add generic speakers if the text strongly looks like dialogue.
        if shouldAddGenericSpeakers(paragraphs.joined(separator: "\n\n")) {
            return addGenericSpeakers(paragraphs)
        }
        
        return paragraphs.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Heuristics
    
    private static func shouldAddGenericSpeakers(_ text: String) -> Bool {
        // Conservative: only do this when the transcript looks like rapid back-and-forth.
        // We avoid hallucinating "speakers" for monologues.
        let sentences = splitIntoSentences(text)
        guard sentences.count >= 10 else { return false }
        
        let shortCount = sentences.filter { $0.count <= 40 }.count
        let shortRatio = Double(shortCount) / Double(max(sentences.count, 1))
        let qCount = text.filter { $0 == "?" }.count
        
        return shortRatio >= 0.40 && qCount >= 2
    }
    
    // MARK: - Formatting
    
    private static func paragraphize(_ text: String) -> [String] {
        let sentences = splitIntoSentences(text)
        guard !sentences.isEmpty else { return [text] }
        
        var out: [String] = []
        var current: [String] = []
        var currentLen = 0
        
        // Paragraph targets
        let maxChars = 360
        let maxSentences = 3
        
        for s in sentences {
            let sentence = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { continue }
            
            current.append(sentence)
            currentLen += sentence.count + 1
            
            if current.count >= maxSentences || currentLen >= maxChars {
                out.append(current.joined(separator: " "))
                current.removeAll()
                currentLen = 0
            }
        }
        
        if !current.isEmpty {
            out.append(current.joined(separator: " "))
        }
        
        return out.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    private static func addGenericSpeakers(_ paragraphs: [String]) -> String {
        var out: [String] = []
        var speaker = 1
        
        for p in paragraphs {
            out.append("Speaker \(speaker):\n\(p)")
            speaker = (speaker == 1) ? 2 : 1
        }
        
        return out.joined(separator: "\n\n")
    }
    
    private static func containsSpeakerLabels(_ text: String) -> Bool {
        // Detect lines like: "Name:" or "Speaker 1:"
        // We also detect inline patterns like "John: hello ..." near sentence boundaries.
        let pattern = #"(?m)^\s*[A-Za-zÀ-ÖØ-öø-ÿ0-9][A-Za-zÀ-ÖØ-öø-ÿ0-9 ._-]{0,24}:\s+\S"#
        return (try? NSRegularExpression(pattern: pattern)).map { regex in
            regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        } ?? false
    }
    
    private static func formatWithExistingSpeakerLabels(_ text: String) -> String {
        // Ensure each speaker label starts a new paragraph.
        // Also paragraphize within speaker blocks.
        let lines = text.components(separatedBy: .newlines)
        var blocks: [String] = []
        var currentBlock: [String] = []
        
        let labelRegex = try? NSRegularExpression(
            pattern: #"^\s*[A-Za-zÀ-ÖØ-öø-ÿ0-9][A-Za-zÀ-ÖØ-öø-ÿ0-9 ._-]{0,24}:\s+\S"#
        )
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            let isLabel = labelRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
            if isLabel {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock.joined(separator: " "))
                    currentBlock.removeAll()
                }
                currentBlock.append(line)
            } else {
                currentBlock.append(line)
            }
        }
        
        if !currentBlock.isEmpty {
            blocks.append(currentBlock.joined(separator: " "))
        }
        
        // Light paragraphization: break very long blocks.
        var out: [String] = []
        for b in blocks {
            let parts = paragraphize(b)
            if parts.count <= 1 {
                out.append(b)
            } else {
                // Keep the first line (speaker label) if present.
                if let firstLine = b.components(separatedBy: ":").first,
                   b.contains(":"),
                   b.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(firstLine) {
                    out.append(parts.joined(separator: "\n\n"))
                } else {
                    out.append(parts.joined(separator: "\n\n"))
                }
            }
        }
        
        return out.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Sentence Splitting
    
    private static func splitIntoSentences(_ text: String) -> [String] {
        // Simple heuristic sentence splitter.
        // Keeps abbreviations reasonably by requiring a space/newline after punctuation.
        let pattern = #"(?<=[\.\!\?])\s+"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let regex else { return [text] }
        
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        
        if matches.isEmpty { return [text] }
        
        var result: [String] = []
        var last = 0
        for m in matches {
            let r = m.range
            let chunk = ns.substring(with: NSRange(location: last, length: r.location - last))
            result.append(chunk)
            last = r.location + r.length
        }
        if last < ns.length {
            result.append(ns.substring(from: last))
        }
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    // MARK: - Whitespace
    
    private static func normalizeWhitespacePreservingNewlines(_ text: String) -> String {
        // Collapse repeated spaces/tabs, but keep newlines.
        let lines = text.components(separatedBy: .newlines)
        let cleaned = lines.map { line -> String in
            let replacedTabs = line.replacingOccurrences(of: "\t", with: " ")
            return replacedTabs.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        return cleaned.joined(separator: "\n").replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }
}

