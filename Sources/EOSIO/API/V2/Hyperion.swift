
public extension API.V2 {
    /// Hyperion APIs.
    struct Hyperion { private init() {} }
}

public extension API.V2.Hyperion {
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
    }
    
    /// Get accounts by public key.
    struct GetKeyAccounts: Request {
        public static let path = "/v2/state/get_key_accounts"
        public static let method = "GET"

        public struct Response: Decodable {
            public let accountNames: [Name]
        }

        public var publicKey: PublicKey

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
    }
    
    /// Get actions based on notified account. this endpoint also accepts generic filters based on indexed fields (e.g. act.authorization.actor=eosio or act.name=delegatebw), if included they will be combined with a AND operator
    struct GetActions: Request {
        public static let path = "/v2/history/get_actions"
        public static let method = "GET"
        
        public enum SortDirection: String, Encodable {
            case desc = "desc"
            case asc = "asc"
        }
        
        public struct RamDelta: Decodable {
            public let account: Name
            public let delta: Int64
        }
        
        public struct Authority: Decodable {
            public let threshold: UInt32
            public let accounts: [PermissionLevelWeight] = []
        }
        
        public struct Data: Decodable {
            public let permission: Name
            public let parent: Name
            public let auth: Authority
            public let account: Name
        }
        
        public struct Action: Decodable {
            public let account: Name
            public let name: Name
            public let authorization: [PermissionLevel]
            public let data: Data
        }

        public struct Transaction: Decodable {
            public let timestamp: TimePoint
            public let blockNum: BlockNum
            public let trxId: TransactionId
            public let act: Action
            public let notified: [Name]
            public let cpuUsageUs: UInt8
            public let netUsageWords: UInt
            public let accountRamDeltas: [RamDelta]
            public let globalSequence: UInt64
            public let receiver: Name
            public let producer: Name
            public let actionOrdinal: UInt32
            public let creatorActionOrdinal: UInt32
        }

        public struct Response: Decodable {
            public let actions: [Transaction]
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
        /// Simplified output mode
        public var simple: Bool?
        /// Exclude large binary data
        public var noBinary: Bool?
        /// Perform reversibility check
        public var checkLib: Bool?
        
        public init(_ account: Name? = nil) {
            self.account = account
        }
    }
}
