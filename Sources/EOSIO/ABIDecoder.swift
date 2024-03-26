
import CoreFoundation
import Foundation

/// A protocol for types which can be decoded from binary ABI format.
public protocol ABIDecodable: Decodable {
    init(fromAbi decoder: ABIDecoder) throws
}

/// Provide a default implementation which calls through to `Decodable`.
/// This allows `ABIDecodable` to use the `Decodable` implementation generated by the compiler.
public extension ABIDecodable {
    init(fromAbi decoder: ABIDecoder) throws {
        try self.init(from: decoder)
    }
}

/// The EOSIO ABI decoder class.
public final class ABIDecoder {
    private var data = Data()
    private var cursor = 0

    public var codingPath: [CodingKey] = []
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    // TODO: split decoder into private and public class
    public func decode<T: Decodable>(_: T.Type, from data: Data) throws -> T {
        self.data = Data(data)
        self.cursor = 0
        return try self.decode(T.self)
    }
}

/// A convenience function for creating a decoder from some data and decoding it
/// into a value all in one shot.
public extension ABIDecoder {
    static func decode<T: ABIDecodable>(_: T.Type, data: Data) throws -> T {
        return try ABIDecoder().decode(T.self, from: data)
    }
}

/// The error type.
public extension ABIDecoder {
    /// All errors which `ABIDecoder` itself can throw.
    enum Error: Swift.Error {
        /// The decoder hit the end of the data while the values it was decoding expected more.
        case prematureEndOfData

        /// Attempted to decode a type which is `Decodable`, but not `ABIDecodable`.
        case typeNotConformingToABIDecodable(Decodable.Type)

        /// Attempted to decode a type which is not `Decodable`.
        case typeNotConformingToDecodable(Any.Type)

        /// Attempted to decode an `Int` which can't be represented. This happens in 32-bit
        /// code when the stored `Int` doesn't fit into 32 bits.
        case intOutOfRange(Int64)

        /// Attempted to decode a `UInt` which can't be represented. This happens in 32-bit
        /// code when the stored `UInt` doesn't fit into 32 bits.
        case uintOutOfRange(UInt64)

        /// Attempted to decode a `Bool` where the byte representing it was not a `1` or a `0`.
        case boolOutOfRange(UInt8)

        /// Attempted to decode a `String` but the encoded `String` data was not valid UTF-8.
        case invalidUTF8(Data)

        case unknownVariant(UInt8)
    }
}

/// Methods for decoding various types.
public extension ABIDecoder {
    func decode(_: Bool.Type) throws -> Bool {
        switch try self.decode(UInt8.self) {
        case 0: return false
        case 1: return true
        case let x: throw Error.boolOutOfRange(x)
        }
    }

    func decode(_: Float.Type) throws -> Float {
        var float = Float(0)
        try read(into: &float)
        return float
    }

    func decode(_: Double.Type) throws -> Double {
        var double = Double(0)
        try read(into: &double)
        return double
    }

    func decode(_: Data.Type, byteCount: Int?) throws -> Data {
        if let count = byteCount {
            return try self.readData(count)
        } else {
            return try self.readData(Int(try self.decode(UInt.self)))
        }
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        switch type {
        case is Int.Type:
            return Int(try self.readVarint()) as! T
        case is UInt.Type:
            return UInt(try self.readVaruint()) as! T
        case let abiType as ABIDecodable.Type:
            return try abiType.init(fromAbi: self) as! T
        default:
            throw Error.typeNotConformingToABIDecodable(type)
        }
    }

    /// Read the appropriate number of raw bytes directly into the given value.
    /// - NOTE: No byte swapping or other postprocessing is done.
    func read<T>(into: inout T) throws {
        try self.read(MemoryLayout<T>.size, into: &into)
    }
}

/// Internal methods for decoding raw data.
private extension ABIDecoder {
    /// Read the given number of bytes into the given pointer, advancing the cursor
    /// appropriately.
    func read(_ byteCount: Int, into: UnsafeMutableRawPointer) throws {
        if self.cursor + byteCount > self.data.count {
            throw Error.prematureEndOfData
        }

        self.data.withUnsafeBytes {
            let from = $0.baseAddress! + cursor
            memcpy(into, from, byteCount)
        }

        self.cursor += byteCount
    }

    func readData(_ byteCount: Int) throws -> Data {
        if self.cursor + byteCount > self.data.count {
            throw Error.prematureEndOfData
        }
        let data = self.data.subdata(in: self.cursor..<self.cursor + byteCount)
        self.cursor += byteCount
        return data
    }

    func readByte() throws -> UInt8 {
        if self.cursor + 1 > self.data.count {
            throw Error.prematureEndOfData
        }
        let byte = self.data[self.cursor]
        self.cursor += 1
        return byte
    }

    func readVarint() throws -> Int32 {
        var v: UInt32 = 0, b: UInt8 = 0, by: UInt32 = 0
        repeat {
            b = try self.readByte()
            v |= UInt32(b & 0x7F) << by
            by += 7
        } while b & 0x80 != 0
        return Int32(bitPattern: v)
    }

    func readVaruint() throws -> UInt32 {
        var v: UInt64 = 0, b: UInt8 = 0, by: UInt8 = 0
        repeat {
            b = try self.readByte()
            v |= UInt64(UInt32(b & 0x7F) << by)
            by += 7
        } while (b & 0x80) != 0 && by < 32
        return UInt32(v)
    }
}

extension ABIDecoder: Decoder {
    public func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return KeyedDecodingContainer(KeyedContainer<Key>(decoder: self))
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UnkeyedContainer(decoder: self)
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return UnkeyedContainer(decoder: self)
    }

    private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var decoder: ABIDecoder

        var codingPath: [CodingKey] { return [] }

        var allKeys: [Key] { return [] }

        func contains(_: Key) -> Bool {
            return true
        }

        func decode<T>(_: T.Type, forKey _: Key) throws -> T where T: Decodable {
            return try self.decoder.decode(T.self)
        }

        func decodeNil(forKey _: Key) throws -> Bool {
            return true
        }

        func decodeIfPresent(_: String.Type, forKey _: Key) throws -> String? {
            return try self.decoder.decode(String?.self)
        }

        func decodeIfPresent(_: Bool.Type, forKey _: Key) throws -> Bool? {
            return try self.decoder.decode(Bool?.self)
        }

        func decodeIfPresent(_: Double.Type, forKey _: Key) throws -> Double? {
            return try self.decoder.decode(Double?.self)
        }

        func decodeIfPresent(_: Float.Type, forKey _: Key) throws -> Float? {
            return try self.decoder.decode(Float?.self)
        }

        func decodeIfPresent(_: Int.Type, forKey _: Key) throws -> Int? {
            return try self.decoder.decode(Int?.self)
        }

        func decodeIfPresent(_: UInt.Type, forKey _: Key) throws -> UInt? {
            return try self.decoder.decode(UInt?.self)
        }

        func decodeIfPresent(_: Int8.Type, forKey _: Key) throws -> Int8? {
            return try self.decoder.decode(Int8?.self)
        }

        func decodeIfPresent(_: Int16.Type, forKey _: Key) throws -> Int16? {
            return try self.decoder.decode(Int16?.self)
        }

        func decodeIfPresent(_: Int32.Type, forKey _: Key) throws -> Int32? {
            return try self.decoder.decode(Int32?.self)
        }

        func decodeIfPresent(_: Int64.Type, forKey _: Key) throws -> Int64? {
            return try self.decoder.decode(Int64?.self)
        }

        func decodeIfPresent(_: UInt8.Type, forKey _: Key) throws -> UInt8? {
            return try self.decoder.decode(UInt8?.self)
        }

        func decodeIfPresent(_: UInt16.Type, forKey _: Key) throws -> UInt16? {
            return try self.decoder.decode(UInt16?.self)
        }

        func decodeIfPresent(_: UInt32.Type, forKey _: Key) throws -> UInt32? {
            return try self.decoder.decode(UInt32?.self)
        }

        func decodeIfPresent(_: UInt64.Type, forKey _: Key) throws -> UInt64? {
            return try self.decoder.decode(UInt64?.self)
        }

        func decodeIfPresent<T>(_: T.Type, forKey _: Key) throws -> T? where T: Decodable {
            return try self.decoder.decode(T?.self)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey _: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            return try self.decoder.container(keyedBy: type)
        }

        func nestedUnkeyedContainer(forKey _: Key) throws -> UnkeyedDecodingContainer {
            return try self.decoder.unkeyedContainer()
        }

        func superDecoder() throws -> Decoder {
            return self.decoder
        }

        func superDecoder(forKey _: Key) throws -> Decoder {
            return self.decoder
        }
    }

    private struct UnkeyedContainer: UnkeyedDecodingContainer, SingleValueDecodingContainer {
        var decoder: ABIDecoder

        var codingPath: [CodingKey] { return [] }

        var count: Int? { return nil }

        var currentIndex: Int { return 0 }

        var isAtEnd: Bool { return false }

        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            return try self.decoder.decode(type)
        }

        func decodeNil() -> Bool {
            return true
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            return try self.decoder.container(keyedBy: type)
        }

        func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            return self
        }

        func superDecoder() throws -> Decoder {
            return self.decoder
        }
    }
}
