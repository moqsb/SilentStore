import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthManager()
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var vaultStore: VaultStore
    @State private var showPermissions = false
    @AppStorage("didOnboard") private var didOnboard = false
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("faceIdEnabled") private var faceIdEnabled = false
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
                LockScreenView(
                    passcode: $passcode,
                    passcodeError: $passcodeError,
                    hasPasscode: hasPasscode,
                    faceIdEnabled: faceIdEnabled,
                    onUnlock: { Task { await unlockWithPasscode() } },
                    onBiometricUnlock: { Task { await unlockWithBiometrics() } }
                )
                .onAppear {
                    // Auto-trigger Face ID if enabled when lock screen appears
                    if faceIdEnabled && !isUnlocking && !isPasscodeUnlocking {
                        Task {
                            await unlockWithBiometrics()
                        }
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
            HapticFeedback.prepareAll()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                authManager.lock()
                KeyManager.shared.clearMasterKeyFromMemory()
                vaultStore.markLocked()
                // Save locked state
                UserDefaults.standard.set(true, forKey: "isLocked")
            case .active:
                hasPasscode = KeyManager.shared.hasPasscode()
                // Check if app was locked and should auto-unlock with Face ID
                let wasLocked = UserDefaults.standard.bool(forKey: "isLocked")
                if wasLocked && faceIdEnabled && shouldHideContent {
                    // Small delay to ensure lock screen is visible
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        await unlockWithBiometrics()
                    }
                }
            default:
                break
            }
        }
        .onChange(of: didOnboard) { _, newValue in
            if newValue {
                hasPasscode = KeyManager.shared.hasPasscode()
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
            // Clear locked state
            UserDefaults.standard.set(false, forKey: "isLocked")
            await vaultStore.prepareIfNeeded()
        } else {
            HapticFeedback.play(.error)
            passcodeError = NSLocalizedString("Incorrect passcode.", comment: "")
            passcode = ""
        }
    }
    
    // Unlock with biometrics when button is tapped or auto-triggered (only if enabled)
    private func unlockWithBiometrics() async {
        guard faceIdEnabled else { return }
        guard !isUnlocking else { return }
        isUnlocking = true
        defer { isUnlocking = false }
        let success = await authManager.authenticate(useBiometrics: true)
        if success {
            HapticFeedback.play(.success)
            passcodeError = nil
            passcode = ""
            // Clear locked state
            UserDefaults.standard.set(false, forKey: "isLocked")
            await vaultStore.prepareIfNeeded()
        } else {
            HapticFeedback.play(.warning)
        }
    }
}

#Preview {
    ContentView(context: PersistenceController.preview.container.viewContext)
}
