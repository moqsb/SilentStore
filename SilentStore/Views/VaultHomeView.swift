import SwiftUI
import UniformTypeIdentifiers

struct VaultHomeView: View {
    @ObservedObject var vaultStore: VaultStore
    @Binding var initialFilter: VaultStore.FilterOption?
    @State private var filter: VaultStore.FilterOption = .all
    @State private var sort: VaultStore.SortOption = .newest
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectionMode = false
    @State private var selectedItems: Set<UUID> = []
    @State private var selectedFolderPaths: Set<String> = []
    @State private var shareItem: ShareItem?
    @State private var lastSharedURLs: [URL] = []
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
    @State private var showMoveConflictAlert = false
    @State private var pendingMoveTargetPath: String?
    @State private var pendingMoveItemIDs: Set<UUID> = []
    @State private var selectedRecentsFilter: RecentsFilter = .all
    @State private var aiSuggestions: [AISuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var showFolderExistsAlert = false
    @State private var pendingDeletionAssetIds: [String] = []
    @State private var showDeleteOriginalAlert = false
    @State private var pendingImport: ImportResult?
    @State private var pendingImports: [ImportResult] = []
    @State private var isProcessingImport = false
    @State private var showReplaceAlert = false
    @State private var duplicateImports: [PendingImportContext] = []
    @State private var showBulkDuplicateAlert = false
    @AppStorage("aiEnabled") private var aiEnabled = false
    @Environment(\.layoutDirection) private var layoutDirection
    
    enum RecentsFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This Week"
        
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            filesBodyContent(geometry: geometry)
                .gesture(edgeSwipeGesture(geometry: geometry))
        }
        .navigationTitle(pathStack.isEmpty ? NSLocalizedString("Files", comment: "") : pathStack.last ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Menu {
                        ForEach(VaultStore.SortOption.allCases, id: \.id) { option in
                            Button {
                                HapticFeedback.play(.light)
                                sort = option
                            } label: {
                                HStack {
                                    Text(NSLocalizedString(option.rawValue, comment: ""))
                                    if sort == option { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.colors.accent)
                    }
                    .disabled(selectionMode)
                    if selectionMode {
                        Button(NSLocalizedString("Cancel", comment: "")) {
                            HapticFeedback.play(.light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectionMode = false
                                selectedItems.removeAll()
                                selectedFolderPaths.removeAll()
                            }
                        }
                        .foregroundStyle(AppTheme.colors.accent)
                    } else {
                        Button(NSLocalizedString("Select", comment: "")) {
                            HapticFeedback.play(.light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectionMode = true }
                        }
                        .foregroundStyle(AppTheme.colors.accent)
                    }
                }
            }
        }
        .sheet(item: $shareItem, onDismiss: {
            for url in lastSharedURLs {
                try? FileManager.default.removeItem(at: url)
            }
            lastSharedURLs = []
        }) { item in
            ShareSheet(items: item.urls)
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
            Text(String(format: NSLocalizedString("You are about to delete %d item(s).", comment: ""), selectedItems.count + selectedFolderPaths.count))
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
            ForEach(availableFolderDestinations(for: nil)) { folder in
                Button(folder.name) {
                    if !moveItemIDs.isEmpty {
                        applyMoveToFolder(folder.path, itemIDs: moveItemIDs)
                    }
                    for path in selectedFolderPaths {
                        if path != folder.path && !folder.path.hasPrefix(path + "/") {
                            try? vaultStore.moveFolder(from: path, to: folder.path)
                        }
                    }
                    selectedFolderPaths.removeAll()
                    selectedItems.removeAll()
                    moveItemIDs.removeAll()
                }
            }
            Button(NSLocalizedString("Move to Root", comment: "")) {
                if !moveItemIDs.isEmpty {
                    applyMoveToFolder("", itemIDs: moveItemIDs)
                }
                for path in selectedFolderPaths {
                    try? vaultStore.moveFolder(from: path, to: nil)
                }
                selectedFolderPaths.removeAll()
                selectedItems.removeAll()
                moveItemIDs.removeAll()
            }
            Button("Cancel", role: .cancel) {
                moveItemIDs.removeAll()
                selectedItems.removeAll()
                selectedFolderPaths.removeAll()
            }
        }
        .alert(NSLocalizedString("Duplicate names", comment: ""), isPresented: $showMoveConflictAlert) {
            Button(NSLocalizedString("Replace", comment: ""), role: .destructive) {
                applyMoveConflictResolution(replace: true)
            }
            Button(NSLocalizedString("Keep both", comment: "")) {
                applyMoveConflictResolution(replace: false)
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {
                pendingMoveTargetPath = nil
                pendingMoveItemIDs = []
                moveItemIDs.removeAll()
                selectedItems.removeAll()
            }
        } message: {
            Text(NSLocalizedString("Some files already exist in that folder. Replace them or keep both (renamed)?", comment: ""))
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
        .alert(deleteOriginalTitle, isPresented: $showDeleteOriginalAlert) {
            Button("Delete", role: .destructive) {
                let ids = pendingDeletionAssetIds
                for id in ids {
                    vaultStore.deletePHAsset(localIdentifier: id) { _ in }
                }
                pendingDeletionAssetIds.removeAll()
            }
            Button("Keep", role: .cancel) {
                pendingDeletionAssetIds.removeAll()
            }
        } message: {
            Text("You can remove the original photo from your library after importing it.")
        }
        .alert("New Folder", isPresented: $showCreateFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let targetPath = makeFolderPath(trimmed)
                    if vaultStore.folderExists(path: targetPath) {
                        showFolderExistsAlert = true
                    } else {
                        vaultStore.createFolder(path: targetPath)
                        // Refresh to show the new folder immediately
                        Task {
                            await vaultStore.refresh()
                        }
                    }
                }
                newFolderName = ""
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Create a new folder in your vault.")
        }
        .alert("Folder exists", isPresented: $showFolderExistsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A folder with the same name already exists.")
        }
        .alert("File exists", isPresented: $showReplaceAlert) {
            Button("Replace", role: .destructive) {
                Task { await replacePendingImport() }
            }
            Button("Cancel", role: .cancel) {
                pendingImport = nil
                finishCurrentImport()
            }
        } message: {
            Text("A file with the same name already exists in this folder. Replace it?")
        }
        .alert(NSLocalizedString("Duplicates found", comment: ""), isPresented: $showBulkDuplicateAlert) {
            Button("Replace All", role: .destructive) {
                Task { await handleBulkDuplicates(mode: .replaceAll) }
            }
            Button("Keep Both") {
                Task { await handleBulkDuplicates(mode: .keepBoth) }
            }
            Button("Skip All", role: .cancel) {
                duplicateImports.removeAll()
            }
        } message: {
            Text(String(format: NSLocalizedString("Duplicate files detected (%d).", comment: ""), duplicateImports.count))
        }
        .onAppear {
            if let f = initialFilter {
                filter = f
                initialFilter = nil
            }
        }
        .onChange(of: initialFilter) { _, newValue in
            if let f = newValue {
                filter = f
                initialFilter = nil
            }
        }
        .task {
            if aiEnabled && pathStack.isEmpty {
                await loadAISuggestions()
            }
        }
        .refreshable {
            await vaultStore.refresh()
            if aiEnabled && pathStack.isEmpty {
                await loadAISuggestions()
            }
        }
    }

    @ViewBuilder
    private func filesBodyContent(geometry: GeometryProxy) -> some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    unifiedHeader
                    if !pathStack.isEmpty { improvedBreadcrumbBar }
                    unifiedContentGrid
                }
                .padding(.bottom, 100)
            }
            .background(AppTheme.gradients.background.ignoresSafeArea())
            if !selectionMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Menu {
                            Button { showPhotoPicker = true } label: { Label(NSLocalizedString("Import from Photos", comment: ""), systemImage: "photo.on.rectangle") }
                            Button { showDocumentPicker = true } label: { Label(NSLocalizedString("Import Document", comment: ""), systemImage: "doc.badge.plus") }
                            Button { showCreateFolder = true } label: { Label(NSLocalizedString("New Folder", comment: ""), systemImage: "folder.badge.plus") }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.gradients.accent)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: AppTheme.colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            if selectionMode {
                VStack {
                    Spacer()
                    selectionModeBar
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerSheet { results in enqueueImports(results); showPhotoPicker = false } onCancel: { showPhotoPicker = false }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerSheet { results in enqueueImports(results); showDocumentPicker = false } onCancel: { showDocumentPicker = false }
        }
    }

    private func edgeSwipeGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard !pathStack.isEmpty else { return }
                let screenWidth = geometry.size.width
                let edgeThreshold: CGFloat = 20
                let swipeThreshold: CGFloat = 100
                if layoutDirection == .rightToLeft {
                    let isFromEdge = value.startLocation.x >= screenWidth - edgeThreshold
                    if isFromEdge && value.translation.width > swipeThreshold {
                        HapticFeedback.play(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = pathStack.popLast() }
                    }
                } else {
                    let isFromEdge = value.startLocation.x <= edgeThreshold
                    if isFromEdge && value.translation.width > swipeThreshold {
                        HapticFeedback.play(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = pathStack.popLast() }
                    }
                }
            }
    }
    
    private var unifiedHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.colors.secondaryText)
                TextField(NSLocalizedString("Search files...", comment: ""), text: $searchText)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onSubmit { isSearchFocused = false }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                    )
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(VaultStore.FilterOption.allCases, id: \.id) { option in
                        CustomFilterButton(
                            title: NSLocalizedString(option.rawValue, comment: ""),
                            icon: filterIcon(option),
                            isSelected: filter == option
                        ) {
                            HapticFeedback.play(.selection)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { filter = option }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var unifiedContentGrid: some View {
        let currentPath: String? = pathStack.isEmpty ? nil : pathStack.joined(separator: "/")
        let folders: [FolderNode] = {
            if !searchText.isEmpty {
                let lower = searchText.lowercased()
                return flattenFoldersForSearch(vaultStore.folderNodes()).filter { $0.name.lowercased().contains(lower) || $0.path.lowercased().contains(lower) }
            }
            return vaultStore.folderChildren(of: currentPath)
        }()
        let filteredItems = vaultStore.filteredItems(filter: filter, searchText: searchText.isEmpty ? "" : searchText, sort: sort)
        let displayedItems: [VaultItem] = {
            if !searchText.isEmpty { return filteredItems }
            return filteredItems.filter { item in
                if pathStack.isEmpty { return item.folder == nil || item.folder?.isEmpty == true }
                return item.folder == currentPath
            }
        }()
        let pinnedItems = displayedItems.filter { vaultStore.pinnedIDs.contains($0.id) }
        let unpinnedItems = displayedItems.filter { !vaultStore.pinnedIDs.contains($0.id) }

        Group {
            if vaultStore.isLoading {
                loadingState
            } else if folders.isEmpty && displayedItems.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    if !folders.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(folders) { folder in
                                FolderListRow(
                                    folder: folder,
                                    isSelected: selectedFolderPaths.contains(folder.path),
                                    selectionMode: selectionMode
                                ) {
                                    if selectionMode {
                                        toggleFolderSelection(folder.path)
                                    } else {
                                        HapticFeedback.play(.light)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            let parts = folder.path.split(separator: "/").map(String.init)
                                            pathStack = parts
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        moveFolderPath = folder.path
                                        showMoveFolderPicker = true
                                    } label: { Label(NSLocalizedString("Move", comment: ""), systemImage: "folder") }
                                    Button { Task { await prepareShareFolder(folder.path) } } label: { Label(NSLocalizedString("Share", comment: ""), systemImage: "square.and.arrow.up") }
                                    Button(role: .destructive) {
                                        deleteTarget = .folder(folder)
                                    } label: { Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash") }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    if !pinnedItems.isEmpty || !unpinnedItems.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(pinnedItems + unpinnedItems) { item in
                                if selectionMode {
                                    ItemCard4Column(item: item, isSelected: selectedItems.contains(item.id)) { toggleSelection(for: item.id) }
                                } else {
                                    NavigationLink {
                                        FileViewer(item: item)
                                            .environmentObject(vaultStore)
                                    } label: {
                                        ItemCard4Column(
                                            item: item,
                                            isSelected: false,
                                            vaultStore: vaultStore,
                                            onShare: { Task { await prepareShare(for: item) } },
                                            onPin: { vaultStore.togglePin(id: item.id) },
                                            onDelete: { deleteTarget = .file(item) }
                                        ) {}
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button { Task { await prepareShare(for: item) } } label: { Label(NSLocalizedString("Share", comment: ""), systemImage: "square.and.arrow.up") }
                                        Button { vaultStore.togglePin(id: item.id) } label: {
                                            Label(vaultStore.pinnedIDs.contains(item.id) ? NSLocalizedString("Unpin", comment: "") : NSLocalizedString("Pin", comment: ""), systemImage: vaultStore.pinnedIDs.contains(item.id) ? "pin.slash" : "pin")
                                        }
                                        Button(role: .destructive) { deleteTarget = .file(item) } label: { Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash") }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private func flattenFoldersForSearch(_ nodes: [FolderNode]) -> [FolderNode] {
        var result: [FolderNode] = []
        for node in nodes {
            result.append(node)
            result.append(contentsOf: flattenFoldersForSearch(node.children))
        }
        return result
    }

    private func toggleFolderSelection(_ path: String) {
        HapticFeedback.play(.selection)
        if selectedFolderPaths.contains(path) {
            selectedFolderPaths.remove(path)
        } else {
            selectedFolderPaths.insert(path)
        }
    }

    private func prepareShareFolder(_ path: String) async {
        let name = path.split(separator: "/").last.map(String.init) ?? "Folder"
        if let url = try? await vaultStore.temporaryShareURL(forFolderPath: path, name: name) {
            lastSharedURLs = [url]
            shareItem = ShareItem(urls: [url])
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
                    ForEach(aiSuggestions.prefix(3)) { suggestion in
                        AISuggestionCard(suggestion: suggestion, vaultStore: vaultStore)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Recents Stories Section (Snapchat Style)
    
    private var recentsStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
                
                Text(NSLocalizedString("Recents", comment: ""))
                    .font(AppTheme.fonts.subtitle)
                    .foregroundStyle(AppTheme.colors.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            
            // Recents Filter
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
                .padding(.horizontal, 16)
            }
            
            // Stories Circles - Snapchat Style
            let recentItems = getRecentItems()
            if recentItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 32))
                            .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
                        Text(NSLocalizedString("No recent items", comment: ""))
                            .font(AppTheme.fonts.caption)
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(recentItems.prefix(20)) { item in
                            NavigationLink {
                                FileViewer(item: item)
                                    .environmentObject(vaultStore)
                            } label: {
                                StoryCircle(item: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task { await prepareShare(for: item) }
                                } label: {
                                    Label(NSLocalizedString("Share", comment: ""), systemImage: "square.and.arrow.up")
                                }
                                
                                Button {
                                    vaultStore.togglePin(id: item.id)
                                } label: {
                                    Label(
                                        vaultStore.pinnedIDs.contains(item.id) ? NSLocalizedString("Unpin", comment: "") : NSLocalizedString("Pin", comment: ""),
                                        systemImage: vaultStore.pinnedIDs.contains(item.id) ? "pin.slash" : "pin"
                                    )
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteTarget = .file(item)
                                } label: {
                                    Label(NSLocalizedString("Delete", comment: ""), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12) // Extra padding for full circle visibility
                    .environment(\.layoutDirection, layoutDirection)
                }
            }
        }
        .padding(.vertical, 8) // Additional vertical padding for the section
    }
    
    private func filterIcon(_ option: VaultStore.FilterOption) -> String {
        switch option {
        case .all: return "square.grid.2x2"
        case .images: return "photo"
        case .videos: return "video"
        case .documents: return "doc.text"
        case .others: return "ellipsis.circle"
        }
    }
    
    // MARK: - Improved Breadcrumb Bar
    
    private var improvedBreadcrumbBar: some View {
        HStack(spacing: 12) {
            Button {
                HapticFeedback.play(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = pathStack.popLast() }
            } label: {
                Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppTheme.colors.accent.opacity(0.15)))
            }
            .buttonStyle(.plain)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        HapticFeedback.play(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pathStack.removeAll() }
                    } label: {
                        Text("Home")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(pathStack.isEmpty ? AppTheme.colors.accent : AppTheme.colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    ForEach(Array(pathStack.enumerated()), id: \.offset) { index, segment in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
                        Button {
                            HapticFeedback.play(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pathStack = Array(pathStack.prefix(index + 1)) }
                        } label: {
                            Text(segment)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(index == pathStack.count - 1 ? AppTheme.colors.primaryText : AppTheme.colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    // MARK: - Selection Mode Bar
    
    private var selectionModeBar: some View {
        HStack(spacing: 12) {
            Button {
                HapticFeedback.play(.light)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectionMode = false
                    selectedItems.removeAll()
                }
            } label: {
                Text(NSLocalizedString("Cancel", comment: ""))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            
            Spacer()
            
            Text("\(selectedItems.count + selectedFolderPaths.count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.colors.accent)
            Text(NSLocalizedString("Selected", comment: ""))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.colors.primaryText)
            
            Spacer()
            
            if selectedItems.isEmpty && selectedFolderPaths.isEmpty {
                Button {
                    HapticFeedback.play(.light)
                    toggleSelectAll()
                } label: {
                    Text(NSLocalizedString("Select All", comment: ""))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.accent)
                }
            } else {
                Button {
                    HapticFeedback.play(.light)
                    moveItemIDs = selectedItems
                    showMoveItemPicker = true
                } label: {
                    Image(systemName: "folder.badge.arrow.in")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.accent)
                }
                Button {
                    HapticFeedback.play(.light)
                    Task { await shareSelectedItems() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.accent)
                }
                Button(role: .destructive) {
                    HapticFeedback.play(.warning)
                    showBulkDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
    
    // MARK: - States
    
    private var loadingState: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(0..<20, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.colors.cardBackground)
                    .aspectRatio(1, contentMode: .fit)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
            
            Text(NSLocalizedString("No files yet", comment: ""))
                .font(AppTheme.fonts.subtitle)
                .foregroundStyle(AppTheme.colors.primaryText)
            
            Text(NSLocalizedString("Import to get started.", comment: ""))
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    
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
    
    private func toggleSelection(for id: UUID) {
        HapticFeedback.play(.selection)
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
    
    private func toggleSelectAll() {
        let currentPath: String? = pathStack.isEmpty ? nil : pathStack.joined(separator: "/")
        let folders: [FolderNode] = {
            if !searchText.isEmpty {
                let lower = searchText.lowercased()
                return flattenFoldersForSearch(vaultStore.folderNodes()).filter { $0.name.lowercased().contains(lower) || $0.path.lowercased().contains(lower) }
            }
            return vaultStore.folderChildren(of: currentPath)
        }()
        let items = vaultStore.filteredItems(filter: filter, searchText: searchText, sort: sort)
        let displayedItems: [VaultItem] = {
            if !searchText.isEmpty { return items }
            return items.filter { item in
                if pathStack.isEmpty { return item.folder == nil || item.folder?.isEmpty == true }
                return item.folder == currentPath
            }
        }()
        let allFileIds = Set(displayedItems.map(\.id))
        let allFolderPaths = Set(folders.map(\.path))
        let fileCountMatch = selectedItems == allFileIds
        let folderCountMatch = selectedFolderPaths == allFolderPaths
        if fileCountMatch && folderCountMatch {
            selectedItems.removeAll()
            selectedFolderPaths.removeAll()
        } else {
            selectedItems = allFileIds
            selectedFolderPaths = allFolderPaths
        }
    }

    private func deleteSelected() {
        try? vaultStore.deleteItems(ids: selectedItems)
        for path in selectedFolderPaths {
            vaultStore.deleteFolder(path: path)
        }
        selectedItems.removeAll()
        selectedFolderPaths.removeAll()
        selectionMode = false
    }
    
    private func handleDeleteConfirmed(_ target: DeleteTarget) {
        defer { deleteTarget = nil }
        switch target {
        case .file(let item):
            try? vaultStore.deleteItems(ids: [item.id])
            if aiEnabled {
                AILearningManager.shared.learnFromDeletion(item: item)
            }
        case .folder(let folder):
            vaultStore.deleteFolder(path: folder.path)
        }
    }
    
    private func saveFolderToFiles() async {
        guard let saveFolderPath else { return }
        let trimmed = saveFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? saveFolderPath.split(separator: "/").last.map(String.init) ?? "Folder" : trimmed
        if let url = try? await vaultStore.temporaryShareURL(forFolderPath: saveFolderPath, name: name) {
            lastSharedURLs = [url]
            shareItem = ShareItem(urls: [url])
        }
        self.saveFolderPath = nil
        self.saveFolderName = ""
    }
    
    private func loadAISuggestions() async {
        guard aiEnabled else { return }
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }
        
        let suggestions = AIManager.shared.getSmartSuggestions(for: vaultStore.items)
        await MainActor.run {
            aiSuggestions = suggestions
        }
    }
    
    private func availableFolderDestinations(for path: String?) -> [FolderNode] {
        guard let path else { return vaultStore.folderNodes() }
        let all = flatten(folders: vaultStore.folderNodes())
        return all.filter { !$0.path.hasPrefix(path) && $0.path != path }
    }

    private func flatten(folders: [FolderNode]) -> [FolderNode] {
        var result: [FolderNode] = []
        for folder in folders {
            result.append(folder)
            result.append(contentsOf: flatten(folders: folder.children))
        }
        return result
    }
    
    private func prepareShare(for item: VaultItem) async {
        do {
            let url = try await vaultStore.temporaryShareURL(for: item)
            lastSharedURLs = [url]
            shareItem = ShareItem(urls: [url])
        } catch {
            shareItem = nil
        }
    }
    
    private func shareSelectedItems() async {
        var urls: [URL] = []
        for item in vaultStore.items.filter({ selectedItems.contains($0.id) }) {
            if let url = try? await vaultStore.temporaryShareURL(for: item) { urls.append(url) }
        }
        for path in selectedFolderPaths {
            if let url = try? await vaultStore.temporaryShareURL(forFolderPath: path) { urls.append(url) }
        }
        guard !urls.isEmpty else { return }
        lastSharedURLs = urls
        shareItem = ShareItem(urls: urls)
    }

    private func applyMoveToFolder(_ targetPath: String, itemIDs: Set<UUID>) {
        guard !itemIDs.isEmpty else {
            moveItemIDs.removeAll()
            selectedItems.removeAll()
            showMoveItemPicker = false
            return
        }
        let folderForCheck = targetPath.isEmpty ? nil : targetPath
        let pathForAssign = targetPath
        let itemsToMove = vaultStore.items.filter { itemIDs.contains($0.id) }
        let conflicts = itemsToMove.filter { vaultStore.existingItem(named: $0.originalName, inFolder: folderForCheck) != nil }
        if conflicts.isEmpty {
            try? vaultStore.assignFolder(forIDs: itemIDs, folderPath: pathForAssign)
            moveItemIDs.removeAll()
            selectedItems.removeAll()
            showMoveItemPicker = false
        } else {
            pendingMoveTargetPath = pathForAssign
            pendingMoveItemIDs = itemIDs
            showMoveConflictAlert = true
            showMoveItemPicker = false
        }
    }

    private func applyMoveConflictResolution(replace: Bool) {
        guard let targetPath = pendingMoveTargetPath else { return }
        let ids = pendingMoveItemIDs
        let folderForCheck = targetPath.isEmpty ? nil : targetPath
        pendingMoveTargetPath = nil
        pendingMoveItemIDs = []

        if replace {
            for id in ids {
                guard let item = vaultStore.items.first(where: { $0.id == id }) else { continue }
                if let existing = vaultStore.existingItem(named: item.originalName, inFolder: folderForCheck), existing.id != id {
                    try? vaultStore.deleteItems(ids: [existing.id])
                }
            }
            try? vaultStore.assignFolder(forIDs: ids, folderPath: targetPath)
        } else {
            for id in ids {
                guard let item = vaultStore.items.first(where: { $0.id == id }) else { continue }
                if vaultStore.existingItem(named: item.originalName, inFolder: folderForCheck) != nil {
                    let newName = vaultStore.uniqueItemName(base: item.originalName, inFolder: folderForCheck)
                    try? vaultStore.renameItem(id: id, newName: newName)
                }
                try? vaultStore.assignFolder(forIDs: [id], folderPath: targetPath)
            }
        }
        selectedItems.removeAll()
    }
    
    // MARK: - Import Handling
    
    private func enqueueImports(_ results: [ImportResult]) {
        pendingImports.append(contentsOf: results)
        if !isProcessingImport {
            Task { await processNextImport() }
        }
    }
    
    private func processNextImport() async {
        guard !pendingImports.isEmpty else {
            isProcessingImport = false
            if !pendingDeletionAssetIds.isEmpty {
                showDeleteOriginalAlert = true
            }
            if !duplicateImports.isEmpty {
                showBulkDuplicateAlert = true
            }
            return
        }
        isProcessingImport = true
        let result = pendingImports[0]
        await handleImport(result)
    }
    
    private func finishCurrentImport() {
        if !pendingImports.isEmpty {
            pendingImports.removeFirst()
        }
        Task { await processNextImport() }
    }
    
    private var deleteOriginalTitle: String {
        pendingDeletionAssetIds.count > 1
            ? NSLocalizedString("Delete original photos?", comment: "")
            : NSLocalizedString("Delete original photo?", comment: "")
    }
    
    private func handleImport(_ result: ImportResult) async {
        var category: String? = nil
        if aiEnabled, result.isImage {
            category = await AIManager.shared.classifyImage(result.data)
        }
        let folder = normalizedCurrentFolderPath ?? category
        if vaultStore.existingItem(named: result.originalName, inFolder: folder) != nil {
            duplicateImports.append(PendingImportContext(result: result, folder: folder, category: category))
            finishCurrentImport()
            return
        }
        do {
            try await vaultStore.addItem(
                data: result.data,
                originalName: result.originalName,
                mimeType: result.mimeType,
                isImage: result.isImage,
                category: category,
                folder: folder
            )
            if let assetId = result.assetIdentifier {
                pendingDeletionAssetIds.append(assetId)
            }
            selectionMode = false
        } catch {
            print("Import failed: \(error)")
        }
        finishCurrentImport()
    }
    
    private func replacePendingImport() async {
        guard let pendingImport else { return }
        let folder: String?
        if let normalizedCurrentFolderPath {
            folder = normalizedCurrentFolderPath
        } else if aiEnabled && pendingImport.isImage {
            folder = await AIManager.shared.classifyImage(pendingImport.data)
        } else {
            folder = nil
        }
        if let existing = vaultStore.existingItem(named: pendingImport.originalName, inFolder: folder) {
            try? vaultStore.deleteItems(ids: [existing.id])
        }
        do {
            try await vaultStore.addItem(
                data: pendingImport.data,
                originalName: pendingImport.originalName,
                mimeType: pendingImport.mimeType,
                isImage: pendingImport.isImage,
                category: folder,
                folder: folder
            )
            if let assetId = pendingImport.assetIdentifier {
                pendingDeletionAssetIds.append(assetId)
            }
            selectionMode = false
        } catch {
            print("Import failed: \(error)")
        }
        self.pendingImport = nil
        finishCurrentImport()
    }
    
    private func handleBulkDuplicates(mode: BulkDuplicateMode) async {
        let contexts = duplicateImports
        duplicateImports.removeAll()
        var reservedNames: [String: Set<String>] = [:]
        
        for context in contexts {
            let folderKey = context.folder ?? ""
            if reservedNames[folderKey] == nil {
                reservedNames[folderKey] = Set(
                    vaultStore.items
                        .filter { $0.folder == context.folder }
                        .map { $0.originalName }
                )
            }
            var targetName = context.result.originalName
            if mode != .skipAll {
                if mode == .replaceAll {
                    if let existing = vaultStore.existingItem(named: targetName, inFolder: context.folder) {
                        try? vaultStore.deleteItems(ids: [existing.id])
                        reservedNames[folderKey]?.remove(existing.originalName)
                    }
                }
                if mode == .keepBoth || (reservedNames[folderKey]?.contains(targetName) ?? false) {
                    targetName = uniqueName(base: targetName, used: &reservedNames[folderKey]!)
                }
            }
            
            guard mode != .skipAll else { continue }
            do {
                try await vaultStore.addItem(
                    data: context.result.data,
                    originalName: targetName,
                    mimeType: context.result.mimeType,
                    isImage: context.result.isImage,
                    category: context.category,
                    folder: context.folder
                )
                if let assetId = context.result.assetIdentifier {
                    pendingDeletionAssetIds.append(assetId)
                }
            } catch {
                print("Bulk import failed: \(error)")
            }
        }
        
        if !pendingDeletionAssetIds.isEmpty {
            showDeleteOriginalAlert = true
        }
    }
    
    private func uniqueName(base: String, used: inout Set<String>) -> String {
        if !used.contains(base) {
            used.insert(base)
            return base
        }
        let ext = (base as NSString).pathExtension
        let name = (base as NSString).deletingPathExtension
        var counter = 1
        while true {
            let candidate = "\(name) (\(counter))" + (ext.isEmpty ? "" : ".\(ext)")
            if !used.contains(candidate) {
                used.insert(candidate)
                return candidate
            }
            counter += 1
        }
    }
    
    private func makeFolderPath(_ name: String) -> String {
        guard let currentFolderPath = normalizedCurrentFolderPath else {
            return name
        }
        return currentFolderPath + "/" + name
    }
    
    private var normalizedCurrentFolderPath: String? {
        let trimmed = (pathStack.isEmpty ? nil : pathStack.joined(separator: "/"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}


// MARK: - Story Circle Component (Snapchat Style)

private struct StoryCircle: View {
    let item: VaultItem
    @Environment(\.layoutDirection) var layoutDirection
    
    var body: some View {
        ZStack {
            // Outer ring (gradient)
            Circle()
                .stroke(
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

private struct FolderListRow: View {
    let folder: FolderNode
    let isSelected: Bool
    let selectionMode: Bool
    let action: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if selectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? AppTheme.colors.accent : AppTheme.colors.secondaryText)
                }
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.colors.accent)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.colors.accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.colors.primaryText)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: folder.totalSize, countStyle: .file))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                Spacer()
                if !selectionMode {
                    Image(systemName: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder Card Horizontal

private struct FolderCardHorizontal: View {
    let folder: FolderNode
    let action: () -> Void
    @Environment(\.layoutDirection) var layoutDirection
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.colors.accent)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.colors.accent.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.primaryText)
                        .lineLimit(1)
                    
                    Text(ByteCountFormatter.string(fromByteCount: folder.totalSize, countStyle: .file))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: layoutDirection == .rightToLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            .padding(14)
            .frame(width: 280)
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Filter Button

private struct CustomFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : AppTheme.colors.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
                                    .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                            )
                    }
                }
            )
            .shadow(
                color: isSelected ? AppTheme.colors.accent.opacity(0.3) : Color.clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Item Card 4 Columns (Fixed)

private struct ItemCard4Column: View {
    let item: VaultItem
    let isSelected: Bool
    let vaultStore: VaultStore?
    let onShare: (() -> Void)?
    let onPin: (() -> Void)?
    let onDelete: (() -> Void)?
    let action: () -> Void
    
    init(
        item: VaultItem,
        isSelected: Bool,
        vaultStore: VaultStore? = nil,
        onShare: (() -> Void)? = nil,
        onPin: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.vaultStore = vaultStore
        self.onShare = onShare
        self.onPin = onPin
        self.onDelete = onDelete
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                VaultThumbnailView(item: item, size: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.colors.accent.opacity(0.4))
                        .overlay(
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        )
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Action Button (FAB)

private struct FloatingActionButton: View {
    @Binding var showMenu: Bool
    let onTap: () -> Void
    let onAddFile: () -> Void
    let onAddFolder: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if showMenu {
                // Menu items
                VStack(spacing: 12) {
                    FABMenuItem(
                        icon: "photo.on.rectangle",
                        title: NSLocalizedString("Add Files", comment: ""),
                        color: AppTheme.colors.accent
                    ) {
                        onAddFile()
                    }
                    
                    FABMenuItem(
                        icon: "folder.badge.plus",
                        title: NSLocalizedString("New Folder", comment: ""),
                        color: AppTheme.colors.accent
                    ) {
                        onAddFolder()
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Main FAB button
            Button(action: {
                HapticFeedback.play(.medium)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onTap()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gradients.accent)
                        .frame(width: 56, height: 56)
                        .shadow(color: AppTheme.colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: showMenu ? "xmark" : "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(showMenu ? 45 : 0))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FABMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.play(.light)
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(color)
                    )
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.colors.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(AppTheme.colors.cardBackground)
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                            )
                    )
            }
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Other Components

private struct AISuggestionCard: View {
    let suggestion: AISuggestion
    @ObservedObject var vaultStore: VaultStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppTheme.colors.accent.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.primaryText)
                    
                    Text(suggestion.description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(width: 180)
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
    }
}

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

private enum BulkDuplicateMode {
    case replaceAll
    case keepBoth
    case skipAll
}

private struct PendingImportContext {
    let result: ImportResult
    let folder: String?
    let category: String?
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
    let urls: [URL]
    var id: String { urls.map(\.path).joined(separator: "\n") }
}
