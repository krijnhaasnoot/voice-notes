import Foundation

struct DetectedListItem: Identifiable {
    let id = UUID()
    let text: String
    let listType: ListType
    let confidence: Confidence

    enum ListType: String, CaseIterable {
        case todo = "To-Do"
        case shopping = "Shopping"
        case ideas = "Ideas"
        case action = "Action Items"
        case general = "List"

        var icon: String {
            switch self {
            case .todo: return "checklist"
            case .shopping: return "cart"
            case .ideas: return "lightbulb"
            case .action: return "bolt"
            case .general: return "list.bullet"
            }
        }
    }

    enum Confidence {
        case high
        case medium
        case low
    }
}

struct DetectionResult {
    let items: [DetectedListItem]
    let listType: DetectedListItem.ListType
    let hasListIntent: Bool
}

final class ListItemDetector {
    static let shared = ListItemDetector()
    private init() {}

    // MARK: - Public API

    func detectListItems(from text: String) -> DetectionResult? {
        let normalizedText = text.lowercased()

        // First, detect if there's list intent
        guard let listType = detectListType(from: normalizedText) else {
            return nil
        }

        // Extract items based on patterns
        let items = extractItems(from: text, listType: listType)

        guard !items.isEmpty else {
            return nil
        }

        return DetectionResult(items: items, listType: listType, hasListIntent: true)
    }

    // MARK: - List Type Detection

    private func detectListType(from text: String) -> DetectedListItem.ListType? {
        let patterns: [(DetectedListItem.ListType, [String])] = [
            (.todo, todoPatterns),
            (.shopping, shoppingPatterns),
            (.ideas, ideasPatterns),
            (.action, actionPatterns)
        ]

        for (listType, keywords) in patterns {
            if keywords.contains(where: { text.contains($0) }) {
                return listType
            }
        }

        // Check for general list patterns
        if generalListPatterns.contains(where: { text.contains($0) }) {
            return .general
        }

        return nil
    }

    // MARK: - Item Extraction

    private func extractItems(from text: String, listType: DetectedListItem.ListType) -> [DetectedListItem] {
        var items: [DetectedListItem] = []

        // Try different extraction strategies

        // Strategy 1: Numbered lists (1., 2., 3. or 1, 2, 3)
        items.append(contentsOf: extractNumberedItems(from: text, listType: listType))

        // Strategy 2: Bullet points or dashes
        items.append(contentsOf: extractBulletedItems(from: text, listType: listType))

        // Strategy 3: "I need to" / "I have to" / "ik moet" patterns
        items.append(contentsOf: extractImperativeItems(from: text, listType: listType))

        // Strategy 4: Items after trigger phrases
        items.append(contentsOf: extractTriggeredItems(from: text, listType: listType))

        // Remove duplicates and clean up
        return cleanAndDeduplicate(items)
    }

    private func extractNumberedItems(from text: String, listType: DetectedListItem.ListType) -> [DetectedListItem] {
        var items: [DetectedListItem] = []

        // Pattern: "1. item" or "1) item" or "1: item"
        let pattern = #"(?:^|\n)\s*(\d+)[.):]\s*([^\n.]+?)(?:\n|$|\.(?:\s|$))"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                if match.numberOfRanges >= 3 {
                    let itemRange = match.range(at: 2)
                    let itemText = nsText.substring(with: itemRange).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !itemText.isEmpty && itemText.count > 2 {
                        items.append(DetectedListItem(text: itemText, listType: listType, confidence: .high))
                    }
                }
            }
        }

        return items
    }

    private func extractBulletedItems(from text: String, listType: DetectedListItem.ListType) -> [DetectedListItem] {
        var items: [DetectedListItem] = []

        // Pattern: "- item" or "* item" or "• item"
        let pattern = #"(?:^|\n)\s*[-*•]\s*([^\n]+)"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                if match.numberOfRanges >= 2 {
                    let itemRange = match.range(at: 1)
                    let itemText = nsText.substring(with: itemRange).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !itemText.isEmpty && itemText.count > 2 {
                        items.append(DetectedListItem(text: itemText, listType: listType, confidence: .high))
                    }
                }
            }
        }

        return items
    }

    private func extractImperativeItems(from text: String, listType: DetectedListItem.ListType) -> [DetectedListItem] {
        var items: [DetectedListItem] = []

        let imperativePhrases = [
            // English
            "i need to ", "i have to ", "i must ", "i should ",
            "need to ", "have to ", "must ", "should ",
            "don't forget to ", "remember to ", "make sure to ",
            // Dutch
            "ik moet ", "ik ga ", "ik wil ", "moet ik ",
            "vergeet niet ", "vergeet niet om ", "denk eraan om "
        ]

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))

        for sentence in sentences {
            let lowerSentence = sentence.lowercased()

            for phrase in imperativePhrases {
                if let range = lowerSentence.range(of: phrase) {
                    let itemText = String(sentence[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !itemText.isEmpty && itemText.count > 3 {
                        items.append(DetectedListItem(text: itemText, listType: listType, confidence: .medium))
                    }
                }
            }
        }

        return items
    }

    private func extractTriggeredItems(from text: String, listType: DetectedListItem.ListType) -> [DetectedListItem] {
        var items: [DetectedListItem] = []

        // Look for text after trigger phrases
        let triggerPatterns = [
            // English
            "add to my (?:todo|list|shopping list)",
            "put (?:this|that|these|it) on (?:my|the) (?:todo|list|shopping list)",
            "(?:items?|things?) (?:to|I need to) (?:do|buy|get|remember)",
            // Dutch
            "zet (?:dit|dat|deze) op (?:mijn|de) (?:todo|lijst|boodschappenlijst)",
            "(?:dingen?|items?) (?:die ik moet|om te) (?:doen|kopen|onthouden)"
        ]

        for patternStr in triggerPatterns {
            if let regex = try? NSRegularExpression(pattern: patternStr, options: [.caseInsensitive]) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

                // Get text after the match
                for match in matches {
                    let matchEnd = match.range.location + match.range.length
                    if matchEnd < nsText.length {
                        let remainingText = nsText.substring(from: matchEnd)

                        // Extract the next sentence or phrase
                        if let endRange = remainingText.rangeOfCharacter(from: CharacterSet(charactersIn: ".!?\n")) {
                            let itemText = String(remainingText[..<endRange.lowerBound])
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: CharacterSet(charactersIn: ":,-"))
                                .trimmingCharacters(in: .whitespacesAndNewlines)

                            if !itemText.isEmpty && itemText.count > 3 {
                                items.append(DetectedListItem(text: itemText, listType: listType, confidence: .medium))
                            }
                        }
                    }
                }
            }
        }

        return items
    }

    private func cleanAndDeduplicate(_ items: [DetectedListItem]) -> [DetectedListItem] {
        var seen = Set<String>()
        var cleaned: [DetectedListItem] = []

        for item in items {
            let normalizedText = item.text.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip if too short or already seen
            guard normalizedText.count > 2 && !seen.contains(normalizedText) else {
                continue
            }

            seen.insert(normalizedText)
            cleaned.append(item)
        }

        return cleaned
    }

    // MARK: - Pattern Definitions

    private let todoPatterns = [
        // English
        "todo", "to-do", "to do", "task", "tasks",
        "add to my todo", "put on my todo", "add this to my list",
        "things i need to do", "things to do",
        // Dutch
        "taak", "taken", "todolijst", "to-dolijst",
        "zet op mijn todo", "zet dit op mijn lijst",
        "dingen die ik moet doen"
    ]

    private let shoppingPatterns = [
        // English
        "shopping", "shopping list", "grocery", "groceries",
        "need to buy", "have to buy", "add to shopping",
        "things to buy", "items to get",
        // Dutch
        "boodschappen", "boodschappenlijst", "winkel",
        "moet kopen", "moet ik kopen", "zet op boodschappen",
        "dingen om te kopen"
    ]

    private let ideasPatterns = [
        // English
        "idea", "ideas", "thought", "thoughts",
        "add to my ideas", "remember this idea",
        // Dutch
        "idee", "ideeën", "gedachte", "gedachten",
        "zet bij mijn ideeën"
    ]

    private let actionPatterns = [
        // English
        "action item", "action items", "need to follow up",
        "follow up on", "reach out to", "contact",
        // Dutch
        "actiepunt", "actiepunten", "opvolgen",
        "contact opnemen", "bellen"
    ]

    private let generalListPatterns = [
        // English
        "add to my list", "put on my list", "make a list",
        // Dutch
        "zet op mijn lijst", "voeg toe aan lijst"
    ]
}
