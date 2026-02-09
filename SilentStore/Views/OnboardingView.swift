import SwiftUI

struct OnboardingView: View {
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var statusMessage: String?
    @State private var isSaving = false
    @State private var hasPasscode = false
    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                OnboardingPage(
                    icon: "lock.shield.fill",
                    title: "Your Private Vault",
                    message: "All files are encrypted locally and protected by Face ID and your app passcode."
                )
                OnboardingPage(
                    icon: "tray.and.arrow.down.fill",
                    title: "Import in Seconds",
                    message: "Bring photos, videos, and documents into your vault with one tap."
                )
                OnboardingPage(
                    icon: "folder.fill.badge.plus",
                    title: "Organize with Folders",
                    message: "Create folders and move items to keep everything in order."
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            passcodeSection

            Button {
                HapticFeedback.play(.success)
                didOnboard = true
            } label: {
                Text("Get Started")
            }
            .buttonStyle(AppTheme.buttons.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .disabled(!hasPasscode)
        }
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .onAppear {
            hasPasscode = KeyManager.shared.hasPasscode()
        }
    }

    private var passcodeSection: some View {
        VStack(spacing: 16) {
            Text(isConfirming ? NSLocalizedString("Confirm Passcode", comment: "") : NSLocalizedString("Set App Passcode", comment: ""))
                .font(AppTheme.fonts.subtitle)
            Text("Use this passcode to recover access if you cannot use Face ID.")
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if hasPasscode {
                Text("Passcode saved.")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            } else {
                if isConfirming {
                    PasscodeEntryView(passcode: $confirmPasscode, length: 6) {
                        Task { await savePasscode() }
                    }
                } else {
                    PasscodeEntryView(passcode: $passcode, length: 6) {
                        if passcode.count == 6 {
                            isConfirming = true
                        }
                    }
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(statusMessage.contains("Failed") || statusMessage.contains("don't") ? .red : AppTheme.colors.secondaryText)
                        .padding(.top, 8)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var canSavePasscode: Bool {
        return passcode.count == 6 && confirmPasscode.count == 6 && passcode == confirmPasscode
    }

    private func savePasscode() async {
        guard passcode.count == 6 && confirmPasscode.count == 6 else { return }
        guard passcode == confirmPasscode else {
            HapticFeedback.play(.error)
            statusMessage = NSLocalizedString("Passcodes don't match. Try again.", comment: "")
            passcode = ""
            confirmPasscode = ""
            isConfirming = false
            return
        }
        isSaving = true
        statusMessage = nil
        do {
            try await KeyManager.shared.setPasscode(passcode)
            HapticFeedback.play(.success)
            hasPasscode = true
            passcode = ""
            confirmPasscode = ""
            isConfirming = false
            statusMessage = NSLocalizedString("Passcode saved.", comment: "")
        } catch {
            HapticFeedback.play(.error)
            statusMessage = NSLocalizedString("Failed to save passcode.", comment: "")
            passcode = ""
            confirmPasscode = ""
            isConfirming = false
        }
        isSaving = false
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.colors.cardBackground)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.accent)
            }
            Text(title)
                .font(AppTheme.fonts.title)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppTheme.fonts.body)
                .foregroundStyle(AppTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.top, 24)
    }
}
