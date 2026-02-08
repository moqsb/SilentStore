import SwiftUI

struct VaultHomeGrid: View {
    let items: [VaultItem]
    let selectionMode: Bool
    @Binding var selectedItems: Set<UUID>
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    if selectionMode {
                        gridCell(for: item)
                            .onTapGesture { toggleSelection(item) }
                    } else {
                        NavigationLink {
                            FileViewer(item: item)
                        } label: {
                            gridCell(for: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func toggleSelection(_ item: VaultItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func itemIcon(for item: VaultItem) -> String {
        if item.isImage { return "photo" }
        if item.isVideo { return "film" }
        if item.isDocument { return "doc.text" }
        return "doc"
    }

    private func gridCell(for item: VaultItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                VaultThumbnailView(item: item, size: 120)
                if selectionMode {
                    Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(AppTheme.colors.accent)
                        .padding(8)
                }
            }
            Text(item.originalName)
                .font(AppTheme.fonts.caption)
                .lineLimit(2)
                .foregroundStyle(AppTheme.colors.primaryText)
        }
        .contentShape(Rectangle())
    }
}
