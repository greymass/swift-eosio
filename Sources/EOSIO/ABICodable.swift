/// The `ABICodable` protocol.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// A type that can convert itself into and out of EOSIO ABI formats.
public typealias ABICodable = ABIEncodable & ABIDecodable

// MARK: Built-in type conformance

/// Strings are represented as `<varuint><utf8_bytes>`.
extension String: ABICodable {
    public init(fromAbi decoder: ABIDecoder) throws {
        let len = try decoder.decode(UInt.self)
        let utfBytes = try decoder.decode(Data.self, byteCount: Int(len))
        guard let string = String(bytes: utfBytes, encoding: .utf8) else {
            throw ABIDecoder.Error.invalidUTF8(utfBytes)
        }
        self = string
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        let utfBytes = self.utf8
        try encoder.encode(UInt(utfBytes.count))
        try encoder.encode(contentsOf: utfBytes)
    }
}

/// Fixed-width integers are encoded as little endian.
/// - NOTE: The Int and UInt types are encoded as var(u)ints by the encoder.
extension FixedWidthInteger where Self: ABICodable {
    public init(fromAbi decoder: ABIDecoder) throws {
        var v = Self()
        try decoder.read(into: &v)
        self.init(littleEndian: v)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try withUnsafeBytes(of: self.littleEndian) {
            try encoder.encode(contentsOf: $0)
        }
    }
}

extension Int8: ABICodable {}
extension UInt8: ABICodable {}
extension Int16: ABICodable {}
extension UInt16: ABICodable {}
extension Int32: ABICodable {}
extension UInt32: ABICodable {}
extension Int64: ABICodable {}
extension UInt64: ABICodable {}

extension Bool: ABICodable {
    public init(fromAbi decoder: ABIDecoder) throws {
        let value = try decoder.decode(UInt8.self)
        switch value {
        case 0:
            self = false
        case 1:
            self = true
        default:
            throw ABIDecoder.Error.boolOutOfRange(value)
        }
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        let value: UInt8 = self ? 1 : 0
        try encoder.encode(value)
    }
}

/// Optionals are encoded as `<uint8>[optional_value]`
extension Optional: ABICodable where Wrapped: Codable {
    public init(fromAbi decoder: ABIDecoder) throws {
        let hasValue = try decoder.decode(Bool.self)
        if hasValue {
            self = .some(try decoder.decode(Wrapped.self))
        } else {
            self = .none
        }
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        switch self {
        case .none:
            try encoder.encode(false)
        case let .some(value):
            try encoder.encode(true)
            try encoder.encode(value)
        }
    }
}

extension Data: ABICodable {
    public init(fromAbi decoder: ABIDecoder) throws {
        let len = try decoder.decode(UInt.self)
        self = try decoder.decode(Data.self, byteCount: Int(len))
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(UInt(self.count))
        try encoder.encode(contentsOf: self)
    }
}

extension Array: ABIEncodable where Element: Encodable {
    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(UInt(self.count))
        for item in self {
            try encoder.encode(item)
        }
    }
}

extension Array: ABIDecodable where Element: Decodable {
    public init(fromAbi decoder: ABIDecoder) throws {
        let len = try decoder.decode(UInt.self)
        self.init()
        self.reserveCapacity(Int(len))
        for _ in 0..<len {
            try self.append(decoder.decode(Element.self))
        }
    }
}

extension Never: ABICodable {
    public init(from decoder: Decoder) throws {
        let ctx = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Attempted to decode Never")
        throw DecodingError.dataCorrupted(ctx)
    }

    public func encode(to encoder: Encoder) throws {
        let ctx = EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Attempted to encode Never")
        throw EncodingError.invalidValue(self, ctx)
    }
}

struct ABIKey: CodingKey {
    let intValue: Int? = nil
    let stringValue: String

    init?(intValue _: Int) { return nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init(_ string: String) { self.stringValue = string }
}

// MARK: Dynamic ABI Coding

public extension CodingUserInfoKey {
    /// The ABI defenition to use when coding.
    static let abiDefinition = CodingUserInfoKey(rawValue: "abiDefinition")!
    /// The root ABI type to use when coding.
    static let abiType = CodingUserInfoKey(rawValue: "abiType")!
}

/// Wrapper that encodes and decodes an untyped object using a EOSIO ABI
public struct AnyABICodable: ABICodable {
    enum Error: Swift.Error {
        case missingAbiDefinition
        case missingRootType
    }

    public var value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let def = try Self.getDefenitions(from: decoder.userInfo)
        self.value = try _decodeAny(def.type, from: decoder, using: def.abi)
    }

    public func encode(to encoder: Encoder) throws {
        let def = try Self.getDefenitions(from: encoder.userInfo)
        try _encodeAny(self.value, ofType: def.type, to: encoder, using: def.abi)
    }

    /// Get the ABI definitions and root type from given userInfo dict.
    private static func getDefenitions(from userInfo: [CodingUserInfoKey: Any]) throws -> (abi: ABI, type: String) {
        guard let abi = userInfo[.abiDefinition] as? ABI else {
            throw Error.missingAbiDefinition
        }
        guard let type = userInfo[.abiType] as? String else {
            throw Error.missingRootType
        }
        return (abi, type)
    }
}

private func _encodeAny(_ value: Any,
                        ofType type: String,
                        to encoder: Encoder,
                        using abi: ABI) throws {
    let rootType = abi.resolveType(type)
    try _encodeAny(value, to: encoder, usingType: rootType)
}

private func _encodeAny(_ value: Any,
                        to encoder: Encoder,
                        usingType type: ABI.ResolvedType) throws {
    if type.builtIn != nil {
        try _encodeAnyBuiltIn(value, to: encoder, usingType: type)
    } else if type.fields != nil {
        try _encodeAnyFields(value, to: encoder, usingType: type)
    } else if type.variant != nil {
        fatalError("not implemented")
    } else {
        throw EncodingError.invalidValue(value, EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Encountered unknown type \(type)"
        ))
    }
}

private func _encodeAnyFields(_ value: Any,
                              to encoder: Encoder,
                              usingType type: ABI.ResolvedType) throws {
    guard let object = value as? [String: Any] else {
        throw EncodingError.invalidValue(value, EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Expected object"
        ))
    }
    var container = encoder.container(keyedBy: ABIKey.self)
    for field in type.fields! {
        let fieldEncoder = container.superEncoder(forKey: ABIKey(field.name))
        try _encodeAny(object[field.name] as Any, to: fieldEncoder, usingType: field.type)
    }
}

private func _encodeAnyBuiltIn(_ value: Any,
                               to encoder: Encoder,
                               usingType type: ABI.ResolvedType) throws {
    func encode<T: Encodable>(_ builtInType: T.Type, _ setValue: Any) throws {
        try _encodeValue(setValue, builtInType, to: encoder, usingType: type)
    }
    switch type.builtIn! {
    case .string: try encode(String.self, value)
    case .int8: try encode(Int8.self, value)
    case .int16: try encode(Int16.self, value)
    case .int32: try encode(Int32.self, value)
    case .int64: try encode(Int64.self, value)
    case .uint8: try encode(Int8.self, value)
    case .uint16: try encode(Int16.self, value)
    case .uint32: try encode(Int32.self, value)
    case .uint64: try encode(Int64.self, value)
    case .name:
        var name = value
        if let string = value as? String {
            name = Name(string)
        }
        try encode(Name.self, name)
    case .asset:
        var asset = value
        if let string = value as? String, let resolved = Asset(string) {
            asset = resolved
        }
        try encode(Asset.self, asset)
    case .symbol:
        var symbol = value
        if let string = value as? String, let resolved = Asset.Symbol(string) {
            symbol = resolved
        }
        try encode(Asset.Symbol.self, symbol)
    case .checksum256:
        fatalError("Not implemented")
    }
}

private func _encodeValue<T: Encodable>(_ value: Any,
                                        _: T.Type,
                                        to encoder: Encoder,
                                        usingType type: ABI.ResolvedType) throws {
    var container = encoder.singleValueContainer()
    func encode<T: Encodable>(_ value: T?) throws {
        if type.flags.contains(.optional) {
            try container.encode(value)
        } else {
            guard let resolvedValue = value else {
                throw EncodingError.invalidValue(value as Any, EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Value not conforming to expected type"
                ))
            }
            try container.encode(resolvedValue)
        }
    }
    if type.flags.contains(.array) {
        try encode(value as? [T])
    } else {
        try encode(value as? T)
    }
}

func _decodeAny(_ type: String,
                from decoder: Decoder,
                using abi: ABI) throws -> Any {
    let rootType = abi.resolveType(type)
    return try _decodeAny(rootType, from: decoder)
}

func _decodeAny(_ type: ABI.ResolvedType,
                from decoder: Decoder) throws -> Any {
    if type.builtIn != nil {
        return try _decodeAnyBuiltIn(type, from: decoder)
    } else if type.fields != nil {
        return try _decodeAnyFields(type, from: decoder)
    } else if type.variant != nil {
        fatalError("not implemented")
    } else {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Encountered unknown type: \(type.name)"
        ))
    }
}

func _decodeAnyFields(_ type: ABI.ResolvedType,
                      from decoder: Decoder) throws -> Any {
    var object: [String: Any] = [:]
    let container = try decoder.container(keyedBy: ABIKey.self)
    for field in type.fields! {
        let fieldEncoder = try container.superDecoder(forKey: ABIKey(field.name))
        object[field.name] = try _decodeAny(field.type, from: fieldEncoder)
    }
    return object
}

func _decodeAnyBuiltIn(_ type: ABI.ResolvedType,
                       from decoder: Decoder) throws -> Any {
    func decodeAny<T: Decodable>(_: T.Type) throws -> Any {
        let container = try decoder.singleValueContainer()
        if type.flags.contains(.array) {
            return try container.decode([T].self)
        } else {
            return try container.decode(T.self)
        }
    }
    func decode<T: Decodable>(_: T.Type) throws -> Any {
        if type.flags.contains(.optional) {
            return (try? decodeAny(T.self)) as Any
        } else {
            return try decodeAny(T.self)
        }
    }
    switch type.builtIn! {
    case .string: return try decode(String.self)
    case .name: return try decode(Name.self)
    case .asset: return try decode(Asset.self)
    case .symbol: return try decode(Asset.Symbol.self)
    case .uint8: return try decode(UInt8.self)
    case .uint16: return try decode(UInt16.self)
    case .uint32: return try decode(UInt32.self)
    case .uint64: return try decode(UInt64.self)
    case .int8: return try decode(Int8.self)
    case .int16: return try decode(Int16.self)
    case .int32: return try decode(Int32.self)
    case .int64: return try decode(Int64.self)
    case .checksum256:
        fatalError("not implem")
    }
}

public protocol AnyABIEncoder {
    func encode<T: Encodable>(_ value: T) throws -> Data
    func encode(_ value: Any, asType type: String, using abi: ABI) throws -> Data
}

extension JSONEncoder: AnyABIEncoder {
    public func encode(_ value: Any, asType type: String, using abi: ABI) throws -> Data {
        self.userInfo[.abiDefinition] = abi
        self.userInfo[.abiType] = type
        return try self.encode(AnyABICodable(value))
    }
}

extension ABIEncoder: AnyABIEncoder {
    public func encode(_ value: Any, asType type: String, using abi: ABI) throws -> Data {
        self.userInfo[.abiDefinition] = abi
        self.userInfo[.abiType] = type
        return try self.encode(AnyABICodable(value))
    }
}

public protocol AnyABIDecoder {
    func decode<T: Decodable>(_ type: T.Type, from: Data) throws -> T
    func decode(_ type: String, from data: Data, using abi: ABI) throws -> Any
}

extension JSONDecoder: AnyABIDecoder {
    public func decode(_ type: String, from data: Data, using abi: ABI) throws -> Any {
        self.userInfo[.abiDefinition] = abi
        self.userInfo[.abiType] = type
        let decoded = try self.decode(AnyABICodable.self, from: data)
        return decoded.value
    }
}

extension ABIDecoder: AnyABIDecoder {
    public func decode(_ type: String, from data: Data, using abi: ABI) throws -> Any {
        self.userInfo[.abiDefinition] = abi
        self.userInfo[.abiType] = type
        let decoded = try self.decode(AnyABICodable.self, from: data)
        return decoded.value
    }
}
