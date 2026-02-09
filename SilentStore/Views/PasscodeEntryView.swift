import SwiftUI

struct PasscodeEntryView: View {
    @Binding var passcode: String
    let length: Int
    let onComplete: (() -> Void)?
    @State private var shakeOffset: CGFloat = 0
    
    init(passcode: Binding<String>, length: Int = 6, onComplete: (() -> Void)? = nil) {
        self._passcode = passcode
        self.length = length
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Passcode dots
            HStack(spacing: 16) {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .fill(index < passcode.count ? AppTheme.colors.accent : Color.clear)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.colors.primaryText.opacity(index < passcode.count ? 0 : 0.4), lineWidth: 1.5)
                        )
                }
            }
            .offset(x: shakeOffset)
            .animation(.easeInOut(duration: 0.1), value: shakeOffset)
            .padding(.bottom, 8)
            
            // Number pad
            VStack(spacing: 20) {
                ForEach(0..<3) { row in
                    HStack(spacing: 40) {
                        ForEach(1..<4) { col in
                            let num = row * 3 + col
                            numberButton(num)
                        }
                    }
                }
                // Bottom row: 0, delete
                HStack(spacing: 40) {
                    Spacer()
                        .frame(width: 80)
                    numberButton(0)
                    deleteButton
                }
            }
        }
        .onChange(of: passcode) { _, newValue in
            // Limit to 6 digits
            if newValue.count > length {
                passcode = String(newValue.prefix(length))
            }
            // Auto-complete when 6 digits entered
            if passcode.count == length, let onComplete {
                HapticFeedback.play(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onComplete()
                }
            }
        }
    }
    
    private func numberButton(_ num: Int) -> some View {
        Button {
            if passcode.count < length {
                HapticFeedback.play(.light)
                passcode += "\(num)"
            }
        } label: {
            Text("\(num)")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppTheme.colors.primaryText)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(AppTheme.colors.surface.opacity(0.3))
                )
        }
        .buttonStyle(InteractiveButtonStyle(hapticStyle: .light))
    }
    
    private var deleteButton: some View {
        Button {
            if !passcode.isEmpty {
                HapticFeedback.play(.medium)
                passcode.removeLast()
            }
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(AppTheme.colors.primaryText)
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(AppTheme.colors.surface.opacity(0.3))
                )
        }
        .buttonStyle(InteractiveButtonStyle(hapticStyle: .medium))
    }
    
    func shake() {
        withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeOffset = 0
        }
    }
}

#Preview {
    @Previewable @State var passcode = ""
    return PasscodeEntryView(passcode: $passcode)
        .padding()
        .background(AppTheme.gradients.background)
}
