import Foundation
import Combine
import LocalAuthentication

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated = false
    private var lastAuthDate: Date?
    private let graceInterval: TimeInterval = 60

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
    }

    private func authenticate(useBiometrics: Bool) async -> Bool {
        let context = LAContext()
        if useBiometrics {
            context.localizedFallbackTitle = ""
        }
        var error: NSError?
        let policy: LAPolicy = useBiometrics ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        let canEvaluate = context.canEvaluatePolicy(policy, error: &error)
        guard canEvaluate else {
            isAuthenticated = true
            return true
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
