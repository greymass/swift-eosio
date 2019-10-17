/// EOSIO ABI binary protocol encoding.
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// A type that can be encoded into EOSIO ABI binary format.
public protocol ABIEncodable: Encodable {
    /// Encode self into EOSIO ABI format.
    func abiEncode(to encoder: ABIEncoder) throws
}

/// Default implementation which calls through to `Encodable`.
public extension ABIEncodable {
    func abiEncode(to encoder: ABIEncoder) throws {
        try self.encode(to: encoder)
    }
}

/// Encodes conforming types into binary (EOSIO ABI) format.
public final class ABIEncoder {
    /// All errors which `ABIEncoder` can throw.
    public enum Error: Swift.Error {
        /// Thrown if encoder encounters a type that is not conforming to `ABIEncodable`.
        case typeNotConformingToAbiEncodable(Encodable.Type)
        /// Thrown if encoder encounters a type that is not confirming to `Encodable`.
        case typeNotConformingToEncodable(Any.Type)

        case typeNotFoundInABI(String)
    }

    /// Data buffer holding the encoded bytes.
    var data = Data()

    public var codingPath: [CodingKey] = []
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Create a new encoder.
    public init() {}

    /// Convenience for creating an encoder, encoding a value and returning the data.
    public static func encode(_ value: ABIEncodable) throws -> Data {
        let encoder = ABIEncoder()
        try value.abiEncode(to: encoder)
        return encoder.data
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        self.data = Data()
        try self.encode(value)
        return self.data
    }

    public func encode(_ value: UInt8) throws {
        self.data.append(value)
    }

    public func encode(_ value: Bool) throws {
        self.data.append(value ? 1 : 0)
    }

    public func encode(_ value: UInt) throws {
        var v = value
        while v > 127 {
            self.data.append(UInt8(v & 0x7F | 0x80))
            v >>= 7
        }
        self.data.append(UInt8(v))
    }

    public func encode<T: Sequence>(contentsOf sequence: T) throws where T.Element == UInt8 {
        self.data.append(contentsOf: sequence)
    }

    public func encode(contentsOf other: Data) throws {
        self.data.append(other)
    }

    public func encode(_ value: Encodable) throws {
        guard let abiValue = value as? ABIEncodable else {
            throw Error.typeNotConformingToAbiEncodable(type(of: value))
        }
        try abiValue.abiEncode(to: self)
    }

    /// Append variable integer to encoder buffer.
    func appendVarint(_ value: UInt64) {
        var v = value
        while v > 127 {
            self.data.append(UInt8(v & 0x7F | 0x80))
            v >>= 7
        }
        self.data.append(UInt8(v))
    }

    /// Append the raw bytes of the parameter to the encoder's data.
    func appendBytes<T>(of value: T) {
        var v = value
        withUnsafeBytes(of: &v) {
            data.append(contentsOf: $0)
        }
    }
}

// MARK: Encoder conformance

extension ABIEncoder: Encoder {
    public func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        return KeyedEncodingContainer(KeyedContainer<Key>(encoder: self))
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContanier(encoder: self)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return UnkeyedContanier(encoder: self)
    }

    private struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var encoder: ABIEncoder

        var codingPath: [CodingKey] { return [] }

        func encode<T>(_ value: T, forKey _: Key) throws where T: Encodable {
            try self.encoder.encode(value)
        }

        func encodeNil(forKey _: Key) throws {}

        // need to implement all specialized versions of encodeIfPresent for some reason
        // otherwise optionals will not carry through

        func encodeIfPresent(_ value: String?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Bool?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Double?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Float?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Int?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: UInt?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Int8?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Int16?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Int32?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: Int64?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: UInt8?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: UInt16?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: UInt32?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent(_ value: UInt64?, forKey _: Key) throws {
            try self.encoder.encode(value)
        }

        func encodeIfPresent<T>(_ value: T?, forKey _: Key) throws where T: Encodable {
            try self.encoder.encode(value)
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey _: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            return self.encoder.container(keyedBy: keyType)
        }

        func nestedUnkeyedContainer(forKey _: Key) -> UnkeyedEncodingContainer {
            return self.encoder.unkeyedContainer()
        }

        func superEncoder() -> Encoder {
            return self.encoder
        }

        func superEncoder(forKey _: Key) -> Encoder {
            return self.encoder
        }
    }

    private struct UnkeyedContanier: UnkeyedEncodingContainer, SingleValueEncodingContainer {
        var encoder: ABIEncoder

        var codingPath: [CodingKey] { return self.encoder.codingPath }

        var count: Int { return 0 }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            return self.encoder.container(keyedBy: keyType)
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            return self
        }

        func superEncoder() -> Encoder {
            return self.encoder
        }

        func encodeNil() throws {}

        func encode<T>(_ value: T) throws where T: Encodable {
            try self.encoder.encode(value)
        }
    }
}

// MARK: Default type encodings

//
// extension Array: ABIEncodable where Element: Encodable {
//    public func abiEncode(to encoder: ABIEncoder) throws {
//        encoder.appendVarint(UInt64(count))
//        for item in self {
//            try encoder.encode(item)
//        }
//    }
// }

// extension OrderedDictionary: AbiEncodable where Key: AbiEncodable, Value: AbiEncodable {
//    public func binaryEncode(to encoder: ABIEncoder) throws {
//        encoder.appendVarint(UInt64(self.count))
//        for (key, value) in self {
//            try encoder.encode(key)
//            try encoder.encode(value)
//        }
//    }
// }

// extension Date: ABIEncodable {
//    public func abiEncode(to encoder: ABIEncoder) throws {
//        try encoder.encode(UInt32(timeIntervalSince1970))
//    }
// }
