import SwiftUI

enum AppTheme {
    enum colors {
        // Neon security colors - unified and safe feeling
        static let accent = Color(red: 0.0, green: 0.8, blue: 1.0) // Cyan neon
        static let accentSecondary = Color(red: 0.0, green: 0.9, blue: 0.7) // Green neon
        static let accentGlow = Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.6)
        
        static let background = Color(red: 0.05, green: 0.05, blue: 0.08) // Dark background
        static let surface = Color(red: 0.08, green: 0.08, blue: 0.12) // Dark surface
        static let cardBackground = Color(red: 0.12, green: 0.12, blue: 0.16) // Dark card
        static let cardBorder = Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3) // Neon border
        static let primaryText = Color.white
        static let secondaryText = Color(red: 0.7, green: 0.7, blue: 0.75)
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
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.08),
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.06, green: 0.06, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let accent = LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.9, blue: 1.0),
                Color(red: 0.0, green: 0.8, blue: 1.0),
                Color(red: 0.0, green: 0.7, blue: 0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let neonGlow = RadialGradient(
            colors: [
                colors.accent.opacity(0.4),
                colors.accent.opacity(0.1),
                Color.clear
            ],
            center: .center,
            startRadius: 20,
            endRadius: 100
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.play(.light)
                }
            }
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.play(.light)
                }
            }
    }
}

struct InteractiveButtonStyle: ButtonStyle {
    let hapticStyle: HapticFeedback
    
    init(hapticStyle: HapticFeedback = .light) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedback.play(hapticStyle)
                }
            }
    }
}
