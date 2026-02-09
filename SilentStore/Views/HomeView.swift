import SwiftUI

struct HomeView: View {
    @ObservedObject var vaultStore: VaultStore
    @Binding var selectedTab: Int
    @Binding var filesInitialFilter: VaultStore.FilterOption?
    @State private var selectedRecentsFilter: RecentsFilter = .all
    @Environment(\.layoutDirection) private var layoutDirection
    
    enum RecentsFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This Week"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                statisticsCardsSection
                recentsStoriesSection
                mostOpenedSection
                lastOpenedSection
            }
        }
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("Home", comment: ""))
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(totalFilesCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.colors.primaryText)
                    
                    Text(NSLocalizedString("Total Files", comment: ""))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(ByteCountFormatter.string(fromByteCount: totalStorageSize, countStyle: .file))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.primaryText)
                    
                    Text(NSLocalizedString("Storage Used", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Statistics Cards Section
    
    private var statisticsCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("Overview", comment: ""))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.colors.primaryText)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                StatCard(
                    icon: "photo.fill",
                    title: NSLocalizedString("Images", comment: ""),
                    count: imagesCount,
                    size: imagesSize,
                    color: .blue,
                    filter: .images,
                    onTap: { filesInitialFilter = .images; selectedTab = 1 }
                )
                StatCard(
                    icon: "video.fill",
                    title: NSLocalizedString("Videos", comment: ""),
                    count: videosCount,
                    size: videosSize,
                    color: .red,
                    filter: .videos,
                    onTap: { filesInitialFilter = .videos; selectedTab = 1 }
                )
                StatCard(
                    icon: "doc.fill",
                    title: NSLocalizedString("Documents", comment: ""),
                    count: documentsCount,
                    size: documentsSize,
                    color: .orange,
                    filter: .documents,
                    onTap: { filesInitialFilter = .documents; selectedTab = 1 }
                )
                StatCard(
                    icon: "folder.fill",
                    title: NSLocalizedString("Others", comment: ""),
                    count: othersCount,
                    size: othersSize,
                    color: .purple,
                    filter: .others,
                    onTap: { filesInitialFilter = .others; selectedTab = 1 }
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Recents Stories Section
    
    private var recentsStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.accent)
                
                Text(NSLocalizedString("Recents", comment: ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RecentsFilter.allCases, id: \.id) { filter in
                        FilterChip(
                            title: NSLocalizedString(filter.rawValue, comment: ""),
                            isSelected: selectedRecentsFilter == filter
                        ) {
                            HapticFeedback.play(.selection)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedRecentsFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)
            let recentItems = getRecentItems()
            if recentItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.4))
                        Text(NSLocalizedString("No recent items", comment: ""))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(recentItems.prefix(20)) { item in
                            NavigationLink {
                                FileViewer(item: item)
                                    .environmentObject(vaultStore)
                                    .onAppear {
                                        // Mark as opened permanently
                                        let key = "recentsOpened_\(item.id.uuidString)"
                                        UserDefaults.standard.set(true, forKey: key)
                                    }
                            } label: {
                                StoryCircleView(item: item)
                                    .environmentObject(vaultStore)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .environment(\.layoutDirection, layoutDirection)
                }
            }
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Most Opened Section
    
    private var mostOpenedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.accent)
                
                Text(NSLocalizedString("Most Opened", comment: ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            let mostOpened = getMostOpenedFiles()
            if mostOpened.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.4))
                        Text(NSLocalizedString("No opened files yet", comment: ""))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(mostOpened.prefix(5).enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            FileViewer(item: item)
                                .environmentObject(vaultStore)
                        } label: {
                            MostOpenedRow(
                                item: item,
                                rank: index + 1,
                                openCount: getOpenCount(for: item.id)
                            )
                            .environmentObject(vaultStore)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Last Opened Section
    
    private var lastOpenedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.accent)
                
                Text(NSLocalizedString("Last Opened", comment: ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            if let lastOpened = getLastOpenedFile() {
                NavigationLink {
                    FileViewer(item: lastOpened)
                        .environmentObject(vaultStore)
                } label: {
                    LastOpenedCard(item: lastOpened)
                        .environmentObject(vaultStore)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.4))
                        Text(NSLocalizedString("No files opened yet", comment: ""))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, 40)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Computed Properties
    
    private var totalFilesCount: Int {
        vaultStore.items.count
    }
    
    private var totalStorageSize: Int64 {
        vaultStore.items.reduce(0) { $0 + $1.size }
    }
    
    private var imagesCount: Int {
        vaultStore.items.filter { $0.isImage }.count
    }
    
    private var imagesSize: Int64 {
        vaultStore.items.filter { $0.isImage }.reduce(0) { $0 + $1.size }
    }
    
    private var videosCount: Int {
        vaultStore.items.filter { $0.isVideo }.count
    }
    
    private var videosSize: Int64 {
        vaultStore.items.filter { $0.isVideo }.reduce(0) { $0 + $1.size }
    }
    
    private var documentsCount: Int {
        vaultStore.items.filter { $0.isDocument }.count
    }
    
    private var documentsSize: Int64 {
        vaultStore.items.filter { $0.isDocument }.reduce(0) { $0 + $1.size }
    }
    
    private var othersCount: Int {
        vaultStore.items.filter { !$0.isImage && !$0.isVideo && !$0.isDocument }.count
    }
    
    private var othersSize: Int64 {
        vaultStore.items.filter { !$0.isImage && !$0.isVideo && !$0.isDocument }.reduce(0) { $0 + $1.size }
    }
    
    // MARK: - Helper Functions
    
    private func getRecentItems() -> [VaultItem] {
        var items = vaultStore.recentOpenedItems()
        
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedRecentsFilter {
        case .all:
            break
        case .today:
            items = items.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
        case .week:
            items = items.filter {
                let days = calendar.dateComponents([.day], from: $0.createdAt, to: now).day ?? 0
                return days <= 7
            }
        }
        
        return items
    }
    
    private func getMostOpenedFiles() -> [VaultItem] {
        let openCounts = vaultStore.items.compactMap { item -> (VaultItem, Int)? in
            let count = getOpenCount(for: item.id)
            guard count > 0 else { return nil }
            return (item, count)
        }
        
        return openCounts
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    private func getOpenCount(for id: UUID) -> Int {
        let key = "openCount_\(id.uuidString)"
        return UserDefaults.standard.integer(forKey: key)
    }
    
    private func getLastOpenedFile() -> VaultItem? {
        vaultStore.recentOpenedItems().first
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let title: String
    let count: Int
    let size: Int64
    let color: Color
    var filter: VaultStore.FilterOption?
    var onTap: (() -> Void)?

    var body: some View {
        let card = VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.colors.primaryText)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.colors.secondaryText)
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                )
        )

        if let onTap {
            Button(action: {
                HapticFeedback.play(.light)
                onTap()
            }) { card }
            .buttonStyle(.plain)
        } else {
            card
        }
    }
}

// MARK: - Most Opened Row

private struct MostOpenedRow: View {
    let item: VaultItem
    let rank: Int
    let openCount: Int
    @EnvironmentObject private var vaultStore: VaultStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(AppTheme.colors.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text("\(rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.colors.accent)
            }
            
            // Thumbnail
            VaultThumbnailView(item: item, size: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                    Text("\(openCount) \(NSLocalizedString("times", comment: ""))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Last Opened Card

private struct LastOpenedCard: View {
    let item: VaultItem
    @EnvironmentObject private var vaultStore: VaultStore
    
    var body: some View {
        HStack(spacing: 16) {
            // Large Thumbnail
            VaultThumbnailView(item: item, size: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(item.originalName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.primaryText)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label(
                        ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file),
                        systemImage: "doc"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.colors.secondaryText)
                    
                    if let category = item.category {
                        Label(category, systemImage: "tag")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Story Circle Component (Snapchat Style)

private struct StoryCircleView: View {
    let item: VaultItem
    @Environment(\.layoutDirection) var layoutDirection
    @EnvironmentObject private var vaultStore: VaultStore
    
    private var isOpened: Bool {
        let key = "recentsOpened_\(item.id.uuidString)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    var body: some View {
        ZStack {
            // Outer ring - Silver if opened, Blue if not
            Circle()
                .stroke(
                    isOpened ?
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.8),
                            Color.gray.opacity(0.5),
                            Color.gray.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [
                            AppTheme.colors.accent,
                            AppTheme.colors.accent.opacity(0.6),
                            AppTheme.colors.accent.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 84, height: 84)
            
            // Thumbnail - slightly larger to avoid clipping
            VaultThumbnailView(item: item, size: 74)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppTheme.colors.background, lineWidth: 2)
                )
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : AppTheme.colors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(AppTheme.gradients.accent)
                        } else {
                            Capsule()
                                .fill(AppTheme.colors.cardBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
