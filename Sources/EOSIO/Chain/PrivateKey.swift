/// EOSIO private key type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// Type representing a EOSIO private key.
public struct PrivateKey: Equatable, Hashable {
    /// Private storage container that holds key data.
    private enum StorageType: Equatable, Hashable {
        case k1(secret: Data)
        case unknown(name: String, data: Data)
    }

    /// All errors `PrivateKey` can throw.
    public enum Error: Swift.Error {
        case parsingFailed(_ message: String)
        case invalidK1(_ message: String)
        case unknownKeyType
    }

    /// The key data.
    private let value: StorageType

    /// Create a new `PrivateKey` instance from k1 data.
    public init(fromK1Data data: Data) throws {
        guard data.count == 33 else {
            throw Error.invalidK1("Expected 33 bytes, got \(data.count)")
        }
        guard data[0] == 0x80 else {
            throw Error.invalidK1("Invalid network ID: expected 0x80, got \(data[0])")
        }
        self.value = .k1(secret: data.suffix(from: 1))
    }

    private init(value: StorageType) {
        self.value = value
    }

    /// Create a `PrivateKey` instance from a secp256k1 key encoded in WIF format or using the EOSIO-style `PVT_<curve>_base56secret` format.
    public init(stringValue: String) throws {
        if stringValue.starts(with: "PVT_") { // new EOSIO format
            let parts = stringValue.split(separator: "_")
            guard parts.count == 3 else {
                throw Error.parsingFailed("Malformed key string")
            }
            let checksumData = parts[1].data(using: .utf8) ?? Data(repeating: 0, count: 4)
            guard let data = Data(base58CheckEncoded: String(parts[2]), .ripemd160Extra(checksumData)) else {
                throw Error.parsingFailed("Unable to decode base58")
            }
            switch parts[1] {
            case "K1":
                try self.init(fromK1Data: [0x80] + data)
            default:
                guard parts[1].count == 2, parts[1].uppercased() == parts[1] else {
                    throw Error.parsingFailed("Invalid key type")
                }
                self.init(value: .unknown(name: String(parts[1]), data: data))
            }
        } else { // WIF format
            guard let secret = Data(base58CheckEncoded: stringValue, .sha256d) else {
                throw Error.parsingFailed("Unable to decode base58")
            }
            try self.init(fromK1Data: secret)
        }
    }

    /// Sign a 32-byte digest using this key.
    public func sign(_ hash: Checksum256) throws -> Signature {
        switch self.value {
        case let .k1(secret):
            let res = try signK1(message: hash.bytes, using: secret)
            return Signature(fromK1: res.0, recovery: Int8(res.1))
        default:
            throw Error.unknownKeyType
        }
    }

    /// Sign a data buffer using this key.
    public func sign(_ data: Data) throws -> Signature {
        return try self.sign(Checksum256.hash(data))
    }

    /// Sign a transaction using this key.
    public func sign(_ transaction: Transaction, using chainId: ChainId) throws -> Signature {
        let digest = try transaction.digest(using: chainId)
        return try self.sign(digest)
    }

    /// Return the corresponding public key for this instance.
    public func getPublic() throws -> PublicKey {
        switch self.value {
        case let .k1(secret):
            let res = try Secp256k1.shared.createPublic(fromSecret: secret)
            return try PublicKey(fromK1Data: res)
        case .unknown:
            throw Error.unknownKeyType
        }
    }

    /// Get the shared secret for given public key.
    public func sharedSecret(for publicKey: PublicKey) throws -> Data {
        switch self.value {
        case let .k1(secret):
            return try Secp256k1.shared.sharedSecret(publicKey: publicKey.keyData, secretKey: secret)
        case .unknown:
            throw Error.unknownKeyType
        }
    }

    /// The key type as a string, .e.g. K1 or R1.
    public var keyType: String {
        switch self.value {
        case .k1:
            return "K1"
        case let .unknown(name, _):
            return name
        }
    }

    /// The key secret.
    public var keyData: Data {
        switch self.value {
        case let .k1(secret):
            return secret
        case let .unknown(_, data):
            return data
        }
    }

    /// The private key represented as WIF* for k1 keys or EOSIO-style `PVT_<type>_base58` for others.
    public var stringValue: String {
        switch self.value {
        case let .k1(secret): // encode as WIF
            var data = Data([0x80]) // network id is fixed to 0x80 (a.k.a. mainnet)
            data.append(contentsOf: secret)
            return data.base58CheckEncodedString(.sha256d)!
        case let .unknown(name, data):
            let encoded = data.base58CheckEncodedString(.ripemd160Extra(Data(name.utf8)))!
            return "PVT_\(name)_\(encoded)"
        }
    }
}

// MARK: Secp256k1 signing helpers

private func signK1(message: Data, using secret: Data) throws -> (Data, Int32) {
    var result: (Data, Int32)
    var ndata = Data(count: 32)
    repeat {
        guard ndata[0] != 255 else {
            // if we haven't found a "canonical" signature by now something is seriously wrong
            throw NSError(domain: "gov.damogran.heart-of-gold", code: 42, userInfo: nil)
        }
        ndata[0] += 1
        result = try Secp256k1.shared.sign(message: message, secretKey: secret, ndata: ndata)
    } while !isCanonicalK1(result.0)
    return result
}

/// here be dragons
/// https://github.com/EOSIO/eos/issues/6699
/// https://github.com/EOSIO/eos/issues/4299
private func isCanonicalK1(_ sig: Data) -> Bool {
    return (
        (sig[0] & 0x80 == 0) &&
            !(sig[0] == 0 && (sig[1] & 0x80 == 0)) &&
            (sig[32] & 0x80 == 0) &&
            !(sig[32] == 0 && (sig[33] & 0x80 == 0))
    )
}

// MARK: Language extensions

// not confirming to LosslessStringConvertible so that secrets can't be unintentionally printed
public extension PrivateKey {
    init?(_ wif: String) {
        guard let instance = try? PrivateKey(stringValue: wif) else {
            return nil
        }
        self = instance
    }
}

extension PrivateKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let instance = try? PrivateKey(stringValue: value) else {
            fatalError("Invalid PrivateKey literal")
        }
        self = instance
    }
}

extension PrivateKey: CustomStringConvertible {
    public var description: String {
        return "PrivateKey\(self.keyType)"
    }
}
