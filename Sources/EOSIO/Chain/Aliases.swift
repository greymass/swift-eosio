/// EOSIO Type aliases, matching the eosio::chain library for convenience.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

// https://github.com/EOSIO/eos/blob/eb88d033c0abbc481b8a481485ef4218cdaa033a/libraries/chain/include/eosio/chain/types.hpp

import Foundation

public typealias ChainId = Checksum256
public typealias BlockId = Checksum256

public extension BlockId {
    /// Get the block prefix, the lower 32 bits of the `BlockId`.
    var blockPrefix: UInt32 {
        self.bytes.withUnsafeBytes {
            $0.load(fromByteOffset: 8, as: UInt32.self)
        }
    }

    /// Get the block number.
    var blockNum: BlockNum {
        self.bytes.withUnsafeBytes {
            UInt32(bigEndian: $0.load(fromByteOffset: 0, as: UInt32.self))
        }
    }
}

public typealias TransactionId = Checksum256
public typealias Digest = Checksum256
public typealias Weight = UInt16
public typealias BlockNum = UInt32
public typealias Share = Int64
public typealias Bytes = Data

public typealias AccountName = Name

/// Type representing a blob of data, same as `Bytes` but wire encoding is is base64.
public struct Blob: Equatable, Hashable, Codable {
    public let bytes: Bytes

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let base64 = BlockOne64(try container.decode(String.self))
        guard let bytes = Bytes(base64Encoded: BlockOne64(base64)) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid Base64 string"
            )
        }
        self.bytes = bytes
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.bytes = try container.decode(Data.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.bytes.base64EncodedString())
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.bytes)
    }
}

// Fix incorrect Base64 padding
// https://github.com/EOSIO/eos/issues/8161
private func BlockOne64(_ str: String) -> String {
    let bare = str.trimmingCharacters(in: ["="])
    let len = bare.count
    return bare.padding(toLength: len + (4 - (len % 4)), withPad: "=", startingAt: 0)
}

public struct AccountResourceLimit: ABICodable, Equatable, Hashable {
    /// Quantity used in current window.
    public let used: Int64
    /// Quantity available in current window (based upon fractional reserve).
    public let available: Int64
    /// Max per window under current congestion.
    public let max: Int64
}

public struct PermissionLevelWeight: ABICodable, Equatable, Hashable {
    let permission: PermissionLevel
    let weight: Weight
}

public struct KeyWeight: ABICodable, Equatable, Hashable {
    let key: PublicKey
    let weight: Weight
}

public struct WaitWeight: ABICodable, Equatable, Hashable {
    let waitSec: UInt32
    let weight: Weight
}

public struct Authority: ABICodable, Equatable, Hashable {
    let threshold: UInt32
    let keys: [KeyWeight]
    let accounts: [PermissionLevelWeight]
    let waits: [WaitWeight]
}

/// EOSIO Float64 type, aka Double, encodes to a string on the wire instead of a number.
///
/// Swift typealiases are not honored for protocol resolution so we need a wrapper struct here.
public struct Float64: Equatable, Hashable {
    let value: Double
}

extension Float64: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let value = Double(try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid Double string"
            )
        }
        self.value = value
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Double.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self.value))
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}
