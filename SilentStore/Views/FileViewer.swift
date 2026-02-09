import SwiftUI
import AVKit
import QuickLook

struct FileViewer: View {
    // Media and document preview screen.
    let item: VaultItem
    @EnvironmentObject private var vaultStore: VaultStore
    @State private var data: Data?
    @State private var tempShareURL: URL?
    @State private var archiveURL: URL?
    @State private var showInfo = false
    @State private var showDeleteAlert = false
    @State private var shareItem: ShareItem?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var mediaItems: [VaultItem] = []
    @State private var selectedMediaID: UUID?
    @State private var showChrome = true
    @State private var currentPlayer: AVPlayer?
    @State private var isPlaying = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isScrubbing = false
    @State private var timeObserver: Any?
    @State private var observerPlayer: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var wasPlayingBeforeScrub = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if isMediaItem {
                mediaBrowser
            } else if let data {
                contentView(for: data)
            } else {
                Text("Unable to load file.")
            }
        }
        .navigationTitle(currentItem.originalName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(isMediaItem ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            if !isMediaItem {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task { await prepareShare(for: currentItem) }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
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
        }
        .alert("Delete file?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                try? vaultStore.deleteItems(ids: [currentItem.id])
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showInfo) {
            FileInfoSheet(item: currentItem)
        }
        .sheet(item: $shareItem, onDismiss: {
            if let tempShareURL {
                try? FileManager.default.removeItem(at: tempShareURL)
                self.tempShareURL = nil
            }
        }) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            await loadData()
        }
        .onDisappear {
            if let tempShareURL {
                try? FileManager.default.removeItem(at: tempShareURL)
            }
            if let archiveURL {
                try? FileManager.default.removeItem(at: archiveURL)
                self.archiveURL = nil
            }
            removeTimeObserver()
            removeEndObserver()
        }
        .onChange(of: currentPlayer) { _, newPlayer in
            setupTimeObserver(for: newPlayer)
            setupEndObserver(for: newPlayer)
        }
        .onChange(of: selectedMediaID) { _, _ in
            currentPlayer?.pause()
            currentPlayer = nil
            removeTimeObserver()
            removeEndObserver()
            currentTime = 0
            duration = 0
            isPlaying = false
        }
    }

    @ViewBuilder
    private func contentView(for data: Data) -> some View {
        if currentItem.mimeType.hasPrefix("text/"), let text = String(data: data, encoding: .utf8) {
            ScrollView {
                Text(text)
                    .font(AppTheme.fonts.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        } else if isArchive {
            if let archiveURL {
                ArchivePreviewView(url: archiveURL)
            } else {
                archiveInfoView
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.colors.accent)
                Text("Preview not available")
                    .font(AppTheme.fonts.body)
                Text("\(currentItem.mimeType) • \(ByteCountFormatter.string(fromByteCount: currentItem.size, countStyle: .file))")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
        }
    }

    private func loadData() async {
        do {
            vaultStore.recordOpened(id: item.id)
            if item.isImage || item.isVideo {
                mediaItems = vaultStore.items
                    .filter { ($0.isImage || $0.isVideo) && $0.folder == item.folder }
                    .sorted { $0.createdAt > $1.createdAt }
                selectedMediaID = item.id
            } else {
                let decrypted = try await vaultStore.decryptItemData(item)
                data = decrypted
                if isArchive {
                    archiveURL = try writeTempArchive(data: decrypted)
                }
            }
        } catch {
            data = nil
        }
        isLoading = false
    }

    private func writeTempShare(data: Data, for item: VaultItem) throws -> URL {
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

    private func writeTempArchive(data: Data) throws -> URL {
        let ext = currentItem.originalName.split(separator: ".").last.map(String.init) ?? "zip"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".\(ext)")
        try data.write(to: url, options: [.atomic])
        return url
    }

    private var isMediaItem: Bool {
        item.isImage || item.isVideo
    }

    private var isArchive: Bool {
        let lower = currentItem.mimeType.lowercased()
        if lower.contains("zip") || lower.contains("rar") { return true }
        let ext = currentItem.originalName.split(separator: ".").last?.lowercased() ?? ""
        return ["zip", "rar", "7z"].contains(ext)
    }

    private var currentItem: VaultItem {
        if let selectedMediaID,
           let item = mediaItems.first(where: { $0.id == selectedMediaID }) {
            return item
        }
        return item
    }

    private var mediaBrowser: some View {
        ZStack {
            TabView(selection: $selectedMediaID) {
                ForEach(mediaItems) { media in
                    MediaPageView(
                        item: media,
                        onPlayerReady: { player in
                            currentPlayer = player
                            if let player {
                                isPlaying = player.timeControlStatus == .playing
                            } else {
                                isPlaying = false
                            }
                        },
                        isPlaying: $isPlaying,
                        showChrome: $showChrome
                    ) {
                        toggleChrome()
                    }
                    .tag(media.id as UUID?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth(duration: 0.3), value: selectedMediaID)
            .background(Color.black)
        }
        .offset(y: dragOffset)
        .scaleEffect(max(0.96, 1 - (dragOffset / 1200)))
        .opacity(max(0.6, 1 - (dragOffset / 800)))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    // Smooth drag from anywhere - prioritize vertical movement
                    let verticalMovement = abs(value.translation.height)
                    let horizontalMovement = abs(value.translation.width)
                    
                    // Allow smooth vertical drags from anywhere
                    if value.translation.height > 0 {
                        // If vertical movement is significant or dominant
                        if verticalMovement > 20 || verticalMovement > horizontalMovement * 1.2 {
                            dragOffset = value.translation.height
                        }
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 80
                    let verticalMovement = abs(value.translation.height)
                    let horizontalMovement = abs(value.translation.width)
                    let velocity = value.predictedEndTranslation.height - value.translation.height
                    
                    // Dismiss if dragged down significantly or with high velocity
                    if (value.translation.height > threshold && verticalMovement > horizontalMovement) || velocity > 500 {
                        let screenHeight = UIScreen.main.bounds.height
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = screenHeight
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            dismiss()
                        }
                    } else {
                        // Smooth spring back
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .safeAreaInset(edge: .top) {
            if showChrome {
                mediaTopBar
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showChrome {
                mediaBottomBar
            }
        }
    }

    private var mediaTopBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(currentItem.originalName)
                    .font(AppTheme.fonts.body)
                    .lineLimit(1)
                Text(formattedDate)
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                showInfo = true
            } label: {
                Image(systemName: "ellipsis")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var mediaBottomBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    HapticFeedback.play(.light)
                    Task { await prepareShare(for: currentItem) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(InteractiveButtonStyle(hapticStyle: .light))
                Spacer()
                Spacer()
                Button(role: .destructive) {
                    HapticFeedback.play(.warning)
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(InteractiveButtonStyle(hapticStyle: .warning))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 30)
            .padding(.top, 8)
            if currentItem.isVideo {
                videoScrubber
                    .padding(.bottom, 4)
            }

            mediaThumbStrip
        }
        .background(.ultraThinMaterial)
    }

    private var currentIndex: Int {
        guard let selectedMediaID,
              let index = mediaItems.firstIndex(where: { $0.id == selectedMediaID }) else {
            return 0
        }
        return index
    }

    private var mediaThumbStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mediaItems) { media in
                    Button {
                        selectedMediaID = media.id
                    } label: {
                        VaultThumbnailView(item: media, size: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected(media) ? AppTheme.colors.accent : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    private func isSelected(_ media: VaultItem) -> Bool {
        media.id == selectedMediaID
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showChrome.toggle()
        }
        // Ensure time observer continues working after chrome toggle
        if showChrome, let player = currentPlayer {
            setupTimeObserver(for: player)
        }
    }

    private func togglePlayback() {
        guard let player = currentPlayer else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            if duration > 0, currentTime >= max(duration - 0.2, 0) {
                player.seek(to: .zero)
                currentTime = 0
            }
            player.play()
            isPlaying = true
        }
    }

    private var videoScrubber: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Skip backward 5 seconds
                Button {
                    HapticFeedback.play(.light)
                    skipBackward(seconds: 5)
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.2))
                        )
                }
                .buttonStyle(InteractiveButtonStyle(hapticStyle: .light))
                
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { currentTime = $0 }
                    ),
                    in: 0...max(duration, 0.1),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if editing {
                            wasPlayingBeforeScrub = isPlaying
                            currentPlayer?.pause()
                            isPlaying = false
                        } else {
                            seekToCurrentTime()
                            if wasPlayingBeforeScrub {
                                currentPlayer?.play()
                                isPlaying = true
                            }
                        }
                    }
                )
                .tint(.white)
                
                // Skip forward 5 seconds
                Button {
                    HapticFeedback.play(.light)
                    skipForward(seconds: 5)
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.2))
                        )
                }
                .buttonStyle(InteractiveButtonStyle(hapticStyle: .light))
            }
            HStack {
                Text(timeString(currentTime))
                Spacer()
                Text(timeString(duration))
            }
            .font(AppTheme.fonts.caption)
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
    }
    
    private func skipBackward(seconds: Double) {
        guard let player = currentPlayer else { return }
        let newTime = max(0, currentTime - seconds)
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time)
        currentTime = newTime
    }
    
    private func skipForward(seconds: Double) {
        guard let player = currentPlayer else { return }
        let newTime = min(duration, currentTime + seconds)
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time)
        currentTime = newTime
    }

    private func seekToCurrentTime() {
        guard let player = currentPlayer else { return }
        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        player.seek(to: time)
    }

    private func setupTimeObserver(for player: AVPlayer?) {
        removeTimeObserver()
        guard let player else {
            currentTime = 0
            duration = 0
            return
        }
        observerPlayer = player
        let assetDuration = player.currentItem?.duration ?? .zero
        let total = CMTimeGetSeconds(assetDuration)
        duration = total.isFinite ? total : 0
        
        // Always update time observer regardless of showChrome state
        let isScrubbingRef = isScrubbing
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { time in
            guard !isScrubbingRef else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                Task { @MainActor in
                    currentTime = seconds
                    if let player = observerPlayer {
                        let candidate = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
                        if candidate.isFinite && candidate > 0 {
                            duration = candidate
                        }
                        isPlaying = player.timeControlStatus == .playing
                    }
                }
            }
        }
    }

    private func removeTimeObserver() {
        if let timeObserver, let player = observerPlayer {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        observerPlayer = nil
    }

    private func setupEndObserver(for player: AVPlayer?) {
        removeEndObserver()
        guard let player, let item = player.currentItem else { return }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            isPlaying = false
            currentTime = duration
        }
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "--:--" }
        let int = Int(seconds)
        let m = int / 60
        let s = int % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var archiveInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(AppTheme.colors.accent)
                Text(NSLocalizedString("Archive", comment: ""))
                    .font(AppTheme.fonts.subtitle)
            }
            Text(currentItem.originalName)
                .font(AppTheme.fonts.body)
            Text(ByteCountFormatter.string(fromByteCount: currentItem.size, countStyle: .file))
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
            Text(NSLocalizedString("Archive preview is not available. Use Share to open in Files.", comment: ""))
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: currentItem.createdAt)
    }


    private func prepareShare(for item: VaultItem) async {
        do {
            let decrypted = try await vaultStore.decryptItemData(item)
            let url = try writeTempShare(data: decrypted, for: item)
            tempShareURL = url
            shareItem = ShareItem(url: url)
        } catch {
            shareItem = nil
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct MediaPageView: View {
    let item: VaultItem
    let onPlayerReady: (AVPlayer?) -> Void
    @Binding var isPlaying: Bool
    @Binding var showChrome: Bool
    let onTap: () -> Void
    @EnvironmentObject private var vaultStore: VaultStore
    @State private var data: Data?
    @State private var player: AVPlayer?
    @State private var tempVideoURL: URL?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if item.isImage, let data, let image = UIImage(data: data) {
                ZoomableImageView(image: image)
                    .ignoresSafeArea(.container, edges: .bottom)
            } else if item.isVideo, let player {
                ZoomableVideoPlayer(player: player)
                    .ignoresSafeArea(.container, edges: .bottom)
            } else {
                Text("Preview not available")
                    .foregroundStyle(.white)
            }
            if item.isVideo && showChrome {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 68, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task(id: item.id) {
            await loadMedia()
        }
        .onDisappear {
            if let tempVideoURL {
                try? FileManager.default.removeItem(at: tempVideoURL)
            }
            player?.pause()
            onPlayerReady(nil)
            isPlaying = false
        }
    }

    private func loadMedia() async {
        do {
            let decrypted = try await vaultStore.decryptItemData(item)
            data = decrypted
            if item.isVideo {
                tempVideoURL = try writeTempVideo(data: decrypted)
                if let tempVideoURL {
                    player = AVPlayer(url: tempVideoURL)
                    onPlayerReady(player)
                }
            } else {
                onPlayerReady(nil)
            }
        } catch {
            data = nil
            onPlayerReady(nil)
        }
        isLoading = false
    }

    private func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func writeTempVideo(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try data.write(to: url, options: [.atomic])
        return url
    }
}

private struct ZoomableVideoPlayer: View {
    let player: AVPlayer
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        PlayerLayerView(player: player)
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

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct ArchivePreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
