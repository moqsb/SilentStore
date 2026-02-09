import Foundation
import Vision
import CoreML
import NaturalLanguage

/// Advanced AI Manager for intelligent file organization and suggestions
@MainActor
final class AIManager {
    static let shared = AIManager()
    
    var enabled: Bool = false
    
    private init() {}
    
    // MARK: - Image Classification
    
    func classifyImage(_ imageData: Data) async -> String? {
        guard let modelURL = Bundle.main.url(forResource: "ImageClassifier", withExtension: "mlmodelc") else {
            return smartCategoryFromMetadata(imageData: imageData)
        }
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL)) else {
            return smartCategoryFromMetadata(imageData: imageData)
        }
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, _ in
                let results = request.results as? [VNClassificationObservation]
                let identifier = results?.first?.identifier
                let confidence = results?.first?.confidence ?? 0
                
                // Use AI classification if confidence is high, otherwise use smart fallback
                if confidence > 0.5 {
                    continuation.resume(returning: self.normalizedCategory(from: identifier))
                } else {
                    continuation.resume(returning: self.smartCategoryFromMetadata(imageData: imageData))
                }
            }
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - Smart Suggestions
    
    /// Get intelligent suggestions for files based on usage patterns
    func getSmartSuggestions(for items: [VaultItem]) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // 1. Suggest important files based on frequency
        let frequentlyOpened = items.filter { item in
            let openCount = UserDefaults.standard.integer(forKey: "openCount_\(item.id.uuidString)")
            return openCount > 5
        }
        if !frequentlyOpened.isEmpty {
            suggestions.append(.importantFiles(frequentlyOpened.prefix(5).map { $0.id }))
        }
        
        // 2. Suggest duplicates
        let duplicates = findDuplicates(in: items)
        if !duplicates.isEmpty {
            suggestions.append(.duplicates(duplicates))
        }
        
        // 3. Suggest large files that might need cleanup
        let largeFiles = items.filter { $0.size > 50_000_000 } // > 50MB
            .sorted { $0.size > $1.size }
            .prefix(5)
        if !largeFiles.isEmpty {
            suggestions.append(.largeFiles(largeFiles.map { $0.id }))
        }
        
        // 4. Suggest unorganized files (no category or folder)
        let unorganized = items.filter { $0.category == nil && $0.folder == nil }
            .prefix(10)
        if !unorganized.isEmpty {
            suggestions.append(.unorganizedFiles(unorganized.map { $0.id }))
        }
        
        // 5. Suggest recent important files
        let recentImportant = items
            .filter { Date().timeIntervalSince($0.createdAt) < 7 * 24 * 3600 } // Last 7 days
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
        if !recentImportant.isEmpty {
            suggestions.append(.recentImportant(recentImportant.map { $0.id }))
        }
        
        return suggestions
    }
    
    // MARK: - Smart Search with Natural Language
    
    /// Enhanced search with semantic understanding using Natural Language Framework
    func smartSearch(query: String, in items: [VaultItem]) -> [VaultItem] {
        guard !query.isEmpty else { return items }
        
        // Use Natural Language Framework for semantic understanding
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(query)
        let dominantLanguage = recognizer.dominantLanguage
        
        // Extract keywords using NL framework
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass, .nameType], options: 0)
        tagger.string = query
        let range = NSRange(location: 0, length: query.utf16.count)
        var keywords: [String] = []
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange, _ in
            if let tag = tag, tag == .noun || tag == .adjective {
                if let word = Range(tokenRange, in: query) {
                    keywords.append(String(query[word]).lowercased())
                }
            }
        }
        
        // If no keywords extracted, use the whole query
        if keywords.isEmpty {
            keywords = [query.lowercased()]
        }
        
        let lowerQuery = query.lowercased()
        let queryWords = lowerQuery.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // Score items based on relevance
        let scoredItems = items.map { item -> (VaultItem, Int) in
            var score = 0
            
            // Exact match (highest priority) - 100 points
            if item.originalName.lowercased().contains(lowerQuery) {
                score += 100
            }
            
            // Category match - 80 points
            if let category = item.category?.lowercased(), category.contains(lowerQuery) {
                score += 80
            }
            
            // Folder match - 60 points
            if let folder = item.folder?.lowercased(), folder.contains(lowerQuery) {
                score += 60
            }
            
            // Keyword match using NL - 50 points per keyword
            for keyword in keywords {
                if item.originalName.lowercased().contains(keyword) {
                    score += 50
                }
                if let category = item.category?.lowercased(), category.contains(keyword) {
                    score += 40
                }
            }
            
            // Word-based match - 30 points
            let itemWords = item.originalName.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            
            for queryWord in queryWords {
                if itemWords.contains(where: { $0.contains(queryWord) || queryWord.contains($0) }) {
                    score += 30
                }
            }
            
            // MIME type match - 20 points
            if item.mimeType.lowercased().contains(lowerQuery) {
                score += 20
            }
            
            return (item, score)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
        
        return scoredItems.map { $0.0 }
    }
    
    // MARK: - Auto Organization
    
    /// Automatically organize files into smart folders
    func suggestOrganization(for items: [VaultItem]) -> [String: [UUID]] {
        var organization: [String: [UUID]] = [:]
        
        // Group by category
        for item in items {
            if let category = item.category {
                if organization[category] == nil {
                    organization[category] = []
                }
                organization[category]?.append(item.id)
            }
        }
        
        // Group by date (recent, this month, older)
        let calendar = Calendar.current
        let now = Date()
        
        let recentItems = items.filter { calendar.isDate($0.createdAt, inSameDayAs: now) || 
                                         calendar.dateComponents([.day], from: $0.createdAt, to: now).day ?? 0 < 7 }
        if !recentItems.isEmpty {
            organization["Recent"] = recentItems.map { $0.id }
        }
        
        return organization
    }
    
    // MARK: - Private Helpers
    
    private func normalizedCategory(from identifier: String?) -> String? {
        guard let identifier else { return nil }
        let lower = identifier.lowercased()
        
        // People
        if lower.contains("person") || lower.contains("face") || lower.contains("people") || 
           lower.contains("portrait") || lower.contains("selfie") {
            return "People"
        }
        
        // Food
        if lower.contains("food") || lower.contains("meal") || lower.contains("drink") ||
           lower.contains("restaurant") || lower.contains("dish") {
            return "Food"
        }
        
        // Documents
        if lower.contains("document") || lower.contains("paper") || lower.contains("text") ||
           lower.contains("letter") || lower.contains("form") {
            return "Documents"
        }
        
        // Receipts
        if lower.contains("receipt") || lower.contains("invoice") || lower.contains("bill") {
            return "Receipts"
        }
        
        // Pets
        if lower.contains("animal") || lower.contains("pet") || lower.contains("dog") || 
           lower.contains("cat") || lower.contains("bird") {
            return "Pets"
        }
        
        // Nature
        if lower.contains("plant") || lower.contains("tree") || lower.contains("mountain") || 
           lower.contains("sky") || lower.contains("sea") || lower.contains("landscape") ||
           lower.contains("sunset") || lower.contains("sunrise") {
            return "Nature"
        }
        
        // Vehicles
        if lower.contains("car") || lower.contains("vehicle") || lower.contains("transport") ||
           lower.contains("motorcycle") || lower.contains("bike") {
            return "Vehicles"
        }
        
        // Screenshots
        if lower.contains("screenshot") || lower.contains("screen") || lower.contains("display") {
            return "Screenshots"
        }
        
        // Work
        if lower.contains("office") || lower.contains("work") || lower.contains("business") ||
           lower.contains("meeting") || lower.contains("presentation") {
            return "Work"
        }
        
        // Travel
        if lower.contains("travel") || lower.contains("vacation") || lower.contains("trip") ||
           lower.contains("hotel") || lower.contains("airport") {
            return "Travel"
        }
        
        return identifier.capitalized
    }
    
    private func smartCategoryFromMetadata(imageData: Data) -> String? {
        // Try to extract metadata or use file name patterns
        // This is a fallback when ML model is not available
        return nil
    }
    
    private func findDuplicates(in items: [VaultItem]) -> [[UUID]] {
        var duplicates: [String: [VaultItem]] = [:]
        
        // Group by name and size (simple duplicate detection)
        for item in items {
            let key = "\(item.originalName)_\(item.size)"
            if duplicates[key] == nil {
                duplicates[key] = []
            }
            duplicates[key]?.append(item)
        }
        
        // Return groups with more than one item
        return duplicates.values
            .filter { $0.count > 1 }
            .map { $0.map { $0.id } }
    }
}

// MARK: - AI Suggestion Types

enum AISuggestion: Identifiable {
    case importantFiles([UUID])
    case duplicates([[UUID]])
    case largeFiles([UUID])
    case unorganizedFiles([UUID])
    case recentImportant([UUID])
    
    var id: String {
        switch self {
        case .importantFiles: return "important"
        case .duplicates: return "duplicates"
        case .largeFiles: return "large"
        case .unorganizedFiles: return "unorganized"
        case .recentImportant: return "recent"
        }
    }
    
    var title: String {
        switch self {
        case .importantFiles: return NSLocalizedString("Important Files", comment: "")
        case .duplicates: return NSLocalizedString("Duplicate Files", comment: "")
        case .largeFiles: return NSLocalizedString("Large Files", comment: "")
        case .unorganizedFiles: return NSLocalizedString("Unorganized Files", comment: "")
        case .recentImportant: return NSLocalizedString("Recent Important", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .importantFiles: return NSLocalizedString("Files you open frequently", comment: "")
        case .duplicates: return NSLocalizedString("Files that appear multiple times", comment: "")
        case .largeFiles: return NSLocalizedString("Files taking up significant space", comment: "")
        case .unorganizedFiles: return NSLocalizedString("Files without category or folder", comment: "")
        case .recentImportant: return NSLocalizedString("Recently added important files", comment: "")
        }
    }
    
    var icon: String {
        switch self {
        case .importantFiles: return "star.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .largeFiles: return "externaldrive.fill"
        case .unorganizedFiles: return "folder.badge.questionmark"
        case .recentImportant: return "clock.fill"
        }
    }
}
