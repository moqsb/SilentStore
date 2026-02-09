import SwiftUI

struct TutorialView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var currentStep = 0
    
    let steps: [TutorialStep] = [
        TutorialStep(
            icon: "lock.shield.fill",
            title: NSLocalizedString("Secure Your Files", comment: ""),
            description: NSLocalizedString("All files are encrypted locally with AES-256. Your data stays private and secure.", comment: "")
        ),
        TutorialStep(
            icon: "folder.fill.badge.plus",
            title: NSLocalizedString("Organize with Folders", comment: ""),
            description: NSLocalizedString("Create folders, move files, and keep everything organized. Swipe left or right to navigate.", comment: "")
        ),
        TutorialStep(
            icon: "photo.on.rectangle",
            title: NSLocalizedString("Import Files", comment: ""),
            description: NSLocalizedString("Tap the + button to import photos, videos, or documents from your device.", comment: "")
        ),
        TutorialStep(
            icon: "hand.draw.fill",
            title: NSLocalizedString("Swipe Actions", comment: ""),
            description: NSLocalizedString("Swipe left to pin files, swipe right to share or delete. Long press for more options.", comment: "")
        ),
        TutorialStep(
            icon: "arrow.down.circle.fill",
            title: NSLocalizedString("Close Media Viewer", comment: ""),
            description: NSLocalizedString("Swipe down on any media to close the viewer. Swipe left or right to browse between files.", comment: "")
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? AppTheme.colors.accent : AppTheme.colors.secondaryText.opacity(0.3))
                            .frame(height: 4)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                // Content
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        TutorialStepView(step: steps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth(duration: 0.3), value: currentStep)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button {
                            HapticFeedback.play(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentStep -= 1
                            }
                        } label: {
                            Text(NSLocalizedString("Previous", comment: ""))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppTheme.colors.surface)
                                )
                        }
                        .buttonStyle(ModernButtonStyle())
                    }
                    
                    Button {
                        HapticFeedback.play(.medium)
                        if currentStep < steps.count - 1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                currentStep += 1
                            }
                        } else {
                            hasSeenTutorial = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }
                    } label: {
                        Text(currentStep < steps.count - 1 ? 
                             NSLocalizedString("Next", comment: "") : 
                             NSLocalizedString("Get Started", comment: ""))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.gradients.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: AppTheme.colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ModernButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            HapticFeedback.prepareAll()
        }
    }
}

struct TutorialStep {
    let icon: String
    let title: String
    let description: String
}

struct TutorialStepView: View {
    let step: TutorialStep
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.colors.accent.opacity(0.2),
                                AppTheme.colors.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(
                                AppTheme.gradients.accent,
                                lineWidth: 2
                            )
                    )
                    .shadow(color: AppTheme.colors.accent.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: step.icon)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).repeatForever(autoreverses: true), value: UUID())
            
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding(.top, 60)
    }
}

private struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
