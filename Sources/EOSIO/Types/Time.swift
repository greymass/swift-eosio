
import Foundation

/// Microsecond resolution timestamp since epoch.
public struct TimePoint: ABICodable, Equatable, Hashable {
    var value: Int64
}

/// Type representing a timestap with second accuracy.
public struct TimePointSec: ABICodable, Equatable, Hashable {
    static var dateFormatter: DateFormatter {
        print("Y U NO LAZY?")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// Seconds sinze 1970.
    var value: UInt32

    init(_ timestamp: UInt32) {
        self.value = timestamp
    }

    init?(_ date: String) {
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

extension TimePointSec {
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
