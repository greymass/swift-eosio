
import Foundation

/// The EOSIO checksum160 type, a.k.a RIPEMD160.
public struct Checksum160: Equatable, Hashable {
    /// The 20-byte ripemd160 checksum.
    public let bytes: Data

    /// Create a new `Checksum160` from given data.
    /// - Parameter data: Data to be hashed.
    public static func hash(_ data: Data) -> Checksum160 {
        return Checksum160(data.ripemd160Digest)
    }

    internal init(_ bytes: Data) {
        assert(bytes.count == 20, "invalid checksum")
        self.bytes = bytes
    }
}

/// The EOSIO checksum256 type, a.k.a SHA256.
public struct Checksum256: Equatable, Hashable {
    /// The 32-byte sha256 checksum.
    public let bytes: Data

    /// Create a new `Checksum256` from given data.
    /// - Parameter data: Data to be hashed.
    public static func hash(_ data: Data) -> Checksum256 {
        return Checksum256(data.sha256Digest)
    }

    internal init(_ bytes: Data) {
        assert(bytes.count == 32, "invalid checksum")
        self.bytes = bytes
    }
}

/// The EOSIO checksum512 type, a.k.a SHA512.
public struct Checksum512: Equatable, Hashable {
    /// The 64-byte sha512 checksum.
    public let bytes: Data

    /// Create a new `Checksum256` from given data.
    /// - Parameter data: Data to be hashed.
    public static func hash(_ data: Data) -> Checksum512 {
        return Checksum512(data.sha512Digest)
    }

    internal init(_ bytes: Data) {
        assert(bytes.count == 64, "invalid checksum")
        self.bytes = bytes
    }
}

extension Checksum160: LosslessStringConvertible {
    public init?(_ description: String) {
        let data = Data(hexEncoded: description)
        guard data.count == 20 else {
            return nil
        }
        self.init(data)
    }

    public var description: String {
        return self.bytes.hexEncodedString()
    }
}

extension Checksum256: LosslessStringConvertible {
    public init?(_ description: String) {
        let data = Data(hexEncoded: description)
        guard data.count == 32 else {
            return nil
        }
        self.init(data)
    }

    public var description: String {
        return self.bytes.hexEncodedString()
    }
}

extension Checksum512: LosslessStringConvertible {
    public init?(_ description: String) {
        let data = Data(hexEncoded: description)
        guard data.count == 64 else {
            return nil
        }
        self.init(data)
    }

    public var description: String {
        return self.bytes.hexEncodedString()
    }
}

extension Checksum160: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let bytes = Data(hexEncoded: value)
        guard bytes.count == 20 else {
            fatalError("Invalid Checksum120 literal")
        }
        self.init(bytes)
    }
}

extension Checksum256: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let bytes = Data(hexEncoded: value)
        guard bytes.count == 32 else {
            fatalError("Invalid Checksum256 literal")
        }
        self.init(bytes)
    }
}

extension Checksum512: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let bytes = Data(hexEncoded: value)
        guard bytes.count == 64 else {
            fatalError("Invalid Checksum512 literal")
        }
        self.init(bytes)
    }
}

extension Checksum160: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = Data(hexEncoded: try container.decode(String.self))
        if data.count != 20 {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Encountered invalid checksum (expected 20 bytes got \(data.count))"
            )
        }
        self.init(data)
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        self.init(try decoder.decode(Data.self, byteCount: 20))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(contentsOf: self.bytes)
    }
}

extension Checksum256: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = Data(hexEncoded: try container.decode(String.self))
        if data.count != 32 {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Encountered invalid checksum (expected 32 bytes got \(data.count))"
            )
        }
        self.init(data)
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        self.init(try decoder.decode(Data.self, byteCount: 32))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(contentsOf: self.bytes)
    }
}

extension Checksum512: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = Data(hexEncoded: try container.decode(String.self))
        if data.count != 64 {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Encountered invalid checksum (expected 64 bytes got \(data.count))"
            )
        }
        self.init(data)
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        self.init(try decoder.decode(Data.self, byteCount: 64))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(contentsOf: self.bytes)
    }
}
