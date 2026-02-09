import SwiftUI

struct StorageDashboard: View {
    @ObservedObject var vaultStore: VaultStore
    @State private var duplicates: [[VaultItem]] = []
    @State private var aiSuggestions: [AISuggestion] = []
    @AppStorage("aiEnabled") private var aiEnabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Storage Overview Cards
                storageOverviewSection
                
                // AI Insights (if enabled)
                if aiEnabled {
                    aiInsightsSection
                }
                
                // Breakdown & Analysis
                analysisSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("Storage", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            duplicates = vaultStore.findExactDuplicates()
            if aiEnabled {
                aiSuggestions = AIManager.shared.getSmartSuggestions(for: vaultStore.items)
            }
        }
    }
    
    // MARK: - Storage Overview
    
    private var storageOverviewSection: some View {
        VStack(spacing: 16) {
            // Device Storage Card
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "externaldrive.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.gradients.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Device Storage", comment: ""))
                                .font(AppTheme.fonts.subtitle)
                                .foregroundStyle(AppTheme.colors.primaryText)
                            
                            Text(storageText(vaultStore.deviceStorage()))
                                .font(AppTheme.fonts.caption)
                                .foregroundStyle(AppTheme.colors.secondaryText)
                        }
                        
                        Spacer()
                    }
                    
                    let storage = vaultStore.deviceStorage()
                    ProgressBar(
                        value: progress(total: storage.total, used: storage.total - storage.available),
                        color: AppTheme.colors.accent
                    )
                }
            }
            
            // Vault Storage Card
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.gradients.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Vault", comment: ""))
                                .font(AppTheme.fonts.subtitle)
                                .foregroundStyle(AppTheme.colors.primaryText)
                            
                            let total = vaultStore.totalAppStorageBytes()
                            let count = vaultStore.items.count
                            Text("\(count) \(NSLocalizedString("files", comment: "")) • \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                                .font(AppTheme.fonts.caption)
                                .foregroundStyle(AppTheme.colors.secondaryText)
                        }
                        
                        Spacer()
                    }
                    
                    let total = vaultStore.totalAppStorageBytes()
                    let storage = vaultStore.deviceStorage()
                    let percent = storage.total == 0 ? 0 : Double(total) / Double(storage.total)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressBar(
                            value: percent,
                            color: AppTheme.colors.accent
                        )
                        
                        Text(String(format: NSLocalizedString("%.2f%% of device storage", comment: ""), percent * 100))
                            .font(AppTheme.fonts.caption)
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                }
            }
        }
    }
    
    // MARK: - AI Insights
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
                
                Text(NSLocalizedString("AI Insights", comment: ""))
                    .font(AppTheme.fonts.subtitle)
                    .foregroundStyle(AppTheme.colors.primaryText)
            }
            .padding(.horizontal, 4)
            
            ForEach(aiSuggestions.prefix(3)) { suggestion in
                ModernCard {
                    HStack(spacing: 12) {
                        Image(systemName: suggestion.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.gradients.accent)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(AppTheme.colors.accent.opacity(0.15))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.colors.primaryText)
                            
                            Text(suggestion.description)
                                .font(AppTheme.fonts.caption)
                                .foregroundStyle(AppTheme.colors.secondaryText)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                }
            }
        }
    }
    
    // MARK: - Analysis Section
    
    private var analysisSection: some View {
        VStack(spacing: 16) {
            // Breakdown by Type
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.gradients.accent)
                        
                        Text(NSLocalizedString("Breakdown", comment: ""))
                            .font(AppTheme.fonts.subtitle)
                            .foregroundStyle(AppTheme.colors.primaryText)
                        
                        Spacer()
                    }
                    
                    let breakdown = vaultStore.breakdownByType()
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(breakdown, id: \.label) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.label)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppTheme.colors.primaryText)
                                    
                                    Spacer()
                                    
                                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                        .font(AppTheme.fonts.caption)
                                        .foregroundStyle(AppTheme.colors.secondaryText)
                                }
                                
                                ProgressBar(
                                    value: progress(total: vaultStore.totalAppStorageBytes(), used: item.size),
                                    color: AppTheme.colors.accent
                                )
                            }
                        }
                    }
                }
            }
            
            // Top Folders
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.gradients.accent)
                        
                        Text(NSLocalizedString("Top Folders", comment: ""))
                            .font(AppTheme.fonts.subtitle)
                            .foregroundStyle(AppTheme.colors.primaryText)
                        
                        Spacer()
                    }
                    
                    let folders = vaultStore.folderNodes()
                    let sorted = folders.sorted { $0.totalSize > $1.totalSize }
                    let top = Array(sorted.prefix(5))
                    
                    if top.isEmpty {
                        Text(NSLocalizedString("Import files to see folder stats.", comment: ""))
                            .font(AppTheme.fonts.caption)
                            .foregroundStyle(AppTheme.colors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(top) { folder in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(folder.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(AppTheme.colors.primaryText)
                                        
                                        Spacer()
                                        
                                        Text(ByteCountFormatter.string(fromByteCount: folder.totalSize, countStyle: .file))
                                            .font(AppTheme.fonts.caption)
                                            .foregroundStyle(AppTheme.colors.secondaryText)
                                    }
                                    
                                    ProgressBar(
                                        value: progress(total: vaultStore.totalAppStorageBytes(), used: folder.totalSize),
                                        color: AppTheme.colors.accent
                                    )
                                }
                            }
                        }
                    }
                }
            }
            
            // Duplicates
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.gradients.accent)
                        
                        Text(NSLocalizedString("Duplicates", comment: ""))
                            .font(AppTheme.fonts.subtitle)
                            .foregroundStyle(AppTheme.colors.primaryText)
                        
                        Spacer()
                        
                        if !duplicates.isEmpty {
                            Text("\(duplicates.count)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.colors.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.colors.accent.opacity(0.15))
                                )
                        }
                    }
                    
                    if duplicates.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(AppTheme.colors.accent)
                                
                                Text(NSLocalizedString("All clear.", comment: ""))
                                    .font(AppTheme.fonts.body)
                                    .foregroundStyle(AppTheme.colors.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(duplicates.indices, id: \.self) { index in
                                let group = duplicates[index]
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.first?.originalName ?? NSLocalizedString("Duplicates", comment: ""))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(AppTheme.colors.primaryText)
                                            .lineLimit(1)
                                        
                                        Text("\(group.count) \(NSLocalizedString("copies", comment: ""))")
                                            .font(AppTheme.fonts.caption)
                                            .foregroundStyle(AppTheme.colors.secondaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        HapticFeedback.play(.warning)
                                        deleteExtras(in: group)
                                    } label: {
                                        Text(NSLocalizedString("Clean", comment: ""))
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(AppTheme.colors.accent)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                
                                if index < duplicates.count - 1 {
                                    Divider()
                                        .background(AppTheme.colors.cardBorder)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func deleteExtras(in group: [VaultItem]) {
        guard group.count > 1 else { return }
        let toDelete = Set(group.dropFirst().map { $0.id })
        try? vaultStore.deleteItems(ids: toDelete)
        duplicates = vaultStore.findExactDuplicates()
        if aiEnabled {
            aiSuggestions = AIManager.shared.getSmartSuggestions(for: vaultStore.items)
        }
    }

    private func progress(total: Int64, used: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    private func storageText(_ storage: (total: Int64, available: Int64)) -> String {
        let totalText = ByteCountFormatter.string(fromByteCount: storage.total, countStyle: .file)
        let freeText = ByteCountFormatter.string(fromByteCount: storage.available, countStyle: .file)
        return "\(freeText) \(NSLocalizedString("free of", comment: "")) \(totalText)"
    }
}

// MARK: - Modern Card Component

private struct ModernCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    .shadow(color: AppTheme.colors.accentGlow.opacity(0.1), radius: 12, x: 0, y: 6)
            )
    }
}

// MARK: - Progress Bar Component

private struct ProgressBar: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(value), height: 6)
            }
        }
        .frame(height: 6)
    }
}
