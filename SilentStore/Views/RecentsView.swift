import SwiftUI

struct RecentsView: View {
    @ObservedObject var vaultStore: VaultStore
    @State private var searchText = ""
    @State private var selectedFilter: FilterType = .all
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var isLoadingSuggestions = false
    @AppStorage("aiEnabled") private var aiEnabled = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    enum FilterType: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // AI Suggestions Section
                if aiEnabled && !aiSuggestions.isEmpty {
                    aiSuggestionsSection
                }
                
                // Filter Bar
                filterBar
                
                // Content
                if vaultStore.isLoading {
                    loadingGrid
                } else if filteredItems.isEmpty {
                    emptyState
                } else {
                    contentGrid
                }
            }
            .padding(.top, 8)
        }
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("Recents", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .task {
            await loadAISuggestions()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - AI Suggestions Section
    
    private var aiSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
                
                Text(NSLocalizedString("AI Suggestions", comment: ""))
                    .font(AppTheme.fonts.subtitle)
                    .foregroundStyle(AppTheme.colors.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(aiSuggestions) { suggestion in
                        AISuggestionCard(suggestion: suggestion, vaultStore: vaultStore)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterType.allCases, id: \.id) { filter in
                    FilterChip(
                        title: NSLocalizedString(filter.rawValue, comment: ""),
                        isSelected: selectedFilter == filter
                    ) {
                        HapticFeedback.play(.selection)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Content
    
    private var contentGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredItems) { item in
                NavigationLink {
                    FileViewer(item: item)
                        .environmentObject(vaultStore)
                } label: {
                    RecentCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Computed Properties
    
    private var filteredItems: [VaultItem] {
        var items = vaultStore.recentOpenedItems()
        
        // Apply time filter
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedFilter {
        case .all:
            break
        case .today:
            items = items.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
        case .week:
            items = items.filter {
                let days = calendar.dateComponents([.day], from: $0.createdAt, to: now).day ?? 0
                return days <= 7
            }
        case .month:
            items = items.filter {
                let days = calendar.dateComponents([.day], from: $0.createdAt, to: now).day ?? 0
                return days <= 30
            }
        }
        
        // Apply search
        if !searchText.isEmpty {
            if aiEnabled {
                items = AIManager.shared.smartSearch(query: searchText, in: items)
            } else {
                items = items.filter { $0.originalName.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return items
    }
    
    // MARK: - Loading & Empty States
    
    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.colors.cardBackground)
                    .frame(height: 140)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter == .all ? "clock" : "clock.badge.xmark")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
            
            Text(emptyStateTitle)
                .font(AppTheme.fonts.subtitle)
                .foregroundStyle(AppTheme.colors.primaryText)
            
            Text(emptyStateMessage)
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return NSLocalizedString("No recent items", comment: "")
        case .today: return NSLocalizedString("No items today", comment: "")
        case .week: return NSLocalizedString("No items this week", comment: "")
        case .month: return NSLocalizedString("No items this month", comment: "")
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return NSLocalizedString("Open a file to see it here.", comment: "")
        case .today: return NSLocalizedString("No files were opened today.", comment: "")
        case .week: return NSLocalizedString("No files were opened this week.", comment: "")
        case .month: return NSLocalizedString("No files were opened this month.", comment: "")
        }
    }
    
    // MARK: - Actions
    
    private func loadAISuggestions() async {
        guard aiEnabled else { return }
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }
        
        let suggestions = AIManager.shared.getSmartSuggestions(for: vaultStore.items)
        await MainActor.run {
            aiSuggestions = suggestions
        }
    }
    
    private func refreshData() async {
        await vaultStore.refresh()
        await loadAISuggestions()
    }
}

// MARK: - AI Suggestion Card

private struct AISuggestionCard: View {
    let suggestion: AISuggestion
    @ObservedObject var vaultStore: VaultStore
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppTheme.colors.accent.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.primaryText)
                    
                    Text(suggestion.description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            if isExpanded {
                Divider()
                    .background(AppTheme.colors.cardBorder)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(getSuggestionItems().prefix(5)) { item in
                        NavigationLink {
                            FileViewer(item: item)
                                .environmentObject(vaultStore)
                        } label: {
                            HStack(spacing: 10) {
                                VaultThumbnailView(item: item, size: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.originalName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.colors.primaryText)
                                        .lineLimit(1)
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(AppTheme.colors.secondaryText)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.colors.accent.opacity(0.3),
                                    AppTheme.colors.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: AppTheme.colors.accent.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .frame(width: isExpanded ? 280 : 200)
        .onTapGesture {
            HapticFeedback.play(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
    
    private func getSuggestionItems() -> [VaultItem] {
        let ids: [UUID]
        switch suggestion {
        case .importantFiles(let uids): ids = uids
        case .duplicates(let groups): ids = groups.flatMap { $0 }
        case .largeFiles(let uids): ids = uids
        case .unorganizedFiles(let uids): ids = uids
        case .recentImportant(let uids): ids = uids
        }
        
        return ids.compactMap { id in
            vaultStore.items.first { $0.id == id }
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
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? AppTheme.colors.primaryText : AppTheme.colors.secondaryText)
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
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : AppTheme.colors.cardBorder,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Card

private struct RecentCard: View {
    let item: VaultItem
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    VaultThumbnailView(item: item, size: proxy.size.width)
                        .frame(width: proxy.size.width, height: proxy.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if item.isVideo {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.colors.accent)
                                    .shadow(color: AppTheme.colors.accentGlow, radius: 8)
                                    .padding(8)
                            }
                        }
                    }
                    
                    // Category badge
                    if let category = item.category {
                        VStack {
                            HStack {
                                Text(category)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(AppTheme.colors.accent.opacity(0.8))
                                    )
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(6)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.colors.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                    
                    Text(timeAgo(from: item.createdAt))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.colors.cardBorder,
                                    AppTheme.colors.cardBorder.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: AppTheme.colors.accentGlow.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
