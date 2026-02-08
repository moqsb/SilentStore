import SwiftUI

struct FolderBrowserView: View {
    @ObservedObject var vaultStore: VaultStore
    var onSelect: ((String) -> Void)?
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var movingFolderPath: String?
    @State private var showMoveSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vaultStore.folderNodes()) { folder in
                    folderRow(folder)
                }
            }
            .navigationTitle("Folders")
            .environmentObject(vaultStore)
            .scrollContentBackground(.hidden)
            .background(AppTheme.gradients.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showMoveSheet) {
                FolderDestinationPicker(
                    folders: vaultStore.folderNodes(),
                    excludingPath: movingFolderPath
                ) { destination in
                    if let movingFolderPath {
                        try? vaultStore.moveFolder(from: movingFolderPath, to: destination)
                    }
                    movingFolderPath = nil
                }
            }
            .alert("New Folder", isPresented: $showCreateFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") {
                    let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        vaultStore.createFolder(path: trimmed)
                    }
                    newFolderName = ""
                }
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
            } message: {
                Text("Create a new folder in your vault.")
            }
        }
    }

    @ViewBuilder
    private func folderRow(_ folder: FolderNode) -> some View {
        NavigationLink(folder.name) {
            FolderDetailView(folder: folder)
        }
        .swipeActions {
            if let onSelect {
                Button("Select") {
                    onSelect(folder.path)
                }
                .tint(AppTheme.colors.accent)
            }
            Button("Move") {
                movingFolderPath = folder.path
                showMoveSheet = true
            }
        }
    }
}

struct FolderDetailView: View {
    let folder: FolderNode
    @EnvironmentObject private var vaultStore: VaultStore
    @State private var showCreateFolder = false
    @State private var newFolderName = ""

    var body: some View {
        List {
            if !folder.children.isEmpty {
                Section("Folders") {
                    ForEach(folder.children) { child in
                        NavigationLink(child.name) {
                            FolderDetailView(folder: child)
                        }
                    }
                }
            }
            if !folder.items.isEmpty {
                Section("Files") {
                    ForEach(folder.items) { item in
                        NavigationLink {
                            FileViewer(item: item)
                        } label: {
                            HStack(spacing: 12) {
                                VaultThumbnailView(item: item, size: 48)
                                Text(item.originalName)
                                    .font(AppTheme.fonts.body)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(folder.name)
        .scrollContentBackground(.hidden)
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .alert("New Subfolder", isPresented: $showCreateFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    vaultStore.createFolder(path: folder.path + "/" + trimmed)
                }
                newFolderName = ""
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text(String(format: NSLocalizedString("Create a subfolder inside %@", comment: ""), folder.name))
        }
    }
}

private struct FolderDestinationPicker: View {
    let folders: [FolderNode]
    let excludingPath: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button("Move to Root") {
                    onSelect(nil)
                    dismiss()
                }
                ForEach(flatten(folders: folders), id: \.path) { folder in
                    if folder.path != excludingPath {
                        Button(folder.path) {
                            onSelect(folder.path)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Move Folder")
        }
    }

    private func flatten(folders: [FolderNode]) -> [FolderNode] {
        var result: [FolderNode] = []
        for folder in folders {
            result.append(folder)
            result.append(contentsOf: flatten(folders: folder.children))
        }
        return result
    }
}
