import SwiftUI
import UIKit

struct VaultThumbnailView: View {
    let item: VaultItem
    let size: CGFloat

    @EnvironmentObject private var vaultStore: VaultStore
    @State private var image: UIImage?
    @State private var isLoading = false

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if isLoading {
                ProgressView()
                    .tint(AppTheme.colors.accent)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.32))
                    .foregroundStyle(AppTheme.colors.accent)
            }
        }
        .frame(width: size, height: size)
        .task(id: item.id) {
            await loadThumbnailIfNeeded()
        }
    }

    private var fallbackIcon: String {
        if item.isImage { return "photo" }
        if item.isVideo { return "film" }
        if item.isDocument { return "doc.text" }
        return "doc"
    }

    private func loadThumbnailIfNeeded() async {
        guard item.isImage else { return }
        let cacheKey = item.id.uuidString as NSString
        if let cached = Self.cache.object(forKey: cacheKey) {
            image = cached
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await vaultStore.decryptItemData(item)
            if let uiImage = UIImage(data: data) {
                Self.cache.setObject(uiImage, forKey: cacheKey)
                image = uiImage
            }
        } catch {
            image = nil
        }
    }
}
