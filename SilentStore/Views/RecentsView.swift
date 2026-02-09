import SwiftUI

struct RecentsView: View {
    @ObservedObject var vaultStore: VaultStore
    @State private var searchText = ""
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        let items = vaultStore.recentOpenedItems()
        let filtered = searchText.isEmpty
            ? items
            : items.filter { $0.originalName.localizedCaseInsensitiveContains(searchText) }

        ScrollView {
            if vaultStore.isLoading {
                loadingGrid
            } else if filtered.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filtered) { item in
                        NavigationLink {
                            FileViewer(item: item)
                        } label: {
                            RecentCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AppTheme.gradients.background.ignoresSafeArea())
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Recents")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.colors.cardBackground)
                    .frame(height: 140)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .allowsHitTesting(false)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.colors.secondaryText)
            Text("No recent items")
                .font(AppTheme.fonts.subtitle)
            Text("Open a file to see it here.")
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

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
                    
                    // Neon glow effect
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
                }
            }
            .aspectRatio(1, contentMode: .fit)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(AppTheme.fonts.body)
                    .foregroundStyle(AppTheme.colors.primaryText)
                    .lineLimit(1)
                Text(item.category ?? "Unsorted")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
}
