import Foundation

public extension API.V1 {
    /// The Chain API.
    struct History { private init() {} }
}

public extension API.V1.History {
    /// Get list of accounts controlled by given public key.
    struct GetKeyAccounts: Request {
        public static let path = "/v1/history/get_key_accounts"
        public struct Response: Decodable {
            /// Account names controlled by key.
            public let accountNames: [Name]
        }

        public var publicKey: PublicKey

        public init(_ publicKey: PublicKey) {
            self.publicKey = publicKey
        }
    }
}
