/// EOSIO asset type
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import CoreFoundation
import Foundation

/// The EOSIO asset type.
public struct Asset: Equatable, Hashable {
    /// All errors which `Asset` can throw.
    public enum Error: Swift.Error {
        case invalidAssetString(message: String)
    }

    /// Create new asset with floating point value and symbol.
    public init(_ value: Double, _ symbol: Symbol) {
        self.symbol = symbol
        self.units = symbol.convert(value)
    }

    /// Create new asset with symbol unit count and symbol.
    public init(units: Int64, symbol: Symbol) {
        self.symbol = symbol
        self.units = units
    }

    /// Create new asset from string, e.g. `1.23 COIN`.
    public init(stringValue: String) throws {
        let parts = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        if parts.count != 2 {
            throw Error.invalidAssetString(message: "Amount and symbol should be separated by a space")
        }
        let formattedValue = parts.first!
        var precision: UInt8 = 0
        if let index = formattedValue.firstIndex(of: ".") {
            let d = formattedValue.distance(from: index, to: formattedValue.endIndex)
            if d == 1 {
                throw Error.invalidAssetString(message: "Missing decimal fraction after decimal point")
            }
            precision = UInt8(d - 1)
        }
        let symbol = try Symbol(precision, String(parts.last!))
        guard let value = Double(formattedValue) else {
            throw Error.invalidAssetString(message: "Unable to parse amount")
        }
        self.init(value, symbol)
    }

    /// The asset symbol.
    public var symbol: Symbol

    /// The asset units.
    /// - Note: This represents numer of  _symbol units_, e.g. for a symbol with presicion 4 incrementing amount by 1 results in a increase of `0.0001`.
    ///         See `Asset.value` for the real number value.
    public var units: Int64

    /// The real asset amount.
    /// - Attention: Assignment will loose presicion according to the asset symbol presicion.
    ///              E.g. with a symbol of `4,EOS` assigning `0.000199` will result in `0.0001`.
    public var value: Double {
        get {
            return self.symbol.convert(self.units)
        }
        set {
            self.units = self.symbol.convert(newValue)
        }
    }

    /// String representing the asset value formatted according to symbol presicion.
    public var formattedValue: String {
        self.symbol.formatter.string(from: NSNumber(value: self.value))!
    }

    /// String representation of this asset.
    public var stringValue: String {
        return "\(self.formattedValue) \(self.symbol.name)"
    }
}

// MARK: Asset Symbol

public extension Asset {
    /// Asset symbol type, containing the symbol name and precision.
    struct Symbol: Equatable, Hashable {
        public static let maxPrecision: UInt8 = 18
        public static let validNameCharacters = CharacterSet(charactersIn: "A"..."Z")

        /// All errors which `Asset.Symbol` can throw.
        public enum Error: Swift.Error {
            case invalidSymbolName(message: String)
            case invalidSymbolPrecision(message: String)
            case invalidSymbolString(message: String)
        }

        /// The raw value of the symbol, first byte is precision rest is symbol name as ascii.
        public let rawValue: UInt64

        /// Create a new `Asset.Symbol` with a raw value.
        /// - Parameter rawSymbol: The raw value of the symbol.
        /// - Note: Normally not used directly, see the other constructors.
        public init(rawSymbol: UInt64) throws {
            self.rawValue = rawSymbol
            if self.precision > Self.maxPrecision {
                throw Error.invalidSymbolPrecision(message: "Must be \(Self.maxPrecision) or less")
            }
            let name = self.name
            if name.isEmpty {
                throw Error.invalidSymbolName(message: "Can not be empty")
            }
            let usedChars = CharacterSet(charactersIn: name)
            guard usedChars.isSubset(of: Self.validNameCharacters) else {
                throw Error.invalidSymbolName(message: "Invalid character")
            }
        }

        /// Create a new `Asset.Symbol` from precision and symbol name.
        /// - Parameter precision: Number of decimals in symbol, e.g. `4` for a symbol that can represent `0.0001`.
        ///                        Biggest allowed precision is `18` (`0.0000000000000000001`).
        /// - Parameter name: Name of the symbol, e.g. `EOS`. May only include the uppercase characters  A-Z.
        public init(_ precision: UInt8, _ name: String) throws {
            var bytes = name.compactMap { $0.asciiValue }
            if bytes.count != name.count {
                throw Error.invalidSymbolName(message: "Encountered non-ascii character")
            }
            bytes.insert(precision, at: 0)
            while bytes.count < 8 { bytes.append(0) }
            let value = bytes.withUnsafeBytes { CFSwapInt64LittleToHost($0.load(as: UInt64.self)) }
            try self.init(rawSymbol: value)
        }

        /// Create a new `Asset.Symbol` from a string representation.
        /// - Parameter stringValue: String to parse into symbol, e.g. `4,EOS`.
        public init(stringValue: String) throws {
            let parts = stringValue.split(separator: ",")
            guard parts.count == 2 else {
                throw Error.invalidSymbolString(message: "Missing comma")
            }
            guard let precision = UInt8(parts.first!) else {
                throw Error.invalidSymbolString(message: "Precision must be an 8-bit integer")
            }
            let name = String(parts.last!)
            try self.init(precision, name)
        }

        /// The precision (how many decimal points) this symbol has.
        public var precision: UInt8 {
            return UInt8(self.rawValue & 0xFF)
        }

        /// The name of this symbol.
        public var name: String {
            let asciiBytes = withUnsafeBytes(of: self.rawValue.bigEndian) { Data($0) }
                .drop { $0 == 0 } // remove trailing zeroes
                .dropLast() // remove precision
                .reversed()
            return String(bytes: asciiBytes, encoding: .ascii)!
        }

        /// String representation of symbol.
        public var stringValue: String {
            return "\(self.precision),\(self.name)"
        }

        /// The symbol code.
        public var symbolCode: UInt64 {
            return self.rawValue >> 8
        }

        /// Number formatter configured to display numbers with this symbols precision.
        public var formatter: NumberFormatter {
            let digits = Int(self.precision)
            let formatter = NumberFormatter()
            formatter.decimalSeparator = "."
            formatter.usesGroupingSeparator = false
            formatter.minimumIntegerDigits = 1
            formatter.minimumFractionDigits = digits
            formatter.maximumFractionDigits = digits
            return formatter
        }

        /// Convert units to value according to symbol precision.
        public func convert(_ units: Int64) -> Double {
            return Double(units) / pow(10, Double(self.precision))
        }

        /// Convert value to units according to symbol precision.
        public func convert(_ value: Double) -> Int64 {
            return Int64(value * pow(10, Double(self.precision)))
        }
    }
}

public extension Asset.Symbol {
    /// Asset symbol code, e.g. `EOS`.
    struct Code: Equatable, Hashable {
        /// The underlying value
        public let rawValue: UInt64

        public init(rawValue: UInt64) throws {
            self.rawValue = rawValue
            guard self.rawStringValue != nil else {
                throw Error.invalidSymbolName(message: "Encountered non-ascii character")
            }
        }

        public init(stringValue: String) throws {
            var bytes = stringValue.compactMap { $0.asciiValue }
            if bytes.count != stringValue.count {
                throw Error.invalidSymbolName(message: "Encountered non-ascii character")
            }
            while bytes.count < 8 { bytes.append(0) }
            self.rawValue = bytes.withUnsafeBytes { UInt64(littleEndian: $0.load(as: UInt64.self)) }
        }

        private var rawStringValue: String? {
            let asciiBytes = withUnsafeBytes(of: self.rawValue.bigEndian) { Data($0) }
                .drop { $0 == 0 } // remove trailing zeroes
                .reversed()
            return String(bytes: asciiBytes, encoding: .ascii)
        }

        public var stringValue: String {
            self.rawStringValue!
        }
    }
}

public struct ExtendedAsset: ABICodable, Equatable, Hashable {
    public var quantity: Asset
    public var contract: Name

    public init(quantity: Asset, contract: Name) {
        self.quantity = quantity
        self.contract = contract
    }
}

// MARK: ABI Coding

extension Asset: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(stringValue: try container.decode(String.self))
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(units: try container.decode(Int64.self), symbol: try container.decode(Symbol.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.units)
        try container.encode(self.symbol)
    }
}

extension Asset.Symbol: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(stringValue: try container.decode(String.self))
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(rawSymbol: try container.decode(UInt64.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension Asset.Symbol.Code: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(stringValue: try container.decode(String.self))
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        var container = try decoder.unkeyedContainer()
        try self.init(rawValue: try container.decode(UInt64.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: Language extensions

extension Asset: ExpressibleByStringLiteral {
    /// Creates an instance initialized to the given string value.
    public init(stringLiteral value: String) {
        guard let asset = try? Self(stringValue: value) else {
            fatalError("Invalid Asset literal")
        }
        self = asset
    }
}

extension Asset.Symbol: ExpressibleByStringLiteral {
    /// Creates an instance initialized to the given string value.
    public init(stringLiteral value: String) {
        guard let symbol = try? Self(stringValue: value) else {
            fatalError("Invalid Symbol literal")
        }
        self = symbol
    }
}

extension Asset: LosslessStringConvertible {
    public init?(_ description: String) {
        if let symbol = try? Self(stringValue: description) {
            self = symbol
        } else {
            return nil
        }
    }

    public var description: String {
        return self.stringValue
    }
}

extension Asset.Symbol: LosslessStringConvertible {
    public init?(_ description: String) {
        if let symbol = try? Self(stringValue: description) {
            self = symbol
        } else {
            return nil
        }
    }

    public var description: String {
        return self.stringValue
    }
}

extension Asset.Symbol.Code: LosslessStringConvertible {
    public init?(_ description: String) {
        if let symbol = try? Self(stringValue: description) {
            self = symbol
        } else {
            return nil
        }
    }

    public var description: String {
        return self.stringValue
    }
}

extension Asset.Symbol: RawRepresentable {
    public init?(rawValue: UInt64) {
        guard let instance = try? Self(rawSymbol: rawValue) else {
            return nil
        }
        self = instance
    }
}

extension Asset: Comparable {
    public static func < (lhs: Asset, rhs: Asset) -> Bool {
        assert(lhs.symbol == rhs.symbol, "comparing assets with different symbols")
        return lhs.units < rhs.units
    }
}

public extension Asset {
    static func += (lhs: inout Asset, rhs: Asset) {
        assert(lhs.symbol == rhs.symbol, "adding assets with different symbols")
        lhs.units += rhs.units
    }

    static func -= (lhs: inout Asset, rhs: Asset) {
        assert(lhs.symbol == rhs.symbol, "subtracting assets with different symbols")
        lhs.units -= rhs.units
    }

    static func *= (lhs: inout Asset, rhs: Asset) {
        assert(lhs.symbol == rhs.symbol, "multiplying assets with different symbols")
        lhs.value *= rhs.value
    }

    static func /= (lhs: inout Asset, rhs: Asset) {
        assert(lhs.symbol == rhs.symbol, "dividing assets with different symbols")
        lhs.value /= rhs.value
    }

    static func + (lhs: Asset, rhs: Asset) -> Asset {
        assert(lhs.symbol == rhs.symbol, "adding assets with different symbols")
        return Asset(units: lhs.units + rhs.units, symbol: lhs.symbol)
    }

    static func - (lhs: Asset, rhs: Asset) -> Asset {
        assert(lhs.symbol == rhs.symbol, "subtracting assets with different symbols")
        return Asset(units: lhs.units - rhs.units, symbol: lhs.symbol)
    }

    static func * (lhs: Asset, rhs: Asset) -> Asset {
        assert(lhs.symbol == rhs.symbol, "multiplying assets with different symbols")
        return Asset(lhs.value * rhs.value, lhs.symbol)
    }

    static func / (lhs: Asset, rhs: Asset) -> Asset {
        assert(lhs.symbol == rhs.symbol, "dividing assets with different symbols")
        return Asset(lhs.value / rhs.value, lhs.symbol)
    }

    static func += (lhs: inout Asset, rhs: Double) {
        lhs.value += rhs
    }

    static func -= (lhs: inout Asset, rhs: Double) {
        lhs.value -= rhs
    }

    static func *= (lhs: inout Asset, rhs: Double) {
        lhs.value *= rhs
    }

    static func /= (lhs: inout Asset, rhs: Double) {
        lhs.value /= rhs
    }

    static func + (lhs: Asset, rhs: Double) -> Asset {
        return Asset(lhs.value + rhs, lhs.symbol)
    }

    static func - (lhs: Asset, rhs: Double) -> Asset {
        return Asset(lhs.value - rhs, lhs.symbol)
    }

    static func * (lhs: Asset, rhs: Double) -> Asset {
        return Asset(lhs.value * rhs, lhs.symbol)
    }

    static func / (lhs: Asset, rhs: Double) -> Asset {
        return Asset(lhs.value / rhs, lhs.symbol)
    }
}
