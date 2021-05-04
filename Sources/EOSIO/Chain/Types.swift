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
    public let used: FCInt<Int64>
    /// Quantity available in current window (based upon fractional reserve).
    public let available: FCInt<Int64>
    /// Max per window under current congestion.
    public let max: FCInt<Int64>
}

public struct PermissionLevelWeight: ABICodable, Equatable, Hashable {
    public var permission: PermissionLevel
    public var weight: Weight

    public init(_ permission: PermissionLevel, weight: Weight = 1) {
        self.permission = permission
        self.weight = weight
    }
}

public struct KeyWeight: ABICodable, Equatable, Hashable {
    public var key: PublicKey
    public var weight: Weight

    public init(_ key: PublicKey, weight: Weight = 1) {
        self.key = key
        self.weight = weight
    }
}

public struct WaitWeight: ABICodable, Equatable, Hashable {
    public var waitSec: UInt32
    public var weight: Weight

    public init(_ waitSec: UInt32, weight: Weight = 1) {
        self.waitSec = waitSec
        self.weight = weight
    }
}

public struct Authority: ABICodable, Equatable, Hashable {
    public var threshold: UInt32
    public var keys: [KeyWeight] = []
    public var accounts: [PermissionLevelWeight] = []
    public var waits: [WaitWeight] = []

    public init(threshold: UInt32, keys: [KeyWeight] = [], accounts: [PermissionLevelWeight] = [], waits: [WaitWeight] = []) {
        self.threshold = threshold
        self.keys = keys
        self.accounts = accounts
        self.waits = waits
    }

    public init(_ key: PublicKey, delay: UInt32 = 0) {
        self.threshold = 1
        self.keys = [KeyWeight(key)]
        if delay > 0 {
            self.threshold += 1
            self.waits.append(WaitWeight(delay))
        }
    }
}

public extension Authority {
    /// Total weight of all waits.
    var waitThreshold: UInt32 {
        self.waits.reduce(0) { val, wait -> UInt32 in
            val + UInt32(wait.weight)
        }
    }

    /// Check if given public key has permission in this authority,
    /// - Parameter includePartial: Whether to consider auths where the key is included but can't be reached alone (e.g. multisig).
    /// - Attention: Does not take indirect permissions for the key via account weights into account.
    func hasPermission(for publicKey: PublicKey, includePartial: Bool = false) -> Bool {
        let keyTreshhold = self.threshold - self.waitThreshold
        for val in self.keys {
            if val.key == publicKey, includePartial || val.weight >= keyTreshhold {
                return true
            }
        }
        return false
    }
}

/// EOSIO Float64 type, aka Double, encodes to a string on the wire instead of a number.
///
/// Swift typealiases are not honored for protocol resolution so we need a wrapper struct here.
public struct Float64: Equatable, Hashable {
    public let value: Double
}

extension Float64: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var double = try? container.decode(Double.self)
        if double == nil, let string = try? container.decode(String.self) {
            double = Double(string)
        }
        guard let value = double else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid Float64"
            )
        }
        self.value = value
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        self.value = try decoder.decode(Double.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self.value))
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(self.value)
    }
}

public struct Float32: Equatable, Hashable {
    public let value: Float
}

extension Float32: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var double = try? container.decode(Float.self)
        if double == nil, let string = try? container.decode(String.self) {
            double = Float(string)
        }
        guard let value = double else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid Float32"
            )
        }
        self.value = value
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        self.value = try decoder.decode(Float.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self.value))
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(self.value)
    }
}

public struct PermissionLevel: ABICodable, Equatable, Hashable {
    public var actor: Name
    public var permission: Name

    public init(_ actor: Name, _ permission: Name) {
        self.actor = actor
        self.permission = permission
    }
}

extension PermissionLevel: LosslessStringConvertible {
    public init?(_ description: String) {
        let parts = description.split(separator: "@")
        guard parts.count == 2 else {
            return nil
        }
        self = PermissionLevel(Name(String(parts[0])), Name(String(parts[1])))
    }

    public var description: String {
        return "\(self.actor)@\(self.permission)"
    }
}

extension PermissionLevel: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let instance = Self(value) else {
            fatalError("Invalid PermissionLevel literal")
        }
        self = instance
    }
}
