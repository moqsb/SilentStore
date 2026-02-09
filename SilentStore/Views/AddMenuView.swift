import SwiftUI

struct AddMenuView: View {
    enum Style {
        case icon
        case card
    }

    @ObservedObject var vaultStore: VaultStore
    @Binding var selectionMode: Bool
    var currentFolderPath: String? = nil
    var style: Style = .icon
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var pendingDeletionAssetIds: [String] = []
    @State private var showDeleteOriginalAlert = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var pendingImport: ImportResult?
    @State private var pendingImports: [ImportResult] = []
    @State private var isProcessingImport = false
    @State private var showReplaceAlert = false
    @State private var showFolderExistsAlert = false
    @State private var duplicateImports: [PendingImportContext] = []
    @State private var showBulkDuplicateAlert = false
    @AppStorage("aiEnabled") private var aiEnabled = false

    var body: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Import from Photos", systemImage: "photo.on.rectangle")
            }
            Button {
                showDocumentPicker = true
            } label: {
                Label("Import Document", systemImage: "doc.badge.plus")
            }
            Button {
                showCreateFolder = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
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
            PhotoPickerSheet { results in
                enqueueImports(results)
                showPhotoPicker = false
            } onCancel: {
                showPhotoPicker = false
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerSheet { results in
                enqueueImports(results)
                showDocumentPicker = false
            } onCancel: {
                showDocumentPicker = false
            }
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
    }

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
            category = await CoreMLManager.shared.classifyImage(result.data)
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
            folder = await CoreMLManager.shared.classifyImage(pendingImport.data)
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
        let trimmed = currentFolderPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
