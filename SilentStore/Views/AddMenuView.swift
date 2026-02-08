import SwiftUI

struct AddMenuView: View {
    enum Style {
        case icon
        case card
    }

    @ObservedObject var vaultStore: VaultStore
    @Binding var selectionMode: Bool
    var style: Style = .icon
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var pendingDeletionAssetId: String?
    @State private var showDeleteOriginalAlert = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var pendingImport: ImportResult?
    @State private var showReplaceAlert = false
    @State private var showFolderExistsAlert = false
    @AppStorage("aiEnabled") private var aiEnabled = false

    var body: some View {
        Menu {
            Button("Import from Photos") {
                showPhotoPicker = true
            }
            Button("Import Document") {
                showDocumentPicker = true
            }
            Button("New Folder") {
                showCreateFolder = true
            }
        } label: {
            switch style {
            case .icon:
                Label("Add", systemImage: "plus.circle.fill")
            case .card:
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.accent)
                    Text("Add")
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
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerSheet { result in
                Task { await handleImport(result) }
                showPhotoPicker = false
            } onCancel: {
                showPhotoPicker = false
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerSheet { result in
                Task { await handleImport(result) }
                showDocumentPicker = false
            } onCancel: {
                showDocumentPicker = false
            }
        }
        .alert("Delete original photo?", isPresented: $showDeleteOriginalAlert) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeletionAssetId {
                    vaultStore.deletePHAsset(localIdentifier: id) { _ in }
                }
                pendingDeletionAssetId = nil
            }
            Button("Keep", role: .cancel) {
                pendingDeletionAssetId = nil
            }
        } message: {
            Text("You can remove the original photo from your library after importing it.")
        }
        .alert("New Folder", isPresented: $showCreateFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if vaultStore.folderExists(path: trimmed) {
                        showFolderExistsAlert = true
                    } else {
                        vaultStore.createFolder(path: trimmed)
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
            }
        } message: {
            Text("A file with the same name already exists in this folder. Replace it?")
        }
    }

    private func handleImport(_ result: ImportResult) async {
        var category: String? = nil
        if aiEnabled, result.isImage {
            category = await CoreMLManager.shared.classifyImage(result.data)
        }
        let folder = category
        if vaultStore.existingItem(named: result.originalName, inFolder: folder) != nil {
            pendingImport = result
            showReplaceAlert = true
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
                pendingDeletionAssetId = assetId
                showDeleteOriginalAlert = true
            }
            selectionMode = false
        } catch {
            print("Import failed: \(error)")
        }
    }

    private func replacePendingImport() async {
        guard let pendingImport else { return }
        let folder = aiEnabled && pendingImport.isImage
            ? await CoreMLManager.shared.classifyImage(pendingImport.data)
            : nil
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
                pendingDeletionAssetId = assetId
                showDeleteOriginalAlert = true
            }
            selectionMode = false
        } catch {
            print("Import failed: \(error)")
        }
        self.pendingImport = nil
    }
}
