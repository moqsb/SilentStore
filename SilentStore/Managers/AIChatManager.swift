import Foundation
import NaturalLanguage
import Vision
import CoreML

/// Advanced AI Chat Manager - Real-time intelligent responses
@MainActor
final class AIChatManager {
    static let shared = AIChatManager()
    
    private init() {}
    
    // MARK: - Process Query with Real Intelligence
    
    func processQuery(_ query: String, vaultStore: VaultStore) async -> String {
        // Use Natural Language Framework for semantic understanding
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(query)
        
        // Extract intent and entities
        let tagger = NSLinguisticTagger(tagSchemes: [.nameType, .lexicalClass], options: 0)
        tagger.string = query
        let range = NSRange(location: 0, length: query.utf16.count)
        
        var intent: String = ""
        var entities: [String] = []
        var fileNames: [String] = []
        
        // Extract entities (file names, dates, etc.)
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange, _ in
            if let tag = tag {
                if let word = Range(tokenRange, in: query) {
                    let entity = String(query[word])
                    entities.append(entity)
                    if tag == .organizationName || tag == .placeName {
                        fileNames.append(entity)
                    }
                }
            }
        }
        
        // Extract keywords
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange, _ in
            if let tag = tag, tag == .noun || tag == .verb {
                if let word = Range(tokenRange, in: query) {
                    let keyword = String(query[word]).lowercased()
                    if !entities.contains(keyword) {
                        entities.append(keyword)
                    }
                }
            }
        }
        
        let lowerQuery = query.lowercased()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if lowerQuery.contains("rename") || lowerQuery.contains("change name") || lowerQuery.contains("سمّ") || trimmed.contains("إلى") {
            intent = "rename"
        } else if lowerQuery.contains("find") || lowerQuery.contains("search") || lowerQuery.contains("ابحث") || lowerQuery.contains("جد") || lowerQuery.contains("أين") {
            intent = "search"
        } else if (lowerQuery.contains("most") && (lowerQuery.contains("open") || lowerQuery.contains("used"))) || lowerQuery.contains("الأكثر فتحاً") {
            intent = "most_opened"
        } else if (lowerQuery.contains("last") && (lowerQuery.contains("open") || lowerQuery.contains("recent"))) || lowerQuery.contains("آخر") || lowerQuery.contains("حديث") {
            intent = "last_opened"
        } else if lowerQuery.contains("storage") || lowerQuery.contains("space") || lowerQuery.contains("clean") || lowerQuery.contains("مساحة") || lowerQuery.contains("كم مساحة") || lowerQuery.contains("كيف مساحة") {
            intent = "storage"
        } else if lowerQuery.contains("analyze") || lowerQuery.contains("what") || lowerQuery.contains("tell") || lowerQuery.contains("حلل") {
            intent = "analyze"
        } else if lowerQuery.contains("duplicate") || lowerQuery.contains("مكرر") || lowerQuery.contains("تكرار") {
            intent = "duplicates"
        } else if lowerQuery.contains("large") || lowerQuery.contains("big") || lowerQuery.contains("كبير") || lowerQuery.contains("ضخم") {
            intent = "large_files"
        } else {
            intent = "general"
        }
        
        // Process based on intent
        switch intent {
        case "rename":
            return await handleRename(query: query, entities: entities, vaultStore: vaultStore)
        case "search":
            return await handleSearch(query: query, entities: entities, vaultStore: vaultStore)
        case "most_opened":
            return await handleMostOpened(vaultStore: vaultStore)
        case "last_opened":
            return await handleLastOpened(vaultStore: vaultStore)
        case "storage":
            return await handleStorage(vaultStore: vaultStore)
        case "analyze":
            return await handleAnalyze(query: query, entities: entities, vaultStore: vaultStore)
        case "duplicates":
            return await handleDuplicates(vaultStore: vaultStore)
        case "large_files":
            return await handleLargeFiles(vaultStore: vaultStore)
        default:
            return await handleGeneral(query: query, vaultStore: vaultStore)
        }
    }
    
    // MARK: - Intent Handlers
    
    private func handleRename(query: String, entities: [String], vaultStore: VaultStore) async -> String {
        // Extract file name and new name from query
        let words = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // Try to find file name and new name
        var oldName: String?
        var newName: String?
        
        // Look for patterns like "rename X to Y" or "change X name to Y"
        for (index, word) in words.enumerated() {
            if word.lowercased() == "to" || word.lowercased() == "إلى" {
                if index > 0 && index < words.count - 1 {
                    oldName = words[index - 1]
                    newName = words[index + 1]
                }
            }
        }
        
        // If not found, try to extract from entities
        if oldName == nil || newName == nil {
            // Use smart search to find the file
            let searchResults = AIManager.shared.smartSearch(query: query, in: vaultStore.items)
            if let firstResult = searchResults.first {
                oldName = firstResult.originalName
                // Try to extract new name from query
                let queryLower = query.lowercased()
                if let toIndex = queryLower.range(of: "to") ?? queryLower.range(of: "إلى") {
                    let afterTo = String(query[toIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !afterTo.isEmpty {
                        newName = afterTo
                    }
                }
            }
        }
        
        guard let oldName = oldName, let newName = newName else {
            return NSLocalizedString("I need more information. Please specify which file to rename and the new name.\nExample: 'Rename photo.jpg to vacation.jpg'", comment: "")
        }
        
        // Find the file
        let file = vaultStore.items.first { $0.originalName.lowercased() == oldName.lowercased() }
        
        guard let file = file else {
            // Try smart search
            let searchResults = AIManager.shared.smartSearch(query: oldName, in: vaultStore.items)
            if let foundFile = searchResults.first {
                do {
                    try vaultStore.renameItem(id: foundFile.id, newName: newName)
                    return String(format: NSLocalizedString("✅ Successfully renamed '%@' to '%@'", comment: ""), foundFile.originalName, newName)
                } catch {
                    return String(format: NSLocalizedString("❌ Failed to rename file: %@", comment: ""), error.localizedDescription)
                }
            }
            return String(format: NSLocalizedString("❌ File '%@' not found. Please check the name and try again.", comment: ""), oldName)
        }
        
        do {
            try vaultStore.renameItem(id: file.id, newName: newName)
            return String(format: NSLocalizedString("✅ Successfully renamed '%@' to '%@'", comment: ""), file.originalName, newName)
        } catch {
            return String(format: NSLocalizedString("❌ Failed to rename file: %@", comment: ""), error.localizedDescription)
        }
    }
    
    private func handleSearch(query: String, entities: [String], vaultStore: VaultStore) async -> String {
        // Remove search keywords
        var searchQuery = query
        for keyword in ["find", "search", "ابحث", "جد", "أين", "عن"] {
            searchQuery = searchQuery.replacingOccurrences(of: keyword, with: " ", options: .caseInsensitive)
        }
        searchQuery = searchQuery.trimmingCharacters(in: .whitespaces)
        
        let results = AIManager.shared.smartSearch(query: searchQuery, in: vaultStore.items)
        
        if results.isEmpty {
            return String(format: NSLocalizedString("No files found matching '%@'. Try different keywords or check the spelling.", comment: ""), searchQuery)
        }
        
        var response = String(format: NSLocalizedString("Found %d file(s):\n\n", comment: ""), results.count)
        for (index, item) in results.prefix(10).enumerated() {
            let size = ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .none
            let dateStr = dateFormatter.string(from: item.createdAt)
            
            response += "\(index + 1). \(item.originalName)\n"
            response += "   📁 \(item.folder ?? NSLocalizedString("Root", comment: ""))\n"
            response += "   📊 \(size) • \(dateStr)\n\n"
        }
        
        if results.count > 10 {
            response += String(format: NSLocalizedString("... and %d more files", comment: ""), results.count - 10)
        }
        
        return response
    }
    
    private func handleMostOpened(vaultStore: VaultStore) async -> String {
        let mostOpened = vaultStore.items
            .sorted { item1, item2 in
                let count1 = UserDefaults.standard.integer(forKey: "openCount_\(item1.id.uuidString)")
                let count2 = UserDefaults.standard.integer(forKey: "openCount_\(item2.id.uuidString)")
                return count1 > count2
            }
            .prefix(10)
        
        if mostOpened.isEmpty {
            return NSLocalizedString("No files have been opened yet. Start using your vault to see usage statistics!", comment: "")
        }
        
        var response = NSLocalizedString("Your most opened files:\n\n", comment: "")
        for (index, item) in mostOpened.enumerated() {
            let count = UserDefaults.standard.integer(forKey: "openCount_\(item.id.uuidString)")
            let size = ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
            response += "\(index + 1). \(item.originalName)\n"
            response += "   📊 Opened \(count) times • \(size)\n"
            if let folder = item.folder {
                response += "   📁 \(folder)\n"
            }
            response += "\n"
        }
        
        return response
    }
    
    private func handleLastOpened(vaultStore: VaultStore) async -> String {
        let recent = vaultStore.recentOpenedItems()
        
        if recent.isEmpty {
            return NSLocalizedString("No recent files found.", comment: "")
        }
        
        var response = NSLocalizedString("Recently opened files:\n\n", comment: "")
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        for (index, item) in recent.prefix(10).enumerated() {
            let timeAgo = formatter.localizedString(for: item.createdAt, relativeTo: Date())
            let size = ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
            response += "\(index + 1). \(item.originalName)\n"
            response += "   ⏰ \(timeAgo) • \(size)\n"
            if let folder = item.folder {
                response += "   📁 \(folder)\n"
            }
            response += "\n"
        }
        
        return response
    }
    
    private func handleStorage(vaultStore: VaultStore) async -> String {
        let total = vaultStore.totalAppStorageBytes()
        let duplicates = vaultStore.findExactDuplicates()
        let largeFiles = vaultStore.items.filter { $0.size > 50_000_000 }.sorted { $0.size > $1.size }
        
        var response = String(format: NSLocalizedString("📊 Storage Analysis:\n\n", comment: ""))
        response += String(format: NSLocalizedString("Total Storage: %@\n", comment: ""), ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
        response += String(format: NSLocalizedString("Total Files: %d\n\n", comment: ""), vaultStore.items.count)
        
        if !duplicates.isEmpty {
            let duplicateSize = duplicates.flatMap { $0 }.dropFirst().reduce(0) { $0 + $1.size }
            response += String(format: NSLocalizedString("🔄 Duplicates: %d groups\n   Potential savings: %@\n\n", comment: ""), duplicates.count, ByteCountFormatter.string(fromByteCount: duplicateSize, countStyle: .file))
        }
        
        if !largeFiles.isEmpty {
            response += String(format: NSLocalizedString("📦 Large Files (>50MB): %d files\n", comment: ""), largeFiles.count)
            for file in largeFiles.prefix(5) {
                response += String(format: "   • %@: %@\n", file.originalName, ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
            }
            response += "\n"
        }
        
        if duplicates.isEmpty && largeFiles.isEmpty {
            response += NSLocalizedString("✅ Your vault is well organized! 🎉", comment: "")
        } else {
            response += NSLocalizedString("💡 Consider cleaning duplicates and large files to save space.", comment: "")
        }
        
        return response
    }
    
    private func handleAnalyze(query: String, entities: [String], vaultStore: VaultStore) async -> String {
        // Try to find specific file to analyze
        let searchResults = AIManager.shared.smartSearch(query: query, in: vaultStore.items)
        
        if let file = searchResults.first {
            return await analyzeFile(file: file, vaultStore: vaultStore)
        }
        
        // General analysis
        return await handleGeneral(query: query, vaultStore: vaultStore)
    }
    
    private func analyzeFile(file: VaultItem, vaultStore: VaultStore) async -> String {
        var response = String(format: NSLocalizedString("📄 Analysis of '%@':\n\n", comment: ""), file.originalName)
        
        response += String(format: NSLocalizedString("Size: %@\n", comment: ""), ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
        response += String(format: NSLocalizedString("Type: %@\n", comment: ""), file.mimeType)
        
        if let folder = file.folder {
            response += String(format: NSLocalizedString("Location: %@\n", comment: ""), folder)
        }
        
        if let category = file.category {
            response += String(format: NSLocalizedString("Category: %@\n", comment: ""), category)
        }
        
        let openCount = UserDefaults.standard.integer(forKey: "openCount_\(file.id.uuidString)")
        response += String(format: NSLocalizedString("Opened: %d times\n", comment: ""), openCount)
        
        // Analyze image if possible
        if file.isImage {
            do {
                let data = try await vaultStore.decryptItemData(file)
                if let category = await AIManager.shared.classifyImage(data) {
                    response += String(format: NSLocalizedString("AI Classification: %@\n", comment: ""), category)
                }
            } catch {
                // Skip if can't analyze
            }
        }
        
        return response
    }
    
    private func handleDuplicates(vaultStore: VaultStore) async -> String {
        let duplicates = vaultStore.findExactDuplicates()
        
        if duplicates.isEmpty {
            return NSLocalizedString("✅ No duplicate files found! Your vault is clean.", comment: "")
        }
        
        var response = String(format: NSLocalizedString("🔄 Found %d duplicate groups:\n\n", comment: ""), duplicates.count)
        
        for (index, group) in duplicates.prefix(5).enumerated() {
            let totalSize = group.reduce(0) { $0 + $1.size }
            response += String(format: NSLocalizedString("Group %d (%d files):\n", comment: ""), index + 1, group.count)
            for file in group.prefix(3) {
                response += "   • \(file.originalName)\n"
            }
            if group.count > 3 {
                response += String(format: "   ... and %d more\n", group.count - 3)
            }
            response += String(format: NSLocalizedString("   Total size: %@\n\n", comment: ""), ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
        }
        
        if duplicates.count > 5 {
            response += String(format: NSLocalizedString("... and %d more groups", comment: ""), duplicates.count - 5)
        }
        
        return response
    }
    
    private func handleLargeFiles(vaultStore: VaultStore) async -> String {
        let largeFiles = vaultStore.items.filter { $0.size > 50_000_000 }.sorted { $0.size > $1.size }
        
        if largeFiles.isEmpty {
            return NSLocalizedString("✅ No large files found. All files are under 50MB.", comment: "")
        }
        
        var response = String(format: NSLocalizedString("📦 Large Files (>50MB): %d files\n\n", comment: ""), largeFiles.count)
        
        for (index, file) in largeFiles.prefix(10).enumerated() {
            response += "\(index + 1). \(file.originalName)\n"
            response += String(format: "   Size: %@\n", ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
            if let folder = file.folder {
                response += "   📁 \(folder)\n"
            }
            response += "\n"
        }
        
        if largeFiles.count > 10 {
            response += String(format: NSLocalizedString("... and %d more files", comment: ""), largeFiles.count - 10)
        }
        
        return response
    }
    
    private func handleGeneral(query: String, vaultStore: VaultStore) async -> String {
        // Use smart search to find relevant files
        let results = AIManager.shared.smartSearch(query: query, in: vaultStore.items)
        
        if !results.isEmpty {
            var response = String(format: NSLocalizedString("I found %d file(s) related to your query:\n\n", comment: ""), results.count)
            for (index, item) in results.prefix(5).enumerated() {
                response += "\(index + 1). \(item.originalName)\n"
            }
            if results.count > 5 {
                response += String(format: NSLocalizedString("\n... and %d more files", comment: ""), results.count - 5)
            }
            return response
        }
        
        // General helpful response
        return NSLocalizedString("I can help you with:\n\n• Finding files: 'Find vacation photos'\n• Renaming files: 'Rename photo.jpg to vacation.jpg'\n• Storage analysis: 'How much space am I using?'\n• Most opened files: 'What are my most opened files?'\n• Duplicates: 'Show me duplicate files'\n• Large files: 'What are my largest files?'\n\nTry asking me anything about your files!", comment: "")
    }
}
