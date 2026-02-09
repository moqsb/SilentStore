import Foundation

/// AI Learning Manager - Learns from user behavior and preferences
@MainActor
final class AILearningManager {
    static let shared = AILearningManager()
    
    private init() {}
    
    // MARK: - User Preference Learning
    
    /// Learn from user's file opening patterns
    func learnFromFileOpen(item: VaultItem, category: String?) {
        // Track category preferences
        if let category = category {
            let key = "preferredCategory_\(category)"
            let count = UserDefaults.standard.integer(forKey: key)
            UserDefaults.standard.set(count + 1, forKey: key)
        }
        
        // Track time-based patterns
        let hour = Calendar.current.component(.hour, from: Date())
        let key = "preferredHour_\(hour)"
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
        
        // Track file type preferences
        let fileType = item.isImage ? "image" : (item.isVideo ? "video" : "document")
        let typeKey = "preferredType_\(fileType)"
        let typeCount = UserDefaults.standard.integer(forKey: typeKey)
        UserDefaults.standard.set(typeCount + 1, forKey: typeKey)
    }
    
    /// Learn from user's folder organization
    func learnFromFolderCreation(folderName: String, items: [VaultItem]) {
        // Learn common patterns in folder names
        let key = "folderPattern_\(folderName.lowercased())"
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
        
        // Learn which file types go together
        let types = items.map { $0.isImage ? "image" : ($0.isVideo ? "video" : "document") }
        let typeSet = Set(types)
        for type in typeSet {
            let key = "folderType_\(type)"
            let count = UserDefaults.standard.integer(forKey: key)
            UserDefaults.standard.set(count + 1, forKey: key)
        }
    }
    
    /// Learn from user's search queries
    func learnFromSearch(query: String, selectedItem: VaultItem?) {
        guard let item = selectedItem else { return }
        
        // Learn search patterns
        let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        for word in queryWords where word.count > 2 {
            let key = "searchWord_\(word)"
            var associatedItems = UserDefaults.standard.stringArray(forKey: key) ?? []
            if !associatedItems.contains(item.id.uuidString) {
                associatedItems.append(item.id.uuidString)
                UserDefaults.standard.set(Array(associatedItems.prefix(10)), forKey: key)
            }
        }
    }
    
    /// Learn from user's pinning behavior
    func learnFromPin(item: VaultItem, isPinned: Bool) {
        if isPinned {
            // Learn what user considers important
            let categoryKey = "pinnedCategory_\(item.category ?? "none")"
            let count = UserDefaults.standard.integer(forKey: categoryKey)
            UserDefaults.standard.set(count + 1, forKey: categoryKey)
            
            let typeKey = "pinnedType_\(item.isImage ? "image" : (item.isVideo ? "video" : "document"))"
            let typeCount = UserDefaults.standard.integer(forKey: typeKey)
            UserDefaults.standard.set(typeCount + 1, forKey: typeKey)
        }
    }
    
    /// Learn from user's deletion patterns
    func learnFromDeletion(item: VaultItem) {
        // Learn what user doesn't want to keep
        let categoryKey = "deletedCategory_\(item.category ?? "none")"
        let count = UserDefaults.standard.integer(forKey: categoryKey)
        UserDefaults.standard.set(count + 1, forKey: categoryKey)
        
        // Track file age at deletion
        let age = Date().timeIntervalSince(item.createdAt)
        let ageKey = "deletedAge_\(Int(age / (24 * 3600)))"
        let ageCount = UserDefaults.standard.integer(forKey: ageKey)
        UserDefaults.standard.set(ageCount + 1, forKey: ageKey)
    }
    
    // MARK: - Personalized Predictions
    
    /// Predict which files user might want to open next
    func predictNextFiles(from items: [VaultItem]) -> [UUID] {
        var scores: [UUID: Double] = [:]
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        let preferredHour = getPreferredHour()
        
        for item in items {
            var score: Double = 0
            
            // Time-based scoring
            if abs(currentHour - preferredHour) < 2 {
                score += 10
            }
            
            // Category preference
            if let category = item.category {
                let prefCount = UserDefaults.standard.integer(forKey: "preferredCategory_\(category)")
                score += Double(prefCount) * 2
            }
            
            // File type preference
            let fileType = item.isImage ? "image" : (item.isVideo ? "video" : "document")
            let typePref = UserDefaults.standard.integer(forKey: "preferredType_\(fileType)")
            score += Double(typePref) * 1.5
            
            // Recency
            let daysSinceCreation = Date().timeIntervalSince(item.createdAt) / (24 * 3600)
            score += max(0, 20 - daysSinceCreation)
            
            // Frequency
            let openCount = UserDefaults.standard.integer(forKey: "openCount_\(item.id.uuidString)")
            score += Double(openCount) * 3
            
            scores[item.id] = score
        }
        
        return scores.sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
    }
    
    /// Get user's preferred hour for file access
    func getPreferredHour() -> Int {
        var maxCount = 0
        var preferredHour = 12 // Default to noon
        
        for hour in 0..<24 {
            let count = UserDefaults.standard.integer(forKey: "preferredHour_\(hour)")
            if count > maxCount {
                maxCount = count
                preferredHour = hour
            }
        }
        
        return preferredHour
    }
    
    /// Get user's preferred file types
    func getPreferredFileTypes() -> [String] {
        let types = ["image", "video", "document"]
        var scores: [String: Int] = [:]
        
        for type in types {
            scores[type] = UserDefaults.standard.integer(forKey: "preferredType_\(type)")
        }
        
        return scores.sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    /// Suggest folder name based on items
    func suggestFolderName(for items: [VaultItem]) -> String? {
        // Analyze common patterns
        let categories = items.compactMap { $0.category }
        let mostCommonCategory = categories.mostFrequent()
        
        if let category = mostCommonCategory, categories.filter({ $0 == category }).count >= items.count / 2 {
            return category
        }
        
        // Check date patterns
        let dates = items.map { Calendar.current.component(.day, from: $0.createdAt) }
        if let mostCommonDate = dates.mostFrequent(), dates.filter({ $0 == mostCommonDate }).count >= items.count / 2 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            if let firstItem = items.first {
                return formatter.string(from: firstItem.createdAt)
            }
        }
        
        return nil
    }
}

extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let counts = Dictionary(grouping: self, by: { $0 })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
