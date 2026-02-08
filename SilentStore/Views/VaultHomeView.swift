import SwiftUI

struct VaultHomeView: View {
    @ObservedObject var vaultStore: VaultStore
    @State private var filter: VaultStore.FilterOption = .all
    @State private var sort: VaultStore.SortOption = .newest
    @State private var searchText = ""
    @State private var selectionMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showSettings = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var activeFolderPath: String?
    @State private var deleteTarget: DeleteTarget?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                filterChips
                content
            }
            .padding(.top, 8)
            .background(AppTheme.gradients.background.ignoresSafeArea())
            .navigationTitle("SilentStore")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(VaultStore.SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        Button(selectionMode ? "Done Selecting" : "Select Items") {
                            selectionMode.toggle()
                            if !selectionMode {
                                selectedItems.removeAll()
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    AddMenuView(vaultStore: vaultStore, selectionMode: $selectionMode)
                }
                if selectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(vaultStore.folderNodes()) { folder in
                                Button(folder.name) {
                                    try? vaultStore.assignFolder(forIDs: selectedItems, folderPath: folder.path)
                                    selectedItems.removeAll()
                                    selectionMode = false
                                }
                            }
                        } label: {
                            Text("Move")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                if let shareURL {
                    try? FileManager.default.removeItem(at: shareURL)
                    self.shareURL = nil
                }
            }) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    handleDeleteConfirmed()
                }
                Button("Cancel", role: .cancel) {
                    deleteTarget = nil
                }
            } message: {
                Text(deleteDialogMessage)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(vaultStore: vaultStore)
            }
        }
    }

    private var content: some View {
        let items = vaultStore.filteredItems(filter: filter, searchText: searchText, sort: sort)
        let folders = vaultStore.folderNodes()
        let displayedItems = items.filter { item in
            guard let activeFolderPath else { return true }
            return item.folder == activeFolderPath
        }
        return Group {
            if items.isEmpty && folders.isEmpty {
                emptyState
            } else {
                List {
                    if !folders.isEmpty {
                        Section("Folders") {
                            ForEach(folders) { folder in
                                Button {
                                    activeFolderPath = folder.path
                                } label: {
                                    VaultCardRow(
                                        title: folder.name,
                                        subtitle: ByteCountFormatter.string(fromByteCount: folder.totalSize, countStyle: .file),
                                        icon: "folder.fill"
                                    )
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(AppTheme.colors.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                                        )
                                        .padding(.vertical, 6)
                                )
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteTarget = .folder(folder)
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button("Save to Files") {
                                        Task {
                                            shareURL = try? await vaultStore.temporaryShareURL(forFolderPath: folder.path)
                                            showShareSheet = shareURL != nil
                                        }
                                    }
                                    Button("Share") {
                                        Task {
                                            shareURL = try? await vaultStore.temporaryShareURL(forFolderPath: folder.path)
                                            showShareSheet = shareURL != nil
                                        }
                                    }
                                    Button("Move") {
                                        // No-op for now: move handled in selection mode menu
                                    }
                                    Button("Delete", role: .destructive) {
                                        deleteTarget = .folder(folder)
                                        showDeleteConfirm = true
                                    }
                                }
                            }
                        }
                    }
                    if let activeFolderPath {
                        Section("Files") {
                            ForEach(displayedItems) { item in
                                fileRow(item)
                            }
                        }
                    } else {
                        ForEach(displayedItems) { item in
                            fileRow(item)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await vaultStore.refresh()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.colors.cardBackground)
                    .frame(width: 84, height: 84)
                Image(systemName: "lock.doc")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.colors.accent)
            }
            Text("Your vault is empty")
                .font(AppTheme.fonts.title)
            Text("Import files to begin securing your private storage.")
                .font(AppTheme.fonts.body)
                .foregroundStyle(AppTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(VaultStore.FilterOption.allCases) { option in
                    Button(option.rawValue) {
                        filter = option
                    }
                    .buttonStyle(FilterChipStyle(isSelected: filter == option))
                }
                if activeFolderPath != nil {
                    Button("All Files") {
                        activeFolderPath = nil
                    }
                    .buttonStyle(FilterChipStyle(isSelected: false))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Secure Vault")
                        .font(AppTheme.fonts.subtitle)
                    Text("All content is encrypted on your device.")
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                    if let activeFolderPath {
                        Text(activeFolderPath)
                            .font(AppTheme.fonts.caption)
                            .foregroundStyle(AppTheme.colors.accent)
                    }
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppTheme.colors.cardBackground)
                            .frame(width: 44, height: 44)
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(AppTheme.colors.accent)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func deleteSelected() {
        try? vaultStore.deleteItems(ids: selectedItems)
        selectedItems.removeAll()
        selectionMode = false
    }

    private func fileRow(_ item: VaultItem) -> some View {
        VaultRow(
            item: item,
            selectionMode: selectionMode,
            selectedItems: $selectedItems,
            isPinned: vaultStore.pinnedIDs.contains(item.id),
            onPin: { vaultStore.togglePin(id: item.id) }
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                )
                .padding(.vertical, 6)
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteTarget = .file(item)
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                Task {
                    shareURL = try? await vaultStore.temporaryShareURL(for: item)
                    showShareSheet = shareURL != nil
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                vaultStore.togglePin(id: item.id)
            } label: {
                Label(vaultStore.pinnedIDs.contains(item.id) ? "Unpin" : "Pin", systemImage: "pin")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button("Save to Files") {
                Task {
                    shareURL = try? await vaultStore.temporaryShareURL(for: item)
                    showShareSheet = shareURL != nil
                }
            }
            Button("Share") {
                Task {
                    shareURL = try? await vaultStore.temporaryShareURL(for: item)
                    showShareSheet = shareURL != nil
                }
            }
            Button("Move") {
                selectionMode = true
                selectedItems = [item.id]
            }
            Button("Delete", role: .destructive) {
                deleteTarget = .file(item)
                showDeleteConfirm = true
            }
        }
    }

    private var deleteDialogTitle: String {
        switch deleteTarget {
        case .file:
            return NSLocalizedString("Delete file?", comment: "")
        case .folder:
            return NSLocalizedString("Delete folder?", comment: "")
        case .none:
            return NSLocalizedString("Delete", comment: "")
        }
    }

    private var deleteDialogMessage: String {
        switch deleteTarget {
        case .file:
            return NSLocalizedString("This action cannot be undone.", comment: "")
        case .folder:
            return NSLocalizedString("This folder will be removed.", comment: "")
        case .none:
            return ""
        }
    }

    private func handleDeleteConfirmed() {
        defer { deleteTarget = nil }
        switch deleteTarget {
        case .file(let item):
            try? vaultStore.deleteItems(ids: [item.id])
        case .folder(let folder):
            if folder.items.isEmpty && folder.children.isEmpty {
                vaultStore.deleteFolder(path: folder.path)
            }
        case .none:
            break
        }
    }

}

private enum DeleteTarget {
    case file(VaultItem)
    case folder(FolderNode)
}

private struct FilterChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.fonts.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.colors.accent.opacity(0.18) : AppTheme.colors.surface)
            .foregroundStyle(isSelected ? AppTheme.colors.accent : AppTheme.colors.primaryText)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct VaultCardRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.colors.surface)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.colors.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.fonts.body)
                Text(subtitle)
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

private struct QuickActionCard: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.accent)
                Text(title)
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
            )
        }
    }
}

private struct VaultRow: View {
    let item: VaultItem
    let selectionMode: Bool
    @Binding var selectedItems: Set<UUID>
    let isPinned: Bool
    let onPin: () -> Void

    var body: some View {
        Group {
            if selectionMode {
                rowContent
                    .onTapGesture { toggleSelection() }
            } else {
                NavigationLink {
                    FileViewer(item: item)
                } label: {
                    rowContent
                }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VaultThumbnailView(item: item, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.originalName)
                    .font(AppTheme.fonts.body)
                Text(item.category ?? "Unsorted")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            Spacer()
            if isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.orange)
            }
            if selectionMode {
                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(AppTheme.colors.accent)
            }
        }
        .contentShape(Rectangle())
    }

    private func toggleSelection() {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
}
