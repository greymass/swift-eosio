
import Foundation

/// Microsecond resolution timestamp since epoch.
public struct TimePoint: ABICodable, Equatable, Hashable {
    var value: Int64
}

/// ISO8601-ish formatter used to format EOSIO timestamps.
public class TimePointFormatter: DateFormatter {
    public override init() {
        super.init()
        self.configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.configure()
    }

    internal func configure() {
        self.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        self.timeZone = TimeZone(secondsFromGMT: 0)
        self.locale = Locale(identifier: "en_US_POSIX")
    }
}

/// Type representing a timestap with second accuracy.
public struct TimePointSec: Equatable, Hashable {
    static let dateFormatter = TimePointFormatter()

    /// Seconds sinze 1970.
    var value: UInt32

    init(_ timestamp: UInt32) {
        self.value = timestamp
    }

    public init?(_ date: String) {
        guard let date = Self.dateFormatter.date(from: date) else {
            return nil
        }
        self.value = UInt32(date.timeIntervalSince1970)
    }

    var date: Date {
        return Date(timeIntervalSince1970: TimeInterval(self.value))
    }

    var stringValue: String {
        return Self.dateFormatter.string(from: self.date)
    }
}

// MARK: ABI Coding

extension TimePointSec: ABICodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let instance = Self(try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unable to decode date"
            )
        }
        self = instance
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(UInt32.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.stringValue)
    }

    public func abiEncode(to encoder: ABIEncoder) throws {
        try encoder.encode(self.value)
    }
}

// MARK: Language extensions

extension TimePointSec: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = TimePointSec(value) ?? TimePointSec(0)
    }
}

extension TimePointSec: LosslessStringConvertible {
    public var description: String {
        return self.stringValue
    }
}
