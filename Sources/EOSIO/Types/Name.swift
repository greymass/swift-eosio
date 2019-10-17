/// EOSIO name type
/// - Author: Johan Nordberg <code@johan-nordberg.com>

import Foundation

/// Type representing a EOSIO name.
public struct Name: Equatable, Hashable {
    private static let charMap: [Character] = Array(".12345abcdefghijklmnopqrstuvwxyz")

    /// The raw value of the name.
    public var rawValue: UInt64

    /// Create a new name.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Create a new name from string.
    public init(stringValue name: String) {
        var v: UInt64 = 0
        for (i, c) in name.prefix(12).enumerated() {
            v |= UInt64(c.nameSymbol & 0x1F) << (64 - 5 * (i + 1))
        }
        if name.count > 12 {
            let c = name[name.index(name.startIndex, offsetBy: 12)]
            v |= UInt64(c.nameSymbol & 0x0F)
        }
        self.rawValue = v
    }

    /// String representation of this name.
    public var stringValue: String {
        if self.rawValue == 0 {
            return "............."
        }
        var str = String()
        var tmp = self.rawValue
        for i in 0...12 {
            let c = Self.charMap[Int(tmp & (i == 0 ? 0x0F : 0x1F))]
            str.append(c)
            tmp >>= (i == 0 ? 4 : 5)
        }
        return String(str.drop { $0 == "." }.reversed())
    }
}

// MARK: ABI Coding

extension Name: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(stringValue: try container.decode(String.self))
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UInt64.self))
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

extension Name: LosslessStringConvertible {
    public init(_ description: String) {
        self.init(stringValue: description)
    }

    public var description: String {
        return self.stringValue
    }
}

extension Name: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(stringValue: value)
    }
}

extension Name: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.init(rawValue: value)
    }
}

// MARK: -

private extension Character {
    var nameSymbol: UInt8 {
        guard let c = self.asciiValue else {
            return 0
        }
        // a = 97, z = 122
        if c >= 97, c <= 122 {
            return (c - 97) + 6
        }
        // 1 = 49, 5 = 53
        if c >= 49, c <= 53 {
            return (c - 49) + 1
        }
        return 0
    }
}
