/// EEP-7 signing request type
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Compression
import Foundation

public struct SigningRequest: Equatable, Hashable {
    /// The signing request version
    public static let version: UInt8 = 2

    /// The magic `Name` used to resolve action and permission to signing user.
    public static let placeholder: Name = "............1"

    /// Placeholder permission level that resolve both actor and permission to signer.
    public static let placeholderPermission = PermissionLevel(Self.placeholder, Self.placeholder)

    /// Recursively resolve any `Name` types found in value.
    public static func resolvePlaceholders<T>(_ value: T, to name: Name) -> T {
        var depth = 0
        func resolve(_ value: Any) -> Any {
            guard depth < 100 else { return value }
            switch value {
            case let n as Name:
                return n == Self.placeholder ? name : n
            case let array as [Any]:
                depth += 1
                return array.map(resolve)
            case let object as [String: Any]:
                depth += 1
                return object.mapValues(resolve)
            default:
                return value
            }
        }
        return resolve(value) as! T
    }

    /// All errors `SigningRequest` can throw.
    public enum Error: Swift.Error {
        /// Decoding from URI or data failed.
        case decodingFailed(_ message: String, reason: Swift.Error? = nil)
        /// Encoding to URI failed.
        case encodingFailed(_ message: String, reason: Swift.Error? = nil)
        /// ABI definition missing when resolving request.
        case missingAbi(Name)
        /// TaPoS source missing when resolving request.
        case missingTaposSource
    }

    /// Underlying request data.
    fileprivate var data: SigningRequestData

    /// Request signature data.
    fileprivate var sigData: RequestSignatureData?

    /// Create a signing request with action(s).
    /// - Parameter chainId: The chain id for which the request is valid.
    /// - Parameter actions: The EOSIO actions to request a signature for.
    /// - Parameter broadcast: Whether the signer should broadcast the transaction after signing.
    /// - Parameter callback: Callback url signer should hit after signing and/or broadcasting.
    /// - Parameter background: Whether the callback should be performed in the background.
    /// - Parameter info: Optional request headers.
    public init(chainId: ChainId, actions: [Action], broadcast: Bool = true, callback: String? = nil, background: Bool = true, info: [String: String] = [:]) {
        self = SigningRequest(chainId, req: actions.count == 1 ? .action(actions.first!) : .actions(actions),
                              broadcast: broadcast, callback: callback, background: background, info: info)
    }

    /// Create a signing request with a transaction.
    /// - Parameter chainId: The chain id for which the request is valid.
    /// - Parameter transaction: The transaction to request a signature for.
    /// - Parameter broadcast: Whether the signer should broadcast the transaction after signing.
    /// - Parameter callback: Callback url signer should hit after signing and/or broadcasting.
    /// - Parameter background: Whether the callback should be performed in the background.
    /// - Parameter info: Optional request headers.
    public init(chainId: ChainId, transaction: Transaction, broadcast: Bool = true, callback: String? = nil, background: Bool = true, info: [String: String] = [:]) {
        self = SigningRequest(chainId, req: .transaction(transaction),
                              broadcast: broadcast, callback: callback, background: background, info: info)
    }

    /// Create an identity request.
    /// - Parameter chainId: The chain id for which the request is valid.
    /// - Parameter identity: The account name to request identity for, defaults to placeholder name, i.e. signer selects.
    /// - Parameter identityKey: Optional request key wallet implementer can use to verify subsequent requests.
    /// - Parameter callback: Callback that wallet implementer should hit with the identity proof.
    /// - Parameter background: Whether the callback should be performed in the background.
    /// - Parameter info: Optional request headers.
    public init(chainId: ChainId, identity: Name = Self.placeholder, identityKey: PublicKey? = nil, callback: String, background: Bool = true, info: [String: String] = [:]) {
        self = SigningRequest(chainId,
                              req: .identity(IdentityData(account: identity, requestKey: identityKey)),
                              broadcast: false,
                              callback: callback,
                              background: background,
                              info: info)
    }

    private init(
        _ chainId: ChainId,
        req: SigningRequestData.RequestVariant,
        broadcast: Bool,
        callback: String?,
        background: Bool,
        info: [String: String]?
    ) {
        var flags: SigningRequestData.RequestFlags = []
        if broadcast {
            flags.insert(.broadcast)
        }
        if background {
            flags.insert(.background)
        }
        var infoPairs: [SigningRequestData.InfoPair] = []
        if let info = info {
            for (key, value) in info.sorted(by: { $0.key > $1.key }) {
                guard let data = value.data(using: .utf8, allowLossyConversion: true) else {
                    continue
                }
                infoPairs.append(SigningRequestData.InfoPair(key: key, value: data))
            }
        }
        self.data = SigningRequestData(
            chainId: chainId,
            req: req,
            flags: flags,
            callback: callback ?? "",
            info: infoPairs
        )
        self.sigData = nil
    }

    /// Decode a signing request from a string.
    public init(_ string: String) throws {
        var string = string
        if string.starts(with: "esr:") {
            string.removeFirst(4)
            if string.starts(with: "//") {
                string.removeFirst(2)
            }
        }
        guard let data = Data(base64uEncoded: string) else {
            throw Error.decodingFailed("Unable to decode request payload")
        }
        self = try SigningRequest(data)
    }

    /// Decode a signing request from binary format.
    /// - Note: The first byte is the header, rest is the abi-encoded signing request data.
    public init(_ data: Data) throws {
        var data = data
        guard let header = data.popFirst() else {
            throw Error.decodingFailed("Signature header missing")
        }
        let version = header & ~(1 << 7)
        guard version == Self.version else {
            throw Error.decodingFailed("Unsupported version")
        }
        if (header & 1 << 7) != 0 {
            data = try data.withUnsafeBytes { ptr in
                guard !ptr.isEmpty else {
                    throw Error.decodingFailed("No data to decompress")
                }
                var size = 5_000_000
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                defer { buffer.deallocate() }
                if #available(iOS 9.0, OSX 10.11, *) {
                    size = compression_decode_buffer(buffer, size, ptr.bufPtr, ptr.count, nil, COMPRESSION_ZLIB)
                } else {
                    // TODO: compression fallback for linux
                    throw Error.decodingFailed("Compressed requests are not supported on your platform yet")
                }
                guard size != 5_000_000 else {
                    throw Error.decodingFailed("Payload too large")
                }
                return Data(bytes: buffer, count: size)
            }
        }
        let decoder = ABIDecoder()
        do {
            self.data = try decoder.decode(SigningRequestData.self, from: data)
            do {
                self.sigData = try decoder.decode(RequestSignatureData.self)
            } catch ABIDecoder.Error.prematureEndOfData {
                self.sigData = nil
            }
        } catch {
            throw Error.decodingFailed("Request data malformed", reason: error)
        }
    }

    /// Whether the request has a callback.
    public var hasCallback: Bool {
        !self.data.callback.isEmpty
    }

    /// Whether the request is an identity request.
    public var isIdentity: Bool {
        switch self.data.req {
        case .identity:
            return true
        default:
            return false
        }
    }

    /// Present if the request is an identity request and requests a specific account.
    /// - Note: This returns `nil` unless a specific identity has been requested, use`isIdentity` to check id requests.
    public var identity: Name? {
        switch self.data.req {
        case let .identity(id):
            return id.account == Self.placeholder ? nil : id.account
        default:
            return nil
        }
    }

    /// Present if the request is an identity request and specifies a request key.
    public var identityKey: PublicKey? {
        switch self.data.req {
        case let .identity(id):
            return id.requestKey
        default:
            return nil
        }
    }

    /// Chain ID this request is valid for.
    public var chainId: ChainId {
        self.data.chainId.value
    }

    /// Whether the request should be broadcast after being signed.
    public var broadcast: Bool {
        if self.isIdentity {
            return false
        }
        return self.data.flags.contains(.broadcast)
    }

    /// Request metadata.
    /// - Note: Keys that does not encode as utf-8 will be omitted, see `rawInfo`.
    public var info: [String: String] {
        return self.rawInfo.compactMapValues { String(bytes: $0, encoding: .utf8) }
    }

    /// Raw request metadata.
    public var rawInfo: [String: Data] {
        var rv: [String: Data] = [:]
        for pair in self.data.info {
            rv[pair.key] = pair.value
        }
        return rv
    }

    /// All (unresolved) actions this request contains.
    public var actions: [Action] {
        switch self.data.req {
        case let .action(action):
            return [action]
        case let .actions(actions):
            return actions
        case let .identity(id):
            return [id.action]
        case let .transaction(tx):
            return tx.actions
        }
    }

    /// The unresolved transaction.
    public var transaction: Transaction {
        let actions: [Action]
        switch self.data.req {
        case let .transaction(tx):
            return tx
        default:
            actions = self.actions
        }
        return Transaction(TransactionHeader.zero, actions: actions)
    }

    /// ABIs required to resolve this request.
    public var requiredAbis: Set<Name> {
        Set(self.actions.compactMap { $0.account == 0 ? nil : $0.account })
    }

    /// Whether TaPoS values are required to resolve this request.
    public var requiresTapos: Bool {
        if self.isIdentity {
            return false
        }
        let header = self.transaction.header
        return header.refBlockNum == 0 && header.refBlockPrefix == 0 && header.expiration == 0
    }

    /// Request signature.
    public var signature: Signature? {
        self.sigData?.signature
    }

    /// Account that signed the request.
    public var signer: Name? {
        self.sigData?.signer
    }

    /// Signing digest.
    public var digest: Checksum256 {
        let encoder = ABIEncoder()
        var data: Data = (try? encoder.encode(self.data)) ?? Data()
        data.insert(Self.version, at: 0)
        data.insert(contentsOf: [0x72, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74], at: 1) // "request"
        return Checksum256.hash(data)
    }

    /// Set the request signature and signer.
    public mutating func setSignature(_ signature: Signature, signer: Name) {
        self.sigData = RequestSignatureData(signer: signer, signature: signature)
    }

    /// Removes the request signature and signer.
    public mutating func removeSignature() {
        self.sigData = nil
    }

    /// Sets the request callback.
    public mutating func setCallback(_ url: String, background: Bool) {
        self.data.callback = url
        if background {
            self.data.flags.insert(.background)
        } else {
            self.data.flags.remove(.background)
        }
    }

    /// Removes the request callback.
    public mutating func removeCallback() {
        self.data.callback = ""
    }

    /// Set metadata key to data value.
    public mutating func setInfo(_ key: String, data: Data) {
        let pair = SigningRequestData.InfoPair(key: key, value: data)
        if let existingIdx = self.data.info.firstIndex(where: { $0.key == key }) {
            self.data.info[existingIdx] = pair
        } else {
            self.data.info.append(pair)
        }
    }

    /// Set metadata key to string value.
    /// - Note: Key will be unset if string fails to encode to UTF-8.
    public mutating func setInfo(_ key: String, string: String) {
        if let data = string.data(using: .utf8, allowLossyConversion: true) {
            self.setInfo(key, data: data)
        } else {
            self.removeInfo(key)
        }
    }

    /// Set metadata key to any `ABIEncodable` value.
    /// - Note: Key will be unset if value fails do encode.
    public mutating func setInfo<T: ABIEncodable>(_ key: String, value: T) {
        if let data: Data = try? ABIEncoder().encode(value) {
            self.setInfo(key, data: data)
        } else {
            self.removeInfo(key)
        }
    }

    /// Remove metadata value for key, or all values if key is `nil`.
    public mutating func removeInfo(_ key: String? = nil) {
        if let key = key {
            self.data.info.removeAll { $0.key == key }
        } else {
            self.data.info = []
        }
    }

    /// Get data for info key.
    public func getInfo(_ key: String) -> Data? {
        return self.data.info.first { $0.key == key }?.value
    }

    /// Get string for info key.
    public func getInfo(_ key: String, as _: String.Type) -> String? {
        if let data = self.getInfo(key) {
            return String(bytes: data, encoding: .utf8)
        }
        return nil
    }

    /// Get `ABIDecodable` for info key.
    public func getInfo<T: ABIDecodable>(_ key: String, as _: T.Type) -> T? {
        if let data = self.getInfo(key) {
            return try? ABIDecoder().decode(T.self, from: data)
        }
        return nil
    }

    /// Resolve the signing request.
    /// - Parameter permission: The permission level, aka signer, to use when resolving the request.
    /// - Parameter abis: The ABI definitions needed to resolve the action data, see `requiredAbis`.
    /// - Parameter tapos: The TaPoS source (e.g. block header or get info rpc call) used if request does not explicitly specify them, see `requiresTapos`.
    /// - Returns: A resolved signing request ready to be signed and/or broadcast with a helper to resolve the callback if present.
    public func resolve(using permission: PermissionLevel, abis: [Name: ABI] = [:], tapos: TaposSource? = nil) throws -> ResolvedSigningRequest {
        var tx = self.transaction
        tx.actions = try tx.actions.map { action in
            var action = action
            guard let abi = abis[action.account] ?? (action.account == 0 ? IdentityData.abi : nil) else {
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
        if !self.isIdentity, tx.header.expiration == 0, tx.header.refBlockNum == 0, tx.header.refBlockPrefix == 0 {
            guard let tapos = tapos else {
                throw Error.missingTaposSource
            }
            let values = tapos.taposValues
            tx.refBlockNum = values.refBlockNum
            tx.refBlockPrefix = values.refBlockPrefix
            tx.expiration = values.expiration ?? TimePointSec(Date().addingTimeInterval(60))
        }
        return ResolvedSigningRequest(self, permission, tx)
    }

    /// Encode request to `esr://` uri string.
    /// - Parameter compress: Whether to compress the request, recommended.
    /// - Parameter slashes: Whether to add two slashes after the protocol, recommended as the resulting uri string will not be clickable in many places otherwise.
    ///                      Can be turned off if uri will be used in a QR code or encoded in a NFC tag to save two bytes.
    public func encodeUri(compress: Bool = true, slashes: Bool = true) throws -> String {
        let encoder = ABIEncoder()
        var data: Data
        do {
            data = try encoder.encode(self.data)
            if let sigData = self.sigData {
                data.append(try encoder.encode(sigData))
            }
        } catch {
            throw Error.encodingFailed("Unable to ABI-encode request data", reason: error)
        }
        var header: UInt8 = Self.version
        if compress {
            header |= 1 << 7
            data = try data.withUnsafeBytes { ptr in
                var size = ptr.count
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                defer { buffer.deallocate() }
                if #available(iOS 9.0, OSX 10.11, *) {
                    size = compression_encode_buffer(buffer, size, ptr.bufPtr, ptr.count, nil, COMPRESSION_ZLIB)
                } else {
                    // TODO: compression fallback for linux
                    throw Error.encodingFailed("Compressed requests are not supported on your platform yet")
                }
                guard size != 0 else {
                    throw Error.encodingFailed("Unknown compression error")
                }
                return Data(bytes: buffer, count: size)
            }
        }
        data.insert(header, at: 0)
        var scheme = "esr:"
        if slashes {
            scheme += "//"
        }
        return scheme + data.base64uEncodedString()
    }
}

// MARK: Resolved request

public struct ResolvedSigningRequest: Hashable, Equatable {
    public struct Callback: Encodable, Equatable, Hashable {
        private struct Payload: Encodable, Equatable, Hashable {
            let signatures: [Signature]
            let request: ResolvedSigningRequest
            let blockNum: BlockNum?

            enum Key: String, CaseIterable, CodingKey {
                /// The first signature.
                case sig
                /// Transaction ID as HEX-encoded string.
                case tx
                /// Block number hint (only present if transaction was broadcast).
                case bn
                /// Signer authority, aka account name.
                case sa
                /// Signer permission, e.g. "active".
                case sp
                /// Expiration time used when resolving request.
                case ex
                /// Reference block num used when resolving request.
                case rbn
                /// Reference block id used when resolving request.
                case rid
                /// The originating signing request packed as a uri string.
                case req
            }

            struct SignatureKey: CodingKey {
                let stringValue: String
                init(stringValue: String) {
                    self.stringValue = stringValue
                }

                let intValue: Int? = nil
                init?(intValue _: Int) {
                    return nil
                }

                init(_ i: Int) {
                    self.stringValue = "sig\(i)"
                }
            }

            func stringValue(forKey key: Key) -> String {
                switch key {
                case .tx:
                    return self.request.transaction.id.bytes.hexEncodedString()
                case .bn:
                    guard let blockNum = self.blockNum else {
                        return ""
                    }
                    return String(blockNum)
                case .sa:
                    return String(self.request.signer.actor)
                case .sp:
                    return String(self.request.signer.permission)
                case .sig:
                    return String(self.signatures[0])
                case .req:
                    return (try? self.request.request.encodeUri(slashes: false)) ?? ""
                case .rbn:
                    return String(self.request.transaction.refBlockNum)
                case .rid:
                    return String(self.request.transaction.refBlockPrefix)
                case .ex:
                    return self.request.transaction.expiration.stringValue
                }
            }

            public func encode(to encoder: Encoder) throws {
                var sigContainer = encoder.container(keyedBy: SignatureKey.self)
                for i in 1..<self.signatures.count {
                    try sigContainer.encode(self.signatures[i], forKey: SignatureKey(i))
                }
                var container = encoder.container(keyedBy: Key.self)
                for key in Key.allCases {
                    let value = self.stringValue(forKey: key)
                    guard !value.isEmpty else {
                        continue
                    }
                    try container.encode(value, forKey: key)
                }
            }
        }

        private struct ExtendedPayload: Encodable {
            let payload: Payload
            let extra: [String: String]?

            func encode(to encoder: Encoder) throws {
                try self.payload.encode(to: encoder)
                var container = encoder.container(keyedBy: StringCodingKey.self)
                if let extra = self.extra {
                    for (key, value) in extra {
                        guard Payload.Key(rawValue: key) == nil, !key.starts(with: "sig") else {
                            throw EncodingError.invalidValue(value, EncodingError.Context(
                                codingPath: container.codingPath,
                                debugDescription: "Reserved key '\(key)' used in extra data"
                            ))
                        }
                        try container.encode(value, forKey: StringCodingKey(key))
                    }
                }
            }
        }

        private let data: Payload

        fileprivate init(_ request: ResolvedSigningRequest, _ signatures: [Signature], _ blockNum: BlockNum?) {
            self.data = Payload(signatures: signatures, request: request, blockNum: blockNum)
        }

        /// The url where the callback should be delivered.
        public var url: String {
            var url = self.data.request.request.data.callback
            for key in Payload.Key.allCases {
                guard let range = url.range(of: "{{\(key.rawValue)}}") else { continue }
                url.replaceSubrange(range, with: self.data.stringValue(forKey: key))
            }
            for i in 0..<self.data.signatures.count {
                let key = "sig\(i)"
                guard let range = url.range(of: "{{\(key)}}") else { continue }
                url.replaceSubrange(range, with: String(self.data.signatures[i]))
            }
            return url
        }

        /// Whether the callback should be delivered in the background.
        public var background: Bool {
            return self.data.request.request.data.flags.contains(.background)
        }

        /// The JSON payload that should be delivered for background requests.
        /// - Parameter extra: Extra data to add to the payload, note that if any key conflicts with
        ///                    the payload keys this method will throw.
        public func getPayload(extra: [String: String]? = nil) throws -> Data {
            let encoder = JSONEncoder()
            return try encoder.encode(ExtendedPayload(payload: self.data, extra: extra))
        }
    }

    private let request: SigningRequest
    public let signer: PermissionLevel
    public private(set) var transaction: Transaction

    fileprivate init(_ request: SigningRequest, _ signer: PermissionLevel, _ transaction: Transaction) {
        self.request = request
        self.signer = signer
        self.transaction = transaction
    }

    /// The transaction header, only part of transaction that can be mutated after being resolved.
    public var header: TransactionHeader {
        get { self.transaction.header }
        set { self.transaction.header = newValue }
    }

    /// Get the request callback.
    /// - Parameter signatures: The signature(s) for obtained by signing the transaction for the requested signer.
    /// - Parameter blockNum: The block num hint obtained if the transaction was broadcast.
    /// - Returns: The resolved callback or `nil` if the request didn't specify any.
    public func getCallback(using signatures: [Signature], blockNum: BlockNum?) -> Callback? {
        guard !self.request.data.callback.isEmpty else {
            return nil
        }
        return Callback(self, signatures, blockNum)
    }
}

// MARK: Data types

private struct SigningRequestData: ABICodable, Hashable, Equatable {
    /// Chain ID variant, either a chain name alias or full chainid checksum.
    enum ChainIdVariant: Equatable, Hashable {
        case alias(UInt8)
        case id(ChainId)

        init(_ chainId: ChainId) {
            let name = chainId.name
            self = name == .unknown ? .id(chainId) : .alias(name.rawValue)
        }

        /// Name of the chain.
        var name: ChainName {
            switch self {
            case let .id(chainId):
                return chainId.name
            case let .alias(num):
                return ChainName(rawValue: num) ?? .unknown
            }
        }

        /// The actual chain id.
        var value: ChainId {
            switch self {
            case let .id(chainId):
                return chainId
            case let .alias(num):
                return ChainId(ChainName(rawValue: num) ?? .unknown)
            }
        }
    }

    enum RequestVariant: Equatable, Hashable {
        case action(Action)
        case actions([Action])
        case transaction(Transaction)
        case identity(IdentityData)
    }

    struct InfoPair: Equatable, Hashable, ABICodable {
        let key: String
        let value: Data
    }

    struct RequestFlags: OptionSet, Equatable, Hashable {
        let rawValue: UInt8
        /// Resulting transaction should be broadcast by signer.
        static let broadcast = RequestFlags(rawValue: 1 << 0)
        /// Callback should be called in the background.
        static let background = RequestFlags(rawValue: 1 << 1)
    }

    /// The chain id for the request.
    var chainId: ChainIdVariant
    /// The request data.
    var req: RequestVariant
    /// Request flags.
    var flags: RequestFlags
    /// Callback to hit after request is signed and/or broadcast.
    var callback: String
    /// Request metadata.
    var info: [InfoPair]

    init(chainId: ChainId, req: RequestVariant, flags: RequestFlags, callback: String, info: [InfoPair]) {
        self.chainId = ChainIdVariant(chainId)
        self.req = req
        self.flags = flags
        self.callback = callback
        self.info = info
    }
}

private struct IdentityData: ABICodable, Equatable, Hashable {
    public let account: Name
    public let requestKey: PublicKey?

    /// The mock action that is signed to prove identity.
    public var action: Action {
        try! Action(account: 0, name: "identity", value: self)
    }

    /// ABI definition for the mock identity contract.
    public static let abi = ABI(
        structs: [
            ["identity": [
                ["account", "name"],
                ["request_key", "public_key?"],
            ]],
        ],
        actions: ["identity"]
    )
}

private struct RequestSignatureData: ABICodable, Equatable, Hashable {
    public let signer: Name
    public let signature: Signature
}

// MARK: Helpers

/// Type that provides Transaction as Proof of Stake (TaPoS) values.
public protocol TaposSource {
    /// The TaPoS values.
    /// - Note: Transaction expiration, technically not part of TaPoS values but in practice they are usually set together.
    ///         Implementers can return nil expiration to have resolver set expiration from system time.
    var taposValues: (refBlockNum: UInt16, refBlockPrefix: UInt32, expiration: TimePointSec?) { get }
}

extension TransactionHeader: TaposSource {
    public var taposValues: (refBlockNum: UInt16, refBlockPrefix: UInt32, expiration: TimePointSec?) {
        return (self.refBlockNum, self.refBlockPrefix, self.expiration)
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

// MARK: ABI Coding

extension SigningRequestData.RequestFlags: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(UInt8.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension SigningRequestData.ChainIdVariant: ABICodable {
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

extension SigningRequestData.RequestVariant: ABICodable {
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
        case "identity":
            self = .identity(try container.decode(IdentityData.self))
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
        case 3:
            self = .identity(try decoder.decode(IdentityData.self))
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
        case let .identity(identity):
            try container.encode("identity")
            try container.encode(identity)
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
        case let .identity(identity):
            try encoder.encode(3 as UInt8)
            try encoder.encode(identity)
        }
    }
}
