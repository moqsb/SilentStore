import Foundation

struct ImportResult {
    let data: Data
    let originalName: String
    let mimeType: String
    let isImage: Bool
    let assetIdentifier: String?
}
