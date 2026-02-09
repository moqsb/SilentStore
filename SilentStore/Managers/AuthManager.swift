import Foundation
import Combine
import LocalAuthentication

@MainActor
final class AuthManager: ObservableObject {
    // Centralized authentication state and biometric flow.
    @Published private(set) var isAuthenticated = false
    private var lastAuthDate: Date?
    private let graceInterval: TimeInterval = 60
    private var lastAuthContext: LAContext?

    func authenticateIfNeeded(useBiometrics: Bool) async -> Bool {
        guard !isAuthenticated else { return true }
        if isWithinGracePeriod() {
            isAuthenticated = true
            return true
        }
        return await authenticate(useBiometrics: useBiometrics)
    }

    func lock() {
        isAuthenticated = false
        lastAuthContext = nil
        KeyManager.shared.setAuthenticationContext(nil)
    }

    func authenticateWithPasscode(_ passcode: String) async -> Bool {
        do {
            let success = try KeyManager.shared.unlockWithPasscode(passcode)
            if success {
                isAuthenticated = true
                lastAuthDate = Date()
            }
            return success
        } catch {
            return false
        }
    }

    func authenticate(useBiometrics: Bool) async -> Bool {
        let context = LAContext()
        if useBiometrics {
            context.localizedFallbackTitle = ""
            context.touchIDAuthenticationAllowableReuseDuration = graceInterval
        }
        var error: NSError?
        let policy: LAPolicy = useBiometrics ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        let canEvaluate = context.canEvaluatePolicy(policy, error: &error)
        guard canEvaluate else {
            isAuthenticated = false
            return false
        }

        let reason = "Unlock SilentStore"
        return await withCheckedContinuation { continuation in
            var didComplete = false

            let finish: @MainActor (Bool) -> Void = { success in
                guard !didComplete else { return }
                didComplete = true
                self.isAuthenticated = success
                if success {
                    self.lastAuthDate = Date()
                    self.lastAuthContext = context
                    KeyManager.shared.setAuthenticationContext(context)
                }
                continuation.resume(returning: success)
            }

            let timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                finish(true)
            }

            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    timeoutTask.cancel()
                    finish(success)
                }
            }
        }
    }

    private func isWithinGracePeriod() -> Bool {
        guard let lastAuthDate else { return false }
        return Date().timeIntervalSince(lastAuthDate) < graceInterval
    }
}
