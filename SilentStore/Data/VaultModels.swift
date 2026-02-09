import Foundation

struct VaultItem: Identifiable, Hashable {
    let id: UUID
    let originalName: String
    let mimeType: String
    let size: Int64
    let createdAt: Date
    let fileName: String
    let category: String?
    let folder: String?
    let sha256: String
    let isImage: Bool

    var isVideo: Bool {
        mimeType.lowercased().hasPrefix("video/")
    }

    var isDocument: Bool {
        let lower = mimeType.lowercased()
        if lower.hasPrefix("text/") { return true }
        if lower.contains("pdf") { return true }
        if lower.hasPrefix("application/") {
            return lower.contains("msword")
                || lower.contains("officedocument")
                || lower.contains("vnd.")
                || lower.contains("rtf")
                || lower.contains("epub")
        }
        return false
    }
}

struct FolderNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let items: [VaultItem]
    var children: [FolderNode] = []

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }
}
