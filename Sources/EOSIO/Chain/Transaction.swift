/// EOSIO transaction type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

public typealias TransactionId = Checksum256

extension TransactionId {
    public static var Invalid: Self {
        return TransactionId(Data(repeating: 0, count: 32))
    }
}

public struct TransactionExtension: ABICodable, Equatable, Hashable {
    public var type: UInt16
    public var data: Data
}

public struct TransactionHeader: ABICodable, Equatable, Hashable {
    /// The time at which a transaction expires.
    public var expiration: TimePointSec
    /// Specifies a block num in the last 2^16 blocks.
    public var refBlockNum: UInt16
    /// Specifies the lower 32 bits of the blockid.
    public var refBlockPrefix: UInt32
    /// Upper limit on total network bandwidth (in 8 byte words) billed for this transaction.
    public var maxNetUsageWords: UInt
    /// Upper limit on the total CPU time billed for this transaction.
    public var maxCpuUsageMs: UInt8
    /// Number of seconds to delay this transaction for during which it may be canceled.
    public var delaySec: UInt
}

public struct Transaction: ABICodable, Equatable, Hashable {
    /// The transaction header.
    public var header: TransactionHeader
    /// The context free actions in the transaction.
    public var contextFreeActions: [Action]
    /// The actions in the transaction.
    public var actions: [Action]
    /// Transaction extensions.
    public var transactionExtensions: [TransactionExtension]
}

public struct SignedTransaction: ABICodable, Equatable, Hashable {
    /// The transaction that is signed.
    public var transaction: Transaction
    /// List of signatures.
    public var signatures: [Data]
    /// Context-free action data, for each context-free action, there is an entry here.
    public var contextFreeData: [Data]
}

// MARK: Signing digest

extension Transaction {
    public var id: TransactionId {
        let encoder = ABIEncoder()
        guard let data: Data = try? encoder.encode(self) else {
            return TransactionId.Invalid
        }
        return Checksum256.hash(data)
    }

    public func digest(using chainId: Data) throws -> Checksum256 {
        let encoder = ABIEncoder()
        var data: Data = try encoder.encode(self)
        data.insert(contentsOf: chainId, at: 0)
        return Checksum256.hash(data)
    }
}

// MARK: ABI Coding

private enum TransactionCodingKeys: String, CodingKey {
    case expiration
    case refBlockNum
    case refBlockPrefix
    case maxNetUsageWords
    case maxCpuUsageMs
    case delaySec
    case contextFreeActions
    case actions
    case transactionExtensions
    case signatures
    case contextFreeData
}

extension Transaction {
    public init(from decoder: Decoder) throws {
        self.header = try TransactionHeader(from: decoder)
        let container = try decoder.container(keyedBy: TransactionCodingKeys.self)
        self.contextFreeActions = try container.decode(.contextFreeActions)
        self.actions = try container.decode(.actions)
        self.transactionExtensions = try container.decode(.transactionExtensions)
    }

    public func encode(to encoder: Encoder) throws {
        try self.header.encode(to: encoder)
        var container = encoder.container(keyedBy: TransactionCodingKeys.self)
        try container.encode(self.contextFreeActions, forKey: .contextFreeActions)
        try container.encode(self.actions, forKey: .actions)
        try container.encode(self.transactionExtensions, forKey: .transactionExtensions)
    }
}

extension SignedTransaction {
    public init(from decoder: Decoder) throws {
        self.transaction = try Transaction(from: decoder)
        let container = try decoder.container(keyedBy: TransactionCodingKeys.self)
        self.signatures = try container.decode(.signatures)
        self.contextFreeData = try container.decode(.contextFreeData)
    }

    public func encode(to encoder: Encoder) throws {
        try self.transaction.encode(to: encoder)
        var container = encoder.container(keyedBy: TransactionCodingKeys.self)
        try container.encode(self.signatures, forKey: .signatures)
        try container.encode(self.contextFreeData, forKey: .contextFreeData)
    }
}
