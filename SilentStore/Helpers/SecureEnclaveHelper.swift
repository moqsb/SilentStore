import Foundation
import Security
import LocalAuthentication

enum SecureEnclaveHelper {
    private static let tag = "com.silentstore.secureenclave.key".data(using: .utf8)!

    static func loadOrCreateKeyPair(context: LAContext? = nil) throws -> SecKey {
        if let existing = try loadPrivateKey(context: context) {
            return existing
        }

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.privateKeyUsage, .userPresence],
            nil
        )

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access as Any
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? SecureEnclaveError.keyCreationFailed
        }
        return privateKey
    }

    static func wrap(_ data: Data, with publicKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            publicKey,
            .eciesEncryptionCofactorX963SHA256AESGCM,
            data as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() ?? SecureEnclaveError.wrapFailed
        }
        return encrypted
    }

    static func unwrap(_ data: Data, with privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(
            privateKey,
            .eciesEncryptionCofactorX963SHA256AESGCM,
            data as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() ?? SecureEnclaveError.unwrapFailed
        }
        return decrypted
    }

    private static func loadPrivateKey(context: LAContext?) throws -> SecKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw SecureEnclaveError.queryFailed(status: status)
        }
        guard let item else {
            throw SecureEnclaveError.queryFailed(status: errSecInternalComponent)
        }
        let typeMatches = CFGetTypeID(item) == SecKeyGetTypeID()
        guard typeMatches else {
            throw SecureEnclaveError.queryFailed(status: errSecInternalComponent)
        }
        return (item as! SecKey)
    }

    static func deleteKeyPair() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tag
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureEnclaveError.queryFailed(status: status)
        }
    }
}

enum SecureEnclaveError: Error {
    case keyCreationFailed
    case wrapFailed
    case unwrapFailed
    case queryFailed(status: OSStatus)
}
