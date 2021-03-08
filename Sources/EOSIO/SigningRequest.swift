/// EEP-7 signing request type
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

#if canImport(Compression)
    import Compression
#endif

public struct SigningRequest: Equatable, Hashable {
    /// The signing request version
    public static let version: UInt8 = 3

    /// Special `Name` that is resolved to to signing actor (account name).
    public static let actorPlaceholder: Name = "............1"

    /// Special `Name` that is resolved to to signing permission name.
    public static let permissionPlaceholder: Name = "............2"

    /// Placeholder permission level that resolve both actor and permission to signer.
    public static let placeholderPermission = PermissionLevel(Self.actorPlaceholder, Self.permissionPlaceholder)

    /// Recursively resolve any `Name` placeholders types found in value.
    public static func resolvePlaceholders<T>(_ value: T, using signer: PermissionLevel) -> T {
        func resolve(_ value: Any) -> Any {
            switch value {
            case let n as Name:
                switch n {
                case Self.actorPlaceholder:
                    return signer.actor
                case Self.permissionPlaceholder:
                    return signer.permission
                default:
                    return n
                }
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

    /// All errors `SigningRequest` can throw.
    public enum Error: Swift.Error {
        /// Decoding from URI or data failed.
        case decodingFailed(_ message: String, reason: Swift.Error? = nil)
        /// Encoding to URI failed.
        case encodingFailed(_ message: String, reason: Swift.Error? = nil)
        /// ABI definition missing when resolving request.
        case missingAbi(Name)
        /// ABI did not specify the expected actions and types.
        case invalidAbi(ABI)
        /// TaPoS source missing when resolving request.
        case missingTaposSource
        /// Thrown during resolve if unable to decode or re-encode action data using given ABI(s).
        case abiCodingFailed(action: Action, reason: Swift.Error)
        /// Chain id missing when resolving a multi chain request.
        case missingChainId
        /// Encountered chain id that wasn't part of requested chain ids when resolving request.
        case unsupportedChainId(ChainId)
    }

    /// The request version.
    public var version: UInt8

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
    public init(chainId: ChainId, actions: [Action], broadcast: Bool = true, callback: String? = nil, background: Bool = true) {
        self = .init(version: 2, data: SigningRequestData(
            chainId: SigningRequestData.ChainIdVariant(chainId),
            req: actions.count == 1 ? .action(actions.first!) : .actions(actions),
            flags: SigningRequestData.RequestFlags(broadcast: broadcast, background: background),
            callback: callback ?? "",
            info: []
        ))
    }

    /// Create a signing request with a transaction.
    /// - Parameter chainId: The chain id for which the request is valid.
    /// - Parameter transaction: The transaction to request a signature for.
    /// - Parameter broadcast: Whether the signer should broadcast the transaction after signing.
    /// - Parameter callback: Callback url signer should hit after signing and/or broadcasting.
    /// - Parameter background: Whether the callback should be performed in the background.
    public init(chainId: ChainId, transaction: Transaction, broadcast: Bool = true, callback: String? = nil, background: Bool = true) {
        self = .init(version: 2, data: SigningRequestData(
            chainId: SigningRequestData.ChainIdVariant(chainId),
            req: .transaction(transaction),
            flags: SigningRequestData.RequestFlags(broadcast: broadcast, background: background),
            callback: callback ?? "",
            info: []
        ))
    }

    /// Create a legacy (v2) identity request.
    /// - Parameter chainId: The chain id for which the request is valid.
    /// - Parameter callback: Callback that wallet implementer should hit with the identity proof.
    /// - Parameter identity: The account name to request identity confirmation for, if nil will create a "any id" request.
    /// - Parameter permission: Optional account permission constrain identity request to.
    /// - Parameter background: Whether the callback should be performed in the background.
    public init(chainId: ChainId, callback: String, identity: Name? = nil, permission: Name? = nil, background: Bool = true) {
        self = .init(version: 2, data: SigningRequestData(
            chainId: SigningRequestData.ChainIdVariant(chainId),
            req: .identity_v2(IdentityDataV2(identity, permission)),
            flags: SigningRequestData.RequestFlags(background: background),
            callback: callback,
            info: []
        ))
    }

    /// Create an identity request.
    /// - Parameters:
    ///   - chainId: The chain id for which the request is valid.
    ///   - scope: Scope of the request, e.g. a contract or dapp name.
    ///   - callback: Callback that wallet implementer should hit with the identity proof.
    ///   - permission: Optional account permission constrain identity request to.
    ///   - background: Whether the callback should be performed in the background.
    public init(chainId: ChainId?, scope: Name, callback: String, permission: PermissionLevel? = nil, background: Bool = true) {
        self = .init(data: SigningRequestData(
            chainId: (chainId != nil) ? SigningRequestData.ChainIdVariant(chainId!) : .alias(0),
            req: .identity_v3(IdentityDataV3(scope: scope, permission: permission)),
            flags: SigningRequestData.RequestFlags(background: background),
            callback: callback,
            info: []
        ))
    }

    private init(
        version: UInt8 = SigningRequest.version,
        data: SigningRequestData,
        sigData: RequestSignatureData? = nil
    ) {
        self.version = version
        self.data = data
        self.sigData = sigData
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
            throw Error.decodingFailed("Request header missing")
        }
        let version = header & ~(1 << 7)
        guard version == 3 || version == 2 else {
            throw Error.decodingFailed("Unsupported version")
        }
        if (header & 1 << 7) != 0 {
            #if canImport(zlib) || canImport(zlibLinux)
                data = try data.inflated()
            #elseif canImport(Compression)
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
                        throw Error.decodingFailed("Compressed requests are not supported on your platform")
                    }
                    guard size != 5_000_000 else {
                        throw Error.decodingFailed("Payload too large")
                    }
                    return Data(bytes: buffer, count: size)
                }
            #else
                throw Error.decodingFailed("Compressed requests are not supported on your platform")
            #endif
        }
        let decoder = ABIDecoder()
        decoder.userInfo[.esrVersion] = version
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
        self.version = version
    }

    /// Whether the request has a callback.
    public var hasCallback: Bool {
        !self.data.callback.isEmpty
    }

    /// Get the unresolved callback for this request (if any).
    public var unresolvedCallback: (url: String, background: Bool)? {
        guard self.hasCallback else { return nil }
        return (self.data.callback, self.data.flags.contains(.background))
    }

    /// Whether the request is an identity request.
    public var isIdentity: Bool {
        switch self.data.req {
        case .identity_v2, .identity_v3:
            return true
        default:
            return false
        }
    }

    /// Present if the request is an identity request and requests a specific account.
    /// - Note: This returns `nil` unless a specific identity has been requested, use`isIdentity` to check id requests.
    public var identity: Name? {
        switch self.data.req {
        case let .identity_v2(id):
            return id.permission?.actor == Self.actorPlaceholder ? nil : id.permission?.actor
        case let .identity_v3(id):
            return id.permission?.actor == Self.actorPlaceholder ? nil : id.permission?.actor
        default:
            return nil
        }
    }

    /// Present if the request is an identity request and requests a specific account permission.
    /// - Note: This returns `nil` unless a specific identity with permission has been requested, use`isIdentity` to check id requests.
    public var identityPermission: Name? {
        switch self.data.req {
        case let .identity_v2(id):
            return id.permission?.permission == Self.permissionPlaceholder ? nil : id.permission?.permission
        case let .identity_v3(id):
            return id.permission?.permission == Self.permissionPlaceholder ? nil : id.permission?.permission
        default:
            return nil
        }
    }

    /// Present for v3+ identity requests.
    public var identityScope: Name? {
        switch self.data.req {
        case let .identity_v3(id):
            return id.scope
        default:
            return nil
        }
    }

    /// Chain ID this request is valid for.
    public var chainId: ChainId {
        get { self.data.chainId.value }
        set { self.data.chainId = SigningRequestData.ChainIdVariant(newValue) }
    }

    /// Chain IDs this request is valid for, only valid for multi chain requests. Value of nil when `isMultiChain` is true denotes any chain.
    public var chainIds: [ChainId]? {
        get {
            guard self.isMultiChain, let ids = self.getInfo("chain_ids", as: [SigningRequestData.ChainIdVariant].self) else {
                return nil
            }
            return ids.map { $0.value }
        }
        set {
            if let ids = newValue {
                let value = ids.map { SigningRequestData.ChainIdVariant($0) }
                self.setInfo("chain_ids", value: value)
            } else {
                self.removeInfo("chain_ids")
            }
        }
    }

    /// True if chainId is set to chain alias `0` which indicates that the request is valid for any chain.
    public var isMultiChain: Bool {
        self.data.chainId == .alias(0)
    }

    /// Whether the request should be broadcast after being signed.
    /// - Note: This always returns `false` for an identity request.
    public var broadcast: Bool {
        get {
            if self.isIdentity {
                return false
            }
            return self.data.flags.contains(.broadcast)
        }
        set {
            guard !self.isIdentity else {
                return
            }
            self.data.flags.insert(.broadcast)
        }
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
        case let .identity_v2(id):
            return [id.action]
        case let .identity_v3(id):
            return [id.action]
        case let .transaction(tx):
            return tx.actions
        }
    }

    /// The unresolved transaction.
    public var transaction: Transaction {
        get {
            let actions: [Action]
            switch self.data.req {
            case let .transaction(tx):
                return tx
            default:
                actions = self.actions
            }
            return Transaction(TransactionHeader.zero, actions: actions)
        }
        set {
            self.data.req = .transaction(newValue)
        }
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

    /// Get the binary request data.
    public func getData() throws -> Data {
        let encoder = ABIEncoder()
        encoder.userInfo[.esrVersion] = self.version
        return try encoder.encode(self.data)
    }

    /// Signing digest.
    public var digest: Checksum256 {
        var data = try! self.getData()
        data.insert(self.version, at: 0)
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

    private var identityAbi: ABI {
        switch self.version {
        case 2:
            return IdentityDataV2.abi
        default:
            return IdentityDataV3.abi
        }
    }

    /// Resolve the signing request.
    /// - Parameters:
    ///   - signer: The permission level, aka signer, to use when resolving the request.
    ///   - abis: The ABI definitions needed to resolve the action data, see `requiredAbis`.
    ///   - tapos: The TaPoS source (e.g. block header or get info rpc call) used if request does not explicitly specify them, see `requiresTapos`.
    ///   - chainId: ChainID to use when resolving a multi network request.
    /// - Throws: If the transaction couldn't be resolved or the required ABI or TaPoS was missing.
    /// - Returns: A resolved signing request ready to be signed and/or broadcast with a helper to resolve the callback if present.
    public func resolve(using signer: PermissionLevel, abis: [Name: ABI] = [:], tapos: TaposSource? = nil, chainId: ChainId? = nil) throws -> ResolvedSigningRequest {
        var tx = self.transaction
        tx.actions = try tx.actions.map { action in
            var action = action
            guard let abi = abis[action.account] ?? (action.account == 0 ? self.identityAbi : nil) else {
                throw Error.missingAbi(action.account)
            }
            guard let abiAction = abi.getAction(action.name) else {
                throw Error.invalidAbi(abi)
            }
            do {
                let object = Self.resolvePlaceholders(try action.data(using: abi), using: signer)
                let encoder = ABIEncoder()
                action.data = try encoder.encode(object, asType: abiAction.type, using: abi)
            } catch {
                throw Error.abiCodingFailed(action: action, reason: error)
            }
            action.authorization = action.authorization.map { auth in
                var auth = auth
                if auth.actor == Self.actorPlaceholder {
                    auth.actor = signer.actor
                }
                if auth.permission == Self.permissionPlaceholder {
                    auth.permission = signer.permission
                }
                // backwards compatibility, actor placeholder will also resolve to permission when used in auth
                if auth.permission == Self.actorPlaceholder {
                    auth.permission = signer.permission
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
        } else if self.isIdentity, self.version > 2 {
            // identity requests on v3 onwards uses expiration time
            tx.refBlockNum = 0
            tx.refBlockPrefix = 0
            tx.expiration = tapos?.taposValues.expiration ?? TimePointSec(Date().addingTimeInterval(60))
        }
        if self.isMultiChain {
            guard let chainId = chainId else {
                throw Error.missingChainId
            }
            if let chainIds = self.chainIds {
                guard chainIds.contains(chainId) else {
                    throw Error.unsupportedChainId(chainId)
                }
            }
        }
        return ResolvedSigningRequest(self, signer, tx, chainId)
    }

    /// Encode request to binary format.
    /// - Parameter compress: Whether to compress the request, recommended.
    public func encode(compress: Bool = true) throws -> Data {
        let encoder = ABIEncoder()
        encoder.userInfo[.esrVersion] = self.version
        var data: Data
        do {
            data = try encoder.encode(self.data)
            if let sigData = self.sigData {
                data.append(try encoder.encode(sigData))
            }
        } catch {
            throw Error.encodingFailed("Unable to ABI-encode request data", reason: error)
        }
        var header: UInt8 = self.version
        if compress {
            #if canImport(zlib) || canImport(zlibLinux)
                let compressed = try data.deflated(level: .bestCompression)
                if compressed.count < data.count {
                    header |= 1 << 7
                    data = compressed
                }
            #elseif canImport(Compression)
                let compressed = try data.withUnsafeBytes { ptr -> Data? in
                    var size = ptr.count
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                    defer { buffer.deallocate() }
                    if #available(iOS 9.0, OSX 10.11, *) {
                        size = compression_encode_buffer(buffer, size, ptr.bufPtr, ptr.count, nil, COMPRESSION_ZLIB)
                    } else {
                        throw Error.encodingFailed("Compressed requests are not supported on your platform")
                    }
                    guard size != 0 else {
                        return nil
                    }
                    return Data(bytes: buffer, count: size)
                }
                if let compressed = compressed, compressed.count < data.count {
                    header |= 1 << 7
                    data = compressed
                }
            #else
                throw Error.encodingFailed("Compressed requests are not supported on your platform")
            #endif
        }
        data.insert(header, at: 0)
        return data
    }

    /// Encode request to `esr://` uri string.
    /// - Parameter compress: Whether to compress the request, recommended.
    /// - Parameter slashes: Whether to add two slashes after the protocol, recommended as the resulting uri string will not be clickable in many places otherwise.
    ///                      Can be turned off if uri will be used in a QR code or encoded in a NFC tag to save two bytes.
    public func encodeUri(compress: Bool = true, slashes: Bool = true) throws -> String {
        let data = try self.encode(compress: compress)
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
            let chainId: ChainId

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
                /// The chain id of the request (or the selected chain id for multi chain requests)
                case cid
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
                case .cid:
                    return String(self.chainId)
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

        fileprivate init(_ request: ResolvedSigningRequest, _ signatures: [Signature], _ blockNum: BlockNum?, _ chainId: ChainId) {
            self.data = Payload(signatures: signatures, request: request, blockNum: blockNum, chainId: chainId)
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
    private let resolvedChainId: ChainId?
    public let signer: PermissionLevel
    public private(set) var transaction: Transaction

    public init(_ request: SigningRequest, _ signer: PermissionLevel, _ transaction: Transaction, _ chainId: ChainId?) {
        self.request = request
        self.signer = signer
        self.transaction = transaction
        self.resolvedChainId = chainId
    }

    /// The resolved chainId.
    public var chainId: ChainId {
        if self.request.isMultiChain {
            return self.resolvedChainId ?? self.request.chainId
        } else {
            return self.request.chainId
        }
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
        guard !self.request.data.callback.isEmpty, !signatures.isEmpty else {
            return nil
        }
        return Callback(self, signatures, blockNum, self.chainId)
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
        case identity_v2(IdentityDataV2)
        case identity_v3(IdentityDataV3)
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

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        init(broadcast: Bool = false, background: Bool = false) {
            var flags = RequestFlags(rawValue: 0)
            if broadcast { flags.insert(.broadcast) }
            if background { flags.insert(.background) }
            self = flags
        }
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

    init(chainId: ChainIdVariant, req: RequestVariant, flags: RequestFlags, callback: String, info: [InfoPair]) {
        self.chainId = chainId
        self.req = req
        self.flags = flags
        self.callback = callback
        self.info = info
    }
}

private struct IdentityDataV2: ABICodable, Equatable, Hashable {
    public let permission: PermissionLevel?

    init(_ actor: Name?, _ permission: Name?) {
        let permission = PermissionLevel(
            actor ?? SigningRequest.actorPlaceholder,
            permission ?? SigningRequest.permissionPlaceholder
        )
        self = .init(permission)
    }

    init(_ permission: PermissionLevel?) {
        // placeholder permission is equivalent to null permission to save space for the most
        if permission == SigningRequest.placeholderPermission {
            self.permission = nil
        } else {
            self.permission = permission
        }
    }

    /// The mock action that is signed to prove identity.
    public var action: Action {
        if let permission = self.permission {
            return try! Action(account: 0, name: "identity", authorization: [permission], value: self)
        } else {
            return Action(
                account: 0,
                name: "identity",
                authorization: [SigningRequest.placeholderPermission],
                data: Data(hexEncoded: "0101000000000000000200000000000000")
            )
        }
    }

    /// ABI definition for the mock identity contract.
    public static let abi = ABI(
        structs: [
            ["permission_level": [
                ["actor", "name"],
                ["permission", "name"],
            ]],
            ["identity": [
                ["permission", "permission_level?"],
            ]],
        ],
        actions: ["identity"]
    )
}

private struct IdentityDataV3: ABICodable, Equatable, Hashable {
    public var scope: Name
    public var permission: PermissionLevel?

    init(scope: Name, permission: PermissionLevel?) {
        self.scope = scope
        self.permission = permission
    }

    /// The mock action that is signed to prove identity.
    public var action: Action {
        var data = self
        if data.permission == nil {
            data.permission = SigningRequest.placeholderPermission
        }
        return try! Action(account: 0, name: "identity", authorization: [data.permission!], value: data)
    }

    /// ABI definition for the mock identity contract.
    public static let abi = ABI(
        structs: [
            ["permission_level": [
                ["actor", "name"],
                ["permission", "name"],
            ]],
            ["identity": [
                ["scope", "name"],
                ["permission", "permission_level?"],
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

public extension TaposSource {
    var transactionHeader: TransactionHeader {
        let values = self.taposValues
        return .init(
            expiration: values.expiration ?? TimePointSec(Date().addingTimeInterval(60)),
            refBlockNum: values.refBlockNum,
            refBlockPrefix: values.refBlockPrefix
        )
    }
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
    case wax = 10
    case proton = 11
    case fio = 12

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
        case .wax:
            return "WAX"
        case .proton:
            return "Proton"
        case .fio:
            return "FIO"
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
        case .wax:
            return "1064487b3cd1a897ce03ae5b6a865651747e2e152090f99c1d19d44e01aea5a4"
        case .proton:
            return "384da888112027f0321850a169f737c33e53b388aad48b5adace4bab97f437e0"
        case .fio:
            return "21dcae42c0182200e93f954a074011f9048a7624c6fe81d3c9541a614a88bd1c"
        }
    }
}

public extension ChainId {
    init(_ name: ChainName) {
        self = name.id
    }

    var name: ChainName {
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

public extension CodingUserInfoKey {
    /// The ESR version to follow when coding.
    static let esrVersion = CodingUserInfoKey(rawValue: "esrVersion")!
}

extension SigningRequestData.RequestVariant: ABICodable {
    public init(from decoder: Decoder) throws {
        let version = decoder.userInfo[.esrVersion] as? UInt8 ?? SigningRequest.version
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
            if version == 2 {
                self = .identity_v2(try container.decode(IdentityDataV2.self))
            } else {
                self = .identity_v3(try container.decode(IdentityDataV3.self))
            }
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown type in variant")
        }
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let version = decoder.userInfo[.esrVersion] as? UInt8 ?? SigningRequest.version
        let type = try decoder.decode(UInt8.self)
        switch type {
        case 0:
            self = .action(try decoder.decode(Action.self))
        case 1:
            self = .actions(try decoder.decode([Action].self))
        case 2:
            self = .transaction(try decoder.decode(Transaction.self))
        case 3:
            if version == 2 {
                self = .identity_v2(try decoder.decode(IdentityDataV2.self))
            } else {
                self = .identity_v3(try decoder.decode(IdentityDataV3.self))
            }
        default:
            throw ABIDecoder.Error.unknownVariant(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        let version = encoder.userInfo[.esrVersion] as? UInt8 ?? SigningRequest.version
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
        case let .identity_v2(identity):
            guard version == 2 else {
                throw EncodingError.invalidValue(self, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unable to encode v2 identity payload for esr versions other than 2"
                ))
            }
            try container.encode("identity")
            try container.encode(identity)
        case let .identity_v3(identity):
            guard version > 2 else {
                throw EncodingError.invalidValue(self, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unable to encode v3 identity payload for esr versions less than 3"
                ))
            }
            try container.encode("identity")
            try container.encode(identity)
        }
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        let version = encoder.userInfo[.esrVersion] as? UInt8 ?? SigningRequest.version
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
        case let .identity_v2(identity):
            guard version == 2 else {
                throw EncodingError.invalidValue(self, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unable to encode v2 identity payload for esr versions other than 2"
                ))
            }
            try encoder.encode(3 as UInt8)
            try encoder.encode(identity)
        case let .identity_v3(identity):
            guard version > 2 else {
                throw EncodingError.invalidValue(self, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unable to encode v3 identity payload for esr versions less than 3"
                ))
            }
            try encoder.encode(3 as UInt8)
            try encoder.encode(identity)
        }
    }
}
