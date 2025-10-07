import Foundation
import SwiftUI

@MainActor
class TagStore: ObservableObject {
    @Published private(set) var allTags: [String] = []
    
    private let userDefaults = UserDefaults.standard
    private let tagsKey = "voice_notes_all_tags"
    
    // Default tags to pre-seed
    private let defaultTags = [
        "todo", "decision", "next-steps", "bug", "feature", "design", "meeting", "client", "urgent",
        "medical", "dental", "follow-up", "billing",
        "personal", "family", "travel"
    ]
    
    static let shared = TagStore()
    
    private init() {
        loadTags()
        
        // Pre-seed with default tags if this is first launch
        if allTags.isEmpty {
            for tag in defaultTags {
                add(tag)
            }
        }
    }
    
    // MARK: - Public API
    
    func all() -> [String] {
        return allTags.sorted { $0.lowercased() < $1.lowercased() }
    }
    
    private let maxTags = 500  // Reasonable limit for tag collection

    func add(_ tag: String) {
        let cleaned = cleanTag(tag)
        guard !cleaned.isEmpty && cleaned.count <= 32 else { return }

        // Check if tag exists case-insensitively
        let lowercased = cleaned.lowercased()
        if !allTags.contains(where: { $0.lowercased() == lowercased }) {
            // Check limit
            if allTags.count >= maxTags {
                print("⚠️ TagStore: Maximum tag limit reached (\(maxTags)). Remove unused tags.")
                return
            }
            allTags.append(cleaned)
            saveTags()
        }
    }
    
    func rename(old: String, new: String) {
        let cleanedNew = cleanTag(new)
        guard !cleanedNew.isEmpty && cleanedNew.count <= 32 else { return }
        
        if let index = allTags.firstIndex(where: { $0.lowercased() == old.lowercased() }) {
            // Check if new name conflicts with existing tag
            let newLowercased = cleanedNew.lowercased()
            if !allTags.contains(where: { $0.lowercased() == newLowercased }) {
                allTags[index] = cleanedNew
                saveTags()
                
                // Notify that tag was renamed for external updates
                NotificationCenter.default.post(
                    name: .tagRenamed,
                    object: nil,
                    userInfo: ["old": old, "new": cleanedNew]
                )
            }
        }
    }
    
    func remove(_ tag: String) {
        allTags.removeAll { $0.lowercased() == tag.lowercased() }
        saveTags()
        
        // Notify that tag was removed for external cleanup
        NotificationCenter.default.post(
            name: .tagRemoved,
            object: nil,
            userInfo: ["tag": tag]
        )
    }
    
    func suggest(prefix: String) -> [String] {
        guard !prefix.isEmpty else { return [] }
        
        let lowercasedPrefix = prefix.lowercased()
        return allTags
            .filter { $0.lowercased().hasPrefix(lowercasedPrefix) }
            .sorted { $0.lowercased() < $1.lowercased() }
    }
    
    func merge(from: String, into: String) {
        let cleanedInto = cleanTag(into)
        guard !cleanedInto.isEmpty else { return }

        // Validate source tag exists
        guard allTags.contains(where: { $0.lowercased() == from.lowercased() }) else {
            print("⚠️ TagStore: Source tag '\(from)' does not exist, cannot merge")
            return
        }

        // Add the target tag if it doesn't exist
        add(cleanedInto)

        // Remove the source tag
        remove(from)

        // Notify for external updates
        NotificationCenter.default.post(
            name: .tagMerged,
            object: nil,
            userInfo: ["from": from, "into": cleanedInto]
        )
    }

    func clearAllTags() {
        allTags.removeAll()
        saveTags()
    }

    // MARK: - Private Helpers
    
    private func cleanTag(_ tag: String) -> String {
        return tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func loadTags() {
        if let data = userDefaults.data(forKey: tagsKey),
           let decodedTags = try? JSONDecoder().decode([String].self, from: data) {
            allTags = decodedTags
        }
    }
    
    private func saveTags() {
        do {
            let data = try JSONEncoder().encode(allTags)
            userDefaults.set(data, forKey: tagsKey)
        } catch {
            print("❌ TagStore: Failed to encode tags: \(error)")
        }
    }
    
    // Stable color generation for tags
    func colorForTag(_ tag: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink]
        // Use stable hash based on UTF-8 characters
        let stableHash = tag.lowercased().utf8.reduce(0) { $0 &+ Int($1) }
        let index = abs(stableHash) % colors.count
        return colors[index]
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let tagRenamed = Notification.Name("tagRenamed")
    static let tagRemoved = Notification.Name("tagRemoved")
    static let tagMerged = Notification.Name("tagMerged")
}

// MARK: - Tag Utilities

extension Array where Element == String {
    func normalized() -> [String] {
        var seen = Set<String>()
        return self.compactMap { tag in
            let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }

            let lowercased = cleaned.lowercased()
            guard !seen.contains(lowercased) else { return nil }

            seen.insert(lowercased)
            return cleaned
        }
    }
}