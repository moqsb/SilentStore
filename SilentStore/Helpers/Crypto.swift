import Foundation
import CryptoKit

enum Crypto {
    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.invalidSeal
        }
        return combined
    }

    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum CryptoError: Error {
    case invalidSeal
}

extension Data {
    mutating func zeroOut() {
        resetBytes(in: 0..<count)
    }
}
