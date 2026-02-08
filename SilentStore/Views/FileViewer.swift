import SwiftUI
import AVKit

struct FileViewer: View {
    let item: VaultItem
    @EnvironmentObject private var vaultStore: VaultStore
    @State private var data: Data?
    @State private var tempVideoURL: URL?
    @State private var tempShareURL: URL?
    @State private var player: AVPlayer?
    @State private var showInfo = false
    @State private var showDeleteAlert = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let data {
                contentView(for: data)
            } else {
                Text("Unable to load file.")
            }
        }
        .navigationTitle(item.originalName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if tempShareURL != nil {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Delete file?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                try? vaultStore.deleteItems(ids: [item.id])
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showInfo) {
            FileInfoSheet(item: item)
        }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            if let tempShareURL {
                try? FileManager.default.removeItem(at: tempShareURL)
                self.tempShareURL = nil
            }
        }) {
            if let tempShareURL {
                ShareSheet(items: [tempShareURL])
            }
        }
        .task {
            await loadData()
        }
        .onDisappear {
            if let tempVideoURL {
                try? FileManager.default.removeItem(at: tempVideoURL)
            }
            if let tempShareURL {
                try? FileManager.default.removeItem(at: tempShareURL)
            }
        }
    }

    @ViewBuilder
    private func contentView(for data: Data) -> some View {
        if item.isImage, let image = UIImage(data: data) {
            ZoomableImageView(image: image)
        } else if item.isVideo, let player {
            ZoomableVideoPlayer(player: player)
                .onAppear { player.play() }
        } else if item.mimeType.hasPrefix("text/"), let text = String(data: data, encoding: .utf8) {
            ScrollView {
                Text(text)
                    .font(AppTheme.fonts.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.colors.accent)
                Text("Preview not available")
                    .font(AppTheme.fonts.body)
                Text("\(item.mimeType) • \(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
        }
    }

    private func loadData() async {
        do {
            let decrypted = try await vaultStore.decryptItemData(item)
            data = decrypted
            if item.isVideo {
                tempVideoURL = try writeTempVideo(data: decrypted)
                if let tempVideoURL {
                    player = AVPlayer(url: tempVideoURL)
                }
            }
            tempShareURL = try writeTempShare(data: decrypted)
        } catch {
            data = nil
        }
        isLoading = false
    }

    private func writeTempVideo(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func writeTempShare(data: Data) throws -> URL {
        let ext: String
        if item.mimeType.contains("png") {
            ext = "png"
        } else if item.mimeType.contains("jpeg") || item.mimeType.contains("jpg") {
            ext = "jpg"
        } else if item.mimeType.contains("pdf") {
            ext = "pdf"
        } else if item.isVideo {
            ext = "mp4"
        } else if let originalExt = item.originalName.split(separator: ".").last {
            ext = String(originalExt)
        } else {
            ext = "dat"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".\(ext)")
        try data.write(to: url, options: [.atomic])
        return url
    }
}

private struct ZoomableVideoPlayer: View {
    let player: AVPlayer
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        VideoPlayer(player: player)
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let updated = lastScale * value
                        scale = min(max(updated, 1), 3)
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}
