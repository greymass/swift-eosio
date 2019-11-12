/// EEP-7 signing request type
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Compression
import Foundation

public struct SigningRequest: ABICodable, Equatable, Hashable {
    public let chainId: ChainIdVariant
    public let req: RequestType
    public let broadcast: Bool
    public let callback: Callback?

    public enum ChainIdVariant: Equatable, Hashable {
        case alias(UInt8)
        case id(ChainId)
    }

    public enum RequestType: Equatable, Hashable {
        case action(Action)
        case actions([Action])
        case transaction(Transaction)
    }

    public struct Callback: Equatable, Hashable, ABICodable {
        let url: String
        let background: Bool
    }

    public enum Error: Swift.Error {
        case invalidBase64u
        case invalidData
        case unsupportedVersion
        case compressionUnsupported
    }

    public init(chainId: ChainIdVariant, req: RequestType, broadcast: Bool, callback: Callback?) {
        self.chainId = chainId
        self.req = req
        self.broadcast = broadcast
        self.callback = callback
    }

    public init(_ string: String) throws {
        var string = string
        if string.starts(with: "eosio:") {
            string.removeFirst(6)
            if string.starts(with: "//") {
                string.removeFirst(2)
            }
        }
        guard let data = Data(base64uEncoded: string) else {
            throw Error.invalidBase64u
        }
        self = try SigningRequest(data)
    }

    public init(_ data: Data) throws {
        var data = data
        guard let header = data.popFirst() else {
            throw Error.invalidData
        }
        let version = header & ~(1 << 7)
        guard version == 1 else {
            throw Error.unsupportedVersion
        }
        if (header & 1 << 7) != 0 {
            data = try data.withUnsafeBytes { ptr in
                guard !ptr.isEmpty else {
                    throw Error.invalidData
                }
                var size = 5_000_000
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                defer { buffer.deallocate() }
                if #available(iOS 9.0, OSX 10.11, *) {
                    size = compression_decode_buffer(buffer, size, ptr.bufPtr, ptr.count, nil, COMPRESSION_ZLIB)
                } else {
                    // TODO: compression fallback for linux
                    throw Error.compressionUnsupported
                }
                return Data(bytes: buffer, count: size)
            }
        }
        let decoder = ABIDecoder()
        self = try decoder.decode(SigningRequest.self, from: data)
    }
}

extension SigningRequest.ChainIdVariant: ABICodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)
        switch type {
        case "chain_alias":
            self = .alias(try container.decode(UInt8.self))
        case "chain_id":
            self = .id(try container.decode(Checksum256.self))
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown type in variant")
        }
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let type = try decoder.decode(UInt8.self)
        switch type {
        case 0:
            self = .alias(try decoder.decode(UInt8.self))
        case 1:
            self = .id(try decoder.decode(Checksum256.self))
        default:
            throw ABIDecoder.Error.unknownVariant(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .alias(alias):
            try container.encode("chain_alias")
            try container.encode(alias)
        case let .id(hash):
            try container.encode("chain_id")
            try container.encode(hash)
        }
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        switch self {
        case let .alias(alias):
            try encoder.encode(0 as UInt8)
            try encoder.encode(alias)
        case let .id(hash):
            try encoder.encode(1 as UInt8)
            try encoder.encode(hash)
        }
    }
}

extension SigningRequest.RequestType: ABICodable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)
        switch type {
        case "action":
            self = .action(try container.decode(Action.self))
        case "actions":
            self = .actions(try container.decode([Action].self))
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown type in variant")
        }
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let type = try decoder.decode(UInt8.self)
        switch type {
        case 0:
            self = .action(try decoder.decode(Action.self))
        case 1:
            self = .actions(try decoder.decode([Action].self))
        default:
            throw ABIDecoder.Error.unknownVariant(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .action(action):
            try container.encode("action")
            try container.encode(action)
        case let .actions(actions):
            try container.encode("actions")
            try container.encode(actions)
        case let .transaction(transaction):
            try container.encode("transaction")
            try container.encode(transaction)
        }
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        switch self {
        case let .action(action):
            try encoder.encode(0 as UInt8)
            try encoder.encode(action)
        case let .actions(actions):
            try encoder.encode(1 as UInt8)
            try encoder.encode(actions)
        case let .transaction(transaction):
            try encoder.encode(2 as UInt8)
            try encoder.encode(transaction)
        }
    }
}
