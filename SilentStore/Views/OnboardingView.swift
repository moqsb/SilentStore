import SwiftUI

struct OnboardingView: View {
    @AppStorage("didOnboard") private var didOnboard = false

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                OnboardingPage(
                    icon: "lock.shield.fill",
                    title: "Your Private Vault",
                    message: "All files are encrypted locally and protected by Face ID or your device passcode."
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

            Button("Get Started") {
                didOnboard = true
            }
            .buttonStyle(AppTheme.buttons.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(AppTheme.gradients.background.ignoresSafeArea())
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
