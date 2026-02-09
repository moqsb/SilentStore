import Foundation
import CryptoKit
import LocalAuthentication

final class KeyManager {
    static let shared = KeyManager()

    // Stores the wrapped master key and app passcode metadata in Keychain.
    private let wrappedKeyService = "com.silentstore.keys"
    private let wrappedKeyAccount = "wrappedMasterKey"
    private let recoveryService = "com.silentstore.recovery"
    private let recoveryAccount = "recoveryBlob"
    private let passcodeService = "com.silentstore.passcode"
    private let passcodeHashAccount = "passcodeHash"
    private let passcodeSaltAccount = "passcodeSalt"
    private let passcodeWrappedKeyAccount = "passcodeWrappedKey"

    private var cachedMasterKey: SymmetricKey?
    private var authContext: LAContext?

    func getOrCreateMasterKey() async throws -> SymmetricKey {
        if let cachedMasterKey { return cachedMasterKey }
        if let wrapped = try KeychainHelper.read(service: wrappedKeyService, account: wrappedKeyAccount) {
            // Try to load key with current auth context
            do {
                let privateKey = try SecureEnclaveHelper.loadOrCreateKeyPair(context: authContext)
                let raw = try SecureEnclaveHelper.unwrap(wrapped, with: privateKey, context: authContext)
                let key = SymmetricKey(data: raw)
                cachedMasterKey = key
                return key
            } catch {
                // If unwrap failed, it might be because auth context is invalid
                // Try to reload the key - this will trigger authentication if needed
                // But we need a valid context first
                if authContext == nil {
                    throw KeyManagerError.missingPasscodeData
                }
                // Re-throw the error - caller should handle authentication
                throw error
            }
        }
        let key = SymmetricKey(size: .bits256)
        let privateKey = try SecureEnclaveHelper.loadOrCreateKeyPair(context: authContext)
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let raw = key.withUnsafeBytes { Data($0) }
        let wrapped = try SecureEnclaveHelper.wrap(raw, with: publicKey)
        try KeychainHelper.save(wrapped, service: wrappedKeyService, account: wrappedKeyAccount)
        cachedMasterKey = key
        return key
    }

    func createRecoveryKey() async throws -> String {
        let masterKey = try await getOrCreateMasterKey()
        let recoveryKeyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let recoveryKey = SymmetricKey(data: recoveryKeyData)
        let masterKeyData = masterKey.withUnsafeBytes { Data($0) }
        let encrypted = try Crypto.encrypt(masterKeyData, using: recoveryKey)
        try KeychainHelper.save(encrypted, service: recoveryService, account: recoveryAccount)
        return recoveryKeyData.base64EncodedString()
    }

    func recoverMasterKey(from recoveryKey: String) async throws {
        guard let recoveryKeyData = Data(base64Encoded: recoveryKey) else {
            throw KeyManagerError.invalidRecoveryKey
        }
        guard let blob = try KeychainHelper.read(service: recoveryService, account: recoveryAccount) else {
            throw KeyManagerError.noRecoveryBlob
        }
        let recoverySymmetric = SymmetricKey(data: recoveryKeyData)
        let decrypted = try Crypto.decrypt(blob, using: recoverySymmetric)
        let masterKey = SymmetricKey(data: decrypted)
        let privateKey = try SecureEnclaveHelper.loadOrCreateKeyPair(context: authContext)
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let wrapped = try SecureEnclaveHelper.wrap(decrypted, with: publicKey)
        try KeychainHelper.save(wrapped, service: wrappedKeyService, account: wrappedKeyAccount)
        cachedMasterKey = masterKey
    }

    func clearMasterKeyFromMemory() {
        cachedMasterKey = nil
    }

    func setAuthenticationContext(_ context: LAContext?) {
        authContext = context
    }

    func hasPasscode() -> Bool {
        (try? KeychainHelper.read(service: passcodeService, account: passcodeHashAccount)) != nil
    }

    func setPasscode(_ passcode: String) async throws {
        guard passcode.count == 6 && passcode.allSatisfy({ $0.isNumber }) else {
            throw KeyManagerError.invalidPasscode
        }
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let hash = passcodeHash(passcode, salt: salt)
        let passcodeKey = derivePasscodeKey(passcode, salt: salt)
        let masterKey = try await getOrCreateMasterKey()
        let rawMasterKey = masterKey.withUnsafeBytes { Data($0) }
        let wrapped = try Crypto.encrypt(rawMasterKey, using: passcodeKey)
        try KeychainHelper.save(salt, service: passcodeService, account: passcodeSaltAccount)
        try KeychainHelper.save(hash, service: passcodeService, account: passcodeHashAccount)
        try KeychainHelper.save(wrapped, service: passcodeService, account: passcodeWrappedKeyAccount)
    }

    func verifyPasscode(_ passcode: String) throws -> Bool {
        guard passcode.count == 6 && passcode.allSatisfy({ $0.isNumber }) else {
            return false
        }
        guard
            let salt = try KeychainHelper.read(service: passcodeService, account: passcodeSaltAccount),
            let storedHash = try KeychainHelper.read(service: passcodeService, account: passcodeHashAccount)
        else {
            return false
        }
        return passcodeHash(passcode, salt: salt) == storedHash
    }

    func unlockWithPasscode(_ passcode: String) throws -> Bool {
        guard passcode.count == 6 && passcode.allSatisfy({ $0.isNumber }) else {
            return false
        }
        guard try verifyPasscode(passcode) else { return false }
        guard
            let salt = try KeychainHelper.read(service: passcodeService, account: passcodeSaltAccount),
            let wrapped = try KeychainHelper.read(service: passcodeService, account: passcodeWrappedKeyAccount)
        else {
            throw KeyManagerError.missingPasscodeData
        }
        let passcodeKey = derivePasscodeKey(passcode, salt: salt)
        let raw = try Crypto.decrypt(wrapped, using: passcodeKey)
        cachedMasterKey = SymmetricKey(data: raw)
        // Clear auth context when using passcode - will need fresh auth for Secure Enclave
        authContext = nil
        return true
    }

    func changePasscode(current: String, new: String) async throws {
        let ok = try verifyPasscode(current)
        guard ok else { throw KeyManagerError.invalidPasscode }
        _ = try unlockWithPasscode(current)
        try await setPasscode(new)
    }

    func clearPasscode() throws {
        try KeychainHelper.delete(service: passcodeService, account: passcodeHashAccount)
        try KeychainHelper.delete(service: passcodeService, account: passcodeSaltAccount)
        try KeychainHelper.delete(service: passcodeService, account: passcodeWrappedKeyAccount)
    }

    func resetAllSecrets() {
        try? KeychainHelper.delete(service: wrappedKeyService, account: wrappedKeyAccount)
        try? KeychainHelper.delete(service: recoveryService, account: recoveryAccount)
        try? clearPasscode()
        try? SecureEnclaveHelper.deleteKeyPair()
        cachedMasterKey = nil
        authContext = nil
    }

    private func derivePasscodeKey(_ passcode: String, salt: Data) -> SymmetricKey {
        let input = SymmetricKey(data: Data(passcode.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: input,
            salt: salt,
            info: Data("silentstore-passcode".utf8),
            outputByteCount: 32
        )
    }

    private func passcodeHash(_ passcode: String, salt: Data) -> Data {
        var data = Data()
        data.append(salt)
        data.append(Data(passcode.utf8))
        return Data(SHA256.hash(data: data))
    }
}

enum KeyManagerError: Error {
    case invalidRecoveryKey
    case noRecoveryBlob
    case invalidPasscode
    case missingPasscodeData
}
