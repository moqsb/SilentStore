import SwiftUI

enum AppTheme {
    static var isLightMode: Bool {
        let appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        switch appearanceMode {
        case "light":
            return true
        case "dark":
            return false
        default:
            return UITraitCollection.current.userInterfaceStyle == .light
        }
    }
    
    enum colors {
        // MEGA Official Colors - Exact match
        // #1C9EBD - MEGA Teal/Cyan accent
        static var accent: Color {
            Color(red: 0.11, green: 0.62, blue: 0.74) // #1C9EBD
        }
        static var accentSecondary: Color {
            Color(red: 0.08, green: 0.55, blue: 0.66) // Darker teal
        }
        static var accentLight: Color {
            Color(red: 0.15, green: 0.70, blue: 0.82) // Lighter teal
        }
        static var accentGlow: Color {
            Color(red: 0.11, green: 0.62, blue: 0.74).opacity(0.3)
        }
        
        // Background colors - adapt to light/dark mode
        static var background: Color {
            isLightMode ? Color(red: 0.98, green: 0.98, blue: 0.99) : Color(red: 0.027, green: 0.031, blue: 0.051) // #07080D
        }
        static var surface: Color {
            isLightMode ? Color(red: 0.95, green: 0.95, blue: 0.96) : Color(red: 0.11, green: 0.13, blue: 0.16)
        }
        static var cardBackground: Color {
            isLightMode ? Color.white : Color(red: 0.15, green: 0.17, blue: 0.20)
        }
        static var cardBorder: Color {
            isLightMode ? Color(red: 0.11, green: 0.62, blue: 0.74).opacity(0.2) : Color(red: 0.11, green: 0.62, blue: 0.74).opacity(0.15)
        }
        
        static var surfaceSecondary: Color {
            isLightMode ? Color(red: 0.92, green: 0.92, blue: 0.93) : Color(red: 0.23, green: 0.30, blue: 0.38) // #3A4D62
        }
        
        // Text colors - adapt to light/dark mode
        static var primaryText: Color {
            isLightMode ? Color(red: 0.1, green: 0.1, blue: 0.15) : Color.white
        }
        static var secondaryText: Color {
            isLightMode ? Color(red: 0.4, green: 0.4, blue: 0.5) : Color(red: 0.68, green: 0.69, blue: 0.78) // #AEB0C7
        }
        static var tertiaryText: Color {
            isLightMode ? Color(red: 0.5, green: 0.5, blue: 0.6) : Color(red: 0.56, green: 0.57, blue: 0.65)
        }
        
        // Interactive colors - MEGA style
        static var success: Color {
            Color(red: 0.11, green: 0.62, blue: 0.74) // MEGA teal
        }
        static var warning: Color {
            Color(red: 0.76, green: 0.40, blue: 0.21) // #C36736
        }
        static var error: Color {
            Color(red: 0.90, green: 0.26, blue: 0.21) // Red
        }
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
        // MEGA background gradient - adapt to light/dark mode
        static var background: LinearGradient {
            if isLightMode {
                return LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 0.99),
                        Color(red: 0.96, green: 0.96, blue: 0.97),
                        Color(red: 0.98, green: 0.98, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [
                        Color(red: 0.027, green: 0.031, blue: 0.051), // #07080D
                        Color(red: 0.05, green: 0.06, blue: 0.08),
                        Color(red: 0.027, green: 0.031, blue: 0.051)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        // MEGA accent gradient
        static let accent = LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.70, blue: 0.82), // Lighter teal
                Color(red: 0.11, green: 0.62, blue: 0.74), // #1C9EBD
                Color(red: 0.08, green: 0.55, blue: 0.66)  // Darker teal
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        // MEGA glow effect
        static let glow = RadialGradient(
            colors: [
                colors.accent.opacity(0.3),
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
