import SwiftUI

enum AppTheme {
    enum colors {
        static let accent = Color("AccentColor")
        static let background = Color("AppBackground")
        static let surface = Color("AppSurface")
        static let cardBackground = Color("AppCard")
        static let cardBorder = Color("AccentColor").opacity(0.18)
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
    }

    enum fonts {
        static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let subtitle = Font.system(size: 18, weight: .medium, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .regular, design: .rounded)
    }

    enum buttons {
        static let primary = PrimaryButtonStyle()
        static let secondary = SecondaryButtonStyle()
    }

    enum gradients {
        static let background = LinearGradient(
            colors: [colors.background, colors.surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let accent = LinearGradient(
            colors: [colors.accent.opacity(0.9), colors.accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                AppTheme.gradients.accent
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: AppTheme.colors.accent.opacity(0.2), radius: 12, x: 0, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(AppTheme.colors.cardBackground)
            .foregroundStyle(AppTheme.colors.primaryText)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
