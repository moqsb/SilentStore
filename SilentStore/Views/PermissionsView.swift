import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.colors.accent)
                Text("Welcome to SilentStore")
                    .font(AppTheme.fonts.title)
                Text("We need a few permissions to help you import and protect your files.")
                    .font(AppTheme.fonts.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.colors.secondaryText)
                    .padding(.horizontal)
            }
            HStack(spacing: 12) {
                Button("Allow") {
                    Task { await requestPermissions() }
                }
                .buttonStyle(AppTheme.buttons.primary)
                Button("Skip") {
                    permissionsManager.markShown()
                    dismiss()
                }
                .buttonStyle(AppTheme.buttons.secondary)
            }
            if isRequesting {
                ProgressView()
            }
        }
        .padding()
        .background(AppTheme.gradients.background.ignoresSafeArea())
    }

    private func requestPermissions() async {
        isRequesting = true
        await permissionsManager.requestAllPermissions()
        permissionsManager.markShown()
        isRequesting = false
        dismiss()
    }
}
