import SwiftUI
import UniformTypeIdentifiers

struct VaultHomeView: View {
    @ObservedObject var vaultStore: VaultStore
    @State private var filter: VaultStore.FilterOption = .all
    @State private var sort: VaultStore.SortOption = .newest
    @State private var searchText = ""
    @State private var selectionMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showSettings = false
    @State private var shareItem: ShareItem?
    @State private var lastSharedURL: URL?
    @State private var pathStack: [String] = []
    @State private var deleteTarget: DeleteTarget?
    @State private var saveFolderPath: String?
    @State private var saveFolderName = ""
    @State private var showSaveFolderPrompt = false
    @State private var moveFolderPath: String?
    @State private var moveItemIDs: Set<UUID> = []
    @State private var showMoveFolderPicker = false
    @State private var showMoveItemPicker = false
    @State private var showBulkDeleteConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if selectionMode {
                    selectionBar
                }
                filterBar
                breadcrumbBar
                content
            }
            .navigationTitle("Files")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .background(AppTheme.gradients.background.ignoresSafeArea())
            .toolbar {
                if !selectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(VaultStore.SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AddMenuView(
                            vaultStore: vaultStore,
                            selectionMode: $selectionMode,
                            currentFolderPath: pathStack.joined(separator: "/")
                        )
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticFeedback.play(.selection)
                        selectionMode.toggle()
                        if !selectionMode {
                            selectedItems.removeAll()
                        }
                    } label: {
                        Image(systemName: selectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .accessibilityLabel(Text(NSLocalizedString(selectionMode ? "Done" : "Select", comment: "")))
                    .buttonStyle(InteractiveButtonStyle())
                }
                if selectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            HapticFeedback.play(.warning)
                            showBulkDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(InteractiveButtonStyle(hapticStyle: .warning))
                    }
                }
            }
            .sheet(item: $shareItem, onDismiss: {
                if let url = lastSharedURL {
                    try? FileManager.default.removeItem(at: url)
                    lastSharedURL = nil
                }
            }) { item in
                ShareSheet(items: [item.url])
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .alert(item: $deleteTarget) { target in
                Alert(
                    title: Text(target.title),
                    message: Text(target.message),
                    primaryButton: .destructive(Text("Delete")) {
                        handleDeleteConfirmed(target)
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(NSLocalizedString("Delete selected items?", comment: ""), isPresented: $showBulkDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(String(format: NSLocalizedString("You are about to delete %d item(s).", comment: ""), selectedItems.count))
            }
            .confirmationDialog(
                NSLocalizedString("Move Folder", comment: ""),
                isPresented: $showMoveFolderPicker,
                titleVisibility: .visible
            ) {
                ForEach(availableFolderDestinations(for: moveFolderPath), id: \.path) { folder in
                    Button(folder.name) {
                        if let moveFolderPath {
                            try? vaultStore.moveFolder(from: moveFolderPath, to: folder.path)
                        }
                        self.moveFolderPath = nil
                    }
                }
                Button(NSLocalizedString("Move to Root", comment: "")) {
                    if let moveFolderPath {
                        try? vaultStore.moveFolder(from: moveFolderPath, to: nil)
                    }
                    self.moveFolderPath = nil
                }
                Button("Cancel", role: .cancel) {
                    self.moveFolderPath = nil
                }
            }
            .confirmationDialog(
                NSLocalizedString("Move to Folder", comment: ""),
                isPresented: $showMoveItemPicker,
                titleVisibility: .visible
            ) {
                ForEach(vaultStore.folderNodes()) { folder in
                    Button(folder.name) {
                        try? vaultStore.assignFolder(forIDs: moveItemIDs, folderPath: folder.path)
                        moveItemIDs.removeAll()
                    }
                }
                Button("Cancel", role: .cancel) {
                    moveItemIDs.removeAll()
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(vaultStore: vaultStore)
            }
            .alert("Save Folder", isPresented: $showSaveFolderPrompt) {
                TextField("Folder name", text: $saveFolderName)
                Button("Save") {
                    Task { await saveFolderToFiles() }
                }
                Button("Cancel", role: .cancel) {
                    saveFolderPath = nil
                }
            } message: {
                Text("Change the folder name before saving to Files.")
            }
        }
    }

    private var content: some View {
        let items = vaultStore.filteredItems(filter: filter, searchText: searchText, sort: sort)
        let currentPath = pathStack.joined(separator: "/")
        let allFolders = vaultStore.folderChildren(of: pathStack.isEmpty ? nil : currentPath)
        let displayedItems = items.filter { item in
            if pathStack.isEmpty {
                return item.folder == nil || item.folder?.isEmpty == true
            }
            return item.folder == currentPath
        }
        let pinnedItems = displayedItems.filter { vaultStore.pinnedIDs.contains($0.id) }
        let unpinnedItems = displayedItems.filter { !vaultStore.pinnedIDs.contains($0.id) }
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let folders: [FolderNode]
        if filter == .all && normalizedSearch.isEmpty {
            folders = allFolders
        } else {
            folders = allFolders.filter { folder in
                let nameMatches = !normalizedSearch.isEmpty
                    && folder.name.lowercased().contains(normalizedSearch)
                let itemMatches = items.contains { item in
                    guard let folderPath = item.folder, !folderPath.isEmpty else { return false }
                    if folderPath == folder.path { return true }
                    return folderPath.hasPrefix(folder.path + "/")
                }
                return nameMatches || itemMatches
            }
        }
        return Group {
            if vaultStore.isLoading {
                loadingState
            } else if items.isEmpty && folders.isEmpty {
                emptyState
            } else {
                List {
                    if !folders.isEmpty {
                        Section("Folders") {
                            ForEach(folders) { folder in
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(AppTheme.colors.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(folder.name)
                                            .font(AppTheme.fonts.body)
                                        Text(ByteCountFormatter.string(fromByteCount: folder.totalSize, countStyle: .file))
                                            .font(AppTheme.fonts.caption)
                                            .foregroundStyle(AppTheme.colors.secondaryText)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    pathStack.append(folder.name)
                                }
                                .onDrag {
                                    NSItemProvider(object: "folder:\(folder.path)" as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: VaultDropDelegate(targetFolderPath: folder.path, vaultStore: vaultStore))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        deleteTarget = .folder(folder)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        saveFolderPath = folder.path
                                        saveFolderName = folder.name
                                        showSaveFolderPrompt = true
                                    } label: {
                                        Label("Save to Files", systemImage: "tray.and.arrow.down")
                                    }
                                    Button {
                                        Task {
                                            let url = try? await vaultStore.temporaryShareURL(forFolderPath: folder.path, name: folder.name)
                                            if let url {
                                                lastSharedURL = url
                                                shareItem = ShareItem(url: url)
                                            }
                                        }
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    Button {
                                        moveFolderPath = folder.path
                                        showMoveFolderPicker = true
                                    } label: {
                                        Label("Move", systemImage: "folder")
                                    }
                                    Button("Delete", role: .destructive) {
                                        deleteTarget = .folder(folder)
                                    }
                                }
                            }
                        }
                    }
                    if !pinnedItems.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedItems) { item in
                                fileRow(item)
                            }
                        }
                    }
                    Section("Files") {
                        ForEach(unpinnedItems) { item in
                            fileRow(item)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .animation(.easeInOut(duration: 0.2), value: selectionMode)
                .onDrop(of: [UTType.text], delegate: VaultDropDelegate(targetFolderPath: nil, vaultStore: vaultStore))
                .refreshable {
                    await vaultStore.refresh()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.colors.secondaryText)
            Text("No Files")
                .font(AppTheme.fonts.subtitle)
            Text("Import to get started.")
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectionBar: some View {
        let total = selectionCandidateIDs().count
        let selectedCount = selectedItems.count
        return HStack(spacing: 12) {
            Text("\(selectedCount) \(NSLocalizedString("Selected", comment: ""))")
                .font(AppTheme.fonts.subtitle)
            Spacer()
            Button {
                HapticFeedback.play(.selection)
                toggleSelectAll()
            } label: {
                Image(systemName: selectedCount == total && total > 0 ? "minus.circle" : "checkmark.circle")
            }
            .buttonStyle(AppTheme.buttons.secondary)
            .accessibilityLabel(Text(NSLocalizedString(selectedCount == total && total > 0 ? "Clear" : "Select All", comment: "")))
            Button {
                HapticFeedback.play(.light)
                selectionMode = false
                selectedItems.removeAll()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(AppTheme.buttons.primary)
            .accessibilityLabel(Text(NSLocalizedString("Done", comment: "")))
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var loadingState: some View {
        List {
            Section("Folders") {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.colors.cardBackground)
                            .frame(width: 34, height: 28)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.colors.cardBackground)
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.colors.cardBackground)
                                .frame(width: 120, height: 10)
                        }
                        Spacer()
                    }
                    .redacted(reason: .placeholder)
                }
            }
            Section("Files") {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.colors.cardBackground)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.colors.cardBackground)
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.colors.cardBackground)
                                .frame(width: 140, height: 10)
                        }
                        Spacer()
                    }
                    .redacted(reason: .placeholder)
                }
            }
        }
        .listStyle(.insetGrouped)
        .allowsHitTesting(false)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            ForEach(VaultStore.FilterOption.allCases) { option in
                Button {
                    if filter != option {
                        HapticFeedback.play(.selection)
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        filter = option
                    }
                } label: {
                    Image(systemName: filterIcon(option))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(filter == option ? AppTheme.colors.accent : AppTheme.colors.primaryText)
                        .background(
                            Circle()
                                .fill(filter == option ? AppTheme.colors.accent.opacity(0.18) : AppTheme.colors.surface)
                        )
                        .overlay(
                            Circle()
                                .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                        )
                        .accessibilityLabel(Text(NSLocalizedString(option.rawValue, comment: "")))
                }
                .buttonStyle(InteractiveButtonStyle(hapticStyle: .selection))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func filterIcon(_ option: VaultStore.FilterOption) -> String {
        switch option {
        case .all:
            return "square.grid.2x2"
        case .images:
            return "photo"
        case .videos:
            return "video"
        case .documents:
            return "doc.text"
        case .others:
            return "ellipsis.circle"
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 8) {
            if !pathStack.isEmpty {
                Button {
                    _ = pathStack.popLast()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
            }
            BreadcrumbView(segments: pathStack) { index in
                if let index {
                    pathStack = Array(pathStack.prefix(index + 1))
                } else {
                    pathStack.removeAll()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func deleteSelected() {
        try? vaultStore.deleteItems(ids: selectedItems)
        selectedItems.removeAll()
        selectionMode = false
    }

    private func selectionCandidateIDs() -> [UUID] {
        let items = vaultStore.filteredItems(filter: filter, searchText: searchText, sort: sort)
        let currentPath = pathStack.joined(separator: "/")
        let displayedItems = items.filter { item in
            if pathStack.isEmpty {
                return item.folder == nil || item.folder?.isEmpty == true
            }
            return item.folder == currentPath
        }
        return displayedItems.map { $0.id }
    }

    private func toggleSelectAll() {
        let candidates = selectionCandidateIDs()
        if candidates.isEmpty {
            selectedItems.removeAll()
            return
        }
        let candidateSet = Set(candidates)
        if selectedItems == candidateSet {
            selectedItems.removeAll()
        } else {
            selectedItems = candidateSet
        }
    }

    private func fileRow(_ item: VaultItem) -> some View {
        VaultRow(
            item: item,
            selectionMode: selectionMode,
            selectedItems: $selectedItems,
            isPinned: vaultStore.pinnedIDs.contains(item.id),
            onPin: { vaultStore.togglePin(id: item.id) }
        )
        .onDrag {
            NSItemProvider(object: "file:\(item.id.uuidString)" as NSString)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteTarget = .file(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                Task {
                    let url = try? await vaultStore.temporaryShareURL(for: item)
                    if let url {
                        lastSharedURL = url
                        shareItem = ShareItem(url: url)
                    }
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
            Button {
                Task {
                    let url = try? await vaultStore.temporaryShareURL(for: item)
                    if let url {
                        lastSharedURL = url
                        shareItem = ShareItem(url: url)
                    }
                }
            } label: {
                Label("Save to Files", systemImage: "tray.and.arrow.down")
            }
            Button {
                Task {
                    let url = try? await vaultStore.temporaryShareURL(for: item)
                    if let url {
                        lastSharedURL = url
                        shareItem = ShareItem(url: url)
                    }
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                moveItemIDs = [item.id]
                showMoveItemPicker = true
            } label: {
                Label("Move", systemImage: "folder")
            }
            Button("Delete", role: .destructive) {
                deleteTarget = .file(item)
            }
        }
    }
    private func handleDeleteConfirmed(_ target: DeleteTarget) {
        defer { deleteTarget = nil }
        switch target {
        case .file(let item):
            try? vaultStore.deleteItems(ids: [item.id])
        case .folder(let folder):
            vaultStore.deleteFolder(path: folder.path)
        }
    }

    private func saveFolderToFiles() async {
        guard let saveFolderPath else { return }
        let trimmed = saveFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? saveFolderPath.split(separator: "/").last.map(String.init) ?? "Folder" : trimmed
        if let url = try? await vaultStore.temporaryShareURL(forFolderPath: saveFolderPath, name: name) {
            lastSharedURL = url
            shareItem = ShareItem(url: url)
        }
        self.saveFolderPath = nil
        self.saveFolderName = ""
    }

}

private struct BreadcrumbView: View {
    let segments: [String]
    let onSelect: (Int?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button {
                    onSelect(nil)
                } label: {
                    Text("Home")
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                .buttonStyle(.plain)
                ForEach(segments.indices, id: \.self) { index in
                    Text("›")
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                    Button {
                        onSelect(index)
                    } label: {
                        Text(segments[index])
                            .font(AppTheme.fonts.caption)
                            .foregroundStyle(AppTheme.colors.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private extension VaultHomeView {
    func availableFolderDestinations(for path: String?) -> [FolderNode] {
        guard let path else { return vaultStore.folderNodes() }
        let all = flatten(folders: vaultStore.folderNodes())
        return all.filter { !$0.path.hasPrefix(path) && $0.path != path }
    }

    func flatten(folders: [FolderNode]) -> [FolderNode] {
        var result: [FolderNode] = []
        for folder in folders {
            result.append(folder)
            result.append(contentsOf: flatten(folders: folder.children))
        }
        return result
    }
}

private enum DeleteTarget: Identifiable {
    case file(VaultItem)
    case folder(FolderNode)

    var id: String {
        switch self {
        case .file(let item):
            return item.id.uuidString
        case .folder(let folder):
            return folder.path
        }
    }

    var title: String {
        switch self {
        case .file(let item):
            return String(format: NSLocalizedString("Delete “%@”?", comment: ""), item.originalName)
        case .folder(let folder):
            return String(format: NSLocalizedString("Delete “%@”?", comment: ""), folder.name)
        }
    }

    var message: String {
        switch self {
        case .file:
            return NSLocalizedString("This action cannot be undone.", comment: "")
        case .folder:
            return NSLocalizedString("This folder and its contents will be removed.", comment: "")
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct VaultDropDelegate: DropDelegate {
    let targetFolderPath: String?
    let vaultStore: VaultStore

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.text])
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            let text: String?
            if let data = item as? Data {
                text = String(data: data, encoding: .utf8)
            } else if let string = item as? String {
                text = string
            } else {
                text = nil
            }
            guard let text else { return }
            Task { @MainActor in
                if text.hasPrefix("file:") {
                    let raw = text.replacingOccurrences(of: "file:", with: "")
                    if let id = UUID(uuidString: raw) {
                        let currentFolder = vaultStore.items.first(where: { $0.id == id })?.folder ?? ""
                        if let targetFolderPath {
                            guard currentFolder != targetFolderPath else { return }
                            try? vaultStore.assignFolder(forIDs: [id], folderPath: targetFolderPath)
                        } else {
                            if currentFolder.isEmpty { return }
                            try? vaultStore.assignFolder(forIDs: [id], folderPath: "")
                        }
                    }
                } else if text.hasPrefix("folder:") {
                    let source = text.replacingOccurrences(of: "folder:", with: "")
                    if let targetFolderPath {
                        guard source != targetFolderPath else { return }
                        if targetFolderPath.hasPrefix(source + "/") { return }
                        try? vaultStore.moveFolder(from: source, to: targetFolderPath)
                    } else {
                        if !source.contains("/") { return }
                        try? vaultStore.moveFolder(from: source, to: nil)
                    }
                }
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {}
    func dropExited(info: DropInfo) {}
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
        let isSelected = selectedItems.contains(item.id)
        return HStack(spacing: 12) {
            if selectionMode {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.colors.accent : AppTheme.colors.secondaryText)
            }
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
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected && selectionMode ? AppTheme.colors.accent.opacity(0.12) : Color.clear)
        )
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
