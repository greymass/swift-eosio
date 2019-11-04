import Foundation

public extension API.V1 {
    /// The Chain API.
    struct Chain { private init() {} }
}

public extension API.V1.Chain {
    /// Various details about the blockchain.
    struct GetInfo: Request {
        public static let path = "/v1/chain/get_info"
        public struct Response: Decodable {
            /// Hash representing the last commit in the tagged release.
            public let serverVersion: String
            /// Hash representing the ID of the chain.
            public let chainId: ChainId
            /// Highest block number on the chain
            public let headBlockNum: BlockNum
            /// Highest block number on the chain that has been irreversibly applied to state.
            public let lastIrreversibleBlockNum: BlockNum
            /// Highest block ID on the chain that has been irreversibly applied to state.
            public let lastIrreversibleBlockId: BlockId
            /// Highest block ID on the chain.
            public let headBlockId: BlockId
            /// Highest block unix timestamp.
            public let headBlockTime: TimePoint
            /// Producer that signed the highest block (head block).
            public let headBlockProducer: AccountName
            /// CPU limit calculated after each block is produced, approximately 1000 times `blockCpuLimit`.
            public let virtualBlockCpuLimit: UInt64
            /// NET limit calculated after each block is produced, approximately 1000 times `blockNetLimit`.
            public let virtualBlockNetLimit: UInt64
            /// Actual maximum CPU limit.
            public let blockCpuLimit: UInt64
            /// Actual maximum NET limit.
            public let blockNetLimit: UInt64
            /// String representation of server version - Majorish-Minorish-Patchy.
            /// - Note; Not actually SEMVER.
            public let serverVersionString: String?
            /// Sequential block number representing the best known head in the fork database tree.
            public let forkDbHeadBlockNum: BlockNum?
            /// Hash representing the best known head in the fork database tree.
            public let forkDbHeadBlockId: BlockId?
        }

        public init() {}
    }

    struct GetRawAbi: Request {
        public static let path = "/v1/chain/get_raw_abi"
        public struct Response: Decodable {
            public let accountName: Name
            public let codeHash: Checksum256
            public let abiHash: Checksum256
            public let abi: Blob?
            public var decodedAbi: ABI? {
                guard let data = self.abi?.bytes else {
                    return nil
                }
                return try? ABIDecoder.decode(ABI.self, data: data)
            }
        }

        public var accountName: Name

        public init(_ accountName: Name) {
            self.accountName = accountName
        }
    }

    struct GetRawCodeAndAbi: Request {
        public static let path = "/v1/chain/get_raw_code_and_abi"
        public struct Response: Decodable {
            public let accountName: Name
            public let wasm: Blob
            public let abi: Blob
            public var decodedAbi: ABI? {
                return try? ABIDecoder.decode(ABI.self, data: self.abi.bytes)
            }
        }

        public var accountName: Name

        public init(_ accountName: Name) {
            self.accountName = accountName
        }
    }

    /// Get code and ABI.
    /// - Attention: Nodeos sends invalid JSON for this call for some accounts. Use `GetRawAbi` and `GetRawAbi
    struct GetCode: Request {
        public static let path = "/v1/chain/get_code"
        public struct Response: Decodable {
            public let accountName: Name
            public let wast: String
            public let wasm: String
            public let codeHash: Checksum256
            public let abi: ABI?
        }

        public var accountName: Name
        public var codeAsWasm = true
        
        public init(_ accountName: Name) {
            self.accountName = accountName
        }
    }

    /// Query the contents of EOSIO RAM.
    ///
    /// Some params are unsupported, namely:
    /// - `json`: Whether node should try to decode row data using code abi (we always decode client-side).
    /// - `tableKey`: Deined in api plugin but never actually used.
    /// - `encodeType`: Encoding type of the passed key, redundant, use `keyType` instead.
    /// - `showPayer`: Show the RAM payer of the row, changes response structure in a inconvenient way so not handled.
    struct GetTableRows<T: ABIDecodable>: Request {
        public static var path: String { "/v1/chain/get_table_rows" }
        public struct Response: Decodable {
            public let rows: [T]
            public let more: Bool

            private enum Keys: CodingKey {
                case rows
                case more
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: Keys.self)
                var rowContainer = try container.nestedUnkeyedContainer(forKey: .rows)
                var rows: [T] = []
                while !rowContainer.isAtEnd {
                    let hexValue = try rowContainer.decode(String.self)
                    rows.append(try ABIDecoder.decode(T.self, data: Data(hexEncoded: hexValue)))
                }
                self.rows = rows
                self.more = try container.decode(.more)
            }
        }

        public enum IndexPosition: String, Encodable {
            case primary, secondary, tertiary, fourth, fifth, sixth, seventh, eighth, ninth, tenth
        }

        public enum KeyType: String, Encodable {
            case name, i64, i128, i256, float64, float128, sha256, ripemd160
        }

        /// The name of the smart contract that controls the provided table.
        public var code: Name
        /// The account to which this data belongs.
        public var scope: String
        /// The name of the table to query.
        public var table: Name
        /// Lower lookup bound as string representing `keyType`.
        public var lowerBound: String?
        /// Upper lookup bound as string representing `keyType`.
        public var upperBound: String?
        /// How many results to fetch, defaults to 10 if unset.
        public var limit: UInt32?
        /// Type of key specified by `indexPosition`.
        public var keyType: KeyType = .i64
        /// Position of the index used.
        public var indexPosition: IndexPosition = .primary
        /// Whether to iterate records in reverse order.
        public var reverse: Bool?

        /// Create a new `get_table_rows` request.
        public init(code: Name, table: Name, scope: String) {
            self.code = code
            self.scope = scope
            self.table = table
        }

        /// Create a new `get_table_rows` request with scope set from any type representable by a 64-bit unsigned integer.
        public init<T: RawRepresentable>(code: Name, table: Name, scope: T) where T.RawValue == UInt64 {
            self.code = code
            self.scope = Name(rawValue: scope.rawValue).stringValue
            self.table = table
        }

        /// Create a new `get_table_rows` request with scope from a 64-bit unsigned integer.
        public init(code: Name, table: Name, scope: UInt64) {
            self.code = code
            self.scope = Name(rawValue: scope).stringValue
            self.table = table
        }

        /// Create a new `get_table_rows` request with scope set to the code account.
        public init(code: Name, table: Name) {
            self.code = code
            self.scope = code.stringValue
            self.table = table
        }
    }
}
