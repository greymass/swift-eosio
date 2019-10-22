/// EEP-7 signing request type
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

public struct SigningRequest: ABICodable, Equatable, Hashable {
    let chainId: ChainId
    let req: RequestType
    let broadcast: Bool
    let callback: Callback?

    enum ChainId: Equatable, Hashable {
        case alias(UInt8)
        case id(Checksum256)
    }

    enum RequestType: Equatable, Hashable {
        case action(Action)
        case actions([Action])
        case transaction(Transaction)
    }

    struct Callback: Equatable, Hashable, ABICodable {
        let fu: String
        let vemfan: UInt64
    }
}

extension SigningRequest.ChainId: ABICodable {
    init(from decoder: Decoder) throws {
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

    init(fromAbi decoder: ABIDecoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

    func abiEncode(to encoder: ABIEncoder) throws {
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
    init(from decoder: Decoder) throws {
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

    init(fromAbi decoder: ABIDecoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

    func abiEncode(to encoder: ABIEncoder) throws {
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
