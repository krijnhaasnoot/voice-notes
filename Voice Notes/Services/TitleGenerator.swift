import Foundation

class TitleGenerator {
    static let shared = TitleGenerator()
    
    private init() {}
    
    // Generate a meaningful 3-word title based on transcript/summary content
    func generateTitle(from transcript: String?, summary: String?, mode: SummaryMode? = nil, date: Date) -> String {
        // Try to extract meaningful title from content
        if let meaningfulTitle = extractMeaningfulTitle(from: transcript, summary: summary) {
            return meaningfulTitle
        }
        
        // Fallback to mode-based + time-based titles
        return generateFallbackTitle(mode: mode, date: date)
    }
    
    private func extractMeaningfulTitle(from transcript: String?, summary: String?) -> String? {
        let content = [transcript, summary].compactMap { $0 }.joined(separator: " ")
        
        guard !content.isEmpty else { return nil }
        
        // Clean and normalize the text
        let cleanContent = content.lowercased()
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let words = cleanContent.components(separatedBy: " ").filter { !$0.isEmpty && !stopWords.contains($0) }
        
        // Look for key topics and concepts
        if let topicTitle = findTopicBasedTitle(from: words) {
            return topicTitle
        }
        
        // Extract most meaningful words
        return extractKeyWords(from: words)
    }
    
    private func findTopicBasedTitle(from words: [String]) -> String? {
        let topicPatterns: [String: [String]] = [
            "Meeting Discussion": ["meeting", "discuss", "agenda", "team", "project"],
            "Health Consultation": ["doctor", "health", "symptoms", "medical", "appointment"],
            "Interview Notes": ["interview", "candidate", "questions", "experience", "background"],
            "Lecture Summary": ["learn", "education", "explain", "concept", "understand"],
            "Planning Session": ["plan", "strategy", "goals", "timeline", "objectives"],
            "Brainstorm Ideas": ["ideas", "brainstorm", "creative", "innovative", "solutions"],
            "Personal Notes": ["think", "remember", "personal", "thoughts", "diary"],
            "Tech Discussion": ["code", "software", "development", "technical", "system"]
        ]
        
        for (title, keywords) in topicPatterns {
            let matchCount = keywords.filter { keyword in
                words.contains { $0.contains(keyword) }
            }.count
            
            if matchCount >= 2 {
                return title
            }
        }
        
        return nil
    }
    
    private func extractKeyWords(from words: [String]) -> String {
        // Filter for meaningful words (longer than 2 characters)
        let meaningfulWords = words.filter { $0.count > 2 && !commonWords.contains($0) }
        
        if meaningfulWords.count >= 3 {
            // Take first 3 meaningful words and capitalize them
            return meaningfulWords.prefix(3)
                .map { $0.capitalized }
                .joined(separator: " ")
        } else if meaningfulWords.count >= 1 {
            // Use available meaningful words + fallback
            let availableWords = meaningfulWords.map { $0.capitalized }
            let fallbackWords = generateRandomWords(count: 3 - availableWords.count)
            return (availableWords + fallbackWords).joined(separator: " ")
        }
        
        return generateRandomWords(count: 3).joined(separator: " ")
    }
    
    private func generateFallbackTitle(mode: SummaryMode?, date: Date) -> String {
        let modeWords: [String] = {
            switch mode {
            case .primaryCare: return ["Health", "Care", "Notes"]
            case .dentist: return ["Dental", "Visit", "Notes"]
            case .techTeam: return ["Tech", "Team", "Meeting"]
            case .planning: return ["Planning", "Session", "Notes"]
            case .alignment: return ["Alignment", "Meeting", "Notes"]
            case .brainstorm: return ["Brainstorm", "Session", "Ideas"]
            case .lecture: return ["Lecture", "Learning", "Notes"]
            case .interview: return ["Interview", "Session", "Notes"]
            case .personal, .none: return ["Voice", "Note", "Recording"]
            }
        }()
        
        // Add time context for uniqueness
        let hour = Calendar.current.component(.hour, from: date)
        let timeWords = [
            "Morning", "Midday", "Afternoon", "Evening", "Night"
        ]
        
        let timeIndex = min(hour / 5, timeWords.count - 1)
        var finalWords = modeWords
        finalWords[2] = timeWords[timeIndex]
        
        return finalWords.joined(separator: " ")
    }
    
    private func generateRandomWords(count: Int) -> [String] {
        let adjectives = ["Quick", "Smart", "Clear", "Bright", "Fresh", "Key", "Main", "Core"]
        let nouns = ["Ideas", "Notes", "Talk", "Chat", "Meeting", "Session", "Update", "Review"]
        
        var words: [String] = []
        
        for i in 0..<count {
            if i == 0 || i % 2 == 0 {
                words.append(adjectives.randomElement() ?? "Quick")
            } else {
                words.append(nouns.randomElement() ?? "Notes")
            }
        }
        
        return words
    }
    
    // Common stop words to filter out
    private let stopWords: Set<String> = [
        "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "from", "about", "into", "through", "during", "before", "after", "above", "below",
        "up", "down", "out", "off", "over", "under", "again", "further", "then", "once",
        "here", "there", "when", "where", "why", "how", "all", "any", "both", "each",
        "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only",
        "own", "same", "so", "than", "too", "very", "can", "will", "just", "should",
        "now", "i", "me", "my", "myself", "we", "our", "ours", "ourselves", "you",
        "your", "yours", "yourself", "yourselves", "he", "him", "his", "himself",
        "she", "her", "hers", "herself", "it", "its", "itself", "they", "them",
        "their", "theirs", "themselves", "what", "which", "who", "whom", "this",
        "that", "these", "those", "am", "is", "are", "was", "were", "be", "been",
        "being", "have", "has", "had", "having", "do", "does", "did", "doing",
        "a", "an", "as", "if", "because", "while", "until", "since"
    ]
    
    // Less meaningful common words
    private let commonWords: Set<String> = [
        "like", "really", "actually", "basically", "literally", "totally", "definitely",
        "probably", "maybe", "perhaps", "anyway", "somehow", "somewhere", "something",
        "someone", "anything", "anyone", "everything", "everyone", "nothing", "nobody",
        "thing", "things", "stuff", "time", "times", "way", "ways", "kind", "sort",
        "type", "part", "parts", "lot", "lots", "bit", "bits", "piece", "pieces"
    ]
}