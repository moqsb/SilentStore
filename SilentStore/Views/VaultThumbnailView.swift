import SwiftUI
import UIKit
import AVFoundation

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
            } else if isLoading {
                ProgressView()
                    .tint(AppTheme.colors.accent)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.32))
                    .foregroundStyle(AppTheme.colors.accent)
            }
            if item.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: size * 0.28, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        guard item.isImage || item.isVideo else { return }
        let cacheKey = "\(item.id.uuidString)-thumb" as NSString
        if let cached = Self.cache.object(forKey: cacheKey) {
            image = cached
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await vaultStore.decryptItemData(item)
            if item.isImage {
                if let uiImage = UIImage(data: data) {
                    Self.cache.setObject(uiImage, forKey: cacheKey)
                    image = uiImage
                }
            } else if item.isVideo {
                if let uiImage = await generateVideoThumbnail(from: data) {
                    Self.cache.setObject(uiImage, forKey: cacheKey)
                    image = uiImage
                }
            }
        } catch {
            image = nil
        }
    }

    private func generateVideoThumbnail(from data: Data) async -> UIImage? {
        await Task.detached {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")
            do {
                try data.write(to: tempURL, options: [.atomic])
                defer { try? FileManager.default.removeItem(at: tempURL) }
                let asset = AVAsset(url: tempURL)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                let maxSide = max(size * 2, 200)
                generator.maximumSize = CGSize(width: maxSide, height: maxSide)
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                return nil
            }
        }.value
    }
}
