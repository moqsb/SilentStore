import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthManager()
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var vaultStore: VaultStore
    @State private var showPermissions = false
    @AppStorage("faceIdEnabled") private var faceIdEnabled = true
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var isUnlocking = false
    @State private var passcode = ""
    @State private var passcodeError: String?
    @State private var isPasscodeUnlocking = false
    @State private var hasPasscode = false

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        _vaultStore = StateObject(wrappedValue: VaultStore(context: context))
    }

    var body: some View {
        ZStack {
            if didOnboard {
                MainTabView(vaultStore: vaultStore)
                    .environmentObject(vaultStore)
                    .opacity(shouldHideContent ? 0 : 1)
                    .allowsHitTesting(!shouldHideContent)
            } else {
                OnboardingView()
            }

            if shouldHideContent {
                AppTheme.gradients.background
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.colors.cardBackground)
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.colors.accent)
                    }
                    Text("SilentStore")
                        .font(AppTheme.fonts.title)
                        .foregroundStyle(AppTheme.colors.primaryText)
                    if hasPasscode {
                        Text(NSLocalizedString("Enter Passcode", comment: ""))
                            .font(AppTheme.fonts.subtitle)
                            .foregroundStyle(AppTheme.colors.secondaryText)
                            .padding(.top, 8)
                        if let passcodeError {
                            Text(passcodeError)
                                .font(AppTheme.fonts.caption)
                                .foregroundStyle(.red)
                                .padding(.top, 4)
                        }
                        PasscodeEntryView(passcode: $passcode, length: 6) {
                            Task { await unlockWithPasscode() }
                        }
                        .padding(.top, 20)
                        if faceIdEnabled {
                            Button {
                                HapticFeedback.play(.medium)
                                Task { await unlockWithBiometrics() }
                            } label: {
                                Image(systemName: "faceid")
                                    .font(.system(size: 36, weight: .light))
                                    .foregroundStyle(AppTheme.colors.accent)
                                    .frame(width: 70, height: 70)
                                    .background(
                                        Circle()
                                            .fill(AppTheme.colors.surface.opacity(0.4))
                                            .overlay(
                                                Circle()
                                                    .stroke(AppTheme.colors.accent.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(InteractiveButtonStyle(hapticStyle: .medium))
                            .padding(.top, 32)
                        }
                    } else {
                        Button("Unlock") {
                            Task { await unlockIfNeeded() }
                        }
                        .buttonStyle(AppTheme.buttons.primary)
                    }
                }
            }
        }
        .tint(AppTheme.colors.accent)
        .preferredColorScheme(preferredScheme)
        .sheet(isPresented: $showPermissions) {
            PermissionsView(permissionsManager: permissionsManager)
        }
        .onAppear {
            showPermissions = permissionsManager.shouldShowPermissionsSheet
            hasPasscode = KeyManager.shared.hasPasscode()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                authManager.lock()
                KeyManager.shared.clearMasterKeyFromMemory()
                vaultStore.markLocked()
            case .active:
                hasPasscode = KeyManager.shared.hasPasscode()
                if didOnboard {
                    Task { await unlockIfNeeded() }
                }
            default:
                break
            }
        }
        .onChange(of: didOnboard) { _, newValue in
            if newValue && scenePhase == .active {
                Task { await unlockIfNeeded() }
            }
        }
    }

    // Hide app content while locked or backgrounded.
    private var shouldHideContent: Bool {
        scenePhase == .background || !authManager.isAuthenticated || !vaultStore.isReady
    }

    private var preferredScheme: ColorScheme? {
        switch appearanceMode {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil
        }
    }

    // Perform biometric or passcode unlock before loading data.
    private func unlockIfNeeded() async {
        guard faceIdEnabled else { return }
        guard !isUnlocking else { return }
        isUnlocking = true
        defer { isUnlocking = false }
        let success = await authManager.authenticateIfNeeded(useBiometrics: faceIdEnabled)
        guard success else { return }
        // Small delay to ensure context is properly set in KeyManager
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        await vaultStore.prepareIfNeeded()
    }
    
    // Unlock with biometrics when button is tapped.
    private func unlockWithBiometrics() async {
        guard faceIdEnabled else { return }
        guard !isUnlocking else { return }
        isUnlocking = true
        defer { isUnlocking = false }
        // Force biometric authentication directly
        let success = await authManager.authenticate(useBiometrics: true)
        if success {
            HapticFeedback.play(.success)
            // Small delay to ensure context is properly set
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            await vaultStore.prepareIfNeeded()
        } else {
            HapticFeedback.play(.warning)
        }
    }

    // Unlock with app passcode and load data.
    private func unlockWithPasscode() async {
        guard !isPasscodeUnlocking else { return }
        guard passcode.count == 6 else { return }
        isPasscodeUnlocking = true
        defer { isPasscodeUnlocking = false }
        let success = await authManager.authenticateWithPasscode(passcode)
        if success {
            HapticFeedback.play(.success)
            passcodeError = nil
            passcode = ""
            await vaultStore.prepareIfNeeded()
        } else {
            HapticFeedback.play(.error)
            passcodeError = NSLocalizedString("Incorrect passcode.", comment: "")
            passcode = ""
        }
    }
}

#Preview {
    ContentView(context: PersistenceController.preview.container.viewContext)
}
