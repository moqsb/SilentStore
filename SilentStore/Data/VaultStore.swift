import Foundation
import Combine
import CoreData
import Photos

@MainActor
final class VaultStore: ObservableObject {
    // Primary data source and file vault access layer.
    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case nameAZ = "Name A-Z"
        case nameZA = "Name Z-A"
        case sizeAsc = "Size Asc"
        case sizeDesc = "Size Desc"

        var id: String { rawValue }
    }

    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case images = "Images"
        case videos = "Videos"
        case documents = "Documents"
        case others = "Others"

        var id: String { rawValue }
    }

    private let context: NSManagedObjectContext
    private var isPrepared = false
    private var preparationTask: Task<Void, Never>?
    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var pinnedIDs: Set<UUID> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isReady = false

    private let pinnedKey = "vaultPinnedIDs"
    private let folderKey = "vaultFolderPaths"
    private let recentsKey = "vaultRecentOpened"

    init(context: NSManagedObjectContext) {
        self.context = context
        loadPinned()
    }

    func prepareIfNeeded() async {
        if isPrepared { return }
        if let existing = preparationTask {
            await existing.value
            return
        }
        let task = Task {
            isLoading = true
            isReady = false
            defer { isLoading = false; preparationTask = nil }
            do {
                _ = try await KeyManager.shared.getOrCreateMasterKey()
                try migrateLegacyIfNeeded()
                try loadItems()
                isPrepared = true
                isReady = true
            } catch {
                print("VaultStore prepare failed: \(error)")
                isPrepared = false
                isReady = false
            }
        }
        preparationTask = task
        await task.value
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try loadItems()
            isReady = true
        } catch {
            print("VaultStore refresh failed: \(error)")
            isReady = false
        }
    }

    func markLocked() {
        preparationTask = nil
        isPrepared = false
        isReady = false
    }

    func filteredItems(filter: FilterOption, searchText: String, sort: SortOption) -> [VaultItem] {
        var filtered = items
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            filtered = filtered.filter {
                $0.originalName.lowercased().contains(lower)
                || ($0.category?.lowercased().contains(lower) ?? false)
                || ($0.folder?.lowercased().contains(lower) ?? false)
            }
        }

        switch filter {
        case .all:
            break
        case .images:
            filtered = filtered.filter { $0.isImage }
        case .videos:
            filtered = filtered.filter { $0.isVideo }
        case .documents:
            filtered = filtered.filter { $0.isDocument }
        case .others:
            filtered = filtered.filter { !$0.isImage && !$0.isVideo && !$0.isDocument }
        }

        switch sort {
        case .newest:
            filtered.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            filtered.sort { $0.createdAt < $1.createdAt }
        case .nameAZ:
            filtered.sort { $0.originalName.localizedCaseInsensitiveCompare($1.originalName) == .orderedAscending }
        case .nameZA:
            filtered.sort { $0.originalName.localizedCaseInsensitiveCompare($1.originalName) == .orderedDescending }
        case .sizeAsc:
            filtered.sort { $0.size < $1.size }
        case .sizeDesc:
            filtered.sort { $0.size > $1.size }
        }

        if !pinnedIDs.isEmpty {
            let pinned = filtered.filter { pinnedIDs.contains($0.id) }
            let unpinned = filtered.filter { !pinnedIDs.contains($0.id) }
            filtered = pinned + unpinned
        }

        return filtered
    }

    func addItem(
        data: Data,
        originalName: String,
        mimeType: String,
        isImage: Bool,
        category: String?,
        folder: String?
    ) async throws {
        let masterKey = try await KeyManager.shared.getOrCreateMasterKey()
        let encrypted = try Crypto.encrypt(data, using: masterKey)
        let fileName = UUID().uuidString
        let fileURL = try encryptedFileURL(fileName: fileName)
        try encrypted.write(to: fileURL, options: [.atomic])
        try applyFileProtection(url: fileURL)

        let entity = VaultEntity(context: context)
        entity.id = UUID()
        entity.originalName = originalName
        entity.mimeType = mimeType
        entity.size = Int64(data.count)
        entity.createdAt = Date()
        entity.fileName = fileName
        entity.category = category
        entity.folder = folder ?? category
        entity.sha256 = Crypto.sha256Hex(data)
        entity.isImage = isImage

        try context.save()
        try loadItems()
    }

    func existingItem(named name: String, inFolder folder: String?) -> VaultItem? {
        items.first { item in
            item.originalName == name && item.folder == folder
        }
    }

    func uniqueItemName(base: String, inFolder folder: String?) -> String {
        let existingNames = Set(items.filter { $0.folder == folder }.map(\.originalName))
        if !existingNames.contains(base) { return base }
        let ext = (base as NSString).pathExtension
        let nameWithoutExt = ext.isEmpty ? base : (base as NSString).deletingPathExtension
        var n = 1
        while true {
            let candidate = ext.isEmpty ? "\(nameWithoutExt) (\(n))" : "\(nameWithoutExt) (\(n)).\(ext)"
            if !existingNames.contains(candidate) { return candidate }
            n += 1
        }
    }

    func folderExists(path: String) -> Bool {
        storedFolderPaths().contains(path)
    }

    func deleteItems(ids: Set<UUID>) throws {
        let fetch = NSFetchRequest<VaultEntity>(entityName: "VaultEntity")
        fetch.predicate = NSPredicate(format: "id IN %@", ids)
        let matches = try context.fetch(fetch)
        for entity in matches {
            if let fileName = entity.fileName {
                let url = try? encryptedFileURL(fileName: fileName)
                if let url = url { try? FileManager.default.removeItem(at: url) }
            }
            context.delete(entity)
        }
        try context.save()
        try loadItems()
    }

    func assignCategory(forIDs ids: Set<UUID>, category: String) throws {
        try assignFolder(forIDs: ids, folderPath: category)
    }

    func assignFolder(forIDs ids: Set<UUID>, folderPath: String) throws {
        let fetch = NSFetchRequest<VaultEntity>(entityName: "VaultEntity")
        fetch.predicate = NSPredicate(format: "id IN %@", ids)
        let matches = try context.fetch(fetch)
        for entity in matches {
            entity.folder = folderPath
        }
        try context.save()
        try loadItems()
    }
    
    func renameItem(id: UUID, newName: String) throws {
        let fetch = NSFetchRequest<VaultEntity>(entityName: "VaultEntity")
        fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let matches = try context.fetch(fetch)
        guard let entity = matches.first else { return }
        entity.originalName = newName
        try context.save()
        try loadItems()
        objectWillChange.send()
    }

    func togglePin(id: UUID) {
        let wasPinned = pinnedIDs.contains(id)
        if wasPinned {
            pinnedIDs.remove(id)
        } else {
            pinnedIDs.insert(id)
        }
        savePinned()
        
        // Learn from pinning behavior
        if let item = items.first(where: { $0.id == id }) {
            Task { @MainActor in
                AILearningManager.shared.learnFromPin(item: item, isPinned: !wasPinned)
            }
        }
        
        objectWillChange.send()
    }

    func decryptItemData(_ item: VaultItem) async throws -> Data {
        let masterKey = try await KeyManager.shared.getOrCreateMasterKey()
        let fileURL = try encryptedFileURL(fileName: item.fileName)
        let encrypted = try Data(contentsOf: fileURL)
        return try Crypto.decrypt(encrypted, using: masterKey)
    }

    func temporaryShareURL(forFolderPath path: String) async throws -> URL {
        return try await temporaryShareURL(forFolderPath: path, name: lastPathComponent(path))
    }

    func temporaryShareURL(forFolderPath path: String, name: String) async throws -> URL {
        let matching = items.filter { ($0.folder ?? "").hasPrefix(path) }
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folderURL = tempRoot.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let allFolders = storedFolderPaths().filter { $0 == path || $0.hasPrefix(path + "/") }
        for folderPath in allFolders {
            let relative = folderPath == path ? "" : String(folderPath.dropFirst(path.count + 1))
            let destinationDir = relative.isEmpty ? folderURL : folderURL.appendingPathComponent(relative, isDirectory: true)
            if !FileManager.default.fileExists(atPath: destinationDir.path) {
                try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }
        }

        for item in matching {
            let data = try await decryptItemData(item)
            let relative = item.folder?.replacingOccurrences(of: path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
            let destinationDir = relative.isEmpty ? folderURL : folderURL.appendingPathComponent(relative, isDirectory: true)
            if !FileManager.default.fileExists(atPath: destinationDir.path) {
                try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            }
            let fileURL = destinationDir.appendingPathComponent(uniqueFileName(base: item.originalName, in: destinationDir))
            try data.write(to: fileURL, options: [.atomic])
        }
        return folderURL
    }

    func temporaryShareURL(for item: VaultItem) async throws -> URL {
        let data = try await decryptItemData(item)
        let ext = fileExtension(for: item)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ext)
        try data.write(to: url, options: [.atomic])
        return url
    }

    func findExactDuplicates() -> [[VaultItem]] {
        let grouped = Dictionary(grouping: items, by: { $0.sha256 })
        return grouped.values.filter { $0.count > 1 }
    }

    func recordOpened(id: UUID) {
        var map = recentMap()
        map[id.uuidString] = Date().timeIntervalSince1970
        UserDefaults.standard.set(map, forKey: recentsKey)
        
        // Track open count for AI suggestions
        let openCountKey = "openCount_\(id.uuidString)"
        let currentCount = UserDefaults.standard.integer(forKey: openCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: openCountKey)
        
        // Learn from user behavior
        if let item = items.first(where: { $0.id == id }) {
            Task { @MainActor in
                AILearningManager.shared.learnFromFileOpen(item: item, category: item.category)
            }
        }
        
        objectWillChange.send()
    }

    func recentOpenedItems(from source: [VaultItem]? = nil) -> [VaultItem] {
        let all = source ?? items
        let map = recentMap()
        let filtered = all.compactMap { item -> (VaultItem, TimeInterval)? in
            guard let ts = map[item.id.uuidString] else { return nil }
            return (item, ts)
        }
        return filtered
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    func deletePHAsset(localIdentifier: String, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    func totalAppStorageBytes() -> Int64 {
        let url = encryptedBaseURL()
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    func deviceStorage() -> (total: Int64, available: Int64) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return (0, 0)
        }
        let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let available = Int64(values?.volumeAvailableCapacity ?? 0)
        return (total, available)
    }

    func breakdownByType() -> [(label: String, size: Int64)] {
        let images = items.filter { $0.isImage }.reduce(0) { $0 + $1.size }
        let videos = items.filter { $0.isVideo }.reduce(0) { $0 + $1.size }
        let documents = items.filter { $0.isDocument }.reduce(0) { $0 + $1.size }
        let others = items.filter { !$0.isImage && !$0.isVideo && !$0.isDocument }.reduce(0) { $0 + $1.size }
        return [
            ("Images", images),
            ("Videos", videos),
            ("Documents", documents),
            ("Others", others)
        ]
    }

    func folderNodes() -> [FolderNode] {
        buildFolderTree()
    }

    func folderChildren(of path: String?) -> [FolderNode] {
        let roots = folderNodes()
        guard let path else { return roots }
        return findNode(path: path, in: roots)?.children ?? []
    }

    func items(in path: String?) -> [VaultItem] {
        guard let path else { return items.filter { $0.folder == nil || $0.folder?.isEmpty == true } }
        return items.filter { $0.folder == path }
    }

    func deleteFolder(path: String) {
        do {
            let fetch = NSFetchRequest<VaultEntity>(entityName: "VaultEntity")
            fetch.predicate = NSPredicate(format: "folder BEGINSWITH %@", path)
            let matches = try context.fetch(fetch)
            for entity in matches {
                if let fileName = entity.fileName {
                    let url = try? encryptedFileURL(fileName: fileName)
                    if let url = url { try? FileManager.default.removeItem(at: url) }
                }
                context.delete(entity)
            }
            try context.save()
            try loadItems()
        } catch {
            print("Delete folder failed: \(error)")
        }

        var paths = storedFolderPaths()
        paths.removeAll { $0 == path || $0.hasPrefix(path + "/") }
        UserDefaults.standard.set(paths, forKey: folderKey)
        objectWillChange.send()
    }

    func createFolder(path: String) {
        var paths = storedFolderPaths()
        guard !paths.contains(path) else { return }
        paths.append(path)
        UserDefaults.standard.set(paths, forKey: folderKey)
        objectWillChange.send()
    }

    func moveFolder(from sourcePath: String, to parentPath: String?) throws {
        let newPath = parentPath.map { "\($0)/\(lastPathComponent(sourcePath))" } ?? lastPathComponent(sourcePath)
        guard newPath != sourcePath else { return }

        let fetch = NSFetchRequest<VaultEntity>(entityName: "VaultEntity")
        fetch.predicate = NSPredicate(format: "folder BEGINSWITH %@", sourcePath)
        let matches = try context.fetch(fetch)
        for entity in matches {
            if let folder = entity.folder {
                let suffix = folder.dropFirst(sourcePath.count)
                let updated = newPath + suffix
                entity.folder = updated
            }
        }
        try context.save()

        let paths = storedFolderPaths()
        let updatedPaths = paths.map { path -> String in
            if path == sourcePath { return newPath }
            if path.hasPrefix(sourcePath + "/") {
                return newPath + path.dropFirst(sourcePath.count)
            }
            return path
        }
        UserDefaults.standard.set(Array(Set(updatedPaths)), forKey: folderKey)
        try loadItems()
    }

    func wipeAllData() {
        let fetch = NSFetchRequest<VaultEntity>(entityName: "VaultEntity")
        do {
            let matches = try context.fetch(fetch)
            for entity in matches {
                if let fileName = entity.fileName {
                    let url = try? encryptedFileURL(fileName: fileName)
                    if let url = url { try? FileManager.default.removeItem(at: url) }
                }
                context.delete(entity)
            }
            try context.save()
        } catch {
            print("Wipe failed: \(error)")
        }

        let base = encryptedBaseURL()
        try? FileManager.default.removeItem(at: base)

        UserDefaults.standard.removeObject(forKey: folderKey)
        UserDefaults.standard.removeObject(forKey: pinnedKey)
        UserDefaults.standard.removeObject(forKey: "didMigrateLegacyMetadata")
        pinnedIDs.removeAll()
        items.removeAll()
        KeyManager.shared.resetAllSecrets()
        objectWillChange.send()
    }

    private func loadItems() throws {
        let fetch = NSFetchRequest<VaultEntity>(entityName: "VaultEntity")
        fetch.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let results = try context.fetch(fetch)
        items = results.compactMap { entity in
            guard
                let id = entity.id,
                let originalName = entity.originalName,
                let mimeType = entity.mimeType,
                let createdAt = entity.createdAt,
                let fileName = entity.fileName,
                let sha256 = entity.sha256
            else { return nil }
            return VaultItem(
                id: id,
                originalName: originalName,
                mimeType: mimeType,
                size: entity.size,
                createdAt: createdAt,
                fileName: fileName,
                category: entity.category,
                folder: entity.folder,
                sha256: sha256,
                isImage: entity.isImage
            )
        }
    }

    private func encryptedBaseURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SilentStore", isDirectory: true)
            .appendingPathComponent("EncryptedFiles", isDirectory: true)
    }

    private func encryptedFileURL(fileName: String) throws -> URL {
        let base = encryptedBaseURL()
        if !FileManager.default.fileExists(atPath: base.path) {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base.appendingPathComponent(fileName)
    }

    private func applyFileProtection(url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }

    private func migrateLegacyIfNeeded() throws {
        let legacyURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SilentStore", isDirectory: true)
            .appendingPathComponent("metadata.json")
        guard let legacyURL, FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        let migratedFlag = UserDefaults.standard.bool(forKey: "didMigrateLegacyMetadata")
        guard !migratedFlag else { return }
        UserDefaults.standard.set(true, forKey: "didMigrateLegacyMetadata")
    }

    private func buildFolderTree() -> [FolderNode] {
        let allPaths = Set(items.compactMap { $0.folder }.filter { !$0.isEmpty })
            .union(storedFolderPaths())
        var roots: [FolderNode] = []
        for path in allPaths.sorted() {
            let components = path.split(separator: "/").map(String.init)
            insertFolder(components: components, currentPath: "", nodes: &roots)
        }
        return roots.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func insertFolder(components: [String], currentPath: String, nodes: inout [FolderNode]) {
        guard let first = components.first else { return }
        let path = currentPath.isEmpty ? first : "\(currentPath)/\(first)"
        let itemsHere = itemsForPath(path)

        if let index = nodes.firstIndex(where: { $0.path == path }) {
            nodes[index] = FolderNode(
                name: nodes[index].name,
                path: nodes[index].path,
                items: itemsHere,
                children: nodes[index].children
            )
            if components.count > 1 {
                var children = nodes[index].children
                insertFolder(components: Array(components.dropFirst()), currentPath: path, nodes: &children)
                nodes[index].children = children
            }
        } else {
            var node = FolderNode(name: first, path: path, items: itemsHere, children: [])
            if components.count > 1 {
                insertFolder(components: Array(components.dropFirst()), currentPath: path, nodes: &node.children)
            }
            nodes.append(node)
        }
    }

    private func itemsForPath(_ path: String) -> [VaultItem] {
        items.filter { $0.folder == path }
    }

    private func findNode(path: String, in nodes: [FolderNode]) -> FolderNode? {
        for node in nodes {
            if node.path == path { return node }
            if let found = findNode(path: path, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func storedFolderPaths() -> [String] {
        UserDefaults.standard.stringArray(forKey: folderKey) ?? []
    }

    private func recentMap() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: recentsKey) as? [String: TimeInterval] ?? [:]
    }

    private func lastPathComponent(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    private func fileExtension(for item: VaultItem) -> String {
        if item.mimeType.contains("png") { return ".png" }
        if item.mimeType.contains("jpeg") || item.mimeType.contains("jpg") { return ".jpg" }
        if item.mimeType.contains("pdf") { return ".pdf" }
        if item.isVideo { return ".mp4" }
        if let ext = item.originalName.split(separator: ".").last {
            return "." + ext
        }
        return ".dat"
    }

    private func uniqueFileName(base: String, in directory: URL) -> String {
        let sanitized = base.isEmpty ? "file" : base
        let url = directory.appendingPathComponent(sanitized)
        if !FileManager.default.fileExists(atPath: url.path) {
            return sanitized
        }
        let ext = (sanitized as NSString).pathExtension
        let name = (sanitized as NSString).deletingPathExtension
        let unique = "\(name)-\(UUID().uuidString.prefix(6))"
        return ext.isEmpty ? unique : "\(unique).\(ext)"
    }

    private func loadPinned() {
        let ids = UserDefaults.standard.stringArray(forKey: pinnedKey) ?? []
        pinnedIDs = Set(ids.compactMap(UUID.init))
    }

    private func savePinned() {
        let ids = pinnedIDs.map { $0.uuidString }
        UserDefaults.standard.set(ids, forKey: pinnedKey)
    }
}
