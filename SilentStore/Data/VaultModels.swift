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
        mimeType.lowercased().hasPrefix("text/") || mimeType.lowercased().contains("pdf")
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
