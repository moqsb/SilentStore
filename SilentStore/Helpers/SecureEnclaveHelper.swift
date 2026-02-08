import Foundation
import Security

enum SecureEnclaveHelper {
    private static let tag = "com.silentstore.secureenclave.key".data(using: .utf8)!

    static func loadOrCreateKeyPair() throws -> SecKey {
        if let existing = try loadPrivateKey() {
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

    private static func loadPrivateKey() throws -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw SecureEnclaveError.queryFailed(status: status)
        }
        return item as! SecKey
    }
}

enum SecureEnclaveError: Error {
    case keyCreationFailed
    case wrapFailed
    case unwrapFailed
    case queryFailed(status: OSStatus)
}
