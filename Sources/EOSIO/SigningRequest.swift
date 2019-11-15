/// EEP-7 signing request type
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Compression
import Foundation

public struct SigningRequest: ABICodable, Equatable, Hashable {
    /// The magic `Name` used to resolve action and permission to signing user.
    public static let placeholder: Name = "............1"

    /// Recursivley resolve any `Name` types found in value.
    public static func resolvePlaceholders<T>(_ value: T, to name: Name) -> T {
        var depth = 0
        func resolve(_ value: Any) -> Any {
            depth += 1
            guard depth < 100 else { return value }
            switch value {
            case let n as Name:
                return n == Self.placeholder ? name : n
            case let array as [Any]:
                return array.map(resolve)
            case let object as [String: Any]:
                return object.mapValues(resolve)
            default:
                return value
            }
        }
        return resolve(value) as! T
    }

    public enum ChainIdVariant: Equatable, Hashable {
        case alias(UInt8)
        case id(ChainId)

        /// Name of the chain.
        public var name: ChainName {
            switch self {
            case let .id(chainId):
                return chainId.name
            case let .alias(num):
                return ChainName(rawValue: num) ?? .unknown
            }
        }

        /// The actual chain id.
        public var value: ChainId {
            switch self {
            case let .id(chainId):
                return chainId
            case let .alias(num):
                return ChainId(ChainName(rawValue: num) ?? .unknown)
            }
        }
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

    /// All errors `SigningRequest` can throw.
    public enum Error: Swift.Error {
        case invalidBase64u
        case invalidData
        case unsupportedVersion
        case compressionUnsupported
        case missingAbi(Name)
    }

    /// The chain id for the request.
    public let chainId: ChainIdVariant
    /// The request data.
    public let req: RequestType
    /// Whether the request should be broadcast after it is accepted and signed.
    public let broadcast: Bool
    /// Callback to hit after request is signed and/or broadcast.
    public let callback: Callback?

    /// Create a signing request with actions.
    public init(chainId: ChainId, actions: [Action], broadcast: Bool = true, callback: Callback) {
        let name = chainId.name
        self.chainId = name == .unknown ? .id(chainId) : .alias(name.rawValue)
        self.req = actions.count == 1 ? .action(actions.first!) : .actions(actions)
        self.broadcast = broadcast
        self.callback = callback
    }

    /// Create a signing request with a transaction.
    public init(chainId: ChainId, transaction: Transaction, broadcast: Bool = true, callback: Callback) {
        let name = chainId.name
        self.chainId = name == .unknown ? .id(chainId) : .alias(name.rawValue)
        self.req = .transaction(transaction)
        self.broadcast = broadcast
        self.callback = callback
    }

    /// Decode a signing request from a string.
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

    /// Decode a signing request from binary format.
    /// - Note: The first byte is the header, rest is the abi-encoded signing request data.
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

    internal init(chainId: ChainIdVariant, req: RequestType, broadcast: Bool, callback: Callback?) {
        self.chainId = chainId
        self.req = req
        self.broadcast = broadcast
        self.callback = callback
    }

    /// All (unresolved) actions this reqeust contains.
    public var actions: [Action] {
        switch self.req {
        case let .action(action):
            return [action]
        case let .actions(actions):
            return actions
        case let .transaction(tx):
            return tx.actions
        }
    }

    /// The unresolved transaction.
    public var transaction: Transaction {
        let actions: [Action]
        switch self.req {
        case let .transaction(tx):
            return tx
        case let .action(action):
            actions = [action]
        case let .actions(actionList):
            actions = actionList
        }
        let header = TransactionHeader(expiration: 0, refBlockNum: 0, refBlockPrefix: 0)
        return Transaction(header, actions: actions)
    }

    /// ABIs requred to resolve this transaction.
    public var requiredAbis: Set<Name> {
        Set(self.actions.map { $0.account })
    }

    /// Resolve the transaction
    public func resolve(using permission: PermissionLevel, abis: [Name: ABI]) throws -> Transaction {
        var tx = self.transaction
        tx.actions = try tx.actions.map { action in
            var action = action
            guard let abi = abis[action.account] else {
                throw Error.missingAbi(action.account)
            }
            let object = Self.resolvePlaceholders(try action.data(as: String(action.name), using: abi), to: permission.actor)
            let encoder = ABIEncoder()
            action.data = try encoder.encode(object, asType: String(action.name), using: abi)
            action.authorization = action.authorization.map { auth in
                var auth = auth
                if auth.actor == Self.placeholder {
                    auth.actor = permission.actor
                }
                if auth.permission == Self.placeholder {
                    auth.permission = permission.permission
                }
                return auth
            }
            return action
        }
        return tx
    }
}

// MARK: Chain names

/// Type describing a known chain id.
public enum ChainName: UInt8, CaseIterable, CustomStringConvertible {
    case unknown = 0
    case eos = 1
    case telos = 2
    case jungle = 3
    case kylin = 4
    case worbli = 5
    case bos = 6
    case meetone = 7
    case insights = 8
    case beos = 9

    public var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .eos:
            return "EOS"
        case .telos:
            return "Telos"
        case .jungle:
            return "Jungle Testnet"
        case .kylin:
            return "CryptoKylin Testnet"
        case .worbli:
            return "WORBLI"
        case .bos:
            return "BOSCore"
        case .meetone:
            return "MEET.ONE"
        case .insights:
            return "Insights Network"
        case .beos:
            return "BEOS"
        }
    }

    fileprivate var id: ChainId {
        switch self {
        case .unknown:
            return "0000000000000000000000000000000000000000000000000000000000000000"
        case .eos:
            return "aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906"
        case .telos:
            return "4667b205c6838ef70ff7988f6e8257e8be0e1284a2f59699054a018f743b1d11"
        case .jungle:
            return "e70aaab8997e1dfce58fbfac80cbbb8fecec7b99cf982a9444273cbc64c41473"
        case .kylin:
            return "5fff1dae8dc8e2fc4d5b23b2c7665c97f9e9d8edf2b6485a86ba311c25639191"
        case .worbli:
            return "73647cde120091e0a4b85bced2f3cfdb3041e266cbbe95cee59b73235a1b3b6f"
        case .bos:
            return "d5a3d18fbb3c084e3b1f3fa98c21014b5f3db536cc15d08f9f6479517c6a3d86"
        case .meetone:
            return "cfe6486a83bad4962f232d48003b1824ab5665c36778141034d75e57b956e422"
        case .insights:
            return "b042025541e25a472bffde2d62edd457b7e70cee943412b1ea0f044f88591664"
        case .beos:
            return "b912d19a6abd2b1b05611ae5be473355d64d95aeff0c09bedc8c166cd6468fe4"
        }
    }
}

extension ChainId {
    public init(_ name: ChainName) {
        self = name.id
    }

    public var name: ChainName {
        for name in ChainName.allCases {
            if self == name.id {
                return name
            }
        }
        return .unknown
    }
}

// MARK: Abi coding

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
        case "transaction":
            self = .transaction(try container.decode(Transaction.self))
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
        case 2:
            self = .transaction(try decoder.decode(Transaction.self))
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
