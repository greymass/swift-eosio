/// EOSIO public key type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// Type representing a EOSIO public key.
public struct PublicKey: Equatable, Hashable {
    /// Private storage container that holds public key data.
    private enum StorageType: Equatable, Hashable {
        case k1(key: Data)
        case unknown(name: String, data: Data)
    }

    /// Errors `PublicKey` can throw.
    public enum Error: Swift.Error {
        case parsingFailed(_ message: String)
        case invalidK1(_ message: String)
        case unknownSignatureType
    }

    /// The key data.
    private let value: StorageType

    /// Create a new `PublicKey` from the private storage type.
    private init(value: StorageType) {
        self.value = value
    }

    /// Create a new `PublicKey` from type and signature data.
    public init(type: String, data: Data) throws {
        guard type.count == 2, type.uppercased() == type else {
            throw Error.parsingFailed("Invalid curve type")
        }
        self.value = .unknown(name: type, data: data)
    }

    /// Create new PublicKey instance from k1 data.
    /// - Parameter data: The 33-byte compressed public key.
    public init(fromK1Data data: Data) throws {
        guard data.count == 33 else {
            throw Error.invalidK1("Expected 33 bytes, got \(data.count)")
        }
        self.value = .k1(key: data)
    }

    /// Create new PublicKey instance from a public key string.
    public init(stringValue: String) throws {
        if stringValue.starts(with: "PUB_") {
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
                try self.init(fromK1Data: data)
            default:
                try self.init(type: String(parts[1]), data: data)
            }
        } else { // legacy K1 format
            guard stringValue.count >= 50 else {
                throw Error.parsingFailed("Malformed key string")
            }
            let keyStr = String(stringValue.suffix(50))
            guard let data = Data(base58CheckEncoded: keyStr, .ripemd160) else {
                throw Error.parsingFailed("Unable to decode base58")
            }
            try self.init(fromK1Data: data)
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

    /// The underlying key data.
    public var keyData: Data {
        switch self.value {
        case let .k1(data):
            return data
        case let .unknown(_, data):
            return data
        }
    }

    /// The string representation of the public key in modern EOSIO format, `PUB_<type>_<base58key>`.
    public var stringValue: String {
        let type = self.keyType
        let encoded = self.keyData.base58CheckEncodedString(.ripemd160Extra(Data(type.utf8)))!
        return "PUB_\(type)_\(encoded)"
    }

    /// Format key to legacy public key string representation using given prefix, `<prefix><base58key>`.
    /// - Note: Returns `nil` for other key formats than `K1`.
    public func legacyFormattedString(_ prefix: String = "EOS") -> String? {
        switch self.value {
        case let .k1(key):
            return "\(prefix)\(key.base58CheckEncodedString(.ripemd160)!)"
        default:
            return nil
        }
    }

    /// Legacy public key representation format, `EOS<base58key>`.
    /// - Note: Returns `nil` for other key formats than `K1`.
    public var legacyStringValue: String? {
        return self.legacyFormattedString()
    }
}

// MARK: ABI Coding

extension PublicKey: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(stringValue: try container.decode(String.self))
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let type = try decoder.decode(UInt8.self)
        let data = try decoder.decode(Data.self, byteCount: 33)
        if type == 0 {
            self.value = .k1(key: data)
        } else {
            switch type {
            case 1:
                self.value = .unknown(name: "R1", data: data)
            case 2:
                self.value = .unknown(name: "WA", data: data)
            default:
                self.value = .unknown(name: "XX", data: data)
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        switch self.value {
        case let .k1(data):
            try encoder.encode(0 as UInt8)
            try encoder.encode(contentsOf: data)
        case let .unknown(name, data):
            let type: UInt8
            switch name {
            case "R1":
                type = 1
            case "WA":
                type = 2
            default:
                type = 255
            }
            try encoder.encode(type)
            try encoder.encode(contentsOf: data)
        }
    }
}

// MARK: Language extensions

extension PublicKey: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let instance = try? PublicKey(stringValue: description) else {
            return nil
        }
        self = instance
    }

    public var description: String {
        return self.stringValue
    }
}

extension PublicKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let instance = try? PublicKey(stringValue: value) else {
            fatalError("Invalid PublicKey literal")
        }
        self = instance
    }
}
