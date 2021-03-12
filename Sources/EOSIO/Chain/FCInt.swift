
/// Codable integer type that encodes to strings for values above 0xFFFFFF.
///
/// Behaves exactly like the wrapped integer type but potentially at a performance cost so use the underlying `value` property if using it in a performance critical application.
/// This is needed because nodeos (or more precisely `fc` the library nodeos relies on for json encoding its structs) thinks its a good idea to encode numbers as strings when
/// they exceed `0xFFFFFFFF` (UInt32.max), this is presumably done so that JavaScript JSON decoders won't loose precision for values larger than 52-bit.
public struct FCInt<Wrapped>: Equatable, Codable where Wrapped: ExpressibleByIntegerLiteral & Comparable & Codable & LosslessStringConvertible {
    public var value: Wrapped

    init(_ value: Wrapped) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Wrapped.self) {
            self.value = value
        } else {
            guard let value = Wrapped(try container.decode(String.self)) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Invalid integer value, expected number or string"
                )
            }
            self.value = value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if self.value > 0xFFFF_FFFF {
            try container.encode(String(self.value))
        } else {
            try container.encode(self.value)
        }
    }
}

// Don't encode as string when used in ABI.
extension FCInt: ABICodable {
    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Wrapped.self)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}

// Protocol conformances

extension FCInt: Hashable where Wrapped: Hashable {}
extension FCInt: Comparable where Wrapped: Comparable {
    public static func < (lhs: FCInt<Wrapped>, rhs: FCInt<Wrapped>) -> Bool {
        lhs.value < rhs.value
    }
}

extension FCInt: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Wrapped.IntegerLiteralType) {
        self.value = Wrapped(integerLiteral: value)
    }
}

extension FCInt: AdditiveArithmetic where Wrapped: AdditiveArithmetic {
    public static func + (lhs: FCInt<Wrapped>, rhs: FCInt<Wrapped>) -> FCInt<Wrapped> {
        FCInt(lhs.value + rhs.value)
    }

    public static func - (lhs: FCInt<Wrapped>, rhs: FCInt<Wrapped>) -> FCInt<Wrapped> {
        FCInt(lhs.value - rhs.value)
    }
}

extension FCInt: Strideable where Wrapped: Strideable {
    public func advanced(by n: Wrapped.Stride) -> FCInt<Wrapped> {
        FCInt(self.value.advanced(by: n))
    }

    public func distance(to other: FCInt<Wrapped>) -> Wrapped.Stride {
        self.value.distance(to: other.value)
    }
}

extension FCInt: Numeric where Wrapped: Numeric {
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let value = Wrapped(exactly: source) else {
            return nil
        }
        self.value = value
    }

    public static func * (lhs: FCInt<Wrapped>, rhs: FCInt<Wrapped>) -> FCInt<Wrapped> {
        FCInt(lhs.value * rhs.value)
    }

    public static func *= (lhs: inout FCInt<Wrapped>, rhs: FCInt<Wrapped>) {
        lhs.value *= rhs.value
    }

    public var magnitude: Wrapped.Magnitude {
        self.value.magnitude
    }
}

extension FCInt: LosslessStringConvertible where Wrapped: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let value = Wrapped(description) else {
            return nil
        }
        self.value = value
    }

    public var description: String {
        self.value.description
    }
}
