import SwiftUI

struct FileInfoSheet: View {
    let item: VaultItem

    var body: some View {
        NavigationStack {
            List {
                Section("File") {
                    infoRow("Name", item.originalName)
                    infoRow("Type", item.mimeType)
                    infoRow("Size", ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    infoRow("Category", item.category ?? "Unsorted")
                    infoRow("Folder", item.folder ?? "Unsorted")
                    infoRow("Created", item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    infoRow("Identifier", item.id.uuidString)
                }
                Section("Security") {
                    infoRow("Encryption", "AES-256 (AES-GCM)")
                    infoRow("Key Storage", "Secure Enclave + Keychain")
                }
            }
            .navigationTitle("File Info")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppTheme.gradients.background.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
