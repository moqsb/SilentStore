import SwiftUI

struct StorageDashboard: View {
    @ObservedObject var vaultStore: VaultStore
    @State private var duplicates: [[VaultItem]] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                deviceCard
                vaultCard
                breakdownCard
                foldersCard
                duplicatesCard
            }
            .padding()
        }
        .navigationTitle("Storage")
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .onAppear {
            duplicates = vaultStore.findExactDuplicates()
        }
    }

    private var deviceCard: some View {
        let storage = vaultStore.deviceStorage()
        return InfoCard(title: "Device Storage", subtitle: storageText(storage), icon: "externaldrive") {
            ProgressView(value: progress(total: storage.total, used: storage.total - storage.available))
                .tint(AppTheme.colors.accent)
        }
    }

    private var vaultCard: some View {
        let total = vaultStore.totalAppStorageBytes()
        let count = vaultStore.items.count
        let storage = vaultStore.deviceStorage()
        let percent = storage.total == 0 ? 0 : Double(total) / Double(storage.total)
        return InfoCard(title: "Vault", subtitle: "\(count) files • \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))", icon: "lock.shield") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: percent)
                    .tint(AppTheme.colors.accent)
                Text(String(format: NSLocalizedString("%.2f%% of device storage", comment: ""), percent * 100))
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
        }
    }

    private var breakdownCard: some View {
        let breakdown = vaultStore.breakdownByType()
        return InfoCard(title: "Breakdown", subtitle: "By file type", icon: "chart.pie") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(breakdown, id: \.label) { item in
                    HStack {
                        Text(item.label)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                    ProgressView(value: progress(total: vaultStore.totalAppStorageBytes(), used: item.size))
                        .tint(AppTheme.colors.accent)
                }
            }
        }
    }

    private var foldersCard: some View {
        let folders = vaultStore.folderNodes()
        let sorted = folders.sorted { $0.totalSize > $1.totalSize }
        let top = Array(sorted.prefix(5))
        return InfoCard(title: "Top Folders", subtitle: top.isEmpty ? "No folders yet" : "Largest by size", icon: "folder.fill") {
            if top.isEmpty {
                Text("Import files to see folder stats.")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(top) { folder in
                        HStack {
                            Text(folder.name)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: folder.totalSize, countStyle: .file))
                                .foregroundStyle(AppTheme.colors.secondaryText)
                        }
                        ProgressView(value: progress(total: vaultStore.totalAppStorageBytes(), used: folder.totalSize))
                            .tint(AppTheme.colors.accent)
                    }
                }
            }
        }
    }

    private var duplicatesCard: some View {
        InfoCard(title: "Duplicates", subtitle: duplicates.isEmpty ? "No duplicates found" : "\(duplicates.count) group(s)", icon: "doc.on.doc") {
            if duplicates.isEmpty {
                Text("All clear.")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(duplicates.indices, id: \.self) { index in
                        let group = duplicates[index]
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.first?.originalName ?? "Duplicates")
                                .font(AppTheme.fonts.caption)
                            Button("Clean extras") {
                                deleteExtras(in: group)
                            }
                            .buttonStyle(AppTheme.buttons.secondary)
                        }
                    }
                }
            }
        }
    }

    private func deleteExtras(in group: [VaultItem]) {
        guard group.count > 1 else { return }
        let toDelete = Set(group.dropFirst().map { $0.id })
        try? vaultStore.deleteItems(ids: toDelete)
        duplicates = vaultStore.findExactDuplicates()
    }

    private func progress(total: Int64, used: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    private func storageText(_ storage: (total: Int64, available: Int64)) -> String {
        let totalText = ByteCountFormatter.string(fromByteCount: storage.total, countStyle: .file)
        let freeText = ByteCountFormatter.string(fromByteCount: storage.available, countStyle: .file)
        return "\(freeText) free of \(totalText)"
    }
}

private struct InfoCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let content: Content

    init(title: String, subtitle: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.colors.accent)
                Text(title)
                    .font(AppTheme.fonts.subtitle)
                Spacer()
            }
            Text(subtitle)
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
        )
    }
}
