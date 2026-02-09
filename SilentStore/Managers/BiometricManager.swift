import Foundation
import LocalAuthentication

enum BiometricStatus {
    case available
    case notAvailable
    case notDetermined
    case denied
}

@MainActor
final class BiometricManager {
    static let shared = BiometricManager()
    
    private init() {}
    
    /// Check if biometric authentication is available
    func checkAvailability() -> BiometricStatus {
        let context = LAContext()
        var error: NSError?
        
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        if let error = error {
            switch error.code {
            case LAError.biometryNotAvailable.rawValue:
                return .notAvailable
            case LAError.biometryNotEnrolled.rawValue:
                return .notAvailable
            case LAError.biometryLockout.rawValue:
                return .denied
            default:
                return .notDetermined
            }
        }
        
        if canEvaluate {
            return .available
        }
        
        return .notAvailable
    }
    
    /// Request biometric permission silently (without showing alert if previously denied)
    /// Returns true if permission is available and can be used, false otherwise
    func requestPermissionSilently() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        guard canEvaluate else {
            return false
        }
        
        // Check if biometrics are enrolled and available
        // This doesn't trigger the permission prompt if user hasn't been asked before
        // It only checks availability
        return true
    }
    
    /// Request biometric permission with user prompt
    func requestPermission() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        guard canEvaluate else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            let reason = NSLocalizedString("Enable Face ID / Touch ID to unlock your vault quickly and securely.", comment: "")
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                continuation.resume(returning: success)
            }
        }
    }
}
