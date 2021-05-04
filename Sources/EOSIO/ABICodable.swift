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
public extension FixedWidthInteger where Self: ABICodable {
    init(fromAbi decoder: ABIDecoder) throws {
        var v = Self()
        try decoder.read(into: &v)
        self.init(littleEndian: v)
    }

    func abiEncode(to encoder: ABIEncoder) throws {
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

/// Like optional but only decoded if present at end of ABI stream.
public struct BinaryExtension<Value: ABICodable>: ABICodable {
    public let value: Value?

    public init(_ value: Value?) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.singleValueContainer()
        self.value = try? container?.decode(Value.self)
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        do {
            self.value = try decoder.decode(Value.self)
        } catch ABIDecoder.Error.prematureEndOfData {
            self.value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = self.value {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        if let value = self.value {
            try encoder.encode(value)
        }
    }
}

extension BinaryExtension: Equatable where Value: Equatable {}
extension BinaryExtension: Hashable where Value: Hashable {}

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

    private var abi: ABI?
    private var type: String?

    public init(_ value: Any, abi: ABI? = nil, type: String? = nil) {
        self.value = value
        self.abi = abi
        self.type = type
    }

    public init(from decoder: Decoder) throws {
        let def = try Self.getDefenitions(from: decoder.userInfo)
        self.value = try _decodeAny(def.type, from: decoder, using: def.abi)
    }

    public func encode(to encoder: Encoder) throws {
        if let type = self.type, let abi = self.abi {
            try _encodeAny(self.value, ofType: type, to: encoder, using: abi)
        } else {
            let def = try Self.getDefenitions(from: encoder.userInfo)
            try _encodeAny(self.value, ofType: def.type, to: encoder, using: def.abi)
        }
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
                        using abi: ABI) throws
{
    let rootType = abi.resolveType(type)
    try _encodeAny(value, to: encoder, usingType: rootType)
}

private func _encodeAny(_ value: Any,
                        to encoder: Encoder,
                        usingType type: ABI.ResolvedType) throws
{
    if let other = type.other {
        return try _encodeAny(value, to: encoder, usingType: other)
    }
    func encode(_ value: Any, _ encoder: Encoder) throws {
        if type.builtIn != nil {
            try _encodeAnyBuiltIn(value, to: encoder, usingType: type)
        } else if type.fields != nil {
            try _encodeAnyFields(value, to: encoder, usingType: type)
        } else if type.variant != nil {
            try _encodeAnyVariant(value, to: encoder, usingType: type)
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Encountered unknown type \(type)"
            ))
        }
    }
    if type.flags.contains(.optional) || type.flags.contains(.binaryExt) {
        let hasValue: Bool = !(value as Any?).isNil
        if type.flags.contains(.binaryExt), !hasValue {
            return
        }
        if let abiEncoder = encoder as? ABIEncoder {
            try abiEncoder.encode(hasValue)
        }
        if !hasValue {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
            return
        }
    }
    if type.flags.contains(.array) {
        guard let array = value as? [Any] else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Expected array"
            ))
        }
        if let abiEncoder = encoder as? ABIEncoder {
            abiEncoder.appendVarint(UInt64(array.count))
        }
        var container = encoder.unkeyedContainer()
        for value in array {
            try encode(value, container.superEncoder())
        }
    } else {
        try encode(value, encoder)
    }
}

private func _encodeAnyVariant(_ value: Any,
                               to encoder: Encoder,
                               usingType type: ABI.ResolvedType) throws
{
    guard let array = value as? [Any], array.count == 2, let name = array[0] as? String else {
        throw EncodingError.invalidValue(value, EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Expected variant array"
        ))
    }
    guard let typeIdx = type.variant!.firstIndex(where: { $0.name == name }) else {
        throw EncodingError.invalidValue(value, EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Unknown variant: \(name)"
        ))
    }
    let variantType = type.variant![typeIdx]
    if let abiEncoder = encoder as? ABIEncoder {
        try abiEncoder.encode(UInt8(typeIdx))
        try _encodeAny(array[1], to: abiEncoder, usingType: variantType)
    } else {
        var container = encoder.unkeyedContainer()
        try container.encode(variantType.name)
        try _encodeAny(array[1], to: container.superEncoder(), usingType: variantType)
    }
}

private func _encodeAnyFields(_ value: Any,
                              to encoder: Encoder,
                              usingType type: ABI.ResolvedType) throws
{
    guard let object = value as? [String: Any] else {
        throw EncodingError.invalidValue(value, EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Expected object"
        ))
    }
    var container = encoder.container(keyedBy: StringCodingKey.self)
    for field in type.fields! {
        let fieldEncoder = container.superEncoder(forKey: StringCodingKey(field.name))
        try _encodeAny(object[field.name] as Any, to: fieldEncoder, usingType: field.type)
    }
}

private func _encodeAnyBuiltIn(_ value: Any,
                               to encoder: Encoder,
                               usingType type: ABI.ResolvedType) throws
{
    func encode<T: Encodable>(_ builtInType: T.Type, _ setValue: Any) throws {
        try _encodeValue(setValue, builtInType, to: encoder)
    }
    func encodeS<T: Encodable & LosslessStringConvertible>(_ builtInType: T.Type, _ setValue: Any) throws {
        var val = setValue
        if let string = value as? String, let resolved = T(string) {
            val = resolved
        }
        try _encodeValue(val, builtInType, to: encoder)
    }
    switch type.builtIn! {
    case .string: try encode(String.self, value)
    case .int8: try encode(Int8.self, value)
    case .int16: try encode(Int16.self, value)
    case .int32: try encode(Int32.self, value)
    case .int64: try encode(Int64.self, value)
    case .uint8: try encode(UInt8.self, value)
    case .uint16: try encode(UInt16.self, value)
    case .uint32: try encode(UInt32.self, value)
    case .uint64: try encode(UInt64.self, value)
    case .varuint32: try encode(UInt.self, value)
    case .varint32: try encode(Int.self, value)
    case .name: try encodeS(Name.self, value)
    case .asset: try encodeS(Asset.self, value)
    case .extended_asset: try encode(ExtendedAsset.self, value)
    case .symbol: try encodeS(Asset.Symbol.self, value)
    case .symbol_code: try encodeS(Asset.Symbol.Code.self, value)
    case .checksum256: try encodeS(Checksum256.self, value)
    case .public_key: try encodeS(PublicKey.self, value)
    case .time_point: try encodeS(TimePoint.self, value)
    case .time_point_sec: try encodeS(TimePointSec.self, value)
    case .signature: try encodeS(Signature.self, value)
    case .bool: try encode(Bool.self, value)
    case .bytes: try encode(Data.self, value)
    case .float32: try encode(Float32.self, value)
    case .float64: try encode(Float64.self, value)
    }
}

private func _encodeValue<T: Encodable>(_ value: Any, _ builtinType: T.Type, to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    guard let resolvedValue = value as? T else {
        throw EncodingError.invalidValue(value as Any, EncodingError.Context(
            codingPath: container.codingPath,
            debugDescription: "Value not conforming to expected type: \(builtinType)"
        ))
    }
    try container.encode(resolvedValue)
}

func _decodeAny(_ type: String,
                from decoder: Decoder,
                using abi: ABI) throws -> Any
{
    let rootType = abi.resolveType(type)
    return try _decodeAny(rootType, from: decoder)
}

func _decodeAny(_ type: ABI.ResolvedType,
                from decoder: Decoder) throws -> Any
{
    if type.other != nil {
        return try _decodeAny(type.other!, from: decoder)
    }
    func decode(_ decoder: Decoder) throws -> Any {
        if let abiDecoder = decoder as? ABIDecoder {
            if type.flags.contains(.optional) {
                let exists = try abiDecoder.decode(Bool.self)
                guard exists else {
                    return nil as Any? as Any
                }
            }
            if type.flags.contains(.array) {
                let count = try abiDecoder.decode(UInt.self)
                var rv: [Any] = []
                for _ in 0..<count {
                    rv.append(try decodeInner(abiDecoder))
                }
                return rv
            } else {
                return try decodeInner(abiDecoder)
            }
        } else {
            if type.flags.contains(.array) {
                var container: UnkeyedDecodingContainer
                if type.flags.contains(.optional) {
                    guard let c = try? decoder.unkeyedContainer() else {
                        return nil as Any? as Any
                    }
                    container = c
                } else {
                    container = try decoder.unkeyedContainer()
                }
                var rv: [Any] = []
                while !container.isAtEnd {
                    rv.append(try decodeInner(try container.superDecoder()))
                }
                return rv
            } else {
                if type.flags.contains(.optional) {
                    guard let container = (try? decoder.singleValueContainer()), !container.decodeNil() else {
                        return nil as Any? as Any
                    }
                }
                return try decodeInner(decoder)
            }
        }
    }
    func decodeInner(_ decoder: Decoder) throws -> Any {
        if type.builtIn != nil {
            return try _decodeAnyBuiltIn(type, from: decoder)
        } else if type.fields != nil {
            return try _decodeAnyFields(type, from: decoder)
        } else if type.variant != nil {
            return try _decodeAnyVariant(type, from: decoder)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Encountered unknown type: \(type.name)"
            ))
        }
    }
    if type.flags.contains(.binaryExt) {
        do {
            return try decode(decoder)
        } catch ABIDecoder.Error.prematureEndOfData {
            return nil as Any? as Any
        }
    } else {
        return try decode(decoder)
    }
}

func _decodeAnyVariant(_ type: ABI.ResolvedType,
                       from decoder: Decoder) throws -> Any
{
    if let abiDecoder = decoder as? ABIDecoder {
        let idx = try abiDecoder.decode(UInt8.self)
        guard idx < type.variant!.count else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Variant index out of range"
            ))
        }
        let type = type.variant![Int(idx)]
        return [type.name, try _decodeAny(type, from: decoder)]
    } else {
        var container = try decoder.unkeyedContainer()
        let name = try container.decode(String.self)
        guard let type = type.variant!.first(where: { $0.name == name }) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown variant: \(name)"
            ))
        }
        return [name, try _decodeAny(type, from: try container.superDecoder())]
    }
}

func _decodeAnyFields(_ type: ABI.ResolvedType,
                      from decoder: Decoder) throws -> Any
{
    var object: [String: Any] = [:]
    let container = try decoder.container(keyedBy: StringCodingKey.self)
    for field in type.fields! {
        let fieldEncoder = try container.superDecoder(forKey: StringCodingKey(field.name))
        object[field.name] = try _decodeAny(field.type, from: fieldEncoder)
    }
    return object
}

func _decodeAnyBuiltIn(_ type: ABI.ResolvedType,
                       from decoder: Decoder) throws -> Any
{
    let container = try decoder.singleValueContainer()
    switch type.builtIn! {
    case .string: return try container.decode(String.self)
    case .name: return try container.decode(Name.self)
    case .asset: return try container.decode(Asset.self)
    case .extended_asset: return try container.decode(ExtendedAsset.self)
    case .symbol: return try container.decode(Asset.Symbol.self)
    case .symbol_code: return try container.decode(Asset.Symbol.Code.self)
    case .uint8: return try container.decode(UInt8.self)
    case .uint16: return try container.decode(UInt16.self)
    case .uint32: return try container.decode(UInt32.self)
    case .uint64: return try container.decode(UInt64.self)
    case .int8: return try container.decode(Int8.self)
    case .int16: return try container.decode(Int16.self)
    case .int32: return try container.decode(Int32.self)
    case .int64: return try container.decode(Int64.self)
    case .checksum256: return try container.decode(Checksum256.self)
    case .public_key: return try container.decode(PublicKey.self)
    case .time_point: return try container.decode(TimePoint.self)
    case .time_point_sec: return try container.decode(TimePointSec.self)
    case .varint32: return try container.decode(Int.self)
    case .varuint32: return try container.decode(UInt.self)
    case .bool:
        do {
            return try container.decode(Bool.self)
        } catch {
            // cleos encodes bools as numbers in json :'(
            return try container.decode(UInt8.self) != 0
        }
    case .bytes: return try container.decode(Data.self)
    case .signature: return try container.decode(Signature.self)
    case .float32: return try container.decode(Float32.self)
    case .float64: return try container.decode(Float64.self)
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
