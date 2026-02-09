import SwiftUI
import AVKit
import QuickLook

struct FileViewer: View {
    let item: VaultItem
    @EnvironmentObject private var vaultStore: VaultStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    @State private var data: Data?
    @State private var mediaItems: [VaultItem] = []
    @State private var selectedMediaID: UUID?
    @State private var showChrome = true
    @State private var showInfo = false
    @State private var showDeleteAlert = false
    @State private var shareItem: ShareItem?
    @State private var tempShareURL: URL?
    @State private var archiveURL: URL?
    
    // Video player state
    @State private var currentPlayer: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isScrubbing = false
    @State private var timeObserver: Any?
    @State private var observerPlayer: AVPlayer?
    @State private var endObserver: NSObjectProtocol?
    @State private var chromeTimer: Task<Void, Never>?
    @State private var wasPlayingBeforeScrub = false
    
    private var isMediaItem: Bool {
        item.isImage || item.isVideo
    }
    
    private var currentItem: VaultItem {
        if let selectedMediaID,
           let found = mediaItems.first(where: { $0.id == selectedMediaID }) {
            return found
        }
        return item
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isMediaItem {
                mediaBrowserView
            } else if let data = data {
                contentView(for: data)
            } else {
                errorView
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
                        Task { await prepareShare() }
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
        .task(id: item.id) {
            await loadData()
            let key = "recentsOpened_\(item.id.uuidString)"
            UserDefaults.standard.set(true, forKey: key)
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: selectedMediaID) { _, newID in
            switchMedia(to: newID)
        }
        .onChange(of: currentPlayer) { _, newPlayer in
            setupTimeObserver(for: newPlayer)
            setupEndObserver(for: newPlayer)
        }
    }
    
    // MARK: - Media Browser View
    
    private var mediaBrowserView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if mediaItems.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else {
                    TabView(selection: $selectedMediaID) {
                        ForEach(mediaItems) { media in
                            MediaItemView(
                                item: media,
                                geometry: geometry,
                                onPlayerReady: { player in
                                    if media.id == selectedMediaID {
                                        currentPlayer = player
                                        if let player {
                                            isPlaying = player.timeControlStatus == .playing
                                        }
                                    }
                                },
                                isPlaying: $isPlaying,
                                showChrome: $showChrome
                            )
                            .tag(media.id as UUID?)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .disabled(true)
                    
                    // Navigation buttons
                    if mediaItems.count > 1 {
                        HStack {
                            Button {
                                navigatePrevious()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 20)
                            
                            Spacer()
                            
                            Button {
                                navigateNext()
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 20)
                        }
                        .allowsHitTesting(showChrome)
                        .opacity(showChrome ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: showChrome)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleChrome()
            }
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
    }
    
    // MARK: - Content View
    
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
            archiveInfoView
        } else {
            documentPreviewView
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.colors.error)
            Text("Unable to load file")
                .font(AppTheme.fonts.body)
                .foregroundStyle(AppTheme.colors.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentPreviewView: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var archiveInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Archive")
                .font(AppTheme.fonts.title)
            Text("\(currentItem.originalName)")
                .font(AppTheme.fonts.body)
                .foregroundStyle(AppTheme.colors.secondaryText)
            Text("\(ByteCountFormatter.string(fromByteCount: currentItem.size, countStyle: .file))")
                .font(AppTheme.fonts.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Media Top Bar
    
    private var mediaTopBar: some View {
        HStack {
            Button {
                HapticFeedback.play(.light)
                pauseCurrentVideo()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if mediaItems.count > 1 {
                Text("\(currentIndex + 1) / \(mediaItems.count)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color.black.opacity(0.5), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Media Bottom Bar
    
    private var mediaBottomBar: some View {
        VStack(spacing: 0) {
            if currentItem.isVideo {
                videoControls
            }
            
            HStack(spacing: 24) {
                // Play/Pause
                if currentItem.isVideo {
                    Button {
                        HapticFeedback.play(.light)
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(InteractiveButtonStyle(hapticStyle: .light))
                }
                
                // Share
                Button {
                    HapticFeedback.play(.light)
                    Task { await prepareShare() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                .buttonStyle(InteractiveButtonStyle(hapticStyle: .light))
                
                // Delete
                Button(role: .destructive) {
                    HapticFeedback.play(.warning)
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.red.opacity(0.15)))
                }
                .buttonStyle(InteractiveButtonStyle(hapticStyle: .warning))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.5), Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var videoControls: some View {
        VStack(spacing: 12) {
            // Time labels
            HStack {
                Text(timeString(currentTime))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(timeString(duration))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            
            // Progress bar with skip buttons
            HStack(spacing: 12) {
                Button {
                    HapticFeedback.play(.light)
                    skipBackward(seconds: 5)
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(AppTheme.colors.accent)
                            .frame(width: geometry.size.width * (duration > 0 ? currentTime / duration : 0), height: 4)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isScrubbing {
                                    isScrubbing = true
                                    wasPlayingBeforeScrub = isPlaying
                                    pauseCurrentVideo()
                                }
                                let progress = max(0, min(1, value.location.x / geometry.size.width))
                                currentTime = progress * duration
                            }
                            .onEnded { _ in
                                seekToCurrentTime()
                                isScrubbing = false
                                if wasPlayingBeforeScrub {
                                    playCurrentVideo()
                                }
                            }
                    )
                }
                .frame(height: 44)
                
                Button {
                    HapticFeedback.play(.light)
                    skipForward(seconds: 5)
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            vaultStore.recordOpened(id: item.id)
            
            if item.isImage || item.isVideo {
                let itemFolder = item.folder ?? ""
                await MainActor.run {
                    let sameFolder: [VaultItem] = vaultStore.items
                        .filter { ($0.isImage || $0.isVideo) && ($0.folder ?? "") == itemFolder }
                        .sorted { $0.createdAt > $1.createdAt }
                    mediaItems = sameFolder.isEmpty ? [item] : sameFolder
                    selectedMediaID = item.id
                }
            } else {
                // Load document data
                let decrypted = try await vaultStore.decryptItemData(item)
                await MainActor.run {
                    data = decrypted
                    if isArchive {
                        do {
                            archiveURL = try writeTempArchive(data: decrypted)
                        } catch {
                            print("Failed to write archive: \(error)")
                        }
                    }
                }
            }
        } catch {
            print("Failed to load data: \(error)")
            await MainActor.run {
                data = nil
            }
        }
    }
    
    // MARK: - Media Navigation
    
    private var currentIndex: Int {
        guard let selectedMediaID,
              let index = mediaItems.firstIndex(where: { $0.id == selectedMediaID }) else {
            return 0
        }
        return index
    }
    
    private func navigatePrevious() {
        guard !mediaItems.isEmpty else { return }
        let previousIdx = currentIndex > 0 ? currentIndex - 1 : mediaItems.count - 1
        HapticFeedback.play(.light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedMediaID = mediaItems[previousIdx].id
        }
    }
    
    private func navigateNext() {
        guard !mediaItems.isEmpty else { return }
        let nextIdx = currentIndex < mediaItems.count - 1 ? currentIndex + 1 : 0
        HapticFeedback.play(.light)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedMediaID = mediaItems[nextIdx].id
        }
    }
    
    private func switchMedia(to newID: UUID?) {
        pauseCurrentVideo()
        currentPlayer?.pause()
        currentPlayer = nil
        removeTimeObserver()
        removeEndObserver()
        currentTime = 0
        duration = 0
        isPlaying = false
    }
    
    // MARK: - Chrome Controls
    
    private func toggleChrome() {
        cancelChromeTimer()
        withAnimation(.easeInOut(duration: 0.25)) {
            showChrome.toggle()
        }
        if showChrome {
            startChromeTimer()
        }
    }
    
    private func startChromeTimer() {
        chromeTimer?.cancel()
        chromeTimer = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showChrome = false
                    }
                }
            }
        }
    }
    
    private func cancelChromeTimer() {
        chromeTimer?.cancel()
        chromeTimer = nil
    }
    
    // MARK: - Video Playback
    
    private func togglePlayback() {
        guard let player = currentPlayer else { return }
        if isPlaying {
            pauseCurrentVideo()
        } else {
            if currentTime >= duration - 0.1 {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                currentTime = 0
            }
            playCurrentVideo()
        }
    }
    
    private func playCurrentVideo() {
        currentPlayer?.play()
        isPlaying = true
    }
    
    private func pauseCurrentVideo() {
        currentPlayer?.pause()
        isPlaying = false
    }
    
    private func skipBackward(seconds: Double) {
        guard let player = currentPlayer else { return }
        let newTime = max(0, currentTime - seconds)
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = newTime
    }
    
    private func skipForward(seconds: Double) {
        guard let player = currentPlayer else { return }
        let newTime = min(duration, currentTime + seconds)
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = newTime
    }
    
    private func seekToCurrentTime() {
        guard let player = currentPlayer else { return }
        let time = CMTime(seconds: currentTime, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: - Time Observer
    
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
        ) { [weak player] _ in
            guard let player = player else { return }
            Task { @MainActor in
                isPlaying = false
                currentTime = duration
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                currentTime = 0
            }
        }
    }
    
    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }
    
    // MARK: - Share
    
    private func prepareShare() async {
        do {
            let url = try await vaultStore.temporaryShareURL(for: currentItem)
            tempShareURL = url
            shareItem = ShareItem(url: url)
        } catch {
            print("Failed to prepare share: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func writeTempArchive(data: Data) throws -> URL {
        let ext = currentItem.originalName.split(separator: ".").last.map(String.init) ?? "zip"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".\(ext)")
        try data.write(to: url, options: [.atomic])
        return url
    }
    
    private var isArchive: Bool {
        let lower = currentItem.mimeType.lowercased()
        if lower.contains("zip") || lower.contains("rar") { return true }
        let ext = currentItem.originalName.split(separator: ".").last?.lowercased() ?? ""
        return ["zip", "rar", "7z"].contains(ext)
    }
    
    private func cleanup() {
        pauseCurrentVideo()
        removeTimeObserver()
        removeEndObserver()
        currentPlayer = nil
        cancelChromeTimer()
    }
}

// MARK: - Media Item View

private struct MediaItemView: View {
    let item: VaultItem
    let geometry: GeometryProxy
    let onPlayerReady: (AVPlayer?) -> Void
    @Binding var isPlaying: Bool
    @Binding var showChrome: Bool
    @EnvironmentObject private var vaultStore: VaultStore
    
    @State private var data: Data?
    @State private var player: AVPlayer?
    @State private var tempVideoURL: URL?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.3)
                    Text("Loading...")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if item.isImage, let data = data, let image = UIImage(data: data) {
                ZoomableImageView(image: image)
                    .ignoresSafeArea(.container, edges: .all)
            } else if item.isVideo, let player = player {
                AVPlayerViewControllerRepresentable(player: player)
                    .ignoresSafeArea(.container, edges: .all)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Preview not available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .task(id: item.id) {
            await loadMedia()
        }
        .onChange(of: isPlaying) { _, newValue in
            if item.isVideo {
                if newValue {
                    player?.play()
                } else {
                    player?.pause()
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            if let tempVideoURL {
                try? FileManager.default.removeItem(at: tempVideoURL)
            }
        }
    }
    
    private func loadMedia() async {
        isLoading = true
        data = nil
        player = nil
        
        do {
            let decrypted = try await vaultStore.decryptItemData(item)
            await MainActor.run {
                data = decrypted
                
                if item.isVideo {
                    do {
                        tempVideoURL = try writeTempVideo(data: decrypted)
                        if let tempVideoURL {
                            player = AVPlayer(url: tempVideoURL)
                            onPlayerReady(player)
                        } else {
                            onPlayerReady(nil)
                        }
                    } catch {
                        print("Failed to write temp video: \(error)")
                        onPlayerReady(nil)
                    }
                } else {
                    onPlayerReady(nil)
                }
                
                withAnimation(.easeIn(duration: 0.3)) {
                    isLoading = false
                }
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                data = nil
                onPlayerReady(nil)
                isLoading = false
            }
        }
    }
    
    private func writeTempVideo(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try data.write(to: url, options: [.atomic])
        return url
    }
}

// MARK: - AVPlayer View Controller Representable

private struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

// MARK: - Share Item

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}
