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

// typealias TransactionId = Checksum256
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
