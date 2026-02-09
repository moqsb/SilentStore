import SwiftUI

struct LockScreenView: View {
    @Binding var passcode: String
    @Binding var passcodeError: String?
    let hasPasscode: Bool
    let faceIdEnabled: Bool
    let onUnlock: () -> Void
    let onBiometricUnlock: () -> Void
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // MEGA background
            AppTheme.gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and branding
                VStack(spacing: 24) {
                    // MEGA-style logo circle
                    ZStack {
                        Circle()
                            .fill(AppTheme.gradients.accent)
                            .frame(width: 100, height: 100)
                            .shadow(color: AppTheme.colors.accent.opacity(0.4), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("SilentStore")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.colors.primaryText)
                        
                        Text("Secure Vault")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                }
                .padding(.bottom, 60)
                
                // Passcode entry section
                if hasPasscode {
                    VStack(spacing: 24) {
                        Text("Enter Passcode")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.colors.primaryText)
                        
                        if let passcodeError {
                            Text(passcodeError)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.red.opacity(0.9))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(.red.opacity(0.15))
                                )
                        }
                        
                        // Passcode dots - modern design
                        HStack(spacing: 16) {
                            ForEach(0..<6, id: \.self) { index in
                                Circle()
                                    .fill(index < passcode.count ? 
                                          AppTheme.gradients.accent : 
                                          LinearGradient(
                                            colors: AppTheme.isLightMode ? 
                                                [AppTheme.colors.primaryText.opacity(0.2), AppTheme.colors.primaryText.opacity(0.1)] :
                                                [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                          )
                                    )
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.isLightMode ? 
                                                   AppTheme.colors.primaryText.opacity(index < passcode.count ? 0 : 0.3) :
                                                   .white.opacity(index < passcode.count ? 0 : 0.3), 
                                                   lineWidth: 1.5)
                                    )
                                    .shadow(color: index < passcode.count ? AppTheme.colors.accent.opacity(0.5) : .clear, radius: 4)
                            }
                        }
                        .offset(x: shakeOffset)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: passcode.count)
                        .animation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true), value: shakeOffset)
                        
                        // Modern number pad
                        VStack(spacing: 16) {
                            ForEach(0..<3) { row in
                                HStack(spacing: 20) {
                                    ForEach(1..<4) { col in
                                        let num = row * 3 + col
                                        ModernNumberButton(num: num) {
                                            if passcode.count < 6 {
                                                HapticFeedback.play(.light)
                                                passcode += "\(num)"
                                            }
                                        }
                                    }
                                }
                            }
                            // Bottom row: Face ID (if enabled) or spacer, 0, delete
                            HStack(spacing: 20) {
                                if faceIdEnabled {
                                    ModernFaceIDButton {
                                        HapticFeedback.play(.medium)
                                        onBiometricUnlock()
                                    }
                                } else {
                                    Spacer()
                                        .frame(width: 90)
                                }
                                ModernNumberButton(num: 0) {
                                    if passcode.count < 6 {
                                        HapticFeedback.play(.light)
                                        passcode += "0"
                                    }
                                }
                                ModernDeleteButton {
                                    if !passcode.isEmpty {
                                        HapticFeedback.play(.medium)
                                        passcode.removeLast()
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 40)
                } else {
                    Text("Setting up...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                
                Spacer()
            }
        }
        .onChange(of: passcode) { _, newValue in
            if newValue.count > 6 {
                passcode = String(newValue.prefix(6))
            }
            if passcode.count == 6 {
                HapticFeedback.play(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onUnlock()
                }
            }
        }
        .onChange(of: passcodeError) { _, newValue in
            if newValue != nil {
                shake()
            }
        }
    }
    
    private func shake() {
        withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
            shakeOffset = 12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeOffset = 0
        }
    }
}

private struct ModernNumberButton: View {
    let num: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(num)")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(AppTheme.colors.primaryText)
                .frame(width: 90, height: 90)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: AppTheme.isLightMode ? 
                                        [
                                            AppTheme.colors.primaryText.opacity(0.1),
                                            AppTheme.colors.primaryText.opacity(0.05)
                                        ] :
                                        [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.isLightMode ? 
                                           AppTheme.colors.primaryText.opacity(0.2) :
                                           .white.opacity(0.2), 
                                           lineWidth: 1)
                            )
                    }
                )
        }
        .buttonStyle(ModernButtonStyle())
    }
}

private struct ModernFaceIDButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "faceid")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(AppTheme.colors.accent)
                .frame(width: 90, height: 90)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: AppTheme.isLightMode ? 
                                        [
                                            AppTheme.colors.accent.opacity(0.15),
                                            AppTheme.colors.accent.opacity(0.05)
                                        ] :
                                        [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.colors.accent.opacity(0.4), lineWidth: 1.5)
                            )
                    }
                )
        }
        .buttonStyle(ModernButtonStyle())
    }
}

private struct ModernDeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(AppTheme.colors.primaryText)
                .frame(width: 90, height: 90)
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: AppTheme.isLightMode ? 
                                        [
                                            AppTheme.colors.primaryText.opacity(0.1),
                                            AppTheme.colors.primaryText.opacity(0.05)
                                        ] :
                                        [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.isLightMode ? 
                                           AppTheme.colors.primaryText.opacity(0.2) :
                                           .white.opacity(0.2), 
                                           lineWidth: 1)
                            )
                    }
                )
        }
        .buttonStyle(ModernButtonStyle())
    }
}

private struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
