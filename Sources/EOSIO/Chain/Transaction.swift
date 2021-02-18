/// EOSIO transaction type.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

public struct TransactionExtension: ABICodable, Equatable, Hashable {
    public var type: UInt16
    public var data: Data
}

public struct TransactionHeader: ABICodable, Equatable, Hashable {
    /// Null transaction header.
    public static let zero = TransactionHeader(expiration: 0, refBlockNum: 0, refBlockPrefix: 0)

    /// The time at which a transaction expires.
    public var expiration: TimePointSec
    /// Specifies a block num in the last 2^16 blocks.
    public var refBlockNum: UInt16
    /// Specifies the lower 32 bits of the blockid.
    public var refBlockPrefix: UInt32
    /// Upper limit on total network bandwidth (in 8 byte words) billed for this transaction.
    public var maxNetUsageWords: UInt = 0
    /// Upper limit on the total CPU time billed for this transaction.
    public var maxCpuUsageMs: UInt8 = 0
    /// Number of seconds to delay this transaction for during which it may be canceled.
    public var delaySec: UInt = 0

    /// Create a new transaction header.
    public init(expiration: TimePointSec, refBlockNum: UInt16, refBlockPrefix: UInt32) {
        self.expiration = expiration
        self.refBlockNum = refBlockNum
        self.refBlockPrefix = refBlockPrefix
    }

    /// Create a new transaction header by getting the reference values from a block id.
    public init(expiration: TimePointSec, refBlockId: BlockId) {
        self.expiration = expiration
        self.refBlockNum = UInt16(refBlockId.blockNum & 0xFFFF)
        self.refBlockPrefix = refBlockId.blockPrefix
    }
}

@dynamicMemberLookup
public struct Transaction: ABICodable, Equatable, Hashable {
    /// The transaction header.
    public var header: TransactionHeader
    /// The context free actions in the transaction.
    public var contextFreeActions: [Action] = []
    /// The actions in the transaction.
    public var actions: [Action] = []
    /// Transaction extensions.
    public var transactionExtensions: [TransactionExtension] = []

    public init(_ header: TransactionHeader, actions: [Action] = []) {
        self.header = header
        self.actions = actions
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<TransactionHeader, T>) -> T {
        get { self.header[keyPath: keyPath] }
        set { self.header[keyPath: keyPath] = newValue }
    }
}

@dynamicMemberLookup
public struct SignedTransaction: ABICodable, Equatable, Hashable {
    /// The transaction that is signed.
    public var transaction: Transaction
    /// List of signatures.
    public var signatures: [Signature]
    /// Context-free action data, for each context-free action, there is an entry here.
    public var contextFreeData: [Data]

    public init(_ transaction: Transaction, signatures: [Signature] = [], contextFreeData: [Data] = []) {
        self.transaction = transaction
        self.signatures = signatures
        self.contextFreeData = contextFreeData
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<Transaction, T>) -> T {
        get { self.transaction[keyPath: keyPath] }
        set { self.transaction[keyPath: keyPath] = newValue }
    }
}

public struct PackedTransaction: ABICodable, Equatable, Hashable {
    public enum Compression: UInt8, ABICodable {
        case none = 0
        case gzip = 1
    }

    public enum Error: Swift.Error {
        case unsupportedCompression(Compression)
    }

    public let signatures: [Signature]
    public let compression: Compression
    public let packedContextFreeData: Data
    public let packedTrx: Data

    public init(_ signedTransaction: SignedTransaction) throws {
        let encoder = ABIEncoder()
        self.compression = .none
        self.packedTrx = try encoder.encode(signedTransaction.transaction)
        self.packedContextFreeData = try encoder.encode(signedTransaction.contextFreeData)
        self.signatures = signedTransaction.signatures
    }

    public func unpack() throws -> SignedTransaction {
        guard self.compression == .none else {
            throw Error.unsupportedCompression(self.compression)
        }
        let decoder = ABIDecoder()
        let transaction = try decoder.decode(Transaction.self, from: self.packedTrx)
        let contextFreeData = try decoder.decode([Data].self, from: self.packedContextFreeData)
        return SignedTransaction(transaction,
                                 signatures: self.signatures,
                                 contextFreeData: contextFreeData)
    }
}

// MARK: Signing digest

public extension Transaction {
    var id: TransactionId {
        let encoder = ABIEncoder()
        guard let data: Data = try? encoder.encode(self) else {
            return Checksum256(Data(repeating: 0, count: 32))
        }
        return Checksum256.hash(data)
    }

    func data(using chainId: ChainId) throws -> Data {
        let encoder = ABIEncoder()
        var data: Data = try encoder.encode(self)
        data.insert(contentsOf: chainId.bytes, at: 0)
        data.append(Data(repeating: 0, count: 32))
        return data
    }

    func digest(using chainId: ChainId) throws -> Checksum256 {
        return Checksum256.hash(try self.data(using: chainId))
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

public extension Transaction {
    init(from decoder: Decoder) throws {
        self.header = try TransactionHeader(from: decoder)
        let container = try decoder.container(keyedBy: TransactionCodingKeys.self)
        self.contextFreeActions = try container.decode(.contextFreeActions)
        self.actions = try container.decode(.actions)
        self.transactionExtensions = try container.decode(.transactionExtensions)
    }

    func encode(to encoder: Encoder) throws {
        try self.header.encode(to: encoder)
        var container = encoder.container(keyedBy: TransactionCodingKeys.self)
        try container.encode(self.contextFreeActions, forKey: .contextFreeActions)
        try container.encode(self.actions, forKey: .actions)
        try container.encode(self.transactionExtensions, forKey: .transactionExtensions)
    }
}

public extension SignedTransaction {
    init(from decoder: Decoder) throws {
        self.transaction = try Transaction(from: decoder)
        let container = try decoder.container(keyedBy: TransactionCodingKeys.self)
        self.signatures = try container.decode(.signatures)
        self.contextFreeData = try container.decode(.contextFreeData)
    }

    func encode(to encoder: Encoder) throws {
        try self.transaction.encode(to: encoder)
        var container = encoder.container(keyedBy: TransactionCodingKeys.self)
        try container.encode(self.signatures, forKey: .signatures)
        try container.encode(self.contextFreeData, forKey: .contextFreeData)
    }
}
