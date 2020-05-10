
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
            let name: Name
            let timestamp: TimePoint
            let trxId: TransactionId
        }

        public struct Response: Decodable {
            let accounts: [CreatedAccount]
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
}
