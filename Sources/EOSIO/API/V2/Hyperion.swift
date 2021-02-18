import Foundation

public extension API.V2 {
    /// Hyperion APIs, 3.0.0
    struct Hyperion { private init() {} }
}

public extension API.V2.Hyperion {
    /// Shared struct for GetTransaction, GetActions
    struct RamDelta: Decodable {
        public let account: Name
        public let delta: Int64
    }

    /// Shared struct for GetTransaction, GetActions
    struct ResponseAction<T: ABIDecodable>: Decodable {
        public let account: Name
        public let name: Name
        public let authorization: [PermissionLevel]
        public let data: T
    }

    /// Shared struct for GetTransaction, GetActions
    struct ActionReceipt<T: ABIDecodable>: Decodable {
        public let timestamp: TimePoint
        public let blockNum: BlockNum
        public let trxId: TransactionId
        public let act: ResponseAction<T>
        public let notified: [Name]
        public let cpuUsageUs: UInt?
        public let netUsageWords: UInt?
        public let globalSequence: UInt64?
        public let accountRamDeltas: [RamDelta]?
        public let producer: Name
        public let actionOrdinal: UInt32
        public let creatorActionOrdinal: UInt32
    }

    /// Get all accounts created by one creator.
    struct GetCreatedAccounts: Request {
        public static let path = "/v2/history/get_created_accounts"
        public static let method = "GET"

        public struct CreatedAccount: Decodable {
            public let name: Name
            public let timestamp: TimePoint
            public let trxId: TransactionId
        }

        public struct Response: Decodable {
            public let accounts: [CreatedAccount]
        }

        /// Creator account to lookup.
        public var account: Name
        /// Max number of results to fetch.
        public var limit: UInt?
        /// Number of results to skip.
        public var skip: UInt?

        public init(_ account: Name) {
            self.account = account
        }

        public init(_ account: Name, limit: UInt? = nil, skip: UInt? = nil) {
            self.account = account
            self.limit = limit
            self.skip = skip
        }
    }

    /// Get accounts by public key.
    struct GetKeyAccounts: Request {
        public static let path = "/v2/state/get_key_accounts"
        public static let method = "GET"

        public struct Response: Decodable {
            public let accountNames: [Name]
        }

        public var publicKey: PublicKey

        public enum CodingKeys: String, CodingKey {
            case publicKey = "public_key"
        }

        public init(_ publicKey: PublicKey) {
            self.publicKey = publicKey
        }
    }

    /// Get tokens held by account
    struct GetTokens: Request {
        public static let path = "/v2/state/get_tokens"
        public static let method = "GET"

        public struct Token: Decodable {
            public let symbol: String
            public let precision: UInt8
            public let amount: Double
            public let contract: Name
        }

        public struct Response: Decodable {
            public let tokens: [Token]
        }

        /// Creator account to lookup.
        public var account: Name
        /// Max number of results to fetch.
        public var limit: UInt?
        /// Number of results to skip.
        public var skip: UInt?

        public init(_ account: Name) {
            self.account = account
        }

        public init(_ account: Name, limit: UInt? = nil, skip: UInt? = nil) {
            self.account = account
            self.limit = limit
            self.skip = skip
        }
    }

    /// Get all actions belonging to the same transaction
    struct GetTransaction<T: ABIDecodable>: Request {
        public static var path: String { "/v2/history/get_transaction" }
        public static var method: String { "GET" }

        public struct Response: Decodable {
            public let actions: [ActionReceipt<T>]
        }

        public var id: TransactionId

        public enum CodingKeys: String, CodingKey {
            case id
        }

        public init(_ transactionId: TransactionId) {
            self.id = transactionId
        }
    }

    /// Get actions based on notified account.
    struct GetActions<T: ABIDecodable>: Request {
        public static var path: String { "/v2/history/get_actions" }
        public static var method: String { "GET" }

        public enum SortDirection: String, Encodable {
            case desc
            case asc
        }

        public struct Response: Decodable {
            public let actions: [ActionReceipt<T>]
        }

        /// Creator account to lookup.
        public var account: Name?
        /// Max number of results to fetch.
        public var limit: UInt?
        /// Number of results to skip.
        public var skip: UInt?
        /// Total results to track (count) [number or true]
        public var track: String?
        /// code:name filter
        public var filter: String?
        /// Sort direction
        public var sort: SortDirection?
        /// Filter after specified date (ISO8601)
        public var after: String?
        /// Filter before specified date (ISO8601)
        public var before: String?

        /// Filter transfer.from ANDED together with other like query params
        public var transferFrom: Name?
        /// Filter transfer.to ANDED together with other like query params
        public var transferTo: Name?
        /// Filter transfer.amount ANDED together with other like query params
        public var transferAmount: Double?
        /// Filter transfer.symbol ANDED together with other like query params
        public var transferSymbol: String?
        /// Filter transfer.memo ANDED together with other like query params
        public var transferMemo: String?

        /// Filter unstaketorex.owner ANDED together with other like query params
        public var unstaketorexOwner: Name?
        /// Filter unstaketorex.receiver ANDED together with other like query params
        public var unstaketorexReceiver: Name?
        /// Filter unstaketorex.amount ANDED together with other like query params
        public var unstaketorexAmount: Double?

        /// Filter buyrex.from ANDED together with other like query params
        public var buyrexFrom: Name?
        /// Filter buyrex.amount ANDED together with other like query params
        public var buyrexAmount: Double?

        /// Filter buyrambytes.payer ANDED together with other like query params
        public var buyrambytesPayer: Name?
        /// Filter unstaketorex.receiver ANDED together with other like query params
        public var buyrambytesReceiver: Name?
        /// Filter unstaketorex.bytes ANDED together with other like query params
        public var buyrambytesBytes: Int64?

        /// Filter delegatebw.from ANDED together with other like query params
        public var delegatebwFrom: Name?
        /// Filter delegatebw.receiver ANDED together with other like query params
        public var delegatebwReceiver: Name?
        /// Filter delegatebw.stake_cpu_quantity ANDED together with other like query params
        public var delegatebwStakeCpuQuantity: Double?
        /// Filter delegatebw.stake_net_quantity ANDED together with other like query params
        public var delegatebwStakeNetQuantity: Double?
        /// Filter delegatebw.transfer ANDED together with other like query params
        public var delegatebwTransfer: Bool?
        /// Filter delegate.amount ANDED together with other like query params
        public var delegatebwAmount: Double?

        /// Filter undelegatebw.from ANDED together with other like query params
        public var undelegatebwFrom: Name?
        /// Filter undelegatebw.receiver ANDED together with other like query params
        public var undelegatebwReceiver: Name?
        /// Filter undelegatebw.unstake_cpu_quantity ANDED together with other like query params
        public var undelegatebwUnStakeCpuQuantity: Double?
        /// Filter undelegatebw.unstake_net_quantity ANDED together with other like query params
        public var undelegatebwUnStakeNetQuantity: Double?
        /// Filter undelegatebw.amount ANDED together with other like query params
        public var undelegatebwAmount: Double?

        public enum CodingKeys: String, CodingKey {
            case transferFrom = "transfer.from"
            case transferTo = "transfer.to"
            case transferAmount = "transfer.amount"
            case transferSymbol = "transfer.symbol"
            case transferMemo = "transfer.memo"
            case unstaketorexOwner = "unstaketorex.owner"
            case unstaketorexReceiver = "unstaketorex.receiver"
            case unstaketorexAmount = "unstaketorex.amount"
            case buyrexFrom = "buyrex.from"
            case buyrexAmount = "buyrex.amount"
            case buyrambytesPayer = "buyrambytes.payer"
            case buyrambytesReceiver = "buyrambytes.receiver"
            case buyrambytesBytes = "buyrambytes.bytes"
            case delegatebwFrom = "delegatebw.from"
            case delegatebwReceiver = "delegatebw.receiver"
            case delegatebwStakeCpuQuantity = "delegatebw.stake_cpu_quantity"
            case delegatebwStakeNetQuantity = "delegatebw.stake_net_quantity"
            case delegatebwTransfer = "delegatebw.transfer"
            case delegatebwAmount = "delegatebw.amount"
            case undelegatebwFrom = "undelegate.from"
            case undelegatebwReceiver = "undelegate.receiver"
            case undelegatebwUnStakeCpuQuantity = "undelegate.unstake_cpu_quantity"
            case undelegatebwUnStakeNetQuantity = "undelegate.unstake_net_quantity"
            case undelegatebwAmount = "undelegate.amount"
            case account
            case limit
            case skip
            case track
            case filter
            case sort
            case after
            case before
        }

        public init(_ account: Name? = nil, limit: UInt? = nil, skip: UInt? = nil,
                    track: String? = nil, filter: String? = nil, sort: SortDirection? = nil,
                    after: String? = nil, before: String? = nil)
        {
            self.account = account
            self.limit = limit
            self.skip = skip
            self.track = track
            self.filter = filter
            self.sort = sort
            self.after = after
            self.before = before
        }
    }

    /// Get Creator
    struct GetCreator: Request {
        public static let path = "/v2/history/get_creator"
        public static let method = "GET"

        public struct Response: Decodable {
            public let account: Name
            public let creator: Name
            public let timestamp: TimePoint
            public let blockNum: BlockNum
            public let trxId: TransactionId
        }

        /// Creator account to lookup.
        public var account: Name

        public init(_ account: Name) {
            self.account = account
        }
    }

    /// Get Permission Links
    struct GetLinks: Request {
        public static let path = "/v2/state/get_links"
        public static let method = "GET"

        public struct Link: Decodable {
            public let blockNum: BlockNum
            public let timestamp: TimePoint
            public let account: Name
            public let permission: Name
            public let code: Name
            public let action: Name
        }

        public struct Response: Decodable {
            public let links: [Link]
        }

        /// Account name
        public var account: Name?
        /// Contract name
        public var code: Name?
        /// Action name
        public var action: Name?
        /// Permission name
        public var permission: Name?

        public init(_ account: Name? = nil, code: Name? = nil, action: Name? = nil,
                    permission: Name? = nil)
        {
            self.account = account
            self.code = code
            self.action = action
            self.permission = permission
        }
    }

    // TODO: get_account, get_abi_snapshot, get_deltas, health, get_proposals, get_voters
}
