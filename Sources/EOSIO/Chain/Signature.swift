/// EOSIO signature type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// Type representing a EOSIO signature.
public struct Signature: Equatable, Hashable {
    /// Private storage container that holds signature data.
    private enum StorageType: Equatable, Hashable {
        case k1(sig: Data, recovery: Int8)
        case unknown(name: String, data: Data)
    }

    /// Errors `Signature` can throw.
    public enum Error: Swift.Error {
        case parsingFailed(_ message: String)
        case invalidK1(_ message: String)
        case unknownSignatureType
    }

    /// Invalid signature, used to represent invalid string literals.
    public static let invalid = Signature(value: .unknown(name: "XX", data: Data(repeating: 0, count: 8)))

    /// The signature data.
    private let value: StorageType

    /// Create a new `Signature` from the private storage type.
    private init(value: StorageType) {
        self.value = value
    }

    public init(fromK1Data data: Data) throws {
        guard data.count == 65 else {
            throw Error.invalidK1("Expected 65 bytes, got \(data.count)")
        }
        self.value = .k1(sig: data.suffix(from: 1), recovery: Int8(data[0]) - 31)
    }

    public init(fromK1 sig: Data, recovery: Int8) {
        self.value = .k1(sig: sig, recovery: recovery)
    }

    public init(stringValue: String) throws {
        let parts = stringValue.split(separator: "_")
        guard parts.count == 3 else {
            throw Error.parsingFailed("Malformed signature string")
        }
        guard parts[0] == "SIG" else {
            throw Error.parsingFailed("Expected SIG prefix")
        }
        let checksumData = parts[1].data(using: .utf8) ?? Data(repeating: 0, count: 4)
        guard let data = Data(base58CheckEncoded: String(parts[2]), .ripemd160Extra(checksumData)) else {
            throw Error.parsingFailed("Unable to decode base58")
        }
        switch parts[1] {
        case "K1":
            try self.init(fromK1Data: data)
        default:
            guard parts[1].count == 2, parts[1].uppercased() == parts[1] else {
                throw Error.parsingFailed("Invalid curve type")
            }
            self.init(value: .unknown(name: String(parts[1]), data: data))
        }
    }

    public func verify(_ hash: Checksum256, using key: PublicKey) -> Bool {
        switch self.value {
        case let .k1(sig, _):
            return Secp256k1.shared.verify(signature: sig, message: hash.bytes, publicKey: key.keyData)
        case .unknown:
            return false
        }
    }

    public func verify(_ data: Data, using key: PublicKey) -> Bool {
        return self.verify(Checksum256.hash(data), using: key)
    }

    public func recoverPublicKey(from hash: Checksum256) throws -> PublicKey {
        switch self.value {
        case let .k1(sig, recId):
            let recovered = try Secp256k1.shared.recover(
                message: hash.bytes, signature: sig, recoveryId: Int32(recId)
            )
            return try PublicKey(fromK1Data: recovered)
        case .unknown:
            throw Error.unknownSignatureType
        }
    }

    public func recoverPublicKey(from message: Data) throws -> PublicKey {
        return try self.recoverPublicKey(from: Checksum256.hash(message))
    }

    var signatureType: String {
        switch self.value {
        case .k1:
            return "K1"
        case let .unknown(name, _):
            return name
        }
    }

    var signatureData: Data {
        switch self.value {
        case let .k1(sig, recovery):
            return Data([UInt8(recovery) + 31]) + sig
        case let .unknown(_, data):
            return data
        }
    }

    var stringValue: String {
        let type = self.signatureType
        let encoded = self.signatureData.base58CheckEncodedString(.ripemd160Extra(Data(type.utf8)))!
        return "SIG_\(type)_\(encoded)"
    }
}

// MARK: Language extensions

extension Signature: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let instance = try? Signature(stringValue: description) else {
            return nil
        }
        self = instance
    }

    public var description: String {
        return self.stringValue
    }
}

extension Signature: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        if let instance = try? Signature(stringValue: value) {
            self = instance
        } else {
            self = Self.invalid
        }
    }
}
