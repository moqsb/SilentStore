import Foundation
import CryptoKit
import LocalAuthentication

final class KeyManager {
    static let shared = KeyManager()

    private let wrappedKeyService = "com.silentstore.keys"
    private let wrappedKeyAccount = "wrappedMasterKey"
    private let recoveryService = "com.silentstore.recovery"
    private let recoveryAccount = "recoveryBlob"

    private var cachedMasterKey: SymmetricKey?

    func getOrCreateMasterKey() async throws -> SymmetricKey {
        if let cachedMasterKey { return cachedMasterKey }
        if let wrapped = try KeychainHelper.read(service: wrappedKeyService, account: wrappedKeyAccount) {
            let privateKey = try SecureEnclaveHelper.loadOrCreateKeyPair()
            let raw = try SecureEnclaveHelper.unwrap(wrapped, with: privateKey)
            let key = SymmetricKey(data: raw)
            cachedMasterKey = key
            return key
        }
        let key = SymmetricKey(size: .bits256)
        let privateKey = try SecureEnclaveHelper.loadOrCreateKeyPair()
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
        let privateKey = try SecureEnclaveHelper.loadOrCreateKeyPair()
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let wrapped = try SecureEnclaveHelper.wrap(decrypted, with: publicKey)
        try KeychainHelper.save(wrapped, service: wrappedKeyService, account: wrappedKeyAccount)
        cachedMasterKey = masterKey
    }

    func clearMasterKeyFromMemory() {
        cachedMasterKey = nil
    }
}

enum KeyManagerError: Error {
    case invalidRecoveryKey
    case noRecoveryBlob
}
